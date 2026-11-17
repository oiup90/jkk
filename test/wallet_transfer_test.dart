import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart' show growthTheme;
import 'package:growth_circle/wallet_transfer.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  Future<SupabaseClient> clientFor(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) handler,
  ) async {
    return (await tester.runAsync(() async {
      final client = SupabaseClient(
        'https://example.test',
        'public-test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/token')) {
            return http.Response(
              jsonEncode({
                'access_token': 'synthetic',
                'refresh_token': 'synthetic-refresh',
                'token_type': 'bearer',
                'expires_in': 3600,
                'user': {
                  'id': 'owner',
                  'aud': 'authenticated',
                  'created_at': '2026-11-16T00:00:00Z',
                  'email': 'test@example.test',
                  'app_metadata': {},
                  'user_metadata': {},
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          return handler(request);
        }),
      );
      await client.auth.signInWithPassword(
        email: 'test@example.test',
        password: 'synthetic',
      );
      return client;
    }))!;
  }

  http.Response reply(http.Request request, Object body, [int status = 200]) =>
      http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
        request: request,
      );

  Future<void> open(WidgetTester tester, SupabaseClient client) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: growthTheme(),
        home: WalletTransferPage(client: client),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String number) async {
    await tester.enterText(find.byType(TextFormField).at(0), number);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), '15');
    await tester.enterText(find.byType(TextFormField).at(2), '9876');
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(FilledButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('validates the wallet and shows the recipient before payment', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final lookups = <String>[];
    final client = await clientFor(tester, (request) async {
      final number = (jsonDecode(request.body) as Map)['p_wallet'] as String;
      lookups.add(number);
      return reply(
        request,
        number == '1234567890'
            ? {'status': 'found', 'name': 'Anu', 'recipient_id': '87654321'}
            : {'status': 'not_found'},
      );
    });
    await open(tester, client);
    await tester.enterText(find.byType(TextFormField).first, '1234');
    await tester.pump(const Duration(seconds: 1));
    expect(lookups, isEmpty);
    await tester.enterText(find.byType(TextFormField).first, '1234567891');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Wallet number not found.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextFormField).first, '1234567890');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Anu'), findsOneWidget);
    expect(find.text('Pay now'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(client.dispose);
  });

  testWidgets('a late lookup cannot replace a newer recipient', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final first = Completer<http.Response>();
    http.Request? firstRequest;
    final client = await clientFor(tester, (request) async {
      final number = (jsonDecode(request.body) as Map)['p_wallet'];
      if (number == '1234567890' && firstRequest == null) {
        firstRequest = request;
        return first.future;
      }
      return reply(request, {
        'status': 'found',
        'name': 'New recipient',
        'recipient_id': '87654321',
      });
    });
    await open(tester, client);
    await tester.enterText(find.byType(TextFormField).first, '1234567890');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(firstRequest, isNotNull);
    await tester.enterText(find.byType(TextFormField).first, '1234567891');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('New recipient'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '1234567890');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    first.complete(
      reply(firstRequest!, {
        'status': 'found',
        'name': 'Old recipient',
        'recipient_id': '12345678',
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Old recipient'), findsNothing);
    expect(find.text('New recipient'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(client.dispose);
  });

  testWidgets(
    'Malayalam payment remains usable on a narrow screen with large text',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = await clientFor(tester, (request) async {
        if (request.url.path.endsWith('/lookup_wallet_recipient')) {
          return reply(request, {
            'status': 'found',
            'name': 'Anu Menon',
            'recipient_id': '87654321',
          });
        }
        return reply(request, {
          'status': 'success',
          'reference': '123456789012',
          'wallet': '1234567890',
          'name': 'Anu Menon',
          'amount': 15,
          'created_at': '2026-11-17T12:34:00Z',
        });
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: growthTheme(),
          locale: const Locale('ml'),
          supportedLocales: const [Locale('en'), Locale('ml')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: WalletTransferPage(client: client),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '1234567890');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Anu Menon'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(1), '15');
      await tester.enterText(find.byType(TextFormField).at(2), '1234');
      await tester.ensureVisible(find.text('Pay now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pay now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('സ്ഥിരീകരിക്കുക'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('Payment വിജയിച്ചു'), findsOneWidget);
      await tester.ensureVisible(find.text('123456789012'));
      expect(find.text('123456789012'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(client.dispose);
    },
  );

  for (final state in ['success', 'failure']) {
    testWidgets(
      '$state receipt appears after five seconds with server details',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final requests = <Map<String, dynamic>>[];
        final client = await clientFor(tester, (request) async {
          if (request.url.path.endsWith('/lookup_wallet_recipient')) {
            return reply(request, {
              'status': 'found',
              'name': 'Anu',
              'recipient_id': '87654321',
            });
          }
          requests.add(jsonDecode(request.body) as Map<String, dynamic>);
          return reply(request, {
            'status': state,
            'reference': '123456789012',
            'wallet': '1234567890',
            'name': 'Anu',
            'amount': 15,
            'created_at': '2026-11-17T12:34:00Z',
            'failure_code': state == 'failure' ? 'recipient_unavailable' : null,
          });
        });
        await open(tester, client);
        await fill(tester, '1234567890');
        await confirm(tester);
        expect(find.text('Processing payment'), findsOneWidget);
        expect(requests.single['p_recipient_id'], '87654321');
        await tester.pump(const Duration(seconds: 4));
        expect(find.text('Processing payment'), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(
          find.text(
            state == 'success' ? 'Payment successful' : 'Payment failed',
          ),
          findsOneWidget,
        );
        expect(find.text('123456789012'), findsOneWidget);
        expect(find.text('1234567890'), findsOneWidget);
        expect(find.text('Anu'), findsOneWidget);
        expect(find.text('Date & time'), findsOneWidget);
        if (state == 'failure') {
          expect(
            find.text('Recipient wallet is unavailable or blocked.'),
            findsOneWidget,
          );
        }
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('pending-wallet-transfer-owner'), isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(client.dispose);
      },
    );
  }

  testWidgets(
    'unknown outcome survives reopening and retries the same request without storing PIN',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final calls = <Map<String, dynamic>>[];
      final client = await clientFor(tester, (request) async {
        if (request.url.path.endsWith('/lookup_wallet_recipient')) {
          return reply(request, {
            'status': 'found',
            'name': 'Anu',
            'recipient_id': '87654321',
          });
        }
        calls.add(jsonDecode(request.body) as Map<String, dynamic>);
        if (calls.length == 1) {
          return reply(request, {
            'code': '503',
            'message': 'Network outcome unknown',
          }, 503);
        }
        return reply(request, {
          'status': 'success',
          'reference': '123456789012',
          'wallet': '1234567890',
          'name': 'Anu',
          'amount': 15,
          'created_at': '2026-11-17T12:34:00Z',
          'failure_code': null,
        });
      });
      await open(tester, client);
      await fill(tester, '1234567890');
      await confirm(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Transfer not confirmed'), findsOneWidget);
      expect(find.text('Payment failed'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('pending-wallet-transfer-owner')!;
      expect(saved, isNot(contains('9876')));
      await tester.pumpWidget(const SizedBox.shrink());
      await open(tester, client);
      final fields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      expect(fields[0].controller!.text, '1234567890');
      expect(fields[1].controller!.text, '15');
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byType(TextFormField).first,
                matching: find.byType(TextField),
              ),
            )
            .readOnly,
        true,
      );
      expect(fields[2].controller!.text, isEmpty);
      await tester.enterText(find.byType(TextFormField).at(2), '9876');
      await confirm(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(calls, hasLength(2));
      expect(calls[0]['p_request'], calls[1]['p_request']);
      expect(calls[1]['p_recipient_id'], '87654321');
      expect(find.text('Payment successful'), findsOneWidget);
      expect(prefs.getString('pending-wallet-transfer-owner'), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(client.dispose);
    },
  );
}
