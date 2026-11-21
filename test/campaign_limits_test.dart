import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/referral_history.dart';

void main() {
  testWidgets(
    'campaign limits displays the latest server settings and retries errors',
    (tester) async {
      var fail = true;
      Future<CampaignPlan> load() async {
        if (fail) throw StateError('offline');
        return const CampaignPlan(
          maxTasks: 10,
          campaignCount: 2,
          windowHours: 12,
          baseTasks: 6,
          referralBonus: 4,
        );
      }

      await tester.pumpWidget(
        MaterialApp(home: CampaignLimitsPage(loadPlan: load)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unable to load campaign limits.'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('2 campaign(s) every 12 hours'), findsOneWidget);
      expect(find.text('6 tasks per campaign'), findsOneWidget);
      expect(find.text('4 extra tasks with a referral'), findsOneWidget);
      expect(
        find.textContaining('up to 10 tasks per campaign'),
        findsOneWidget,
      );
    },
  );
}
