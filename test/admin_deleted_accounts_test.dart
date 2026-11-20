import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/admin_deleted_accounts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets(
    'admin searches deleted identities and reads complete archive sections',
    (tester) async {
      final client = SupabaseClient(
        'https://example.test',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          final value = r.url.path.endsWith('/admin_deleted_accounts')
              ? [
                  {
                    'id': 'archive',
                    'user_id': 'deleted-user',
                    'email': 'old@example.test',
                    'display_name': 'Archived member',
                    'deleted_at': '2026-11-20',
                  },
                ]
              : {
                  'archive_id': 'archive',
                  'deleted_at': '2026-11-20',
                  'data': {
                    'account': {'email': 'old@example.test'},
                    'public.coin_ledger': [
                      {'amount': 100, 'reason': 'referral'},
                    ],
                  },
                };
          return http.Response(
            jsonEncode(value),
            200,
            headers: {'content-type': 'application/json'},
            request: r,
          );
        }),
      );
      addTearDown(() {
        client.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(home: AdminDeletedAccounts(client: client)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'old@example.test');
      await tester.tap(find.text('Search / refresh'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'old@example.test'));
      await tester.pumpAndSettle();
      expect(find.text('Download full audit JSON'), findsOneWidget);
      await tester.tap(find.text('public.coin_ledger (1)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('"referral"'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
