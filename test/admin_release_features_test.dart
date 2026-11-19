import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/admin_notifications.dart';
import 'package:growth_circle/admin_app_releases.dart';
import 'package:growth_circle/admin_release_audience.dart';
import 'package:growth_circle/admin_release_activity.dart';
import 'package:growth_circle/app_updates.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_notifications_test.dart' show FakeNotifications;

void main() {
  testWidgets(
    'release history exposes promotion only to editors for targeted releases',
    (tester) async {
      final client = SupabaseClient(
        'https://example.test',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          final rows = request.url.path.endsWith('/admin_app_release_history')
              ? [
                  {
                    'id': 'r1',
                    'version_name': '1.1.1',
                    'version_code': 17,
                    'target_user_id': 'member',
                    'notes': '',
                    'created_at': 'today',
                  },
                  {
                    'id': 'r2',
                    'version_name': '1.0.0',
                    'version_code': 16,
                    'target_user_id': null,
                    'notes': '',
                    'created_at': 'today',
                  },
                ]
              : [];
          return http.Response(
            jsonEncode(rows),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: AdminAppReleasesPage(client: client, canEdit: true)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Published releases'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('1.1.1 · build 17'), findsOneWidget);
      expect(find.text('Publish to all users'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          home: AdminAppReleasesPage(
            key: const ValueKey('viewer'),
            client: client,
            canEdit: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Published releases'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Publish to all users'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      client.dispose();
    },
  );

  testWidgets('promoting a release requires confirmation', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminReleasePromoteButton(
            versionName: '1.1.1',
            versionCode: 17,
            enabled: true,
            onConfirm: () => calls++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Publish to all users'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1.1.1 (build 17)'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.text('Publish to all users'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publish to all'));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets(
    'release audience requires explicit selection and supports returning to all users',
    (tester) async {
      Map<String, dynamic>? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminReleaseAudience(
                gateway: FakeNotifications(),
                enabled: true,
                onChanged: (v) => selected = v,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(selected, isEmpty);
      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.tap(find.byTooltip('Search release recipient'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Alice'));
      await tester.pumpAndSettle();
      expect(selected?['id'], 'user-a');
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(selected, isNull);
    },
  );
  testWidgets(
    'notification template fills editable message and viewers cannot apply it',
    (tester) async {
      final gateway = FakeNotifications();
      await tester.pumpWidget(
        MaterialApp(
          home: AdminSendNotificationPage(gateway: gateway, canEdit: true),
        ),
      );
      await tester.ensureVisible(
        find.byKey(const Key('notification_template')),
      );
      await tester.tap(find.byKey(const Key('notification_template')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('App update').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('notification_title')))
            .controller!
            .text,
        'A new app update is available',
      );
      await tester.enterText(
        find.byKey(const Key('notification_title')),
        'Edited release message',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('notification_title')))
            .controller!
            .text,
        'Edited release message',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AdminSendNotificationPage(
            key: const ValueKey('viewer'),
            gateway: gateway,
            canEdit: false,
          ),
        ),
      );
      expect(
        tester
            .widget<DropdownButtonFormField<AdminMessageTemplate>>(
              find.byKey(const Key('notification_template')),
            )
            .onChanged,
        isNull,
      );
      expect(gateway.calls, isEmpty);
    },
  );
  testWidgets(
    'installation panel refreshes on realtime change and shows pending separately',
    (tester) async {
      final client = SupabaseClient(
        'https://example.test',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final changes = StreamController<void>.broadcast();
      var updated = false, calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                AdminReleaseActivity(
                  client: client,
                  releaseId: 'release',
                  changes: changes.stream,
                  loader: (_) async {
                    calls++;
                    return [
                      {
                        'display_name': 'Alice',
                        'email': 'a@example.test',
                        'updated': updated,
                        'version_code': updated ? 20 : 19,
                      },
                    ];
                  },
                ),
              ],
            ),
          ),
        ),
      );
      expect(calls, 0);
      await tester.tap(find.text('Live installation reports'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Awaiting update'), findsOneWidget);
      updated = true;
      changes.add(null);
      await tester.pumpAndSettle();
      expect(find.textContaining('Updated (reported)'), findsOneWidget);
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox());
      await changes.close();
      client.dispose();
    },
  );
  testWidgets(
    'Android gate reports installed build independently of download or install actions',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            updateChannel,
            (call) async => call.method == 'installedVersion' ? 20 : null,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(updateChannel, null),
      );
      final reports = <dynamic>[];
      final client = SupabaseClient(
        'https://example.test',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/report_app_version')) {
            reports.add(jsonDecode(request.body));
          }
          return http.Response(
            'null',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AppUpdateGate(
            client: client,
            signedIn: true,
            releaseLoader: () => Stream.value([]),
            child: const Text('Home'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(reports, [
        {'p_version_code': 20},
      ]);
      expect(find.text('Home'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      client.dispose();
      debugDefaultTargetPlatformOverride = null;
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
