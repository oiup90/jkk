import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Each destination has its own quiet backdrop; controls and page content remain
/// in the foreground and retain their existing semantics and interactions.
enum UserPageIdentity {
  setup(0),
  signIn(1),
  signUp(2),
  verification(3),
  recovery(4),
  blocked(5),
  home(6),
  earn(7),
  campaigns(8),
  profile(9),
  notifications(10),
  createCampaign(11),
  evidence(12),
  coinHistory(13),
  instagramAccounts(14),
  referrals(15),
  settings(16),
  submissionHistory(17),
  help(18),
  support(19),
  conversation(20),
  personalInfo(21),
  changeEmail(22),
  purchase(23),
  transfer(24),
  processing(25),
  resultSuccess(26),
  resultFailure(27),
  resultUnknown(28),
  privacy(29),
  terms(30),
  updates(31),
  mandatoryUpdate(32);

  const UserPageIdentity(this.designId);
  final int designId;
}

class UserPageScaffold extends Scaffold {
  UserPageScaffold({
    super.key,
    required UserPageIdentity identity,
    required Widget body,
    bool enabled = true,
    super.appBar,
    super.bottomNavigationBar,
    super.floatingActionButton,
    super.resizeToAvoidBottomInset,
  }) : super(
         body: UserPageCanvas(
           identity: identity,
           enabled: enabled,
           child: body,
         ),
         backgroundColor: enabled ? Colors.transparent : null,
       );
}

class UserPageCanvas extends StatelessWidget {
  const UserPageCanvas({
    super.key,
    required this.identity,
    required this.child,
    this.enabled = true,
  });
  final UserPageIdentity identity;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) => !enabled
      ? child
      : Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: CustomPaint(painter: _PagePainter(identity)),
                ),
              ),
            ),
            child,
          ],
        );
}

class _PagePainter extends CustomPainter {
  const _PagePainter(this.identity);
  final UserPageIdentity identity;

  @override
  void paint(Canvas canvas, Size size) {
    final i = identity.designId;
    final hue = (255.0 + i * 23.0) % 360;
    final light = HSLColor.fromAHSL(1, hue, .46, .96).toColor();
    final tint = HSLColor.fromAHSL(1, hue, .62, .76).toColor();
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: i.isEven ? Alignment.topLeft : Alignment.topRight,
          end: i.isEven ? Alignment.bottomRight : Alignment.bottomLeft,
          colors: [const Color(0xfffbf9ff), light],
        ).createShader(rect),
    );
    final fill = Paint()..color = tint.withValues(alpha: .14);
    final line = Paint()
      ..color = tint.withValues(alpha: .25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final w = size.width, h = size.height;
    final x = i.isEven ? w : 0.0;
    switch (i % 5) {
      case 0:
        canvas.drawCircle(Offset(x, h * .08), w * .46, fill);
        canvas.drawCircle(Offset(x, h * .08), w * .37, line);
      case 1:
        final path = Path()
          ..moveTo(0, h * .1)
          ..quadraticBezierTo(w * .48, h * .02, w, h * .16)
          ..lineTo(w, 0)
          ..lineTo(0, 0)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(x, h * .18),
            width: w * .8,
            height: w * .5,
          ),
          0,
          math.pi,
          false,
          line,
        );
      case 2:
        canvas.save();
        canvas.translate(x, h * .14);
        canvas.rotate((i.isEven ? 1 : -1) * .25);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: w * .7,
              height: w * .35,
            ),
            const Radius.circular(36),
          ),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: w * .55,
              height: w * .25,
            ),
            const Radius.circular(28),
          ),
          line,
        );
        canvas.restore();
      case 3:
        for (var row = 0; row < 5; row++) {
          for (var col = 0; col < 5; col++) {
            final px = i.isEven ? w - 18.0 - col * 18 : 18.0 + col * 18;
            canvas.drawCircle(
              Offset(px, 20.0 + row * 18),
              2.0 + (i % 3) * .4,
              fill,
            );
          }
        }
        canvas.drawCircle(Offset(x, h * .76), w * .33, line);
      case 4:
        final path = Path()
          ..moveTo(0, h * .15)
          ..lineTo(w, 0)
          ..lineTo(w, h * .08)
          ..lineTo(0, h * .25)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawLine(Offset(0, h * .25), Offset(w, h * .08), line);
    }
  }

  @override
  bool shouldRepaint(covariant _PagePainter oldDelegate) =>
      oldDelegate.identity != identity;
}
