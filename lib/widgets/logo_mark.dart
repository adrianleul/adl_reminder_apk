import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The app logo, drawn from the same geometry as the launcher icon
/// (assets/logo/logo.svg): an almost-closed countdown ring, a check, and a
/// dot marking the moment that's next.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'ADL Reminder',
      image: true,
      child: CustomPaint(size: Size.square(size), painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 108;
    canvas.scale(unit);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 108, 108),
        const Radius.circular(24),
      ),
      Paint()..color = AppColors.accent,
    );
    canvas
      ..translate(54, 54)
      ..scale(1.3)
      ..translate(-54, -54);
    final stroke = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(54, 54), radius: 24),
      -math.pi / 2,
      math.pi * 300 / 180,
      false,
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(44, 55)
        ..lineTo(51.5, 62.5)
        ..lineTo(65, 47),
      stroke,
    );
    canvas.drawCircle(
      const Offset(42, 33.22),
      4.5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => false;
}
