import 'package:flutter/material.dart';

/// A typographic signature for the user app, with one accessible brand name.
class FreelanWordmark extends StatelessWidget {
  const FreelanWordmark({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Freelan Space',
    image: true,
    child: ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'free',
                  style: TextStyle(color: Color(0xff211343)),
                ),
                TextSpan(
                  text: 'lan',
                  style: TextStyle(color: Color(0xff6736ca)),
                ),
              ],
            ),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 27,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.4,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'SPACE',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3.4,
                  color: Color(0xff5c4779),
                  height: 1,
                ),
              ),
              const SizedBox(width: 5),
              const CustomPaint(size: Size(38, 12), painter: _OrbitPainter()),
            ],
          ),
        ],
      ),
    ),
  );
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final orbit = Path()
      ..moveTo(1, 8)
      ..cubicTo(9, 2, 22, 12, 36, 3);
    canvas.drawPath(
      orbit,
      Paint()
        ..color = const Color(0xff7643d7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      const Offset(32, 5),
      2.5,
      Paint()..color = const Color(0xffc79748),
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) => false;
}
