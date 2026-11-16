import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Printed ruling only; the book's date, place and prose are native text layers.
class SensoryStationery extends StatelessWidget {
  const SensoryStationery({super.key, required this.night});
  final bool night;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _SensoryPaper(night),
    child: const SizedBox.expand(),
  );
}

class _SensoryPaper extends CustomPainter {
  const _SensoryPaper(this.night);
  final bool night;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, u = math.min(w, h);
    final r = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(u * .012)),
      Paint()
        ..color = night ? const Color(0xFFE7EDF5) : const Color(0xFFF1E5CF),
    );
    final ink = night ? const Color(0xFF536D9E) : const Color(0xFFA88C68);
    final rule = Paint()
      ..color = ink.withValues(alpha: .40)
      ..strokeWidth = u * .002;
    if (night) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w * .13, h),
        Paint()..color = const Color(0xFF3153CD),
      );
      canvas.drawCircle(
        Offset(w * .065, h * .14),
        u * .012,
        Paint()..color = const Color(0xFFE5EDF9),
      );
      canvas.drawLine(
        Offset(w * .065, h * .18),
        Offset(w * .065, h * .80),
        Paint()
          ..color = const Color(0xFF8BA8F4)
          ..strokeWidth = u * .004,
      );
      for (final y in [.38, .57, .76]) {
        canvas.drawCircle(
          Offset(w * .065, h * y),
          u * .012,
          Paint()..color = const Color(0xFFE5EDF9),
        );
      }
      canvas.drawLine(Offset(w * .20, h * .23), Offset(w * .91, h * .23), rule);
      for (var i = 0; i < 3; i++) {
        final x = w * (.20 + i * .25);
        canvas.drawLine(Offset(x, h * .70), Offset(x + w * .19, h * .70), rule);
      }
    } else {
      for (var y = h * .06; y < h * .95; y += u * .032) {
        canvas.drawLine(Offset(w * .065, y), Offset(w * .075, y), rule);
      }
      canvas.drawLine(Offset(w * .14, h * .24), Offset(w * .90, h * .24), rule);
      canvas.drawLine(Offset(w * .14, h * .78), Offset(w * .90, h * .78), rule);
      canvas.drawCircle(
        Offset(w * .91, h * .12),
        u * .025,
        Paint()..color = const Color(0xFFCFBA96),
      );
    }
    for (var i = 0; i < 3; i++) {
      final y = h * (.38 + i * .12);
      canvas.drawLine(
        Offset(w * (night ? .20 : .14), y),
        Offset(w * .90, y),
        rule,
      );
    }
  }

  @override
  bool shouldRepaint(_SensoryPaper old) => old.night != night;
}
