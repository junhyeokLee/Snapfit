import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/templates/story_edition_catalog.dart';

/// Resolution independent print artwork. No texture bitmaps, blur layers,
/// animation controllers, image listeners or caches are allocated here.
class StoryEditionStationery extends StatelessWidget {
  const StoryEditionStationery({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _StoryStationeryPainter(id),
    child: const SizedBox.expand(),
  );
}

class _StoryStationeryPainter extends CustomPainter {
  const _StoryStationeryPainter(this.id);
  final String id;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final e = storyMaterialsById[id];
    if (e == null) return;
    canvas.save();
    canvas.scale(size.width / 300, size.height / 240);
    Color color(String value) =>
        Color(int.parse('FF${value.substring(1)}', radix: 16));
    final accent = color(e.accent);
    final ink = color(e.ink);
    final stroke = Paint()
      ..color = accent.withValues(alpha: .60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void line(double x, double y, double xx, double yy, {Paint? paint}) =>
        canvas.drawLine(Offset(x, y), Offset(xx, yy), paint ?? stroke);
    if (id == e.paperId) {
      final paperStyle = e.exclusivePhotography
          ? (e.coverStyle - 5) % 5
          : e.coverStyle;
      const rect = Rect.fromLTWH(7, 6, 286, 228);
      final path = Path();
      switch (paperStyle) {
        case 0:
          path.addRect(rect);
        case 1:
          path.addRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(7)),
          );
        case 2:
          path.moveTo(7, 20);
          path.lineTo(180, 20);
          path.lineTo(194, 6);
          path.lineTo(293, 6);
          path.lineTo(293, 234);
          path.lineTo(7, 234);
          path.close();
        case 3:
          path.moveTo(7, 6);
          path.lineTo(270, 6);
          path.lineTo(293, 29);
          path.lineTo(293, 234);
          path.lineTo(7, 234);
          path.close();
        default:
          path.moveTo(7, 9);
          for (var i = 0; i <= 24; i++) {
            path.lineTo(7 + i * 286 / 24, 8 + math.sin(i * 1.8) * 2);
          }
          path.lineTo(293, 230);
          for (var i = 24; i >= 0; i--) {
            path.lineTo(7 + i * 286 / 24, 231 + math.cos(i * 2.1) * 2);
          }
          path.close();
      }
      // Near-neutral rag paper supports real photographs without color casts.
      canvas.drawPath(path, Paint()..color = const Color(0xFFF1EEE6));
      canvas.drawPath(
        path,
        Paint()
          ..color = ink.withValues(alpha: .15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .65,
      );
      final grain = Paint()
        ..color = ink.withValues(alpha: .045)
        ..strokeWidth = .6;
      for (var n = 0; n < 21; n++) {
        final y = 15.0 + n * 10;
        line(15 + n % 3 * 6, y, 282 - n % 4 * 4, y + .3, paint: grain);
      }
      switch (paperStyle) {
        case 0:
          line(24, 35, 102, 35);
          line(24, 207, 277, 207);
          for (var i = 0; i < 8; i++) line(25 + i * 32, 207, 25 + i * 32, 212);
        case 1:
          for (var i = 0; i < 10; i++) {
            canvas.drawCircle(
              Offset(22, 23 + i * 21),
              1.5,
              Paint()..color = ink.withValues(alpha: .23),
            );
          }
          line(37, 20, 37, 219);
          line(53, 204, 275, 204);
        case 2:
          line(188, 32, 188, 215);
          line(206, 49, 274, 49);
          for (var n = 0; n < 5; n++) line(207, 78 + n * 26, 272, 78 + n * 26);
        case 3:
          final fold = Path()
            ..moveTo(270, 6)
            ..lineTo(270, 29)
            ..lineTo(293, 29);
          canvas.drawPath(fold, stroke);
          line(25, 203, 250, 203);
          line(25, 215, 182, 215);
        default:
          if (e.exclusivePhotography) {
            // Keep the photo/caption field clear. Strong rules through a
            // caption look like a strikethrough once physically printed.
            line(23, 32, 104, 32);
            line(23, 219, 275, 219);
            for (var n = 0; n < 5; n++)
              line(23 + n * 63, 219, 23 + n * 63, 223);
            break;
          }
          for (var n = 0; n < 7; n++)
            line(
              23,
              47 + n * 25,
              275,
              47 + n * 25,
              paint: Paint()
                ..color = accent.withValues(alpha: .16)
                ..strokeWidth = .8,
            );
          line(49, 25, 49, 215);
      }
      // Small subject-specific print at the edge, outside the photo support.
      canvas.save();
      canvas.translate(244, 16);
      canvas.scale(.13, .13);
      _motif(canvas, e, stroke..color = accent.withValues(alpha: .48));
      canvas.restore();
    } else {
      // Cutout ink stamp; transparent negative space blends with photo paper.
      _motif(
        canvas,
        e,
        stroke
          ..color = accent.withValues(alpha: .82)
          ..strokeWidth = 2.5,
      );
    }
    canvas.restore();
  }

