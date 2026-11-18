import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';
import 'package:growth_circle/safe_error_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _BrokenWidget extends StatelessWidget {
  const _BrokenWidget();

  @override
  Widget build(BuildContext context) =>
      throw FlutterError('Database private_table and stack trace #0');
}

void main() {
  testWidgets('unknown errors and PIN outcomes never reveal raw details', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(
      friendlyError(
        context,
        const PostgrestException(
          message: 'private_table SQL query stack trace',
          details: 'private database detail',
        ),
      ),
      words['error']![0],
    );
    expect(
      friendlyError(context, StateError('private stack trace')),
      words['error']![0],
    );
    for (final code in [
      'pin_missing',
      'invalid_pin',
      'pin_locked',
      'invalid_format',
      'otp_required',
      'email_otp_required',
    ]) {
      expect(safePinError(context, code), words[code]![0]);
    }
    for (final value in [
      'private database stack trace',
      'already',
      null,
      123,
    ]) {
      expect(safePinError(context, value), words['error']![0]);
    }
  });

  testWidgets('unexpected PIN setup response stays generic', (tester) async {
    const privateResult = 'private_table SQL error stack trace';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReleasePinDialog(
            setup: true,
            sendOtp: () async {},
            savePin: (_, _) async => privateResult,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Send email OTP'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(0), '123456');
    await tester.enterText(find.byType(TextField).at(1), '1234');
    await tester.enterText(find.byType(TextField).at(2), '1234');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text(words['error']![0]), findsOneWidget);
    expect(find.textContaining('private_table'), findsNothing);
    expect(find.textContaining('stack trace'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final locale in [const Locale('en'), const Locale('ml')]) {
    testWidgets('widget failures show generic text in ${locale.languageCode}', (
      tester,
    ) async {
      final original = ErrorWidget.builder;
      ErrorWidget.builder = safeErrorWidget;
      try {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: const [Locale('en'), Locale('ml')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const Scaffold(body: _BrokenWidget()),
          ),
        );
        expect(tester.takeException(), isFlutterError);
        expect(
          find.text(words['error']![locale.languageCode == 'ml' ? 1 : 0]),
          findsOneWidget,
        );
        expect(find.textContaining('private_table'), findsNothing);
        expect(find.textContaining('stack trace'), findsNothing);
      } finally {
        ErrorWidget.builder = original;
      }
    });
  }
}
