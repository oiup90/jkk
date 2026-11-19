import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';

void main() {
  testWidgets(
    'category pages retain order IDs, cancellation and status filters',
    (tester) async {
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
      expect(find.byType(CampaignCategoryTile), findsNWidgets(4));
      await tester.tap(find.widgetWithText(CampaignCategoryTile, 'Follow'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Order ID: 123456789012'), findsOneWidget);
      expect(find.text('Order ID: 234567890123'), findsNothing);
      expect(find.text('Cancel campaign'), findsOneWidget);
      currentTime = now.add(const Duration(seconds: 61));
      await tester.pump(const Duration(seconds: 61));
      await tester.pump();
      expect(find.text('Cancel campaign'), findsNothing);
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(CampaignCategoryTile, 'Like'));
      await tester.pump();
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
    },
  );

  testWidgets('each category opens separately and receives live updates', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var cancelled = false;
    final feed = StreamController<List<Map<String, dynamic>>>(
      onCancel: () => cancelled = true,
    );
    addTearDown(feed.close);
    final campaigns = [
      for (final type in ['follow', 'like', 'comment', 'share'])
        {
          'id': type,
          'type': type,
          'status': 'completed',
          'createdAt': '2026-01-01T00:00:00Z',
          'order_id': 'order-$type',
          'link': 'https://instagram.com/$type/',
          'remaining': 0,
          'requested': 1,
        },
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: growthTheme(),
        home: Scaffold(
          body: Campaigns(
            uid: 'owner',
            campaignsStream: feed.stream,
            reviewsBuilder: (_) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
    feed.add(campaigns);
    await tester.pump();
    for (final type in ['follow', 'like', 'comment', 'share']) {
      final title = '${type[0].toUpperCase()}${type.substring(1)}';
      await tester.tap(find.widgetWithText(CampaignCategoryTile, title));
      await tester.pumpAndSettle();
      expect(find.text('Order ID: order-$type'), findsOneWidget);
      for (final other in [
        'follow',
        'like',
        'comment',
        'share',
      ].where((x) => x != type)) {
        expect(find.text('Order ID: order-$other'), findsNothing);
      }
      if (type == 'share') {
        feed.add([
          ...campaigns,
          {...campaigns.last, 'id': 'new', 'order_id': 'new-share'},
        ]);
        await tester.pumpAndSettle();
        expect(find.text('Order ID: new-share'), findsOneWidget);
      }
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    expect(find.text('2 Campaigns'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(cancelled, isTrue);
  });

  for (final locale in ['en', 'ml']) {
    testWidgets('empty categories remain accessible at large text in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: growthTheme(),
          locale: Locale(locale),
          supportedLocales: const [Locale('en'), Locale('ml')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Campaigns(uid: 'owner', campaignsStream: Stream.value([])),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final type in ['follow', 'like', 'comment', 'share']) {
        final title = words[type]![locale == 'ml' ? 1 : 0];
        final tile = find.widgetWithText(CampaignCategoryTile, title);
        await tester.scrollUntilVisible(
          tile,
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(
          find.byType(BackButton),
          findsOneWidget,
          reason: 'opened $type in $locale',
        );
        final emptyTitle = find.text(
          words['emptyCampaigns']![locale == 'ml' ? 1 : 0],
        );
        await tester.scrollUntilVisible(
          emptyTitle,
          160,
          scrollable: find.byType(Scrollable).last,
        );
        expect(emptyTitle, findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }
    });
  }
}
