import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/admin_main.dart';
import 'package:growth_circle/admin_notifications.dart';
import 'package:growth_circle/admin_users_support.dart';
import 'package:growth_circle/admin_wallets.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets(
    'directory filters, columns, block reason and user-specific actions',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1500, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <(String, dynamic)>[];
      final client = (await tester.runAsync(
        () async => SupabaseClient(
          'https://example.test',
          'synthetic',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            final path = request.url.path;
            final params = request.body.isEmpty
                ? null
                : jsonDecode(request.body);
            calls.add((path, params));
            dynamic body = [];
            if (path.endsWith('/token')) {
              body = {
                'access_token': 'synthetic-access',
                'refresh_token': 'synthetic-refresh',
                'token_type': 'bearer',
                'expires_in': 3600,
                'user': {
                  'id': 'admin',
                  'aud': 'authenticated',
                  'email': 'admin@example.test',
                  'created_at': '2026-01-01T00:00:00Z',
                  'app_metadata': {},
                  'user_metadata': {},
                },
              };
            } else if (path.endsWith('admin_workspace_role')) {
              body = 'editor';
            } else if (path.endsWith('admin_list_users_v3')) {
              body = [
                {
                  'id': 'user-id',
                  'email': 'user@example.test',
                  'display_name': 'Alice',
                  'public_id': '12345678',
                  'created_at': '2026-01-01T00:00:00Z',
                  'last_sign_in_at': '2026-02-01T00:00:00Z',
                  'coins': 10,
                  'blocked': false,
                  'is_admin': false,
                },
              ];
            } else if (path.endsWith('admin_user_details_v2')) {
              body = {
                'role': null,
                'referrals': 2,
                'referred': false,
                'campaign_count': 3,
                'submission_count': 4,
                'campaigns': [],
                'submissions': [],
                'ledger': [],
                'wallet': {
                  'wallet_number': '1234567890',
                  'balance': 10,
                  'held_balance': 2,
                  'available_balance': 8,
                  'is_active': true,
                },
                'block_history': [
                  {
                    'blocked': true,
                    'reason': 'Policy reason',
                    'actor': 'admin@example.test',
                    'created_at': '2026-01-01T00:00:00Z',
                  },
                ],
              };
            } else if (path.endsWith('admin_set_blocked_with_reason')) {
              body = null;
            }
            return http.Response(
              jsonEncode(body),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      ))!;
      await tester.runAsync(
        () => client.auth.signInWithPassword(
          email: 'admin@example.test',
          password: 'synthetic',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AdminDesktopConsole(
            gateway: SupabaseAdminGateway(client),
            onLogout: () async {},
            onLanguage: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2026-02-01'), findsOneWidget);
      await tester.tap(find.text('All users'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blocked').last);
      await tester.pumpAndSettle();
      expect(
        calls
            .where((c) => c.$1.endsWith('admin_list_users_v3'))
            .last
            .$2['p_status'],
        'blocked',
      );
      await tester.tap(find.text('Sort: Join date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sort: Last login').last);
      await tester.pumpAndSettle();
      expect(
        calls
            .where((c) => c.$1.endsWith('admin_list_users_v3'))
            .last
            .$2['p_sort'],
        'last_login',
      );
      await tester.tap(find.byTooltip('Choose columns'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<String>, 'Email'),
      );
      await tester.pumpAndSettle();
      expect(find.text('user@example.test'), findsNothing);
      await tester.ensureVisible(find.text('Block app access'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block app access'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm'))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Reason for blocking'),
        'Test reason',
      );
      await tester.pump();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      final block = calls
          .singleWhere((c) => c.$1.endsWith('admin_set_blocked_with_reason'))
          .$2;
      expect(block, {
        'p_user_id': 'user-id',
        'p_blocked': true,
        'p_reason': 'Test reason',
      });
      await tester.ensureVisible(find.text('Details').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Details').last);
      await tester.pumpAndSettle();
      expect(find.text('Campaigns: 3'), findsOneWidget);
      expect(find.textContaining('Held: 2'), findsOneWidget);
      expect(find.textContaining('Policy reason'), findsOneWidget);
      await tester.tap(find.text('Support chats'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminUsersSupportPage), findsOneWidget);
      expect(
        calls
            .singleWhere((c) => c.$1.endsWith('admin_support_tickets_for_user'))
            .$2,
        {'p_user': 'user-id'},
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        calls.where((c) => c.$1.endsWith('admin_user_details_v2')).length,
        greaterThanOrEqualTo(2),
      );
      await tester.tap(find.text('Open wallet'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminWalletsPage), findsOneWidget);
      expect(
        calls.singleWhere((c) => c.$1.endsWith('admin_wallet_for_user')).$2,
        {'p_user': 'user-id'},
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Send notification'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AdminSendNotificationPage), findsOneWidget);
      expect(find.text('Selected: user@example.test'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(client.dispose);
    },
  );
  test(
    'directory gateway sends date ranges, ordering and paging to server',
    () async {
      Map<String, dynamic>? params;
      final client = SupabaseClient(
        'https://example.test',
        'synthetic',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          params = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
          return http.Response(
            '[]',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final gateway = SupabaseAdminGateway(client);
      await gateway.filteredUsers(
        'alice',
        'blocked',
        DateTimeRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 31)),
        DateTimeRange(start: DateTime(2026, 2, 1), end: DateTime(2026, 2, 9)),
        'last_login',
        false,
        50,
        50,
      );
      expect(params, {
        'p_query': 'alice',
        'p_status': 'blocked',
        'p_join_from': '2026-01-01',
        'p_join_to': '2026-01-31',
        'p_login_from': '2026-02-01',
        'p_login_to': '2026-02-09',
        'p_sort': 'last_login',
        'p_desc': false,
        'p_offset': 50,
        'p_limit': 50,
      });
      client.dispose();
    },
  );

  testWidgets('viewer can inspect a user but cannot send notifications', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = SupabaseClient(
      'https://example.test',
      'synthetic',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'referrals': 0,
            'referred': false,
            'role': null,
            'campaign_count': 0,
            'submission_count': 0,
            'campaigns': [],
            'submissions': [],
            'ledger': [],
            'wallet': null,
            'block_history': [],
          }),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    const user = AdminUser(
      id: 'user',
      email: 'user@example.test',
      name: 'User',
      joined: '2026-01-01',
      coins: null,
      blocked: false,
      isAdmin: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AdminUserDetails(
          gateway: SupabaseAdminGateway(client),
          user: user,
          canEdit: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Send notification'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Open wallet'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Support chats'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
}
