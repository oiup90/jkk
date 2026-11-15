import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    'pending balance stays hidden then counts real coins with sound',
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
}
