import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart' show tr;
import 'package:growth_circle/support_page.dart' show supportText;
import 'package:growth_circle/user_localization.dart';
import 'package:growth_circle/wallet_balance.dart';

const supported = [
  Locale('en'),
  Locale('hi'),
  Locale('ta'),
  Locale('ar'),
  Locale('ml'),
];

void main() {
  for (final expected in [
    ('en', 'Home', 'Support', 'Wallet'),
    ('hi', 'होम', 'सहायता', 'वॉलेट'),
    ('ta', 'முகப்பு', 'ஆதரவு', 'வாலெட்'),
    ('ar', 'الرئيسية', 'الدعم', 'المحفظة'),
    ('ml', 'ഹോം', 'സഹായം', 'വാലറ്റ്'),
  ]) {
    testWidgets('user pages and wallet resolve ${expected.$1} locale', (
      tester,
    ) async {
      final balances = StreamController<List<Map<String, dynamic>>>();
      addTearDown(balances.close);
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(expected.$1),
          supportedLocales: supported,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  Text(tr(context, 'home')),
                  Text(supportText(context, 'Support', 'സഹായം')),
                  Expanded(
                    child: SingleChildScrollView(
                      child: WalletBalance(balances: balances.stream),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      balances.add([
        {'balance': 100, 'held_balance': 20, 'is_active': true},
      ]);
      await tester.pump();
      expect(find.text(expected.$2), findsOneWidget);
      expect(find.text(expected.$3), findsOneWidget);
      expect(find.text(expected.$4), findsOneWidget);
      if (expected.$1 == 'ar') {
        expect(
          Directionality.of(tester.element(find.text(expected.$4))),
          TextDirection.rtl,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'Arabic transfer confirmation keeps amount, recipient and wallet visible',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: supported,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: Builder(
              builder: (context) => Text(
                userTransferConfirmation(
                  context,
                  amount: '125',
                  name: 'Alex',
                  wallet: '1234567890',
                ),
              ),
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.byType(Text)).data!;
      expect(text, contains('125'));
      expect(text, contains('Alex'));
      expect(text, contains('1234567890'));
      expect(text, contains('لا يمكن إلغاء التحويل'));
      expect(text, contains('\u2068'));
    },
  );
  testWidgets('Arabic wallet fits a narrow display with enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final balances = StreamController<List<Map<String, dynamic>>>();
    addTearDown(balances.close);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: supported,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: WalletBalance(balances: balances.stream),
          ),
        ),
      ),
    );
    balances.add([
      {'balance': 200, 'wallet_number': '1234567890', 'held_balance': 20},
    ]);
    await tester.pumpAndSettle();
    expect(find.text('المحفظة'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
