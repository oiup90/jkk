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
      Uri? opened;
      var loads = 0;
      Future<List<Map<String, dynamic>>> load() async {
        loads++;
        return [
          {'platform': 'instagram', 'url': 'https://instagram.com/freelan'},
          {'platform': 'facebook', 'url': 'https://malicious.test/'},
        ];
      }

      await tester.pumpWidget(
        MaterialApp(
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
      expect(find.text('Instagram'), findsOneWidget);
      expect(find.text('Facebook'), findsNothing);
      await tester.tap(find.text('Instagram'));
      await tester.pump();
      expect(opened.toString(), 'https://instagram.com/freelan');
      expect(loads, 1);
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
