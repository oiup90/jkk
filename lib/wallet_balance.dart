import 'dart:async';

import 'design.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reveals only a server-provided balance; pending requests never show fake coins.
class WalletBalance extends StatefulWidget {
  const WalletBalance({
    super.key,
    required this.balances,
    this.isMalayalam = false,
    this.onBuyCoins,
  });
  final Stream<List<Map<String, dynamic>>> balances;
  final bool isMalayalam;
  final VoidCallback? onBuyCoins;
  @override
  State<WalletBalance> createState() => _WalletBalanceState();
}

class _WalletBalanceState extends State<WalletBalance>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const soundChannel = MethodChannel('growth_circle/wallet_audio');
  late final AnimationController counter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  StreamSubscription<List<Map<String, dynamic>>>? subscription;
  int? balance;
  String? walletNumber;
  int from = 0, target = 0;
  bool revealed = false, failed = false, unavailable = false;
  String text(String en, String ml) => widget.isMalayalam ? ml : en;

  Future<void> sound(bool play) async {
    try {
      await soundChannel.invokeMethod<void>(
        play ? 'playCoinCount' : 'stopCoinCount',
      );
    } on PlatformException {
      // Audio failure must not prevent viewing a balance.
    } on MissingPluginException {
      // Native audio is currently available on Android.
    }
  }

  void listen() {
    subscription = widget.balances.listen(
      (rows) {
        if (!mounted) return;
        final value = rows.isEmpty ? null : rows.first['balance'];
        final number = rows.isEmpty ? null : rows.first['wallet_number'];
        final wasPending = balance == null;
        setState(() {
          failed = false;
          unavailable = value is! int || value < 0;
          balance = value is int && value >= 0 ? value : null;
          walletNumber =
              number is String && RegExp(r'^[1-9][0-9]{9}$').hasMatch(number)
              ? number
              : null;
        });
        if (revealed && balance != null) animate(playSound: wasPending);
        if (balance == null) {
          counter.stop();
          unawaited(sound(false));
        }
      },
      onError: (Object _) {
        if (!mounted) return;
        counter.stop();
        unawaited(sound(false));
        setState(() {
          failed = true;
          balance = null;
        });
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    listen();
  }

  @override
  void didUpdateWidget(covariant WalletBalance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.balances != widget.balances) {
      unawaited(subscription?.cancel());
      counter.stop();
      unawaited(sound(false));
      balance = null;
      walletNumber = null;
      revealed = false;
      failed = false;
      unavailable = false;
      from = 0;
      target = 0;
      listen();
    }
  }

  void animate({required bool playSound}) {
    final next = balance!;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    from = playSound ? 0 : (from + (target - from) * counter.value).round();
    target = next;
    if (reduceMotion || from == target) {
      counter.value = 1;
      return;
    }
    counter.forward(from: 0);
    if (playSound) unawaited(sound(true));
  }

  void toggle() {
    setState(() => revealed = !revealed);
    if (revealed && balance != null) {
      animate(playSound: true);
    } else {
      counter.stop();
      unawaited(sound(false));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      counter.stop();
      unawaited(sound(false));
      if (mounted) setState(() => revealed = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(subscription?.cancel());
    unawaited(sound(false));
    counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: growthGradient,
      borderRadius: BorderRadius.circular(26),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: .55,
              heightFactor: 1,
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.transparent, Colors.white],
                  stops: [0, .4],
                ).createShader(bounds),
                blendMode: BlendMode.dstIn,
                child: Image.asset(
                  'assets/design/wallet_reference.png',
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    text('Wallet', 'വാലറ്റ്'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              if (walletNumber != null)
                SelectableText(
                  '${text('Wallet number', 'വാലറ്റ് നമ്പർ')}: $walletNumber',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              const SizedBox(height: 4),
              AnimatedBuilder(
                animation: counter,
                builder: (context, _) {
                  final message = !revealed
                      ? '••••'
                      : failed
                      ? text(
                          'Unable to load balance. Try again later.',
                          'Balance ലഭിച്ചില്ല. പിന്നീട് വീണ്ടും ശ്രമിക്കുക.',
                        )
                      : unavailable
                      ? text('Balance unavailable', 'Balance ലഭ്യമല്ല')
                      : balance == null
                      ? '••••'
                      : '${(from + (target - from) * Curves.easeOutCubic.transform(counter.value)).round()} ${text('Coins', 'കോയിനുകൾ')}';
                  return Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
              if (widget.onBuyCoins != null)
                TextButton.icon(
                  onPressed: widget.onBuyCoins,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: Text(text('Buy coins', 'Coins വാങ്ങുക')),
                ),
              const SizedBox(height: 4),
              Tooltip(
                message: revealed
                    ? text('Hide balance', 'Balance മറയ്ക്കുക')
                    : text('Check balance', 'Balance പരിശോധിക്കുക'),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xff4710a3),
                    backgroundColor: const Color(0xffd3b8ff),
                    minimumSize: const Size(0, 28),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                  ),
                  onPressed: toggle,
                  icon: Icon(
                    revealed
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 16,
                  ),
                  label: Text(
                    revealed
                        ? text('Hide balance', 'Balance മറയ്ക്കുക')
                        : text('Check balance', 'Balance പരിശോധിക്കുക'),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
