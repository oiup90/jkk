import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:growth_circle/main.dart' show growthTheme;
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/wallet_balance.dart';

void main() {
  const channel = MethodChannel('growth_circle/wallet_audio');
  final sounds = <String>[];
  setUp(() {
    sounds.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          sounds.add(call.method);
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  testWidgets(
    'checking a pending balance plays sound immediately and counts real coins',
    (tester) async {
      final stream = StreamController<List<Map<String, dynamic>>>();
      addTearDown(stream.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: WalletBalance(balances: stream.stream)),
        ),
      );
      await tester.tap(find.byTooltip('Check balance'));
      await tester.pump();
      expect(sounds.where((s) => s == 'playCoinCount').length, 1);
      expect(find.textContaining('Loading'), findsNothing);
      expect(find.text('0 Coins'), findsNothing);
      stream.add([
        {'balance': 128, 'wallet_number': '1234567890'},
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('128 Coins'), findsNothing);
      expect(sounds.where((s) => s == 'playCoinCount').length, 1);
      await tester.pumpAndSettle();
      expect(find.text('128 Coins'), findsOneWidget);
      expect(find.text('Wallet number: 1234567890'), findsOneWidget);
      await tester.tap(find.byTooltip('Hide balance'));
      await tester.pump();
      expect(find.text('128 Coins'), findsNothing);
      expect(sounds.last, 'stopCoinCount');
      stream.add([
        {'balance': 140},
      ]);
      await tester.pump();
      expect(sounds.where((s) => s == 'playCoinCount').length, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('zero balance with reduced motion plays on each check', (
    tester,
  ) async {
    final stream = StreamController<List<Map<String, dynamic>>>();
    addTearDown(stream.close);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(body: WalletBalance(balances: stream.stream)),
      ),
    );
    stream.add([
      {'balance': 0},
    ]);
    await tester.pump();
    await tester.tap(find.byTooltip('Check balance'));
    await tester.pump();
    expect(find.text('0 Coins'), findsOneWidget);
    expect(sounds.where((s) => s == 'playCoinCount').length, 1);
    await tester.tap(find.byTooltip('Hide balance'));
    await tester.pump();
    expect(sounds.last, 'stopCoinCount');
    await tester.tap(find.byTooltip('Check balance'));
    await tester.pump();
    expect(sounds.where((s) => s == 'playCoinCount').length, 2);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'changing wallet streams clears the previous identifier and balance',
    (tester) async {
      final first = StreamController<List<Map<String, dynamic>>>();
      final second = StreamController<List<Map<String, dynamic>>>();
      addTearDown(first.close);
      addTearDown(second.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: WalletBalance(balances: first.stream)),
        ),
      );
      first.add([
        {'balance': 128, 'wallet_number': '1234567890'},
      ]);
      await tester.pump();
      await tester.tap(find.byTooltip('Check balance'));
      await tester.pumpAndSettle();
      expect(find.text('128 Coins'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: WalletBalance(balances: second.stream)),
        ),
      );
      await tester.pump();
      expect(find.textContaining('1234567890'), findsNothing);
      expect(find.text('128 Coins'), findsNothing);
      expect(find.byTooltip('Check balance'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('failure clears stale balance and stops counting', (
    tester,
  ) async {
    final stream = StreamController<List<Map<String, dynamic>>>();
    addTearDown(stream.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WalletBalance(balances: stream.stream)),
      ),
    );
    stream.add([
      {'balance': 25},
    ]);
    await tester.pump();
    await tester.tap(find.byTooltip('Check balance'));
    await tester.pump();
    stream.addError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to load balance'), findsOneWidget);
    expect(find.text('25 Coins'), findsNothing);
    expect(sounds.last, 'stopCoinCount');
    await tester.pumpWidget(const SizedBox());
  });
  for (final locale in ['en', 'ml']) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'wallet actions and copy work at narrow width in $locale at $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          String? copied;
          var buy = false, transfer = false;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, (call) async {
                if (call.method == 'Clipboard.setData') {
                  copied = (call.arguments as Map)['text'] as String?;
                }
                return null;
              });
          addTearDown(
            () => TestDefaultBinaryMessengerBinding
                .instance
                .defaultBinaryMessenger
                .setMockMethodCallHandler(SystemChannels.platform, null),
          );
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
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: WalletBalance(
                      balances: Stream.value([
                        {'balance': 2147483647, 'wallet_number': '1234567890'},
                      ]),
                      isMalayalam: locale == 'ml',
                      onBuyCoins: () => buy = true,
                      onTransfer: () => transfer = true,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.textContaining('2147483647'), findsNothing);
          await tester.tap(
            find.byTooltip(
              locale == 'en' ? 'Check balance' : 'Balance പരിശോധിക്കുക',
            ),
          );
          await tester.pumpAndSettle();
          expect(find.textContaining('2147483647'), findsOneWidget);
          final copy = find.byTooltip(
            locale == 'en' ? 'Copy wallet number' : 'വാലറ്റ് നമ്പർ പകർത്തുക',
          );
          await tester.ensureVisible(copy);
          await tester.tap(copy);
          await tester.pump();
          expect(copied, '1234567890');
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          final buyButton = find.text(
            locale == 'en' ? 'Buy coins' : 'Coins വാങ്ങുക',
          );
          final transferButton = find.text(
            locale == 'en' ? 'Transfer coins' : 'Coins അയയ്ക്കുക',
          );
          await tester.ensureVisible(buyButton);
          await tester.tap(buyButton);
          await tester.ensureVisible(transferButton);
          await tester.tap(transferButton);
          expect(buy, isTrue);
          expect(transfer, isTrue);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  testWidgets(
    'holds reduce available balance and inactive wallet disables outgoing transfers',
    (tester) async {
      final stream = StreamController<List<Map<String, dynamic>>>();
      addTearDown(stream.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WalletBalance(balances: stream.stream, onTransfer: () {}),
          ),
        ),
      );
      stream.add([
        {'balance': 100, 'held_balance': 25, 'is_active': true},
      ]);
      await tester.pump();
      await tester.tap(find.byTooltip('Check balance'));
      await tester.pumpAndSettle();
      expect(find.text('75 Coins'), findsOneWidget);
      expect(find.text('Held coins: 25'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Transfer coins'),
            )
            .onPressed,
        isNotNull,
      );
      stream.add([
        {'balance': 102, 'held_balance': 25, 'is_active': false},
      ]);
      await tester.pumpAndSettle();
      expect(find.text('77 Coins'), findsOneWidget);
      expect(find.textContaining('Wallet inactive'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Transfer coins'),
            )
            .onPressed,
        isNull,
      );
      stream.add([
        {'balance': 102, 'held_balance': 102, 'is_active': true},
      ]);
      await tester.pumpAndSettle();
      expect(find.text('0 Coins'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Transfer coins'),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
