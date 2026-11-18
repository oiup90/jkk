import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:growth_circle/admin_wallets.dart';

final alice = <String, dynamic>{
  'user_id': 'alice',
  'public_id': '12345678',
  'display_name': 'Alice',
  'wallet_number': '1234567890',
  'balance': 100,
  'held_balance': 20,
  'available_balance': 80,
  'is_active': true,
};
final bob = <String, dynamic>{
  ...alice,
  'user_id': 'bob',
  'public_id': '87654321',
  'display_name': 'Bob',
  'wallet_number': '2345678901',
};

class Wallets implements AdminWalletGateway {
  @override
  String get sessionKey => 'wallet-test-owner-project';
  final searches = <(String, int)>[];
  final commands = <Map<String, dynamic>>[];
  Object? failure;
  @override
  Future<List<Map<String, dynamic>>> search(String query, int offset) async {
    searches.add((query, offset));
    if (query == bob['wallet_number'] || query == 'Bob') return [bob];
    return [alice];
  }

  @override
  Future<Map<String, dynamic>> operate(Map<String, dynamic> params) async {
    commands.add(Map.from(params));
    if (failure != null) throw failure!;
    return {
      'id': 'receipt',
      'balance': 105,
      'held_balance': 20,
      'reference': '100000000001',
    };
  }

  @override
  Future<List<Map<String, dynamic>>> history(String user, int offset) async =>
      [];
}

Future<void> show(
  WidgetTester tester,
  Wallets gateway, {
  bool edit = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AdminWalletsPage(gateway: gateway, canEdit: edit),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester, {String coins = '5'}) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Coins'), coins);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Reason'),
    'Synthetic correction',
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'wallet search shows name, public ID, wallet number, available and held balance',
    (tester) async {
      final gateway = Wallets();
      await show(tester, gateway);
      expect(find.text('Wallets Management'), findsOneWidget);
      expect(find.textContaining('12345678'), findsOneWidget);
      expect(find.textContaining('1234567890'), findsOneWidget);
      expect(find.textContaining('Available: 80'), findsOneWidget);
      for (final label in [
        'Add coins',
        'Deduct',
        'Debit',
        'Hold',
        'Release hold',
        'Transfer',
        'Deactivate',
      ]) {
        expect(find.widgetWithText(OutlinedButton, label), findsOneWidget);
      }
      expect(find.textContaining('Approve'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Bob');
      await tester.tap(find.widgetWithText(FilledButton, 'Search'));
      await tester.pumpAndSettle();
      expect(gateway.searches.last, ('Bob', 0));
      expect(
        find.text('Bob', findRichText: false, skipOffstage: true).hitTestable(),
        findsWidgets,
      );
      expect(find.textContaining('87654321'), findsOneWidget);
    },
  );
  testWidgets(
    'single editor can add coins directly; invalid amounts never reach server',
    (tester) async {
      final gateway = Wallets();
      await show(tester, gateway);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Add coins'));
      await tester.pumpAndSettle();
      await fill(tester, coins: '-1');
      await tester.tap(find.text('Apply now'));
      await tester.pumpAndSettle();
      expect(gateway.commands, isEmpty);
      await fill(tester);
      await tester.tap(find.text('Apply now'));
      await tester.pumpAndSettle();
      expect(gateway.commands.single['p_action'], 'add');
      expect(gateway.commands.single['p_amount'], 5);
      expect(gateway.commands.single['p_user'], 'alice');
      expect(find.textContaining('Wallet operation completed'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).containsKey(gateway.sessionKey),
        false,
      );
    },
  );
  testWidgets(
    'unknown result survives page restart and retries the identical request',
    (tester) async {
      final gateway = Wallets()..failure = TimeoutException('lost response');
      await show(tester, gateway);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Debit'));
      await tester.pumpAndSettle();
      await fill(tester);
      await tester.tap(find.text('Apply now'));
      await tester.pumpAndSettle();
      final first = gateway.commands.single;
      final prefs = await SharedPreferences.getInstance();
      expect(
        (jsonDecode(prefs.getString(gateway.sessionKey)!) as Map)['params'],
        first,
      );
      await tester.tap(find.text('Close; keep saved request'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await show(tester, gateway);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Add coins'),
            )
            .onPressed,
        isNull,
      );
      gateway.failure = null;
      await tester.tap(find.text('Resume request'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Coins'))
            .enabled,
        false,
      );
      await tester.tap(find.text('Retry saved request'));
      await tester.pumpAndSettle();
      expect(gateway.commands, [first, first]);
      expect(prefs.containsKey(gateway.sessionKey), false);
    },
  );
  testWidgets(
    'transfer requires a verified recipient identity before submitting',
    (tester) async {
      final gateway = Wallets();
      await show(tester, gateway);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Transfer'));
      await tester.pumpAndSettle();
      await fill(tester);
      await tester.tap(find.text('Apply now'));
      await tester.pumpAndSettle();
      expect(gateway.commands, isEmpty);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Recipient wallet number'),
        bob['wallet_number'] as String,
      );
      await tester.tap(find.text('Check recipient'));
      await tester.pumpAndSettle();
      expect(find.textContaining('To: Bob'), findsOneWidget);
      await tester.tap(find.text('Apply now'));
      await tester.pumpAndSettle();
      expect(gateway.commands.single['p_recipient'], 'bob');
      expect(
        gateway.commands.single['p_recipient_wallet'],
        bob['wallet_number'],
      );
    },
  );
  testWidgets(
    'viewer can search and inspect history but has no wallet mutation buttons',
    (tester) async {
      await show(tester, Wallets(), edit: false);
      expect(find.text('Read-only access'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
      await tester.tap(find.text('Operation history'));
      await tester.pumpAndSettle();
      expect(find.text('No wallet operations'), findsOneWidget);
    },
  );
  testWidgets(
    'server business rejection allows correction, access denial retains unknown request',
    (tester) async {
      final gateway = Wallets()
        ..failure = const PostgrestException(
          message: 'Not enough available coins.',
          code: 'P0001',
        );
      await show(tester, gateway);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Hold'));
      await tester.pumpAndSettle();
      await fill(tester);
      await tester.tap(find.text('Apply now'));
      await tester.pumpAndSettle();
      expect(find.text('Not enough available coins.'), findsOneWidget);
      expect(find.text('Apply now'), findsOneWidget);
      gateway.failure = const PostgrestException(
        message: 'Editor access required.',
        code: 'P0001',
      );
      await tester.tap(find.text('Apply now'));
      await tester.pumpAndSettle();
      expect(find.text('Retry saved request'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).containsKey(gateway.sessionKey),
        true,
      );
    },
  );
}
