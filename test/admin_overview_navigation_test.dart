import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/admin_main.dart';
import 'package:growth_circle/admin_overview.dart';
import 'package:growth_circle/admin_users_support.dart';
import 'package:growth_circle/admin_wallets.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('overview quick actions navigate inside desktop console', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = (await tester.runAsync(
      () async => SupabaseClient(
        'https://example.test',
        'synthetic',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          dynamic body = [];
          if (request.url.path.endsWith('/token')) {
            body = {
              'access_token': 'synthetic-access',
              'refresh_token': 'synthetic-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': 'synthetic-admin',
                'aud': 'authenticated',
                'email': 'admin@example.test',
                'created_at': '2026-11-11T00:00:00Z',
                'app_metadata': {},
                'user_metadata': {},
              },
            };
          } else if (request.url.path.endsWith('admin_workspace_role')) {
            body = 'editor';
          } else if (request.url.path.endsWith('admin_workspace_overview')) {
            body = {
              'users': 2,
              'active_campaigns': 1,
              'pending_submissions': 1,
              'coins_credited': 20,
              'open_support_chats': 1,
              'oldest_pending_at': DateTime.now()
                  .toUtc()
                  .subtract(const Duration(hours: 1))
                  .toIso8601String(),
              'today_users': 1,
              'today_campaigns': 1,
              'today_approved': 0,
            };
          } else if (request.url.path.endsWith('admin_daily_report')) {
            body = [
              {
                'day': '2026-11-19',
                'registrations': 1,
                'campaigns': 1,
                'coins_credited': 5,
                'coins_spent': 0,
              },
            ];
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

    Future<void> overview() async {
      await tester.tap(find.widgetWithText(ListTile, 'Overview'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminOverviewDashboard), findsOneWidget);
      await tester.drag(
        find.descendant(
          of: find.byType(AdminOverviewDashboard),
          matching: find.byType(ListView),
        ),
        const Offset(0, -1200),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Quick actions'));
      await tester.pumpAndSettle();
    }

    await overview();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Users Supports'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminUsersSupportPage), findsOneWidget);
    await overview();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Wallets Management'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminWalletsPage), findsOneWidget);
    await overview();
    await tester.tap(find.widgetWithText(FilledButton, 'Pending submissions'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminSubmissions), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(client.dispose);
  });
}
