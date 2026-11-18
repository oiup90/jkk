import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';

void main() {
  testWidgets('campaign order IDs, cancellation and combined filters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now().toUtc();
    var currentTime = now;
    Map<String, dynamic> campaign(
      String id,
      String type,
      String status,
      DateTime created,
      String order,
    ) => {
      'id': id,
      'type': type,
      'status': status,
      'createdAt': created.toIso8601String(),
      'order_id': order,
      'link': 'https://instagram.com/$id/',
      'remaining': 1,
      'requested': 1,
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: growthTheme(),
        home: Scaffold(
          body: Campaigns(
            uid: 'owner',
            campaignsStream: Stream.value([
              campaign('new', 'follow', 'active', now, '123456789012'),
              campaign(
                'old',
                'like',
                'active',
                now.subtract(const Duration(minutes: 2)),
                '234567890123',
              ),
              campaign(
                'done',
                'like',
                'completed',
                now.subtract(const Duration(minutes: 3)),
                '345678901234',
              ),
            ]),
            reviewsBuilder: (_) => const SizedBox.shrink(),
            now: () => currentTime,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Order ID: 123456789012'), findsOneWidget);
    expect(find.text('Order ID: 234567890123'), findsOneWidget);
    expect(find.text('Cancel campaign'), findsOneWidget);
    currentTime = now.add(const Duration(seconds: 61));
    await tester.pump(const Duration(seconds: 61));
    await tester.pump();
    expect(find.text('Cancel campaign'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Like'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Order ID: 123456789012'), findsNothing);
    expect(find.text('Order ID: 234567890123'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Order ID: 345678901234'), findsOneWidget);
    expect(find.text('Order ID: 234567890123'), findsNothing);
    expect(find.text('Cancel campaign'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
