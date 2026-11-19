import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:growth_circle/earn_design.dart';
import 'package:growth_circle/main.dart';

void main() {
  testWidgets('cancelling a campaign report is safe', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskList(
            uid: 'preview',
            controlsStream: Stream.value([
              {'action_type': 'follow', 'enabled': true},
            ]),
            presenceStream: Stream.value([]),
            claimsStream: Stream.value([]),
            campaignsStream: Stream.value([
              {
                'id': 'campaign',
                'ownerId': 'other',
                'status': 'active',
                'type': 'follow',
                'link': 'https://instagram.com/example/',
                'reward_per_task': 1,
              },
            ]),
            loadSavedIds: () async => [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final report = find.widgetWithText(TextButton, 'Report');
    await tester.ensureVisible(report);
    await tester.pumpAndSettle();
    await tester.tap(report);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Please check this campaign',
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('task view renders injected data and filters without a backend', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: growthTheme(),
        home: Scaffold(
          body: TaskList(
            uid: 'preview',
            controlsStream: Stream.value([
              {'action_type': 'follow', 'enabled': true},
            ]),
            presenceStream: Stream.value([]),
            campaignsStream: Stream.value([]),
            claimsStream: Stream.value([]),
            loadSavedIds: () async => [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('View all submissions'), findsOneWidget);
    expect(find.text('No tasks available yet.'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Follow'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('initial action filter shows only matching tasks', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: growthTheme(),
        home: Scaffold(
          body: TaskList(
            uid: 'preview',
            initialType: 'follow',
            controlsStream: Stream.value([
              {'action_type': 'follow', 'enabled': true},
              {'action_type': 'like', 'enabled': true},
            ]),
            presenceStream: Stream.value([]),
            claimsStream: Stream.value([]),
            campaignsStream: Stream.value([
              {
                'id': 'a',
                'ownerId': 'other',
                'status': 'active',
                'type': 'follow',
                'link': 'https://instagram.com/follow',
                'reward_per_task': 2,
              },
              {
                'id': 'b',
                'ownerId': 'other',
                'status': 'active',
                'type': 'like',
                'link': 'https://instagram.com/like',
                'reward_per_task': 3,
              },
            ]),
            loadSavedIds: () async => [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('https://instagram.com/follow'), findsOneWidget);
    expect(find.text('https://instagram.com/like'), findsNothing);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Like'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Like'));
    await tester.pumpAndSettle();
    expect(find.text('https://instagram.com/like'), findsOneWidget);
    expect(find.text('https://instagram.com/follow'), findsNothing);
  });
  for (final locale in ['en', 'ml']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'task cards preserve filtering, status and action rules at narrow width in $locale at $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          const pendingLink = 'https://www.instagram.com/example/';
          const disabledLink =
              'https://www.instagram.com/p/verylongexamplepostid/';
          await tester.pumpWidget(
            MaterialApp(
              theme: growthTheme(),
              locale: Locale(locale),
              supportedLocales: const [Locale('en'), Locale('ml')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: TaskList(
                  uid: 'preview',
                  controlsStream: Stream.value([
                    {'action_type': 'follow', 'enabled': true},
                    {'action_type': 'like', 'enabled': false},
                  ]),
                  presenceStream: Stream.value([]),
                  campaignsStream: Stream.value([
                    {
                      'id': 'pending',
                      'ownerId': 'other',
                      'status': 'active',
                      'type': 'follow',
                      'link': pendingLink,
                      'reward_per_task': 7,
                    },
                    {
                      'id': 'disabled',
                      'ownerId': 'other',
                      'status': 'active',
                      'type': 'like',
                      'link': disabledLink,
                      'reward_per_task': 12,
                    },
                    {
                      'id': 'own',
                      'ownerId': 'preview',
                      'status': 'active',
                      'type': 'follow',
                      'link': 'https://instagram.com/own',
                      'reward_per_task': 1,
                    },
                  ]),
                  claimsStream: Stream.value([
                    {
                      'campaign_id': 'pending',
                      'status': 'pending',
                      'created_at': '2026-01-01T00:00:00Z',
                    },
                  ]),
                  loadSavedIds: () async => ['pending'],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final pending = find.byWidgetPredicate(
            (w) => w is EarnTaskCard && w.link == pendingLink,
          );
          final disabled = find.byWidgetPredicate(
            (w) => w is EarnTaskCard && w.link == disabledLink,
          );
          await tester.scrollUntilVisible(
            pending,
            180,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(find.text('https://instagram.com/own'), findsNothing);
          expect(
            find.descendant(of: pending, matching: find.text('+7 coins')),
            findsOneWidget,
          );
          expect(
            tester
                .widget<FilledButton>(
                  find.descendant(
                    of: pending,
                    matching: find.byType(FilledButton),
                  ),
                )
                .onPressed,
            isNull,
          );
          expect(
            tester
                .widget<OutlinedButton>(
                  find.descendant(
                    of: pending,
                    matching: find.byType(OutlinedButton),
                  ),
                )
                .onPressed,
            isNotNull,
          );
          expect(
            find.descendant(
              of: pending,
              matching: find.byType(SubmissionStatus),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: pending,
              matching: find.text(
                locale == 'en'
                    ? 'Withdraw submission'
                    : 'സമർപ്പിച്ചത് പിൻവലിക്കുക',
              ),
            ),
            findsOneWidget,
          );

          await tester.scrollUntilVisible(
            disabled,
            180,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(
            find.descendant(of: disabled, matching: find.text('+12 coins')),
            findsOneWidget,
          );
          expect(
            tester
                .widget<FilledButton>(
                  find.descendant(
                    of: disabled,
                    matching: find.byType(FilledButton),
                  ),
                )
                .onPressed,
            isNull,
          );
          expect(
            tester
                .widget<OutlinedButton>(
                  find.descendant(
                    of: disabled,
                    matching: find.byType(OutlinedButton),
                  ),
                )
                .onPressed,
            isNull,
          );
          expect(
            find.descendant(
              of: disabled,
              matching: find.text(locale == 'en' ? 'Report' : 'റിപ്പോർട്ട്'),
            ),
            findsOneWidget,
          );

          final filter = find.widgetWithText(
            FilterChip,
            locale == 'en' ? 'Saved tasks' : 'Save ചെയ്ത tasks',
          );
          await tester.scrollUntilVisible(
            filter,
            -180,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(filter);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byType(EarnSectionHeader),
            -180,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widgetList<EarnSectionHeader>(find.byType(EarnSectionHeader))
                .last
                .count,
            1,
          );
          await tester.scrollUntilVisible(
            pending,
            180,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(disabled, findsNothing);
          final reset = find.text(
            locale == 'en' ? 'Start earning' : 'നേടിത്തുടങ്ങുക',
          );
          await tester.scrollUntilVisible(
            reset,
            -180,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(reset);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            disabled,
            180,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(disabled, findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