  void _activityMotif(Canvas c, StoryEdition e, Paint p) {
    void line(double x, double y, double xx, double yy) =>
        c.drawLine(Offset(x, y), Offset(xx, yy), p);
    void circle(double x, double y, double r) =>
        c.drawCircle(Offset(x, y), r, p);
    final club = e.category == '동아리';
    switch (e.activity!) {
      case StoryActivity.running:
        for (var n = 0; n < 4; n++) {
          final y = 60.0 + n * 35;
          c.drawPath(
            Path()
              ..moveTo(38, y + 16)
              ..quadraticBezierTo(120, y - 24, 262, y),
            p,
          );
        }
        for (var n = 0; n < (club ? 6 : 1); n++)
          circle(62 + n * 34, 76 + n * 11, 6);
      case StoryActivity.climbing:
        final holds = [
          const Offset(75, 170),
          const Offset(155, 117),
          const Offset(224, 59),
        ];
        for (var n = 0; n < holds.length; n++) {
          final o = holds[n];
          c.drawPath(
            Path()
              ..moveTo(o.dx - 22, o.dy + 10)
              ..quadraticBezierTo(o.dx - 28, o.dy - 16, o.dx, o.dy - 20)
              ..quadraticBezierTo(o.dx + 26, o.dy - 10, o.dx + 19, o.dy + 13)
              ..close(),
            p,
          );
          circle(o.dx, o.dy - 2, 3);
        }
        if (club) {
          line(90, 150, 134, 130);
          line(175, 99, 205, 79);
          circle(42, 202, 6);
          circle(64, 205, 6);
          circle(86, 202, 6);
        }
      case StoryActivity.golf:
        c.drawOval(const Rect.fromLTWH(39, 151, 222, 53), p);
        line(175, 162, 175, 45);
        line(175, 45, 224, 63);
        line(224, 63, 175, 79);
        circle(175, 173, 5);
        if (club) {
          for (var n = 0; n < 4; n++) circle(65 + n * 26, 125 - n * 5, 5);
        } else {
          c.drawArc(const Rect.fromLTWH(27, 23, 202, 174), .40, 3.2, false, p);
          circle(61, 160, 8);
        }
      case StoryActivity.badminton:
        c.drawOval(const Rect.fromLTWH(132, 149, 39, 28), p);
        for (var n = 0; n < 5; n++) {
          final x = 75.0 + n * 37;
          line(140 + n * 5, 152, x, 54);
          c.drawOval(Rect.fromLTWH(x - 9, 35, 18, 39), p);
        }
        line(88, 99, 216, 99);
        line(107, 126, 197, 126);
        line(51, 204, 250, 204);
      case StoryActivity.cycling:
        circle(78, 158, 47);
        circle(224, 158, 47);
        line(78, 158, 120, 77);
        line(120, 77, 166, 158);
        line(166, 158, 78, 158);
        line(120, 77, 195, 77);
        line(195, 77, 166, 158);
        line(195, 77, 224, 158);
        line(195, 77, 194, 54);
        line(194, 54, 218, 54);
        line(105, 65, 136, 65);
        line(120, 65, 120, 77);
        if (club) {
          line(40, 217, 141, 217);
          line(162, 217, 262, 217);
        }
      case StoryActivity.tennis:
        c.drawRect(const Rect.fromLTWH(39, 40, 145, 168), p);
        line(39, 124, 184, 124);
        line(59, 40, 59, 208);
        line(164, 40, 164, 208);
        line(59, 83, 164, 83);
        line(59, 164, 164, 164);
        line(111, 83, 111, 164);
        circle(232, 99, 34);
        c.drawArc(const Rect.fromLTWH(204, 66, 41, 65), -.9, 1.8, false, p);
        c.drawArc(const Rect.fromLTWH(230, 66, 41, 65), 2.2, 1.8, false, p);
      case StoryActivity.swimming:
        for (var n = 0; n < 3; n++) {
          final y = 87.0 + n * 44;
          final wave = Path()..moveTo(34, y);
          for (var x = 34.0; x < 250; x += 45) {
            wave
              ..quadraticBezierTo(x + 11, y - 16, x + 23, y)
              ..quadraticBezierTo(x + 34, y + 16, x + 45, y);
          }
          c.drawPath(wave, p);
        }
        circle(110, 47, 12);
        line(132, 56, 178, 46);
        line(178, 46, 210, 64);
    }
  }

