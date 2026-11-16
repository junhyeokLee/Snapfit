import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/templates/story_edition_catalog.dart';

/// Five compact vector kits; the writing areas stay blank for editable layers.
class MilestoneExpansionStationery extends StatelessWidget {
  const MilestoneExpansionStationery({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _MilestoneStationeryPainter(id),
    child: const SizedBox.expand(),
  );
}

class _MilestoneStationeryPainter extends CustomPainter {
  const _MilestoneStationeryPainter(this.id);
  final String id;
  @override
  void paint(Canvas canvas, Size size) {
    final e = storyMaterialsById[id];
    if (e == null ||
        e.qualityRevision != milestoneExpansionRevision ||
        size.isEmpty)
      return;
    final paper = id == e.paperId, kind = e.catalogId.abs() - 9781;
    Color color(String value) =>
        Color(int.parse('FF${value.substring(1)}', radix: 16));
    final ink = color(e.ink), accent = color(e.accent), tint = color(e.tint);
    canvas.save();
    canvas.scale(size.width / 300, size.height / (paper ? 240 : 300));
    final pen = Paint()
      ..color = ink.withValues(alpha: .64)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void line(double x, double y, double xx, double yy, {Paint? paint}) =>
        canvas.drawLine(Offset(x, y), Offset(xx, yy), paint ?? pen);
    void fill(Rect rect, Color c, {double radius = 0}) => canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..color = c,
    );
    if (paper) {
      final bounds = const Rect.fromLTWH(7, 7, 286, 226);
      final path = Path();
      if (kind == 0) {
        path.moveTo(7, 12);
        for (var x = 7; x < 293; x += 13) {
          path.lineTo(x.toDouble(), x.isEven ? 7 : 12);
        }
        path.lineTo(293, 231);
        path.lineTo(7, 231);
        path.close();
      } else if (kind == 2) {
        path.moveTo(7, 7);
        path.lineTo(271, 7);
        path.lineTo(293, 29);
        path.lineTo(293, 233);
        path.lineTo(7, 233);
        path.close();
      } else {
        path.addRRect(
          RRect.fromRectAndRadius(bounds, Radius.circular(kind == 1 ? 2 : 7)),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = kind == 1
              ? const Color(0xFFF0F6F4)
              : const Color(0xFFF7F2E6),
      );
      canvas.drawPath(
        path,
        pen
          ..color = ink.withValues(alpha: .22)
          ..strokeWidth = .8,
      );
      final hair = Paint()
        ..color = accent.withValues(alpha: .45)
        ..strokeWidth = .8;
      switch (kind) {
        case 0:
          for (var n = 0; n < 5; n++) {
            final c = const [
              Color(0xFFCF6B45),
              Color(0xFFDCB841),
              Color(0xFF5B8D73),
            ][n % 3];
            fill(Rect.fromLTWH(14 + n * 6.0, 17, 4, 15), c, radius: 1);
          }
          for (var n = 0; n < 6; n++)
            canvas.drawCircle(
              Offset(20, 56 + n * 27.0),
              2.2,
              Paint()..color = accent.withValues(alpha: .33),
            );
          line(42, 204, 264, 204, paint: hair);
          line(42, 217, 137, 217, paint: hair);
        case 1:
          for (var n = 0; n < 9; n++) {
            line(13, 22 + n * 23.0, 33, 22 + n * 23.0, paint: hair);
          }
          for (var n = 0; n < 3; n++)
            line(15 + n * 7.0, 18, 15 + n * 7.0, 221, paint: hair);
          line(42, 207, 265, 207, paint: hair);
          line(230, 214, 265, 214, paint: hair);
          line(274, 15, 286, 15);
          line(280, 10, 280, 21);
        case 2:
          fill(const Rect.fromLTWH(13, 17, 15, 204), tint, radius: 2);
          fill(const Rect.fromLTWH(13, 17, 15, 38), accent, radius: 2);
          line(271, 7, 271, 29, paint: hair);
          line(271, 29, 293, 29, paint: hair);
          for (var n = 0; n < 5; n++)
            line(17, 85 + n * 25.0, 24, 85 + n * 25.0, paint: hair);
          line(42, 207, 263, 207, paint: hair);
        case 3:
          final fibre = Paint()
            ..color = accent.withValues(alpha: .14)
            ..strokeWidth = .65;
          for (var n = 0; n < 48; n++) {
            final x = 12 + n * 5.8;
            line(x, 11, x + 2, 30, paint: fibre);
            line(x, 212, x - 2, 230, paint: fibre);
          }
          for (var n = 0; n < 9; n++) {
            line(12, 43 + n * 20.0, 29, 43 + n * 20.0, paint: fibre);
            line(272, 43 + n * 20.0, 289, 43 + n * 20.0, paint: fibre);
          }
          line(42, 204, 264, 204, paint: hair);
        default:
          canvas.drawCircle(const Offset(24, 22), 3.5, pen);
          canvas.drawCircle(const Offset(276, 22), 3.5, pen);
          line(27, 22, 273, 22, paint: hair);
          line(42, 206, 264, 206, paint: hair);
          fill(const Rect.fromLTWH(42, 213, 26, 4), ink);
          fill(const Rect.fromLTWH(74, 213, 7, 4), accent);
      }
    } else {
      switch (kind) {
        case 0:
          final crown = Path()
            ..moveTo(42, 108)
            ..lineTo(67, 65)
            ..lineTo(111, 99)
            ..lineTo(151, 47)
            ..lineTo(191, 99)
            ..lineTo(237, 65)
            ..lineTo(258, 108)
            ..lineTo(243, 184)
            ..lineTo(57, 184)
            ..close();
          canvas.drawPath(crown, Paint()..color = const Color(0xFFE7C762));
          canvas.drawPath(
            crown,
            pen
              ..color = accent
              ..strokeWidth = 2.5,
          );
          fill(
            const Rect.fromLTWH(58, 164, 185, 19),
            const Color(0xFFCF6B45),
            radius: 4,
          );
          for (var n = 0; n < 5; n++)
            canvas.drawCircle(
              Offset(82 + n * 34.0, 134),
              4.8,
              Paint()..color = const Color(0xFF628B73),
            );
          canvas.drawCircle(const Offset(222, 216), 30, Paint()..color = tint);
          canvas.drawCircle(
            const Offset(222, 216),
            22,
            pen
              ..color = accent
              ..strokeWidth = 2,
          );
          final ribbon = Path()
            ..moveTo(201, 238)
            ..lineTo(189, 278)
            ..lineTo(211, 267)
            ..lineTo(222, 280)
            ..lineTo(229, 241)
            ..close();
          canvas.drawPath(ribbon, Paint()..color = const Color(0xFFCF6B45));
          for (var n = 0; n < 8; n++) {
            final theta = n * math.pi / 4;
            line(
              31 + math.cos(theta) * 9,
              225 + math.sin(theta) * 9,
              31 + math.cos(theta) * 15,
              225 + math.sin(theta) * 15,
            );
          }
        case 1:
          fill(const Rect.fromLTWH(34, 90, 160, 146), tint, radius: 4);
          canvas.drawRect(
            const Rect.fromLTWH(48, 104, 129, 113),
            pen
              ..color = ink.withValues(alpha: .32)
              ..strokeWidth = 1,
          );
          line(93, 104, 93, 165);
          line(93, 165, 177, 165);
          line(48, 181, 93, 181);
          line(136, 165, 136, 217);
          final gold = Paint()
            ..color = accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 10
            ..strokeCap = StrokeCap.round;
          canvas.drawCircle(const Offset(213, 84), 30, gold);
          line(214, 117, 214, 239, paint: gold);
          line(214, 206, 240, 206, paint: gold);
          line(214, 231, 235, 231, paint: gold);
          fill(
            const Rect.fromLTWH(184, 248, 73, 28),
            const Color(0xFFF6EDD9),
            radius: 3,
          );
          line(193, 262, 244, 262, paint: pen);
        case 2:
          fill(const Rect.fromLTWH(45, 68, 190, 172), tint, radius: 4);
          fill(
            const Rect.fromLTWH(57, 56, 190, 172),
            const Color(0xFFF2EADB),
            radius: 4,
          );
          canvas.drawRect(
            const Rect.fromLTWH(57, 56, 190, 172),
            pen
              ..color = ink.withValues(alpha: .38)
              ..strokeWidth = 1.4,
          );
          fill(
            const Rect.fromLTWH(105, 37, 92, 26),
            const Color(0xFF809095),
            radius: 4,
          );
          fill(
            const Rect.fromLTWH(124, 27, 54, 22),
            const Color(0xFF9DA8AA),
            radius: 6,
          );
          final route = Path()
            ..moveTo(85, 190)
            ..lineTo(125, 190)
            ..lineTo(125, 128)
            ..lineTo(213, 128);
          canvas.drawPath(
            route,
            pen
              ..color = accent
              ..strokeWidth = 5,
          );
          canvas.drawPath(
            Path()
              ..moveTo(195, 111)
              ..lineTo(214, 128)
              ..lineTo(195, 145),
            pen,
          );
          for (var n = 0; n < 3; n++) {
            canvas.drawCircle(
              Offset(84, 94 + n * 23.0),
              3.3,
              Paint()..color = ink.withValues(alpha: .5),
            );
          }
        case 3:
          final medal = const Offset(150, 140);
          canvas.drawCircle(
            medal,
            68,
            Paint()..color = const Color(0xFFE9DFC8),
          );
          canvas.drawCircle(
            medal,
            57,
            pen
              ..color = accent
              ..strokeWidth = 2,
          );
          canvas.drawCircle(
            medal,
            49,
            pen
              ..color = accent.withValues(alpha: .5)
              ..strokeWidth = .9,
          );
          final ribbon = Path()
            ..moveTo(116, 194)
            ..lineTo(103, 264)
            ..lineTo(132, 249)
            ..lineTo(150, 268)
            ..lineTo(159, 198)
            ..close();
          canvas.drawPath(ribbon, Paint()..color = const Color(0xFF9DA58B));
          final ribbon2 = Path()
            ..moveTo(154, 200)
            ..lineTo(170, 265)
            ..lineTo(185, 248)
            ..lineTo(208, 259)
            ..lineTo(189, 189)
            ..close();
          canvas.drawPath(ribbon2, Paint()..color = const Color(0xFFC0B094));
          final twig = Paint()
            ..color = const Color(0xFF6E7E60)
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke;
          canvas.drawArc(
            const Rect.fromLTWH(57, 49, 186, 183),
            .28,
            2.57,
            false,
            twig,
          );
          canvas.drawArc(
            const Rect.fromLTWH(57, 49, 186, 183),
            3.42,
            2.57,
            false,
            twig,
          );
          for (var n = 0; n < 9; n++) {
            final angle = .35 + n * .29;
            for (final sign in [-1, 1]) {
              final x = 150 + sign * math.cos(angle) * 91,
                  y = 141 + math.sin(angle) * 89;
              canvas.save();
              canvas.translate(x, y);
              canvas.rotate(sign * angle);
              canvas.drawOval(
                const Rect.fromLTWH(-4, -11, 8, 20),
                Paint()..color = const Color(0xFF7A8969),
              );
              canvas.restore();
            }
          }
          line(128, 135, 172, 135);
          line(135, 148, 165, 148);
        default:
          canvas.drawCircle(const Offset(88, 42), 5, Paint()..color = ink);
          canvas.drawCircle(const Offset(216, 42), 5, Paint()..color = ink);
          line(
            88,
            42,
            64,
            112,
            paint: pen
              ..color = const Color(0xFF7B7D7C)
              ..strokeWidth = 1.4,
          );
          line(216, 42, 240, 112);
          fill(
            const Rect.fromLTWH(54, 105, 196, 137),
            const Color(0xFFF7F3EB),
            radius: 2,
          );
          canvas.drawRect(
            const Rect.fromLTWH(54, 105, 196, 137),
            pen
              ..color = ink.withValues(alpha: .55)
              ..strokeWidth = 1.1,
          );
          fill(const Rect.fromLTWH(73, 123, 42, 62), tint);
          fill(const Rect.fromLTWH(122, 123, 106, 5), ink);
          fill(const Rect.fromLTWH(122, 138, 83, 3), accent);
          fill(const Rect.fromLTWH(122, 151, 66, 2), ink.withValues(alpha: .4));
          line(73, 202, 228, 202);
          line(73, 218, 163, 218);
          canvas.drawCircle(
            const Offset(244, 235),
            23,
            pen
              ..color = accent
              ..strokeWidth = 2,
          );
          line(232, 235, 256, 235);
          line(244, 223, 244, 247);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MilestoneStationeryPainter oldDelegate) =>
      oldDelegate.id != id;
}
