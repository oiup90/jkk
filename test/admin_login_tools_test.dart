import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:growth_circle/admin_login_tools.dart';
import 'package:growth_circle/password_policy.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('admin recovery rejects weak new passwords before Auth update', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final requests = <String>[];
    final requestBodies = <String, dynamic>{};
    final user = {
      'id': 'user',
      'aud': 'authenticated',
      'email': 'admin@example.test',
      'created_at': '2026-01-01T00:00:00Z',
      'app_metadata': {},
      'user_metadata': {},
    };
    final client = SupabaseClient(
      'https://example.test',
      'test-key',
      authOptions: adminRecoveryAuthOptions,
      httpClient: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        if (request.body.isNotEmpty) {
          requestBodies[request.url.path] = jsonDecode(request.body);
        }
        final response = request.url.path.endsWith('/verify')
            ? {
                'access_token': 'synthetic-access',
                'refresh_token': 'synthetic-refresh',
                'token_type': 'bearer',
                'expires_in': 3600,
                'user': user,
              }
            : request.method == 'PUT' && request.url.path.endsWith('/user')
            ? user
            : <String, dynamic>{};
        return http.Response(
          jsonEncode(response),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => AdminPasswordRecovery(
                  createClient: () => client,
                  savedLogin: AdminSavedLogin('https://example.test'),
                  captchaProvider: (_) async => 'recovery-challenge',
                ),
              ),
              child: const Text('Open recovery'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open recovery'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'admin@example.test');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();
    expect(find.text('Verify OTP'), findsOneWidget);
    expect(
      requestBodies['/auth/v1/recover']['gotrue_meta_security']['captcha_token'],
      'recovery-challenge',
    );
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Verify OTP'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'weak-password');
    await tester.enterText(find.byType(TextField).last, 'weak-password');
    await tester.tap(find.text('Save password'));
    await tester.pump();
    expect(find.text(passwordRequirementsEnglish), findsWidgets);
    expect(requests.where((path) => path.startsWith('PUT ')), isEmpty);
    await tester.enterText(find.byType(TextField).first, 'Synthetic-123A');
    await tester.tap(find.text('Save password'));
    await tester.pump();
    expect(find.text('Passwords must match.'), findsOneWidget);
    expect(requests.where((path) => path.startsWith('PUT ')), isEmpty);
    await tester.enterText(find.byType(TextField).last, 'Synthetic-123A');
    await tester.tap(find.text('Save password'));
    await tester.pumpAndSettle();
    expect(requests.where((path) => path == 'PUT /auth/v1/user'), hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });
  test(
    'saved admin login is scoped to the project and never uses preferences',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      final first = AdminSavedLogin('https://one.supabase.co');
      final second = AdminSavedLogin('https://two.supabase.co');
      await first.save('admin@example.test', 'synthetic-password');
      expect((await first.load())!['email'], 'admin@example.test');
      expect((await first.load())!['password'], 'synthetic-password');
      expect(await second.load(), isNull);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      await first.forget();
      expect(await first.load(), isNull);
    },
  );
}
