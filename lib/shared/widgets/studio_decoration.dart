import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/templates/studio_decoration_catalog.dart';
import 'luminous_stationery.dart';
import 'zine_material.dart';
import 'travel_stationery.dart';
import 'heirloom_stationery.dart';
import 'keepsake_stationery.dart';
import 'atelier_composition_paper.dart';
import 'life_concept_paper.dart';

/// The picker, editor and template renderer share the same material artwork.
class StudioDecoration extends StatelessWidget {
  const StudioDecoration({super.key, required this.spec, this.printImage});
  final StudioDecorationSpec spec;
  final ui.Image? printImage;

  @override
  Widget build(BuildContext context) {
    if (spec.assetPath case final String path) {
      if (printImage != null) {
        return RawImage(
          image: printImage,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        );
      }
      return Image.asset(
        path,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
    }
    if (spec.id.startsWith('material')) return KeepsakeStationery(id: spec.id);
    if (lifeVarietyPapers.any((s) => s.id == spec.id))
      return LifeConceptPaper(id: spec.id);
    if (atelierCompositionDecorations.any((s) => s.id == spec.id))
      return AtelierCompositionPaper(id: spec.id);
    if (spec.id.startsWith('zine')) return ZineStationery(id: spec.id);
    if (spec.id.startsWith('luminous')) return LuminousStationery(id: spec.id);
    if (spec.id.startsWith('travel')) return TravelStationery(id: spec.id);
    if (spec.id.startsWith('heirloom')) return HeirloomStationery(id: spec.id);
    return CustomPaint(
      painter: _StationeryPainter(spec.id),
      child: spec.id == 'studioBotanicalStamp'
          ? LayoutBuilder(
              builder: (context, constraints) => Padding(
                padding: EdgeInsets.fromLTRB(
                  constraints.maxWidth * .16,
                  constraints.maxHeight * .17,
                  constraints.maxWidth * .16,
                  constraints.maxHeight * .18,
                ),
                child: printImage != null
                    ? RawImage(
                        image: printImage,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      )
                    : Image.asset(
                        'assets/sticker/studio/pressed_cosmos.png',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
              ),
            )
          : const SizedBox.expand(),
    );
  }
}

class _StationeryPainter extends CustomPainter {
  const _StationeryPainter(this.id);
  final String id;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // Work in material coordinates, so grain and edges survive scale/export.
    const width = 300.0;
    final height = width * size.height / size.width;
    if (id == 'studioPostalMark') {
      canvas.save();
      canvas.scale(size.width / width);
      _postalMark(canvas, height);
      canvas.restore();
      return;
    }
    final sheet = Rect.fromLTWH(5, 5, width - 10, height - 10);
    final tape = id.startsWith('studioWashi');
    final stamp = id == 'studioBotanicalStamp';
    final travelTicket = id == 'studioTravelTicket';
    final ticket = id == 'studioKeepsakeTicket' || travelTicket;
    final vellum = id == 'studioVellum';
    final path = _edge(sheet, tape: tape, perforated: stamp);
    final shape = ticket
        ? Path.combine(
            PathOperation.difference,
            path,
            Path()
              ..addOval(
                Rect.fromCircle(
                  center: Offset(sheet.left, sheet.center.dy),
                  radius: 9,
                ),
              )
              ..addOval(
                Rect.fromCircle(
                  center: Offset(sheet.right, sheet.center.dy),
                  radius: 9,
                ),
              ),
          )
        : path;
    canvas.save();
    canvas.scale(size.width / width);
    if (!vellum) {
      canvas.drawPath(
        shape.shift(const Offset(.6, 1.2)),
        Paint()
          ..color = const Color(0x14282D29)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
      );
    }
    final color = switch (id) {
      'studioBlushPaper' => const Color(0xFFE8CDD1),
      'studioLedger' => const Color(0xFFF3F5E9),
      'studioVellum' => const Color(0xAEF9F8F1),
      'studioWashiSage' => const Color(0xE0B9C8AE),
      'studioWashiRose' => const Color(0xE0EEC5CD),
      'studioWashiIndigo' => const Color(0xE0D3DFEA),
      'studioKeepsakeTicket' => const Color(0xFFE7ECCD),
      'studioBotanicalStamp' => const Color(0xFFF5E9ED),
      'studioTravelMap' => const Color(0xFFEEF0E8),
      'studioTravelTicket' => const Color(0xFFF0F1E9),
      _ => const Color(0xFFFAF8F0),
    };
    canvas.drawPath(shape, Paint()..color = color);
    canvas.save();
    canvas.clipPath(shape);
    final ink = Paint()
      ..color = const Color(0xFF41614B)
      ..strokeWidth = .65;
    if (id == 'studioTravelMap') {
      _travelMap(canvas, height);
    } else if (id == 'studioLedger') {
      ink.color = const Color(0x30546E59);
      for (var y = 35.0; y < height; y += 20) {
        canvas.drawLine(Offset(5, y), Offset(295, y), ink);
      }
      canvas.drawLine(
        Offset(42, 5),
        Offset(42, height - 5),
        Paint()
          ..color = const Color(0x66B36D75)
          ..strokeWidth = .7,
      );
    } else if (id == 'studioWashiSage') {
      ink.color = const Color(0x85617955);
      for (var x = -height; x < width; x += 12) {
        canvas.drawLine(Offset(x, 0), Offset(x + height, height), ink);
        canvas.drawLine(Offset(x + 2, 0), Offset(x + height + 2, height), ink);
      }
    } else if (id == 'studioWashiRose') {
      ink
        ..color = const Color(0x45934860)
        ..strokeWidth = 3;
      for (var x = 12.0; x < width; x += 17) {
        canvas.drawLine(Offset(x, 0), Offset(x, height), ink);
      }
      for (var y = 10.0; y < height; y += 17) {
        canvas.drawLine(Offset(0, y), Offset(width, y), ink);
      }
    } else if (id == 'studioWashiIndigo') {
      ink.color = const Color(0xA3335673);
      for (var row = 0; row < height / 18; row++) {
        for (var col = 0; col < 17; col++) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(col * 19 + (row.isEven ? 2 : 11), row * 18 + 8),
              width: 2.6,
              height: 3.6,
            ),
            ink,
          );
        }
      }
    }
    // Deterministic fine fibers, not a moving noise overlay or simulated gloss.
    final random = math.Random(1409);
    final fiber = Paint()..strokeCap = StrokeCap.round;
    final count = (width * height / 75).round();
    for (var i = 0; i < count; i++) {
      final x = random.nextDouble() * width;
      final y = random.nextDouble() * height;
      fiber
        ..color = (i.isEven ? Colors.white : const Color(0xFF675F52))
            .withValues(
              alpha: vellum
                  ? .025
                  : i.isEven
                  ? .23
                  : .048,
            )
        ..strokeWidth = .2 + random.nextDouble() * .35;
      canvas.drawLine(
        Offset(x, y),
        Offset(
          x + .5 + random.nextDouble() * 2.4,
          y + (random.nextDouble() - .5) * 1.6,
        ),
        fiber,
      );
    }
    if (!tape && !stamp && !ticket) {
      canvas.drawPath(
        shape,
        Paint()
          ..color = Colors.white.withValues(alpha: .65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
      canvas.drawPath(
        shape,
        Paint()
          ..color = const Color(0x1A84766C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .4,
      );
    }
    if (vellum) {
      final fold = Path()
        ..moveTo(232, 5)
        ..lineTo(295, 67)
        ..lineTo(295, 5)
        ..close();
      canvas.drawPath(fold, Paint()..color = const Color(0x36FFFFFF));
      canvas.drawLine(
        const Offset(232, 5),
        const Offset(295, 67),
        Paint()
          ..color = const Color(0x26979485)
          ..strokeWidth = .6,
      );
    }
    if (travelTicket) {
      _travelTicket(canvas, height);
    } else if (ticket || stamp) {
      final rect = sheet.deflate(stamp ? 14 : 10);
      canvas.drawRect(
        rect,
        Paint()
          ..color = const Color(0x876A7B55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8,
      );
      if (ticket) {
        for (var y = 10.0; y < height - 10; y += 7) {
          canvas.drawLine(
            Offset(238, y),
            Offset(238, y + 2.5),
            Paint()
              ..color = const Color(0x77758761)
              ..strokeWidth = .7,
          );
        }
        _text(
          canvas,
          'KEEP THIS',
          Rect.fromLTWH(23, height * .19, 195, 15),
          10,
          'NotoSans',
        );
        _text(
          canvas,
          'Moment',
          Rect.fromLTWH(23, height * .35, 198, 44),
          34,
          'Cormorant Garamond',
        );
        _text(
          canvas,
          'No. 001',
          Rect.fromLTWH(23, height * .77, 195, 14),
          9,
          'NotoSans',
        );
        canvas.save();
        canvas.translate(271, height * .77);
        canvas.rotate(-math.pi / 2);
        _text(
          canvas,
          'SNAPFIT',
          const Rect.fromLTWH(0, 0, 90, 13),
          9,
          'NotoSans',
        );
        canvas.restore();
      } else {
        _text(
          canvas,
          'BOTANICAL ARCHIVE',
          Rect.fromLTWH(20, 23, 260, 18),
          12,
          'NotoSans',
          center: true,
        );
        _text(
          canvas,
          '01 / PRESSED WITH LOVE',
          Rect.fromLTWH(20, height - 42, 260, 18),
          10,
          'NotoSans',
          center: true,
        );
      }
    }
    canvas.restore();
    canvas.restore();
  }

  void _travelMap(Canvas canvas, double height) {
    canvas.save();
    canvas.scale(1, height / 214);
    final water = Path()
      ..moveTo(203, 0)
      ..cubicTo(152, 48, 243, 83, 194, 123)
      ..cubicTo(166, 147, 221, 178, 196, 214)
      ..lineTo(300, 214)
      ..lineTo(300, 0)
      ..close();
    canvas.drawPath(water, Paint()..color = const Color(0xFFAFC8C8));
    final road = Paint()
      ..color = const Color(0xFFCCD3C5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var row = 0; row < 10; row++) {
      final y = 12.0 + row * 23;
      canvas.drawPath(
        Path()
          ..moveTo(0, y)
          ..cubicTo(65, y - 17, 115, y + 12, 194, y - 5),
        road,
      );
    }
    for (var col = 0; col < 9; col++) {
      final x = 9.0 + col * 23;
      canvas.drawPath(
        Path()
          ..moveTo(x, 0)
          ..cubicTo(x + 23, 68, x - 26, 128, x + 16, 214),
        road,
      );
    }
    final route = Path()
      ..moveTo(39, 175)
      ..cubicTo(38, 135, 106, 159, 111, 111)
      ..cubicTo(116, 65, 151, 85, 161, 45);
    final routeInk = Paint()
      ..color = const Color(0xA34D7775)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;
    for (final metric in route.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 7) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + 3.5, metric.length)),
          routeInk,
        );
      }
    }
    for (final p in [const Offset(39, 175), const Offset(161, 45)]) {
      canvas.drawCircle(p, 3.2, Paint()..color = const Color(0xFFEEF0E8));
      canvas.drawCircle(p, 3.2, routeInk);
    }
    // Printed fold lines are part of the paper, not a raised border.
    for (final x in [100.0, 200.0]) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, 214),
        Paint()
          ..color = const Color(0x18516A62)
          ..strokeWidth = 1.1,
      );
      canvas.drawLine(
        Offset(x + 1, 0),
        Offset(x + 1, 214),
        Paint()
          ..color = const Color(0x66FFFFFF)
          ..strokeWidth = .6,
      );
    }
    _text(
      canvas,
      'N',
      const Rect.fromLTWH(270, 19, 12, 12),
      8,
      'NotoSans',
      center: true,
    );
    canvas.drawLine(const Offset(276, 36), const Offset(276, 57), routeInk);
    canvas.drawLine(const Offset(251, 191), const Offset(282, 191), routeInk);
    canvas.restore();
  }

  void _travelTicket(Canvas canvas, double height) {
    canvas.save();
    canvas.scale(1, height / 120);
    final ink = Paint()
      ..color = const Color(0x99607870)
      ..strokeWidth = .7;
    canvas.drawRect(
      const Rect.fromLTWH(16, 15, 268, 90),
      Paint()
        ..color = ink.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7,
    );
    canvas.drawLine(const Offset(28, 64), const Offset(218, 64), ink);
    for (var y = 10.0; y < 110; y += 6) {
      canvas.drawLine(Offset(236, y), Offset(236, y + 2), ink);
    }
    _text(
      canvas,
      'TRAVEL / PASS',
      const Rect.fromLTWH(27, 25, 188, 12),
      8,
      'NotoSans',
    );
    _text(
      canvas,
      'DEPARTURE',
      const Rect.fromLTWH(27, 48, 82, 12),
      6,
      'NotoSans',
    );
    _text(
      canvas,
      'ARRIVAL',
      const Rect.fromLTWH(142, 48, 78, 12),
      6,
      'NotoSans',
    );
    _text(canvas, 'DATE', const Rect.fromLTWH(27, 74, 45, 12), 6, 'NotoSans');
    _text(
      canvas,
      '02',
      const Rect.fromLTWH(243, 36, 34, 32),
      22,
      'Cormorant Garamond',
      center: true,
    );
    for (var i = 0; i < 22; i++) {
      canvas.drawLine(
        Offset(244 + i * 1.45, 78),
        Offset(244 + i * 1.45, 91),
        Paint()
          ..color = const Color(0x99506C65)
          ..strokeWidth = i % 3 == 0 ? 1.1 : .45,
      );
    }
    canvas.restore();
  }

  void _postalMark(Canvas canvas, double height) {
    canvas.save();
    canvas.scale(1, height / 167);
    final ink = Paint()
      ..color = const Color(0x80546F6B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;
    for (final radius in [57.0, 48.0]) {
      canvas.drawCircle(const Offset(72, 82), radius, ink);
    }
    for (var row = 0; row < 5; row++) {
      final y = 49.0 + row * 16;
      canvas.drawPath(
        Path()
          ..moveTo(123, y)
          ..cubicTo(152, y - 12, 169, y + 12, 193, y)
          ..cubicTo(222, y - 12, 246, y + 12, 288, y),
        ink,
      );
    }
    canvas.drawLine(const Offset(26, 67), const Offset(118, 67), ink);
    canvas.drawLine(const Offset(26, 99), const Offset(118, 99), ink);
    _text(
      canvas,
      'TRAVEL',
      const Rect.fromLTWH(27, 48, 91, 13),
      10,
      'NotoSans',
      center: true,
      color: const Color(0xA6546F6B),
    );
    _text(
      canvas,
      '01',
      const Rect.fromLTWH(27, 74, 91, 19),
      16,
      'Cormorant Garamond',
      center: true,
      color: const Color(0xA6546F6B),
    );
    canvas.restore();
  }

  void _text(
    Canvas canvas,
    String text,
    Rect rect,
    double size,
    String font, {
    bool center = false,
    Color color = const Color(0xFF3B5543),
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontFamily: font,
          fontSize: size,
          height: 1.0,
          letterSpacing: 0,
        ),
      ),
      textAlign: center ? TextAlign.center : TextAlign.left,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(minWidth: rect.width, maxWidth: rect.width);
    painter.paint(canvas, rect.topLeft);
    painter.dispose();
  }

  Path _edge(Rect rect, {required bool tape, required bool perforated}) {
    final corners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ];
    final path = Path()..moveTo(rect.left, rect.top);
    for (var edge = 0; edge < 4; edge++) {
      final a = corners[edge], b = corners[(edge + 1) % 4];
      final delta = b - a;
      final normal = Offset(-delta.dy, delta.dx) / delta.distance;
      final steps = (delta.distance / (perforated ? 13 : 3)).round();
      for (var i = 0; i < steps; i++) {
        final t = (i + 1) / steps;
        if (perforated) {
          final mid = a + delta * ((i + .5) / steps) + normal * 6;
          final end = a + delta * t;
          path.quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy);
        } else {
          final noise =
              (math.sin(i * 12.9 + edge * 3.1) + math.sin(i * 3.7)) * .5 + 1;
          final depth = tape ? (edge.isEven ? .25 : 2.2) : 1.2;
          final point =
              a + delta * t + normal * (i == steps - 1 ? 0 : noise * depth);
          path.lineTo(point.dx, point.dy);
        }
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_StationeryPainter oldDelegate) => oldDelegate.id != id;
}
