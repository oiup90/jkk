import 'user_localization.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reveals only a server-provided balance; pending requests never show fake coins.
class WalletBalance extends StatefulWidget {
  const WalletBalance({
    super.key,
    required this.balances,
    this.isMalayalam = false,
    this.onBuyCoins,
    this.onTransfer,
    this.onHistory,
  });
  final Stream<List<Map<String, dynamic>>> balances;
  final bool isMalayalam;
  final VoidCallback? onBuyCoins;
  final VoidCallback? onTransfer;
  final VoidCallback? onHistory;
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
  int held = 0;
  bool active = true;
  int from = 0, target = 0;
  bool revealed = false, failed = false, unavailable = false;
  String text(String en, String ml) =>
      userText(context, en, ml, forceMalayalam: widget.isMalayalam);

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
        final reserved = rows.isEmpty ? 0 : rows.first['held_balance'];
        final enabled = rows.isEmpty ? true : rows.first['is_active'];
        final wasPending = balance == null;
        setState(() {
          failed = false;
          unavailable = value is! int || value < 0;
          held = reserved is int && reserved >= 0 ? reserved : 0;
          active = enabled != false;
          balance = value is int && value >= held ? value - held : null;
          walletNumber =
              number is String && RegExp(r'^[1-9][0-9]{9}$').hasMatch(number)
              ? number
              : null;
        });
        if (revealed && balance != null) animate(reset: wasPending);
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
      held = 0;
      active = true;
      revealed = false;
      failed = false;
      unavailable = false;
      from = 0;
      target = 0;
      listen();
    }
  }

  void animate({required bool reset}) {
    final next = balance!;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    from = reset ? 0 : (from + (target - from) * counter.value).round();
    target = next;
    if (reduceMotion || from == target) {
      counter.value = 1;
      return;
    }
    counter.forward(from: 0);
  }

  void toggle() {
    setState(() => revealed = !revealed);
    if (revealed) {
      unawaited(sound(true));
      if (balance != null) animate(reset: true);
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
    margin: const EdgeInsets.only(top: 6, bottom: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      boxShadow: [
        BoxShadow(
          color: const Color(0xff211039).withValues(alpha: .25),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff65418d), Color(0xff3c205f), Color(0xff281545)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _WalletStitchPainter()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xfff6e1a8).withValues(alpha: .14),
                          border: Border.all(
                            color: const Color(0xffe7c981)
                                .withValues(alpha: .42),
                          ),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Color(0xfff4dbab),
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              text('Wallet', 'വാലറ്റ്'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Text(
                              'FREELAN SPACE',
                              style: TextStyle(
                                color: Color(0xffd8c6e7),
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const _WalletClasp(),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(15, 14, 15, 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xff8b6ab1),
                          Color(0xff5a387e),
                          Color(0xff473060),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0x66ffffff)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x45201035),
                          blurRadius: 12,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text('Available balance', 'ലഭ്യമായ balance'),
                          style: const TextStyle(
                            color: Color(0xffeadff3),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 5),
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
                                ? text(
                                    'Balance unavailable',
                                    'Balance ലഭ്യമല്ല',
                                  )
                                : balance == null
                                ? '••••'
                                : '${(from + (target - from) * Curves.easeOutCubic.transform(counter.value)).round()} ${text('Coins', 'കോയിനുകൾ')}';
                            return Text(
                              message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .2,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Tooltip(
                          message: revealed
                              ? text('Hide balance', 'Balance മറയ്ക്കുക')
                              : text('Check balance', 'Balance പരിശോധിക്കുക'),
                          child: TextButton.icon(
                            onPressed: toggle,
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xff38204e),
                              backgroundColor: const Color(0xfff2dfb5),
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: Icon(
                              revealed
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 17,
                            ),
                            label: Text(
                              revealed
                                  ? text('Hide balance', 'Balance മറയ്ക്കുക')
                                  : text(
                                      'Check balance',
                                      'Balance പരിശോധിക്കുക',
                                    ),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!active)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        text(
                          'Wallet inactive: outgoing spending is disabled.',
                          'Wallet inactive ആണ്. Coins ചെലവാക്കാൻ കഴിയില്ല.',
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  if (revealed && held > 0)
                    Text(
                      '${text('Held coins', 'Hold ചെയ്ത coins')}: $held',
                      style: const TextStyle(color: Colors.white),
                    ),
                  if (walletNumber != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            '${text('Wallet number', 'വാലറ്റ് നമ്പർ')}: $walletNumber',
                            style: const TextStyle(
                              color: Color(0xffeee3f5),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: text(
                            'Copy wallet number',
                            'വാലറ്റ് നമ്പർ പകർത്തുക',
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: const Color(0xfff4dbab),
                            minimumSize: const Size(48, 48),
                          ),
                          icon: const Icon(
                            Icons.copy_outlined,
                            color: Color(0xfff4dbab),
                            size: 18,
                          ),
                          onPressed: () async {
                            try {
                              await Clipboard.setData(
                                ClipboardData(text: walletNumber!),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    text(
                                      'Wallet number copied',
                                      'വാലറ്റ് നമ്പർ പകർത്തി',
                                    ),
                                  ),
                                ),
                              );
                            } on PlatformException {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      text(
                                        'Unable to copy wallet number',
                                        'വാലറ്റ് നമ്പർ പകർത്താനായില്ല',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                  if (widget.onBuyCoins != null ||
                      widget.onTransfer != null ||
                      widget.onHistory != null) ...[
                    const SizedBox(height: 8),
                    Container(height: 1, color: const Color(0x55d8bde8)),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stack =
                            constraints.maxWidth < 270 ||
                            MediaQuery.textScalerOf(context).scale(1) > 1.2;
                        final buttons = <Widget>[
                          if (widget.onBuyCoins != null)
                            _WalletActionButton(
                              icon: Icons.add_circle_outline,
                              label: text('Buy coins', 'Coins വാങ്ങുക'),
                              onPressed: widget.onBuyCoins!,
                            ),
                          if (widget.onTransfer != null)
                            _WalletActionButton(
                              icon: Icons.send_outlined,
                              label: text('Transfer coins', 'Coins അയയ്ക്കുക'),
                              onPressed:
                                  active && balance != null && balance! > 0
                                  ? widget.onTransfer!
                                  : null,
                            ),
                        ];
                        if (stack) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < buttons.length; i++) ...[
                                if (i > 0) const SizedBox(height: 8),
                                buttons[i],
                              ],
                            ],
                          );
                        }
                        return Row(
                          children: [
                            for (var i = 0; i < buttons.length; i++) ...[
                              if (i > 0) const SizedBox(width: 10),
                              Expanded(child: buttons[i]),
                            ],
                          ],
                        );
                      },
                    ),
                    if (widget.onHistory != null) ...[
                      if (widget.onBuyCoins != null ||
                          widget.onTransfer != null)
                        const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: _WalletActionButton(
                          icon: Icons.history,
                          label: text('Coin history', 'Coin ചരിത്രം'),
                          onPressed: widget.onHistory!,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _WalletActionButton extends StatelessWidget {
  const _WalletActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    label: Text(label, textAlign: TextAlign.center),
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Color(0x99d8bde8)),
      minimumSize: const Size(0, 46),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      textStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    ),
  );
}

class _WalletClasp extends StatelessWidget {
  const _WalletClasp();
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 45,
      height: 30,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff71518d), Color(0xff39204f)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffa88ab6)),
      ),
      child: Center(
        child: Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xffffe8a8), Color(0xffb89047)],
            ),
            border: Border.all(color: const Color(0xffe8cb87)),
          ),
        ),
      ),
    ),
  );
}

class _WalletStitchPainter extends CustomPainter {
  const _WalletStitchPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final border = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(28),
    ).deflate(8);
    final path = Path()..addRRect(border);
    final paint = Paint()
      ..color = const Color(0x55e7c9e9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      for (double position = 0; position < metric.length; position += 6) {
        canvas.drawPath(
          metric.extractPath(
            position,
            (position + 2.5).clamp(0, metric.length),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