  void _motif(Canvas c, StoryEdition e, Paint p) {
    void line(double x, double y, double xx, double yy) =>
        c.drawLine(Offset(x, y), Offset(xx, yy), p);
    void circle(double x, double y, double r) =>
        c.drawCircle(Offset(x, y), r, p);
    void rect(double x, double y, double w, double h) =>
        c.drawRect(Rect.fromLTWH(x, y, w, h), p);
    void arc(Rect r, double start, double end) =>
        c.drawArc(r, start, end, false, p);
    void path(List<Offset> points, {bool close = false}) {
      final shape = Path()..addPolygon(points, close);
      c.drawPath(shape, p);
    }

    if (e.activity != null) {
      _activityMotif(c, e, p);
      return;
    }
    final style = e.coverStyle;
    switch (e.category) {
      case '웨딩':
        switch (style) {
          case 0: // Joined loops, a hand-tied knot rather than a filled badge.
            arc(const Rect.fromLTWH(60, 65, 95, 80), -.3, math.pi * 1.8);
            arc(const Rect.fromLTWH(145, 65, 95, 80), .4, math.pi * 1.8);
            line(145, 112, 105, 190);
            line(155, 112, 195, 190);
          case 1:
            line(145, 83, 127, 184);
            circle(146, 69, 18);
            arc(const Rect.fromLTWH(121, 48, 50, 44), 0, math.pi * 2);
            path([
              const Offset(107, 103),
              const Offset(79, 152),
              const Offset(134, 152),
            ], close: true);
            line(106, 153, 106, 189);
            line(86, 191, 126, 191);
          case 2:
            arc(const Rect.fromLTWH(74, 45, 152, 148), math.pi, math.pi);
            line(74, 120, 74, 195);
            line(226, 120, 226, 195);
            rect(137, 110, 26, 68);
            arc(const Rect.fromLTWH(140, 82, 20, 37), 0, math.pi * 2);
          case 3:
            for (final center in [
              const Offset(74, 65),
              const Offset(226, 65),
              const Offset(74, 175),
              const Offset(226, 175),
            ]) {
              circle(center.dx, center.dy, 12);
              circle(center.dx + 13, center.dy, 8);
              circle(center.dx, center.dy + 13, 8);
            }
            line(92, 65, 208, 65);
            line(92, 187, 208, 187);
          default:
            rect(59, 55, 182, 130);
            path([
              const Offset(59, 55),
              const Offset(150, 126),
              const Offset(241, 55),
            ]);
            circle(150, 139, 22);
            line(139, 139, 150, 150);
            line(150, 150, 167, 127);
        }
      case '여행':
        switch (style) {
          case 0:
            for (var n = 0; n < 5; n++)
              arc(
                Rect.fromLTWH(
                  45 + n * 15,
                  52 + n * 10,
                  210 - n * 30,
                  142 - n * 16,
                ),
                math.pi,
                math.pi * 1.9,
              );
            path([
              const Offset(119, 135),
              const Offset(150, 76),
              const Offset(186, 144),
            ]);
          case 1:
            circle(150, 86, 28);
            for (var n = 0; n < 3; n++)
              line(55, 140 + n * 17, 245, 140 + n * 17);
          case 2:
            path([
              const Offset(55, 173),
              const Offset(115, 173),
              const Offset(115, 112),
              const Offset(197, 112),
              const Offset(197, 62),
            ]);
            for (final v in [
              const Offset(55, 173),
              const Offset(115, 112),
              const Offset(197, 62),
            ])
              circle(v.dx, v.dy, 8);
          case 3:
            for (var n = 0; n < 4; n++) {
              final v = Path()
                ..moveTo(52, 82 + n * 25)
                ..cubicTo(
                  110,
                  35 + n * 25,
                  186,
                  129 + n * 25,
                  248,
                  82 + n * 25,
                );
              c.drawPath(v, p);
            }
          default:
            path([
              const Offset(73, 93),
              const Offset(227, 93),
              const Offset(206, 190),
              const Offset(94, 190),
            ], close: true);
            arc(const Rect.fromLTWH(112, 38, 76, 115), math.pi, math.pi);
            for (var n = 0; n < 4; n++)
              line(102 + n * 29, 109, 110 + n * 24, 177);
        }
      case '일상':
        switch (style) {
          case 0:
            path([
              const Offset(43, 127),
              const Offset(77, 127),
              const Offset(91, 81),
              const Offset(117, 177),
              const Offset(145, 57),
              const Offset(175, 160),
              const Offset(198, 100),
              const Offset(217, 127),
              const Offset(257, 127),
            ]);
          case 1:
            path([
              const Offset(84, 183),
              const Offset(194, 65),
              const Offset(213, 84),
              const Offset(103, 201),
            ], close: true);
            line(86, 67, 209, 190);
            circle(84, 64, 15);
          case 2:
            final stem = Path()
              ..moveTo(140, 196)
              ..quadraticBezierTo(160, 128, 150, 43);
            c.drawPath(stem, p);
            for (var n = 0; n < 4; n++) {
              arc(Rect.fromLTWH(104, 65 + n * 28, 51, 27), -.8, 4.4);
              arc(Rect.fromLTWH(150, 49 + n * 28, 51, 27), -.8, 4.4);
            }
          case 3:
            arc(const Rect.fromLTWH(70, 48, 160, 160), math.pi, math.pi);
            line(66, 146, 236, 146);
            for (var n = 0; n < 4; n++)
              line(100 + n * 33, 161, 83 + n * 40, 202);
          default:
            path([
              const Offset(150, 66),
              const Offset(65, 143),
              const Offset(235, 143),
              const Offset(150, 66),
            ], close: true);
            arc(const Rect.fromLTWH(128, 31, 45, 54), math.pi, math.pi);
            line(150, 56, 150, 65);
            line(68, 178, 231, 178);
        }
      case '성장·육아':
        switch (style) {
          case 0:
            path([
              const Offset(73, 179),
              const Offset(194, 58),
              const Offset(216, 81),
              const Offset(96, 201),
            ], close: true);
            path([
              const Offset(205, 132),
              const Offset(214, 153),
              const Offset(237, 156),
              const Offset(218, 172),
              const Offset(221, 196),
              const Offset(202, 184),
              const Offset(181, 195),
              const Offset(185, 171),
              const Offset(167, 156),
              const Offset(193, 153),
            ], close: true);
          case 1:
            circle(150, 119, 71);
            path([
              const Offset(150, 65),
              const Offset(129, 141),
              const Offset(172, 141),
            ], close: true);
            line(150, 142, 150, 179);
          case 2:
            circle(131, 101, 48);
            circle(131, 101, 34);
            line(166, 136, 212, 186);
            line(174, 128, 220, 178);
          case 3:
            final cloud = Path()
              ..moveTo(70, 155)
              ..cubicTo(20, 100, 85, 65, 114, 94)
              ..cubicTo(141, 24, 228, 58, 218, 107)
              ..cubicTo(282, 98, 285, 166, 230, 166)
              ..lineTo(70, 166);
            c.drawPath(cloud, p);
          default:
            rect(63, 116, 62, 64);
            rect(130, 116, 62, 64);
            rect(130, 47, 62, 64);
            circle(218, 174, 12);
        }
      case '가족·친구':
        switch (style) {
          case 0:
            arc(const Rect.fromLTWH(75, 45, 150, 100), math.pi, math.pi);
            rect(69, 95, 162, 91);
            line(84, 119, 217, 119);
            line(94, 96, 113, 186);
            line(206, 96, 187, 186);
          case 1:
            for (var n = 0; n < 2; n++) {
              rect(64 + n * 98, 75, 76, 48);
              line(61 + n * 98, 139, 143 + n * 98, 139);
              line(75 + n * 98, 141, 75 + n * 98, 187);
              line(132 + n * 98, 141, 132 + n * 98, 187);
            }
          case 2:
            path([
              const Offset(105, 93),
              const Offset(185, 93),
              const Offset(171, 153),
              const Offset(119, 153),
            ], close: true);
            line(145, 154, 145, 194);
            line(118, 195, 173, 195);
            circle(211, 59, 12);
            line(198, 59, 224, 59);
            line(211, 46, 211, 72);
          case 3:
            rect(55, 67, 124, 84);
            rect(124, 107, 124, 84);
            line(84, 152, 84, 175);
            line(84, 175, 115, 153);
            line(214, 191, 214, 211);
            line(214, 211, 190, 191);
          default:
            for (var n = 0; n < 3; n++) {
              c.drawOval(Rect.fromLTWH(72 + n * 58, 83 + n * 19, 30, 62), p);
              circle(86 + n * 58, 71 + n * 19, 8);
            }
        }
      case '커플·기념일':
        switch (style) {
          case 0:
            circle(128, 110, 48);
            circle(179, 110, 48);
            line(58, 163, 241, 163);
          case 1:
            rect(61, 68, 174, 116);
            line(61, 99, 235, 99);
            line(103, 56, 103, 78);
            line(192, 56, 192, 78);
            line(100, 132, 133, 161);
            line(133, 161, 196, 117);
          case 2:
            path([
              const Offset(62, 117),
              const Offset(150, 49),
              const Offset(238, 117),
            ]);
            rect(80, 116, 140, 91);
            circle(145, 144, 12);
            line(145, 157, 145, 185);
            line(146, 177, 162, 177);
          case 3:
            for (var n = 0; n < 2; n++) {
              arc(Rect.fromLTWH(62 + n * 100, 73, 71, 89), 0, math.pi);
              line(60 + n * 100, 118, 136 + n * 100, 118);
              arc(
                Rect.fromLTWH(123 + n * 100, 94, 20, 32),
                -math.pi / 2,
                math.pi,
              );
            }
          default:
            for (var n = 0; n < 2; n++) {
              final h = Path()
                ..moveTo(132 + n * 41, 178)
                ..cubicTo(44 + n * 41, 122, 86 + n * 41, 52, 132 + n * 41, 92)
                ..cubicTo(
                  183 + n * 41,
                  47,
                  217 + n * 41,
                  122,
                  132 + n * 41,
                  178,
                );
              c.drawPath(h, p);
            }
        }
      case '스포츠·도전':
        switch (style) {
          case 5: // Five open track lanes.
            for (var n = 0; n < 5; n++) {
              c.drawRRect(
                RRect.fromRectAndRadius(
                  Rect.fromLTWH(
                    55 + n * 15,
                    48 + n * 15,
                    190 - n * 30,
                    144 - n * 23,
                  ),
                  Radius.circular(58 - n * 10),
                ),
                p,
              );
            }
          case 6: // Water, with no solid badge behind it.
            for (var n = 0; n < 3; n++) {
              final wave = Path()..moveTo(58, 79 + n * 40);
              wave.cubicTo(
                93,
                49 + n * 40,
                112,
                109 + n * 40,
                148,
                79 + n * 40,
              );
              wave.cubicTo(
                184,
                49 + n * 40,
                205,
                109 + n * 40,
                242,
                79 + n * 40,
              );
              c.drawPath(wave, p);
            }
          case 7: // Three rounded climbing holds.
            for (final origin in [
              const Offset(78, 135),
              const Offset(148, 88),
              const Offset(210, 55),
            ]) {
              final hold = Path()
                ..moveTo(origin.dx - 21, origin.dy + 14)
                ..cubicTo(
                  origin.dx - 37,
                  origin.dy - 18,
                  origin.dx + 18,
                  origin.dy - 34,
                  origin.dx + 27,
                  origin.dy - 5,
                )
                ..quadraticBezierTo(
                  origin.dx + 25,
                  origin.dy + 24,
                  origin.dx - 21,
                  origin.dy + 14,
                );
              c.drawPath(hold, p);
              circle(origin.dx, origin.dy, 2);
            }
            line(92, 192, 216, 192);
          case 8: // A mechanically coherent bicycle silhouette.
            circle(83, 152, 40);
            circle(217, 152, 40);
            path([
              const Offset(83, 152),
              const Offset(121, 91),
              const Offset(155, 152),
              const Offset(83, 152),
            ]);
            path([
              const Offset(121, 91),
              const Offset(197, 91),
              const Offset(155, 152),
            ]);
            line(193, 75, 217, 152);
            line(181, 74, 207, 74);
            line(119, 92, 114, 77);
            line(101, 77, 131, 77);
          default: // Strung tennis racket and separate ball.
            c.drawOval(const Rect.fromLTWH(78, 40, 100, 124), p);
            for (var n = 0; n < 5; n++) line(94 + n * 17, 66, 94 + n * 17, 139);
            for (var n = 0; n < 4; n++) line(94, 76 + n * 18, 163, 76 + n * 18);
            line(126, 164, 100, 207);
            line(139, 164, 113, 211);
            circle(218, 177, 25);
            arc(const Rect.fromLTWH(196, 158, 24, 38), -.8, 2.2);
        }
      case '졸업·새출발':
        switch (style) {
          case 5: // Mortarboard and tassel.
            path([
              const Offset(52, 87),
              const Offset(150, 48),
              const Offset(248, 87),
              const Offset(150, 127),
            ], close: true);
            path([
              const Offset(88, 106),
              const Offset(88, 155),
              const Offset(150, 179),
              const Offset(212, 155),
              const Offset(212, 106),
            ]);
            line(248, 89, 248, 157);
            circle(248, 164, 7);
          case 6: // Open book / welcoming window.
            path([
              const Offset(150, 80),
              const Offset(69, 55),
              const Offset(69, 178),
              const Offset(150, 202),
              const Offset(231, 178),
              const Offset(231, 55),
              const Offset(150, 80),
              const Offset(150, 202),
            ]);
            line(88, 90, 127, 103);
            line(88, 118, 127, 131);
            line(172, 103, 211, 90);
            line(172, 131, 211, 118);
          case 7: // Wire paperclip, single light line.
            final clip = Path()
              ..moveTo(109, 176)
              ..lineTo(109, 81)
              ..cubicTo(109, 21, 207, 21, 207, 81)
              ..lineTo(207, 161)
              ..cubicTo(207, 214, 137, 214, 137, 161)
              ..lineTo(137, 85)
              ..cubicTo(137, 61, 178, 61, 178, 85)
              ..lineTo(178, 155);
            c.drawPath(clip, p);
          case 8: // Shop door, small sun outside the frame.
            rect(85, 49, 130, 160);
            rect(101, 65, 98, 76);
            circle(186, 164, 3);
            line(66, 210, 235, 210);
            circle(243, 55, 15);
            line(242, 23, 242, 31);
            line(269, 55, 278, 55);
          default: // Imperfect hand-thrown bowl.
            final bowl = Path()
              ..moveTo(70, 115)
              ..cubicTo(84, 208, 213, 207, 231, 115);
            c.drawPath(bowl, p);
            c.drawOval(const Rect.fromLTWH(70, 88, 161, 52), p);
            arc(const Rect.fromLTWH(87, 92, 126, 32), .1, math.pi * .92);
            line(116, 191, 187, 191);
        }
      case '동아리':
        switch (style) {
          case 10: // Small camera, open viewfinder corners.
            c.drawRRect(
              RRect.fromRectAndRadius(
                const Rect.fromLTWH(58, 77, 184, 116),
                const Radius.circular(13),
              ),
              p,
            );
            path([
              const Offset(89, 77),
              const Offset(105, 55),
              const Offset(153, 55),
              const Offset(169, 77),
            ]);
            circle(151, 134, 39);
            circle(151, 134, 28);
            line(207, 96, 223, 96);
          case 11: // Book and a modest quotation mark.
            path([
              const Offset(150, 81),
              const Offset(65, 59),
              const Offset(65, 176),
              const Offset(150, 198),
              const Offset(235, 176),
              const Offset(235, 59),
              const Offset(150, 81),
              const Offset(150, 198),
            ]);
            arc(const Rect.fromLTWH(93, 95, 18, 30), -.3, math.pi);
            arc(const Rect.fromLTWH(121, 102, 18, 30), -.3, math.pi);
          case 12: // Accessible local hill, no trophy or conquest badge.
            path([
              const Offset(47, 180),
              const Offset(111, 80),
              const Offset(150, 133),
              const Offset(190, 63),
              const Offset(253, 180),
            ]);
            path([
              const Offset(119, 203),
              const Offset(154, 177),
              const Offset(143, 157),
              const Offset(164, 141),
            ]);
            circle(64, 69, 15);
          case 13: // Four imperfect but complementary beats.
            for (var n = 0; n < 4; n++) {
              final h = [66.0, 116.0, 92.0, 142.0][n];
              line(72 + n * 52, 190 - h, 72 + n * 52, 190);
              circle(72 + n * 52, 190 - h, 7);
            }
            line(52, 205, 249, 205);
          case 14: // Two helping hands, transparent open strokes.
            path([
              const Offset(43, 135),
              const Offset(89, 111),
              const Offset(130, 129),
              const Offset(149, 150),
              const Offset(134, 166),
              const Offset(98, 148),
            ]);
            path([
              const Offset(257, 135),
              const Offset(211, 111),
              const Offset(170, 129),
              const Offset(151, 150),
              const Offset(166, 166),
              const Offset(202, 148),
            ]);
            line(45, 152, 79, 181);
            line(255, 152, 221, 181);
            line(113, 181, 150, 195);
            line(187, 181, 150, 195);
          case 15: // A considered gallery wall.
            rect(47, 61, 65, 93);
            rect(128, 81, 65, 93);
            rect(209, 46, 45, 66);
            line(49, 192, 251, 192);
            line(74, 178, 74, 205);
            line(225, 178, 225, 205);
          case 16: // A small community theatre curtain.
            rect(55, 43, 190, 161);
            line(55, 63, 245, 63);
            path([
              const Offset(55, 64),
              const Offset(95, 126),
              const Offset(78, 203),
            ]);
            path([
              const Offset(245, 64),
              const Offset(205, 126),
              const Offset(222, 203),
            ]);
            for (var n = 0; n < 3; n++) {
              line(68 + n * 12, 70, 88 + n * 3, 113);
              line(232 - n * 12, 70, 212 - n * 3, 113);
            }
          case 17: // Position markers and count rhythm, not idealized bodies.
            for (var n = 0; n < 4; n++) {
              final x = 67 + n * 55.0, y = n.isEven ? 93.0 : 147.0;
              circle(x, y, 15);
              line(x - 9, y, x + 9, y);
              line(x, y - 9, x, y + 9);
            }
            path([
              const Offset(58, 190),
              const Offset(102, 168),
              const Offset(155, 192),
              const Offset(221, 172),
            ]);
          case 18: // Modest tent under a few stars.
            path([
              const Offset(57, 187),
              const Offset(151, 67),
              const Offset(244, 187),
            ], close: true);
            path([
              const Offset(109, 187),
              const Offset(151, 120),
              const Offset(194, 187),
            ]);
            line(91, 187, 212, 187);
            line(220, 55, 220, 78);
            line(209, 66, 231, 66);
            circle(73, 82, 4);
          default: // A yarn ball and two wooden needles.
            circle(142, 137, 62);
            for (var n = 0; n < 4; n++)
              arc(Rect.fromLTWH(97 + n * 12, 82, 64, 112), -.9, math.pi * 1.05);
            line(105, 83, 207, 34);
            line(120, 82, 224, 53);
            circle(209, 33, 4);
            circle(225, 53, 4);
            final thread = Path()
              ..moveTo(176, 190)
              ..cubicTo(202, 210, 222, 183, 239, 204);
            c.drawPath(thread, p);
        }
      default: // Pet collection: toy, window, compass, cushion, rope.
        switch (style) {
          case 0:
            for (var n = 0; n < 3; n++)
              arc(Rect.fromLTWH(66 + n * 30, 67, 91, 91), -.2, math.pi * 1.7);
            line(72, 150, 56, 185);
            line(199, 145, 227, 183);
          case 1:
            rect(70, 43, 160, 157);
            line(150, 44, 150, 129);
            line(70, 119, 229, 119);
            path([
              const Offset(116, 160),
              const Offset(116, 126),
              const Offset(132, 140),
              const Offset(149, 126),
              const Offset(149, 160),
            ]);
            arc(const Rect.fromLTWH(115, 140, 37, 43), 0, math.pi);
          case 2:
            circle(150, 120, 73);
            path([
              const Offset(150, 65),
              const Offset(124, 146),
              const Offset(178, 146),
            ], close: true);
            circle(150, 120, 7);
            line(85, 177, 68, 197);
          case 3:
            c.drawRRect(
              RRect.fromRectAndRadius(
                const Rect.fromLTWH(64, 79, 173, 111),
                const Radius.circular(32),
              ),
              p,
            );
            arc(const Rect.fromLTWH(118, 52, 75, 75), .3, math.pi * 1.65);
            line(84, 179, 216, 179);
          default:
            for (var n = 0; n < 4; n++)
              arc(Rect.fromLTWH(56 + n * 38, 85, 67, 67), -.7, math.pi * 1.7);
            for (var n = 0; n < 5; n++) {
              line(61 + n * 6, 140, 43 + n * 6, 185);
              line(215 + n * 6, 137, 229 + n * 6, 183);
            }
        }
    }
  }

  @override
  bool shouldRepaint(_StoryStationeryPainter oldDelegate) =>
      oldDelegate.id != id;
}
