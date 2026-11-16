import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/coin_purchase.dart';

class FakePurchases implements CoinPurchaseSource {
  List<CoinOrder> orders = [];
  bool paid = false, fail = false, opened = false;
  int checks = 0;
  String? bought;
  @override
  Future<List<CoinPlan>> plans() async => const [
    CoinPlan('starter', 100, 4900),
    CoinPlan('popular', 300, 12900),
    CoinPlan('value', 1000, 39900),
  ];
  @override
  Future<List<CoinOrder>> pending() async => List.of(orders);
  @override
  Future<String> create(String plan) async {
    if (fail) throw StateError('provider down');
    bought = plan;
    orders = [const CoinOrder('saved-order', 100, 4900, 'checkout')];
    return 'checkout';
  }

  @override
  Future<bool> open(String checkout) async {
    opened = true;
    return true;
  }

  @override
  Future<bool> verify(String order) async {
    checks++;
    if (fail) throw StateError('connection lost');
    if (paid) orders = [];
    return paid;
  }
}

void main() {
  testWidgets(
    'server plan prices display and checkout is recovered, never credited on opening',
    (tester) async {
      final source = FakePurchases();
      await tester.pumpWidget(
        MaterialApp(home: CoinPurchasePage(source: source)),
      );
      await tester.pumpAndSettle();
      for (final price in ['₹49', '₹129', '₹399']) {
        expect(find.text(price), findsOneWidget);
      }
      await tester.tap(find.text('Buy').first);
      await tester.pumpAndSettle();
      expect(source.bought, 'starter');
      expect(source.opened, true);
      expect(find.textContaining('Coins added'), findsNothing);
      expect(find.text('Pending payments'), findsOneWidget);
      await tester.ensureVisible(find.text('Check payment'));
      await tester.tap(find.text('Check payment'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No completed payment'), findsOneWidget);
      expect(source.checks, 1);
      source.paid = true;
      await tester.tap(find.text('Check payment'));
      await tester.pumpAndSettle();
      expect(
        find.text('Payment confirmed. Coins added to your wallet.'),
        findsOneWidget,
      );
      expect(find.text('Check payment'), findsNothing);
    },
  );
  testWidgets(
    'pending order survives reopening, resume checks it, failure preserves recovery',
    (tester) async {
      final source = FakePurchases()
        ..orders = [const CoinOrder('persisted-order', 100, 4900, 'checkout')];
      await tester.pumpWidget(
        MaterialApp(home: CoinPurchasePage(source: source)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Order: persisted-order'), findsOneWidget);
      source.fail = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(source.checks, 1);
      expect(find.textContaining('Your order is saved'), findsOneWidget);
      expect(find.text('Order: persisted-order'), findsOneWidget);
      source.fail = false;
      source.paid = true;
      await tester.ensureVisible(find.text('Open checkout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open checkout'));
      await tester.pumpAndSettle();
      expect(source.opened, false);
      expect(
        find.text('Payment confirmed. Coins added to your wallet.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'checkout failure never shows success and Malayalam small layout fits',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = FakePurchases()..fail = true;
      await tester.pumpWidget(
        MaterialApp(home: CoinPurchasePage(source: source, isMalayalam: true)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('വാങ്ങുക').first);
      await tester.pumpAndSettle();
      expect(source.opened, false);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Checkout ലഭ്യമല്ല'), findsOneWidget);
    },
  );
  testWidgets(
    'plan capacity uses live rates and refreshes without changing prices',
    (tester) async {
      var rate = 4;
      await tester.pumpWidget(
        MaterialApp(
          home: CoinPurchasePage(
            source: FakePurchases(),
            loadRates: () async => {'follow': rate, 'like': 2},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ExpansionTile).first);
      await tester.pumpAndSettle();
      expect(find.text('Up to 25 follow tasks'), findsOneWidget);
      expect(find.text('Up to 50 like tasks'), findsOneWidget);
      rate = 5;
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(find.text('Up to 20 follow tasks'), findsOneWidget);
      expect(find.text('₹49'), findsOneWidget);
    },
  );
}
