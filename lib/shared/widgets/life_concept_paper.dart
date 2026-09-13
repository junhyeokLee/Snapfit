import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Blank concept-specific supports; every caption remains an editable layer.
class LifeConceptPaper extends StatelessWidget {
  const LifeConceptPaper({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _LifePaperPainter(id),
    child: const SizedBox.expand(),
  );
}

class _LifePaperPainter extends CustomPainter {
  const _LifePaperPainter(this.id);
  final String id;
  @override
  void paint(Canvas c, Size size) {
    if (size.isEmpty) return;
    c.save();
    c.scale(size.width / 500, size.height / 333);
    void fill(Path path, Color color) =>
        c.drawPath(path, Paint()..color = color);
    void line(
      double x,
      double y,
      double x2,
      double y2,
      Color color, [
      double width = 1,
    ]) => c.drawLine(
      Offset(x, y),
      Offset(x2, y2),
      Paint()
        ..color = color
        ..strokeWidth = width,
    );
    final paper = Path();
    final Color color;
    switch (id) {
      case 'lifeWardrobeLabel':
        paper.addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(12, 20, 476, 290),
            const Radius.circular(12),
          ),
        );
        color = const Color(0xFFE4EDF0);
      case 'lifePicnicSlip':
        paper.moveTo(14, 12);
        for (var x = 14.0; x < 486; x += 16) {
          paper.lineTo(x + 8, 18);
          paper.lineTo(math.min(x + 16, 486), 12);
        }
        paper.lineTo(486, 313);
        for (var x = 486.0; x > 14; x -= 16) {
          paper.lineTo(x - 8, 320);
          paper.lineTo(math.max(x - 16, 14), 313);
        }
        paper.close();
        color = const Color(0xFFF6F5E9);
      case 'lifeHomeNote':
        paper.moveTo(18, 10);
        paper.lineTo(482, 10);
        paper.lineTo(482, 279);
        paper.lineTo(444, 320);
        paper.lineTo(18, 320);
        paper.close();
        color = const Color(0xFFECE8EF);
      case 'lifeCompanionTab':
        paper.moveTo(18, 46);
        paper.lineTo(18, 17);
        paper.quadraticBezierTo(18, 8, 30, 8);
        paper.lineTo(159, 8);
        paper.lineTo(180, 46);
        paper.lineTo(482, 46);
        paper.lineTo(482, 320);
        paper.lineTo(18, 320);
        paper.close();
        color = const Color(0xFFE7EEEA);
      default:
        c.restore();
        return;
    }
    fill(paper.shift(const Offset(1, 2)), const Color(0x14515C59));
    fill(paper, color);
    c.save();
    c.clipPath(paper);
    final random = math.Random(1807);
    for (var i = 0; i < 1200; i++) {
      final x = random.nextDouble() * 500, y = random.nextDouble() * 333;
      line(
        x,
        y,
        x + 1.6,
        y + .4,
        i.isEven ? const Color(0x25FFFFFF) : const Color(0x10505A54),
        .55,
      );
    }
    c.restore();
    switch (id) {
      case 'lifeWardrobeLabel':
        c.drawRect(
          const Rect.fromLTWH(12, 20, 25, 290),
          Paint()..color = const Color(0xFFC3D3DB),
        );
        c.drawRect(
          const Rect.fromLTWH(463, 20, 25, 290),
          Paint()..color = const Color(0xFFC3D3DB),
        );
        for (var x = 45.0; x < 456; x += 11) {
          line(x, 38, x + 5, 38, const Color(0xFF8BA4AD));
          line(x, 291, x + 5, 291, const Color(0xFF8BA4AD));
        }
        for (var y = 31.0; y < 305; y += 8) {
          line(21, y, 29, y + 2, const Color(0x99FAFCFB));
          line(470, y, 478, y + 2, const Color(0x99FAFCFB));
        }
        line(65, 68, 141, 68, const Color(0xFF7896A5), 2);
      case 'lifePicnicSlip':
        line(43, 32, 43, 298, const Color(0xFFAB6A61), 2);
        line(51, 32, 51, 298, const Color(0x66AB6A61));
        for (var x = 80.0; x < 452; x += 13)
          line(x, 58, x + 6, 58, const Color(0xFF9DA584));
        for (var i = 0; i < 3; i++)
          c.drawRect(
            Rect.fromLTWH(366 + i * 27, 278, 17, 17),
            Paint()
              ..color = [
                const Color(0xFF758669),
                const Color(0xFFB78977),
                const Color(0xFFE1C899),
              ][i],
          );
      case 'lifeHomeNote':
        c.drawRect(
          const Rect.fromLTWH(18, 10, 464, 33),
          Paint()..color = const Color(0xFFD5CDD9),
        );
        line(37, 45, 458, 45, const Color(0xBBFFFFFF), 2);
        fill(
          Path()
            ..moveTo(444, 279)
            ..lineTo(482, 279)
            ..lineTo(444, 320)
            ..close(),
          const Color(0xFFBEB7C5),
        );
        for (var x = 47.0; x < 428; x += 15)
          line(x, 292, x + 5, 292, const Color(0xFFB9ACBA));
        for (var x in [40.0, 57.0])
          line(x, 21, x, 58, const Color(0xFF959E99), 3);
      case 'lifeCompanionTab':
        c.drawRect(
          const Rect.fromLTWH(25, 54, 22, 254),
          Paint()..color = const Color(0xFF7B9990),
        );
        line(66, 73, 451, 73, const Color(0xFF9CAD9E));
        for (var x in [58.0, 82.0, 106.0])
          c.drawCircle(
            Offset(x, 27),
            3,
            Paint()..color = const Color(0xFF6A8780),
          );
        line(335, 291, 450, 291, const Color(0xFF78998F));
        c.drawCircle(
          const Offset(456, 301),
          3,
          Paint()..color = const Color(0xFFB58A6F),
        );
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _LifePaperPainter old) => old.id != id;
}
