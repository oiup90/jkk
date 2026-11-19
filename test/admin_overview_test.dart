import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/admin_overview.dart';

void main() {
  testWidgets('overview shows counts, trends and all quick actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final destinations = <String>[];
    final rows = List.generate(
      30,
      (i) => {
        'day': '2026-01-${(i + 1).toString().padLeft(2, '0')}',
        'registrations': i + 1,
        'campaigns': i * 2,
        'coins_credited': i * 10,
        'coins_spent': i * 3,
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminOverviewDashboard(
            values: {
              'users': 100,
              'active_campaigns': 5,
              'pending_submissions': 2,
              'coins_credited': 800,
              'open_support_chats': 3,
              'oldest_pending_at': DateTime.now()
                  .toUtc()
                  .subtract(const Duration(hours: 2))
                  .toIso8601String(),
              'today_users': 11,
              'today_campaigns': 4,
              'today_approved': 6,
            },
            trends: rows,
            onNavigate: destinations.add,
            canOpenSupport: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Open support chats'), findsOneWidget);
    expect(find.textContaining('Oldest: 2h'), findsOneWidget);
    expect(find.text('Today’s activity'), findsOneWidget);
    expect(find.text('11'), findsOneWidget);
    await tester.ensureVisible(find.text('30 days'));
    await tester.pumpAndSettle();
    expect(find.text('2026-01-30  ·  30'), findsOneWidget);
    await tester.tap(find.text('30 days'));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byKey(const Key('overview_chart')));
    await tester.tapAt(Offset(rect.left + 37, rect.top + 80));
    await tester.pumpAndSettle();
    expect(find.text('2026-01-01  ·  1'), findsOneWidget);
    await tester.tap(find.text('Coin activity'));
    await tester.pumpAndSettle();
    expect(
      find.text('2026-01-01  ·  Credited: 0  ·  Spent: 0'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Users Supports'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Users Supports'));
    await tester.tap(find.text('Wallets Management'));
    await tester.tap(find.widgetWithText(FilledButton, 'Pending submissions'));
    expect(destinations, ['operations', 'walletsManagement', 'submissions']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'empty queue and missing values are not shown as fabricated counts',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminOverviewDashboard(
              values: const {'pending_submissions': 0},
              trends: const [],
              onNavigate: (_) {},
              canOpenSupport: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No pending reviews'), findsOneWidget);
      expect(find.text('—'), findsWidgets);
      await tester.drag(find.byType(ListView).first, const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(find.text('No activity data available.'), findsOneWidget);
    },
  );
}
