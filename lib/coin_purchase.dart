import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class CoinPlan {
  const CoinPlan(this.id, this.coins, this.amountPaise);
  final String id;
  final int coins, amountPaise;
  String get price =>
      '₹${(amountPaise / 100).toStringAsFixed(amountPaise % 100 == 0 ? 0 : 2)}';
}

class CoinOrder {
  const CoinOrder(this.id, this.coins, this.amountPaise, this.checkout);
  final String id, checkout;
  final int coins, amountPaise;
}

abstract class CoinPurchaseSource {
  Future<List<CoinPlan>> plans();
  Future<List<CoinOrder>> pending();
  Future<String> create(String plan);
  Future<bool> verify(String order);
  Future<bool> open(String checkout);
}

class SupabaseCoinPurchases implements CoinPurchaseSource {
  SupabaseCoinPurchases(this.client) : owner = client.auth.currentUser!.id;
  final SupabaseClient client;
  final String owner;
  void checkSession() {
    if (client.auth.currentUser?.id != owner) {
      throw StateError('Session changed');
    }
  }

  @override
  Future<List<CoinPlan>> plans() async {
    checkSession();
    final rows = await client
        .from('coin_purchase_plans')
        .select()
        .eq('active', true)
        .order('amount_paise');
    return [
      for (final row in rows)
        CoinPlan(
          row['id'] as String,
          row['coins'] as int,
          row['amount_paise'] as int,
        ),
    ];
  }

  @override
  Future<List<CoinOrder>> pending() async {
    checkSession();
    final rows = await client
        .from('coin_purchase_orders')
        .select()
        .eq('user_id', owner)
        .eq('status', 'pending')
        .order('created_at')
        .limit(100);
    return [
      for (final row in rows)
        CoinOrder(
          row['id'] as String,
          row['coins'] as int,
          row['amount_paise'] as int,
          row['checkout_url'] as String,
        ),
    ];
  }

  Future<Map> invoke(Map<String, dynamic> body) async {
    checkSession();
    final result = await client.functions.invoke('coin-purchase', body: body);
    checkSession();
    if (result.status != 200 || result.data is! Map) {
      throw StateError('Payment unavailable');
    }
    return result.data as Map;
  }

