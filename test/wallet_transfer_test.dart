import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/wallet_transfer.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets(
    'uncertain transfer survives reopening and retries the same request without storing PIN',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final calls = <Map<String, dynamic>>[];
      final client = (await tester.runAsync(() async {
        final client = SupabaseClient(
          'https://example.test',
          'public-test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            Object response;
            var status = 200;
            if (request.url.path.endsWith('/token')) {
              response = {
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
              };
            } else {
              calls.add(jsonDecode(request.body) as Map<String, dynamic>);
              if (calls.length == 1) {
                status = 503;
                response = {
                  'code': '503',
                  'message': 'Network outcome unknown',
                };
              } else {
                response = {'status': 'ok', 'id': 'receipt-1'};
              }
            }
            return http.Response(
              jsonEncode(response),
              status,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        await client.auth.signInWithPassword(
          email: 'test@example.test',
          password: 'synthetic',
        );
        return client;
      }))!;
      Future<void> open() async {
        await tester.pumpWidget(
          MaterialApp(home: WalletTransferPage(client: client)),
        );
        await tester.pumpAndSettle();
      }

      Future<void> confirm() async {
        await tester.ensureVisible(find.byType(FilledButton).first);
        await tester.tap(find.byType(FilledButton).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm').last);
        await tester.pumpAndSettle();
      }

      await open();
      await tester.enterText(find.byType(TextFormField).at(0), '1234567890');
      await tester.enterText(find.byType(TextFormField).at(1), '15');
      await tester.enterText(find.byType(TextFormField).at(2), '9876');
      await confirm();
      expect(calls, hasLength(1));
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('pending-wallet-transfer-owner')!;
      expect(saved, isNot(contains('9876')));
      expect(find.textContaining('not confirmed'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await open();
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
      await confirm();
      expect(calls, hasLength(2));
      expect(calls[0]['p_request'], calls[1]['p_request']);
      expect(calls[1]['p_amount'], 15);
      expect(find.text('Transfer completed'), findsOneWidget);
      expect(prefs.getString('pending-wallet-transfer-owner'), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(client.dispose);
    },
  );
}
