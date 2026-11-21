import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/admin_campaign_plan.dart';

class FakePlan implements AdminCampaignPlanGateway {
  Map<String, int> values = {
    'campaign_count': 1,
    'window_hours': 24,
    'base_tasks': 3,
    'referral_bonus': 5,
  };
  int saves = 0;
  @override
  Future<Map<String, dynamic>> loadCampaignPlan() async => values;
  @override
  Future<void> saveCampaignPlan(Map<String, int> settings) async {
    values = settings;
    saves++;
  }
}

void main() {
  testWidgets('editor saves all limits and invalid totals are rejected', (
    tester,
  ) async {
    final gateway = FakePlan();
    await tester.pumpWidget(
      MaterialApp(home: AdminCampaignPlanPage(gateway: gateway, canEdit: true)),
    );
    await tester.pumpAndSettle();
    for (final entry in {
      'campaign_count': '2',
      'window_hours': '12',
      'base_tasks': '6',
      'referral_bonus': '4',
    }.entries) {
      await tester.enterText(
        find.byKey(Key('campaign-plan-${entry.key}')),
        entry.value,
      );
    }
    await tester.ensureVisible(find.text('Save campaign limits'));
    await tester.tap(find.text('Save campaign limits'));
    await tester.pumpAndSettle();
    expect(gateway.saves, 1);
    expect(gateway.values, {
      'campaign_count': 2,
      'window_hours': 12,
      'base_tasks': 6,
      'referral_bonus': 4,
    });
    await tester.enterText(
      find.byKey(const Key('campaign-plan-base_tasks')),
      '99',
    );
    await tester.tap(find.text('Save campaign limits'));
    await tester.pumpAndSettle();
    expect(gateway.saves, 1);
    expect(find.textContaining('1–100 total tasks'), findsOneWidget);
  });

  testWidgets('viewer can see settings but cannot edit them', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminCampaignPlanPage(gateway: FakePlan(), canEdit: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('campaign-plan-base_tasks')))
          .enabled,
      false,
    );
    expect(find.text('Save campaign limits'), findsNothing);
  });
}