  @override
  Future<String> create(String plan) async =>
      (await invoke({'action': 'create', 'plan': plan}))['checkout_url']
          as String;
  @override
  Future<bool> verify(String order) async =>
      (await invoke({'action': 'verify', 'order': order}))['status'] ==
      'credited';
  @override
  Future<bool> open(String checkout) {
    checkSession();
    final uri = Uri.parse(checkout);
    if (uri.scheme != 'https' ||
        uri.host != 'www.instamojo.com' ||
        uri.userInfo.isNotEmpty ||
        uri.port != 443 ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw StateError('Invalid checkout');
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class CoinPurchasePage extends StatefulWidget {
  const CoinPurchasePage({
    super.key,
    required this.source,
    this.isMalayalam = false,
    this.loadRates,
  });
  final CoinPurchaseSource source;
  final bool isMalayalam;
  final Future<Map<String, int>> Function()? loadRates;
  @override
  State<CoinPurchasePage> createState() => _CoinPurchasePageState();
}

class _CoinPurchasePageState extends State<CoinPurchasePage>
    with WidgetsBindingObserver {
  List<CoinPlan> plans = [];
  Map<String, int> rates = {};
  List<CoinOrder> orders = [];
  bool busy = true;
  String? message;
  String text(String en, String ml) => widget.isMalayalam ? ml : en;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) verifyAll();
  }

  Future<void> refresh() async {
    setState(() => busy = true);
    try {
      final nextPlans = await widget.source.plans();
      final nextOrders = await widget.source.pending();
      Map<String, int> nextRates = {};
      try {
        nextRates = await widget.loadRates?.call() ?? {};
      } catch (_) {
        /* Prices still come from the server; estimates may be unavailable. */
      }
      if (!mounted) return;
      setState(() {
        plans = nextPlans;
        rates = nextRates;
        orders = nextOrders;
        message = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => message = text(
            'Unable to load purchases. Refresh to try again.',
            'വാങ്ങലുകൾ ലഭിച്ചില്ല. Refresh ചെയ്ത് വീണ്ടും ശ്രമിക്കുക.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> buy(CoinPlan plan) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final checkout = await widget.source.create(plan.id);
      // Persisted orders are loaded before switching apps, including if opening fails.
      final nextOrders = await widget.source.pending();
      if (!mounted) return;
      setState(() => orders = nextOrders);
      if (!await widget.source.open(checkout)) {
        throw StateError('Browser unavailable');
      }
      if (mounted) {
        setState(
          () => message = text(
            'After payment, return here and tap Check payment.',
            'Payment കഴിഞ്ഞ് ഇവിടെ മടങ്ങിവന്ന് Check payment അമർത്തുക.',
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message = text(
            'Checkout unavailable. Try again shortly. Check pending payments before paying again.',
            'Checkout ലഭ്യമല്ല. അല്പം കഴിഞ്ഞ് ശ്രമിക്കുക. വീണ്ടും അടയ്ക്കുന്നതിന് മുമ്പ് pending payment പരിശോധിക്കുക.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> verifyAll([CoinOrder? selected]) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final pending = selected == null
          ? await widget.source.pending()
          : [selected];
      var credited = false;
      // Bound automatic network work; every order also has an explicit check button.
      for (final order in pending.take(5)) {
        credited = await widget.source.verify(order.id) || credited;
      }
      final remaining = await widget.source.pending();
      if (!mounted) return;
      setState(() {
        orders = remaining;
        message = credited
            ? text(
                'Payment confirmed. Coins added to your wallet.',
                'Payment സ്ഥിരീകരിച്ചു. Coins wallet-ൽ ചേർത്തു.',
              )
            : text(
                'No completed payment confirmed yet. If you paid, wait a moment and check again. Do not pay again.',
                'Payment ഇതുവരെ സ്ഥിരീകരിച്ചിട്ടില്ല. അടച്ചിട്ടുണ്ടെങ്കിൽ അല്പം കാത്ത് വീണ്ടും പരിശോധിക്കുക. വീണ്ടും പണം അടയ്ക്കേണ്ടതില്ല.',
              );
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => message = text(
            'Unable to check payment now. Your order is saved. Check again later.',
            'Payment പരിശോധിക്കാനായില്ല. Order സൂക്ഷിച്ചിട്ടുണ്ട്. പിന്നീട് വീണ്ടും പരിശോധിക്കുക.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(text('Buy coins', 'Coins വാങ്ങുക')),
      actions: [
        IconButton(
          tooltip: text('Refresh', 'Refresh'),
          onPressed: busy ? null : refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          text('Choose a coin plan', 'Coin plan തിരഞ്ഞെടുക്കുക'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          text(
            'Pay securely with Instamojo. Coins are added after payment is verified. Return to this page to check your payment.',
            'Instamojo വഴി പണം അടയ്ക്കാം. Payment സ്ഥിരീകരിച്ചശേഷം coins ചേർക്കും. Payment പരിശോധിക്കാൻ ഈ പേജിൽ മടങ്ങിവരുക.',
          ),
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(liveRegion: true, child: Text(message!)),
          ),
        for (final plan in plans)
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.monetization_on_outlined),
              title: Text('${plan.coins} ${text('coins', 'കോയിനുകൾ')}'),
              subtitle: Text(plan.price),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.expand_more),
                  FilledButton(
                    onPressed: busy ? null : () => buy(plan),
                    child: Text(text('Buy', 'വാങ്ങുക')),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final action in [
                        'follow',
                        'like',
                        'comment',
                        'share',
                      ])
                        if ((rates[action] ?? 0) > 0)
                          Text(
                            '${text('Up to', 'പരമാവധി')} ${plan.coins ~/ rates[action]!} ${switch (action) {
                              'follow' => text('follow tasks', 'follow tasks'),
                              'like' => text('like tasks', 'like tasks'),
                              'comment' => text('comment tasks', 'comment tasks'),
                              _ => text('share tasks', 'share tasks'),
                            }}',
                          ),
                      Text(
                        text(
                          'Use coins across campaigns. Counts are alternatives, not combined; rates may change. Maximum 100 tasks per campaign. No guaranteed results.',
                          'Coins വിവിധ campaigns-ൽ ഉപയോഗിക്കാം. ഓരോ task count-ഉം വേറിട്ട കണക്കാണ്; നിരക്കുകൾ മാറാം. ഒരു campaign-ൽ പരമാവധി 100 tasks. ഫലം ഉറപ്പില്ല.',
                        ),
                      ),
                      if (rates.isEmpty)
                        Text(
                          text(
                            'Task estimates unavailable. Refresh to retry.',
                            'Task കണക്ക് ലഭ്യമല്ല. Refresh ചെയ്യുക.',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (!busy && plans.isEmpty)
          Text(
            text(
              'Coin plans are currently unavailable.',
              'Coin plans ഇപ്പോൾ ലഭ്യമല്ല.',
            ),
          ),
        if (orders.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            text('Pending payments', 'Pending payments'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final order in orders)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${order.coins} ${text('coins', 'കോയിനുകൾ')} · ${CoinPlan('', 0, order.amountPaise).price}',
                    ),
                    Text(
                      '${text('Order', 'Order')}: ${order.id}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: busy ? null : () => verifyAll(order),
                          child: Text(
                            text('Check payment', 'Payment പരിശോധിക്കുക'),
                          ),
                        ),
                        TextButton(
                          onPressed: busy ? null : () => reopen(order),
                          child: Text(
                            text('Open checkout', 'Checkout തുറക്കുക'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    ),
  );

  Future<void> reopen(CoinOrder order) async {
    // Always verify first so an already-paid order is never presented for payment again.
    setState(() => busy = true);
    try {
      if (await widget.source.verify(order.id)) {
        final remaining = await widget.source.pending();
        if (mounted) {
          setState(() {
            orders = remaining;
            message = text(
              'Payment confirmed. Coins added to your wallet.',
              'Payment സ്ഥിരീകരിച്ചു. Coins wallet-ൽ ചേർത്തു.',
            );
          });
        }
      } else if (!await widget.source.open(order.checkout)) {
        throw StateError('Browser unavailable');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message = text(
            'Unable to open checkout. Check payment again later.',
            'Checkout തുറക്കാനായില്ല. പിന്നീട് payment പരിശോധിക്കുക.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
