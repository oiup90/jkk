import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/auth_captcha.dart';

void main() {
  for (final locale in ['en', 'ml', 'hi', 'ta', 'ar']) {
    testWidgets('security panel fits and offers retry in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 570);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var retryCount = 0;
      Widget page(bool failed, bool delayed) => MaterialApp(
        locale: Locale(locale),
        supportedLocales: const [
          Locale('en'),
          Locale('ml'),
          Locale('hi'),
          Locale('ta'),
          Locale('ar'),
        ],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2.0)),
          child: child!,
        ),
        home: Scaffold(
          body: SecurityCheckPanel(
            challenge: const Text('Challenge content'),
            failed: failed,
            delayed: delayed,
            onRetry: () => retryCount++,
          ),
        ),
      );
      await tester.pumpWidget(page(false, false));
      expect(find.text('Challenge content'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(find.text('Cancel'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(page(false, true));
      await tester.ensureVisible(find.byIcon(Icons.refresh));
      await tester.tap(find.byIcon(Icons.refresh));
      expect(retryCount, 1);
      expect(find.text('Challenge content'), findsOneWidget);
      await tester.pumpWidget(page(true, false));
      await tester.ensureVisible(find.byIcon(Icons.refresh));
      await tester.tap(find.byIcon(Icons.refresh));
      expect(retryCount, 2);
      expect(find.text('Challenge content'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
