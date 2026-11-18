import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/auth_languages.dart';
import 'package:growth_circle/main.dart';
import 'package:growth_circle/official_social_links.dart';

class FakeActions extends AuthActions {}

void main() {
  tearDown(() => language.value = const Locale('en'));
  for (final entry in {
    'hi': 'वापस स्वागत है',
    'ta': 'மீண்டும் வரவேற்கிறோம்',
    'ar': 'مرحباً بعودتك',
    'ml': 'വീണ്ടും സ്വാഗതം',
    'en': 'Welcome back',
  }.entries) {
    testWidgets('auth selector switches to ${entry.key} and preserves form', (
      tester,
    ) async {
      language.value = const Locale('en');
      await tester.pumpWidget(
        ValueListenableBuilder<Locale>(
          valueListenable: language,
          builder: (_, locale, _) => MaterialApp(
            locale: locale,
            supportedLocales: const [
              Locale('en'),
              Locale('hi'),
              Locale('ta'),
              Locale('ar'),
              Locale('ml'),
            ],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: AuthScreen(actions: FakeActions()),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('email')),
        'member@example.test',
      );
      await tester.tap(find.byTooltip('Language'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(authLanguages[entry.key]!).last);
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('email')))
            .controller!
            .text,
        'member@example.test',
      );
      if (entry.key == 'ar') {
        expect(
          Directionality.of(tester.element(find.byKey(const Key('email')))),
          TextDirection.rtl,
        );
      }
      final create =
          authTranslations[entry.key]?['noAccount'] ??
          words['noAccount']![entry.key == 'ml' ? 1 : 0];
      await tester.ensureVisible(find.text(create));
      await tester.tap(find.text(create));
      await tester.pumpAndSettle();
      final name =
          authTranslations[entry.key]?['authName'] ??
          words['authName']![entry.key == 'ml' ? 1 : 0];
      expect(find.text(name), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  test('social links permit only expected HTTPS platform hosts', () {
    expect(
      validOfficialSocialUrl('instagram', 'https://www.instagram.com/freelan'),
      true,
    );
    for (final invalid in [
      'http://instagram.com/a',
      'https://instagram.com.evil.test/a',
      'https://instagram.com@evil.test/a',
      'https://instagram.com:444/a',
    ]) {
      expect(validOfficialSocialUrl('instagram', invalid), false);
    }
    expect(
      validOfficialSocialUrl('facebook', 'https://instagram.com/name'),
      false,
    );
  });
  testWidgets(
    'official links show only verified platforms and open the selected URL',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Uri? opened;
      var loads = 0;
      Future<List<Map<String, dynamic>>> load() async {
        loads++;
        return [
          {'platform': 'instagram', 'url': 'https://instagram.com/freelan'},
          {'platform': 'facebook', 'url': 'https://facebook.com/freelan'},
          {'platform': 'youtube', 'url': 'https://youtube.com/@freelan'},
          {'platform': 'x', 'url': 'https://x.com/freelan'},
          {'platform': 'youtube', 'url': 'https://malicious.test/'},
        ];
      }

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: OfficialSocialLinks(
              load: load,
              open: (url) async {
                opened = url;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final entry in {
        'Instagram': ['instagram', 'https://instagram.com/freelan'],
        'Facebook': ['facebook', 'https://facebook.com/freelan'],
        'YouTube': ['youtube', 'https://youtube.com/@freelan'],
        'X': ['x', 'https://x.com/freelan'],
      }.entries) {
        expect(find.text(entry.key), findsOneWidget);
        final button = find.ancestor(
          of: find.text(entry.key),
          matching: find.byType(TextButton),
        );
        final logo = tester.widget<Image>(
          find.descendant(of: button, matching: find.byType(Image)),
        );
        expect(
          (logo.image as AssetImage).assetName,
          'assets/social/${entry.value[0]}.png',
        );
        expect(logo.excludeFromSemantics, isTrue);
        await tester.tap(find.text(entry.key));
        await tester.pump();
        expect(opened.toString(), entry.value[1]);
      }
      expect(loads, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('sign-in shows official links and sign-up hides them', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          actions: FakeActions(),
          socialLinks: () async => [
            {'platform': 'youtube', 'url': 'https://youtube.com/@freelan'},
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('YouTube'));
    expect(find.text('YouTube'), findsOneWidget);
    await tester.tap(find.text('New here? Create account'));
    await tester.pumpAndSettle();
    expect(find.text('YouTube'), findsNothing);
  });
}
