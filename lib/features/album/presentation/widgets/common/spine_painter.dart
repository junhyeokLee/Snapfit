import 'package:flutter/material.dart';

// 책의 끝의 봉재선 부분
class SpinePainter extends CustomPainter {
  final Color baseStart;
  final Color baseEnd;

  SpinePainter({required this.baseStart, required this.baseEnd});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1) Base vertical gradient (top-bottom) to blend with cover
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [baseStart, baseEnd],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    // 2) Bevel across the width (left-right) to create curved/embossed look
    //    Darker edges, bright shoulders, dark groove at center.
    final bevelPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.black.withOpacity(0.35),   // outer left shadow
          Colors.white.withOpacity(0.30),   // left shoulder highlight
          Colors.black.withOpacity(0.15),   // central groove (deep)
          Colors.black.withOpacity(0.1),   // right shoulder highlight
          Colors.white.withOpacity(0.0),   // outer right shadow
        ],
        stops: const [0.0, 0.25, 0.50, 0.8, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bevelPaint);

    // 3) Inner subtle vertical noise/highlight for realism (top brighter)
    final verticalHighlight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.08),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, verticalHighlight);
  }

  @override
  bool shouldRepaint(covariant SpinePainter oldDelegate) {
    return oldDelegate.baseStart != baseStart || oldDelegate.baseEnd != baseEnd;
  }
}