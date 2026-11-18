import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/earn_design.dart';
import 'package:growth_circle/main.dart';

void main() {
  for (final locale in ['en', 'ml', 'ar']) {
    testWidgets(
      'each Earn category opens its own tasks and returns in $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final campaigns = [
          for (final type in earnCategories)
            {
              'id': type,
              'ownerId': 'other',
              'status': 'active',
              'type': type,
              'link': 'https://instagram.com/$type/',
              'reward_per_task': 1,
            },
          {
            'id': 'own',
            'ownerId': 'me',
            'status': 'active',
            'type': 'follow',
            'link': 'https://instagram.com/own/',
            'reward_per_task': 1,
          },
        ];
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            supportedLocales: const [Locale('en'), Locale('ml'), Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: growthTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: EarnLanding(
                uid: 'me',
                openHistory: () {},
                categoryBuilder: (type) => TaskCategoryPage(
                  uid: 'me',
                  type: type,
                  controlsStream: Stream.value([
                    for (final action in earnCategories)
                      {'action_type': action, 'enabled': true},
                  ]),
                  presenceStream: Stream.value([]),
                  claimsStream: Stream.value([]),
                  campaignsStream: Stream.value(campaigns),
                  loadSavedIds: () async => [],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final type in earnCategories) {
          final tile = find.byWidgetPredicate(
            (w) => w is EarnCategoryTile && w.icon == actionIcon(type),
          );
          await tester.scrollUntilVisible(
            tile,
            160,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(tile);
          await tester.pumpAndSettle();
          expect(find.byType(TaskCategoryPage), findsOneWidget);
          expect(
            tester.widget<TaskCategoryPage>(find.byType(TaskCategoryPage)).type,
            type,
          );
          expect(find.byType(TaskTypePicker), findsNothing);
          final card = find.byWidgetPredicate(
            (w) =>
                w is EarnTaskCard && w.link == 'https://instagram.com/$type/',
          );
          await tester.scrollUntilVisible(
            card,
            160,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(card, findsOneWidget);
          for (final other in earnCategories.where((value) => value != type)) {
            expect(
              find.byWidgetPredicate(
                (w) =>
                    w is EarnTaskCard &&
                    w.link == 'https://instagram.com/$other/',
              ),
              findsNothing,
            );
          }
          expect(
            find.byWidgetPredicate(
              (w) =>
                  w is EarnTaskCard && w.link == 'https://instagram.com/own/',
            ),
            findsNothing,
          );
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.byType(EarnLanding), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets('saved filter resets within the selected category', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TaskCategoryPage(
          uid: 'me',
          type: 'follow',
          controlsStream: Stream.value([
            {'action_type': 'follow', 'enabled': true},
          ]),
          presenceStream: Stream.value([]),
          claimsStream: Stream.value([]),
          campaignsStream: Stream.value([
            {
              'id': 'follow',
              'ownerId': 'other',
              'status': 'active',
              'type': 'follow',
              'link': 'https://instagram.com/follow/',
              'reward_per_task': 1,
            },
            {
              'id': 'like',
              'ownerId': 'other',
              'status': 'active',
              'type': 'like',
              'link': 'https://instagram.com/like/',
              'reward_per_task': 1,
            },
          ]),
          loadSavedIds: () async => [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final saved = find.widgetWithText(FilterChip, 'Saved tasks');
    await tester.ensureVisible(saved);
    await tester.tap(saved);
    await tester.pumpAndSettle();
    final reset = find.text('Show all tasks');
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(find.text('https://instagram.com/follow/'), findsOneWidget);
    expect(find.text('https://instagram.com/like/'), findsNothing);
  });

  testWidgets('category page keeps pending submission actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TaskCategoryPage(
          uid: 'me',
          type: 'follow',
          controlsStream: Stream.value([
            {'action_type': 'follow', 'enabled': true},
          ]),
          presenceStream: Stream.value([]),
          claimsStream: Stream.value([
            {
              'campaign_id': 'follow',
              'status': 'pending',
              'created_at': '2026-01-01T00:00:00Z',
            },
          ]),
          campaignsStream: Stream.value([
            {
              'id': 'follow',
              'ownerId': 'other',
              'status': 'active',
              'type': 'follow',
              'link': 'https://instagram.com/follow/',
              'reward_per_task': 1,
            },
          ]),
          loadSavedIds: () async => [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.byType(EarnTaskCard);
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.descendant(of: card, matching: find.byType(SubmissionStatus)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Withdraw submission')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(of: card, matching: find.byType(FilledButton)),
          )
          .onPressed,
      isNull,
    );
  });
}
