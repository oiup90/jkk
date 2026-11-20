import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:growth_circle/delete_account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:growth_circle/main.dart';
import 'package:growth_circle/password_policy.dart';
import 'package:growth_circle/user_saved_login.dart';

void main() {
  test('generated passwords satisfy policy and vary', () {
    final values = {for (var i = 0; i < 100; i++) generateStrongPassword()};
    expect(values.length, 100);
    for (final value in values) {
      expect(value.length, 20);
      expect(meetsPasswordPolicy(value), isTrue);
    }
  });
  test('saved credentials are scoped and can be forgotten', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = UserSavedLogin('https://project.example');
    await store.save('member@example.test', 'A-secret-password9!');
    expect((await store.load())?['email'], 'member@example.test');
    expect(await UserSavedLogin('https://other.example').load(), isNull);
    await store.forget();
    expect(await store.load(), isNull);
  });
  testWidgets('email tap offers encrypted login and fills both fields', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = UserSavedLogin('https://example.test');
    await store.save('user@example.test', 'Abcd12345678!');
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(actions: AuthActions(), savedLogin: store),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('email')));
    await tester.tap(find.byKey(const Key('email')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use saved login'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byKey(const Key('email'))).controller!.text,
      'user@example.test',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('password')))
          .controller!
          .text,
      'Abcd12345678!',
    );
    expect(
      tester.widget<TextField>(find.byKey(const Key('password'))).obscureText,
      isTrue,
    );
  });
  testWidgets('signup generates a policy-compliant password', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(actions: AuthActions())),
    );
    final register = find.textContaining('Create an account');
    // Use the existing sign-up switch label from the app translations.
    final switcher = find.text(
      tr(tester.element(find.byType(AuthScreen)), 'noAccount'),
    );
    await tester.ensureVisible(switcher);
    await tester.tap(switcher);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Generate strong password'));
    await tester.tap(find.text('Generate strong password'));
    await tester.pump();
    expect(
      meetsPasswordPolicy(
        tester
            .widget<TextField>(find.byKey(const Key('password')))
            .controller!
            .text,
      ),
      isTrue,
    );
    expect(register, findsNothing);
  });
  testWidgets('Add coins opens coming soon without a checkout', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BalanceCard(
            uid: 'test',
            balanceStream: Stream.value([
              {'balance': 10},
            ]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add coins'));
    await tester.tap(find.text('Add coins'));
    await tester.pumpAndSettle();
    expect(find.text('Service coming soon'), findsOneWidget);
  });
  testWidgets(
    'deletion requests email proof and never deletes on an invalid code',
    (tester) async {
      var calls = 0;
      final client = SupabaseClient(
        'https://example.test',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/delete_my_account')) {
            calls++;
            return http.Response(
              '"otp_required"',
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(() {
        client.dispose();
      });
      final token =
          'e30.${base64Url.encode(utf8.encode(jsonEncode({'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600}))).replaceAll('=', '')}.c2ln';
      await client.auth.setInitialSession(
        jsonEncode({
          'access_token': token,
          'refresh_token': 'synthetic-refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': '11111111-1111-4111-8111-111111111111',
            'aud': 'authenticated',
            'email': 'synthetic@example.test',
            'created_at': '2026-01-01T00:00:00Z',
            'app_metadata': {},
            'user_metadata': {},
          },
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DeleteAccountPage(
            client: client,
            savedLogin: UserSavedLogin('https://example.test'),
          ),
        ),
      );
      expect(find.text('Delete my account permanently'), findsNothing);
      await tester.tap(find.text('Send confirmation code'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '123456');
      await tester.ensureVisible(find.text('Delete my account permanently'));
      await tester.tap(find.text('Delete my account permanently'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        find.text('Code invalid or expired. Request a new code.'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '),
      );
    },
  );
}
