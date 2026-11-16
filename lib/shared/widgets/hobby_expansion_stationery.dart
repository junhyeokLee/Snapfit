part of 'story_edition_stationery.dart';

/// Native vector stock and collectible marks: no bitmap/blur/image cache cost.
void _paintHobbyExpansionStationery(
  Canvas c,
  Size size,
  String id,
  StoryEdition e,
) {
  final mode = e.coverStyle - 40;
  final paper = id == e.paperId;
  Color color(String hex) =>
      Color(int.parse('FF${hex.substring(1)}', radix: 16));
  final ink = color(e.ink);
  final accent = color(e.accent);
  final tint = color(e.tint);
  c.save();
  if (paper) {
    c.scale(size.width / 300, size.height / 240);
  } else {
    final scale = math.min(size.width / 300, size.height / 240);
    c.translate(
      (size.width - 300 * scale) / 2,
      (size.height - 240 * scale) / 2,
    );
    c.scale(scale, scale);
  }
  final stroke = Paint()
    ..color = accent.withValues(alpha: .85)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.3
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final hairline = Paint()
    ..color = ink.withValues(alpha: .34)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.round;
  Paint fill(Color value) => Paint()..color = value;
  void line(double x, double y, double xx, double yy, {Paint? paint}) =>
      c.drawLine(Offset(x, y), Offset(xx, yy), paint ?? stroke);
  void rr(Rect rect, double radius, {Paint? paint}) => c.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(radius)),
    paint ?? stroke,
  );
  void oval(Rect rect, {Paint? paint}) => c.drawOval(rect, paint ?? stroke);
  if (paper) {
    final stock = Path();
    switch (mode) {
      case 0:
        stock.moveTo(8, 12);
        stock.lineTo(285, 8);
        stock.lineTo(293, 225);
        stock.lineTo(16, 232);
        stock.close();
      case 1:
        stock.moveTo(9, 8);
        stock.lineTo(291, 8);
        stock.lineTo(291, 231);
        stock.lineTo(9, 231);
        stock.close();
      case 2:
        stock.addRect(const Rect.fromLTWH(8, 9, 284, 222));
      case 3:
        stock.moveTo(11, 17);
        for (var x = 11.0; x < 290; x += 20)
          stock.quadraticBezierTo(x + 10, 2, x + 20, 17);
        stock.lineTo(291, 222);
        for (var x = 291.0; x > 12; x -= 20)
          stock.quadraticBezierTo(x - 10, 236, x - 20, 222);
        stock.close();
      case 4:
        stock.addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(8, 12, 284, 216),
            const Radius.circular(14),
          ),
        );
      case 5:
        stock.moveTo(8, 10);
        stock.lineTo(275, 10);
        stock.lineTo(292, 28);
        stock.lineTo(292, 231);
        stock.lineTo(8, 231);
        stock.close();
      case 6:
        stock.moveTo(9, 18);
        stock.lineTo(251, 9);
        stock.lineTo(289, 35);
        stock.lineTo(282, 232);
        stock.lineTo(15, 223);
        stock.close();
      case 7:
        stock.moveTo(9, 13);
        stock.lineTo(291, 13);
        stock.lineTo(291, 99);
        stock.arcToPoint(
          const Offset(291, 124),
          radius: const Radius.circular(13),
          clockwise: false,
        );
        stock.lineTo(291, 227);
        stock.lineTo(9, 227);
        stock.lineTo(9, 124);
        stock.arcToPoint(
          const Offset(9, 99),
          radius: const Radius.circular(13),
          clockwise: false,
        );
        stock.close();
      default:
        stock.moveTo(8, 17);
        stock.lineTo(88, 8);
        stock.lineTo(203, 15);
        stock.lineTo(291, 8);
        stock.lineTo(291, 224);
        stock.lineTo(204, 233);
        stock.lineTo(89, 225);
        stock.lineTo(8, 232);
        stock.close();
    }
    c.drawPath(stock, fill(Color.lerp(const Color(0xFFFAF6ED), tint, .20)!));
    c.drawPath(stock, hairline);
    final edge = Paint()
      ..color = accent.withValues(alpha: .28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    // Every printed detail stays out of the editable13%-87% writing column.
    switch (mode) {
      case 0:
        for (var n = 0; n < 5; n++) {
          oval(
            Rect.fromLTWH(16 + n * 3, 19 + n * 3, 30 - n * 6, 18 - n * 3),
            paint: edge,
          );
        }
        line(25, 215, 275, 215, paint: edge);
        for (var n = 0; n < 11; n++)
          line(25 + n * 25, 215, 25 + n * 25, 221, paint: edge);
      case 1:
        line(22, 28, 22, 211, paint: edge);
        line(22, 211, 279, 211, paint: edge);
        for (var n = 0; n < 6; n++)
          line(20, 42 + n * 29, 26, 42 + n * 29, paint: edge);
        c.save();
        c.translate(254, 17);
        c.scale(.09);
        _hobbyMotif(c, 1, ink, accent);
        c.restore();
      case 2:
        for (var n = 0; n < 13; n++) {
          rr(Rect.fromLTWH(13 + n * 21, 15, 10, 6), 1, paint: edge);
          rr(Rect.fromLTWH(13 + n * 21, 219, 10, 6), 1, paint: edge);
        }
        line(29, 31, 272, 31, paint: edge);
        line(29, 208, 272, 208, paint: edge);
      case 3:
        for (var n = 0; n < 17; n++)
          c.drawCircle(
            Offset(18 + n * 16, 25),
            .9,
            fill(accent.withValues(alpha: .32)),
          );
        line(24, 214, 276, 214, paint: edge);
        c.drawPath(
          Path()
            ..moveTo(264, 24)
            ..lineTo(272, 32)
            ..lineTo(280, 24),
          edge,
        );
      case 4:
        for (var n = 0; n < 18; n++) {
          line(19 + n * 15, 23, 25 + n * 15, 29, paint: edge);
          line(19 + n * 15, 214, 25 + n * 15, 208, paint: edge);
        }
        for (var n = 0; n < 10; n++) {
          line(18, 35 + n * 17, 24, 41 + n * 17, paint: edge);
          line(275, 35 + n * 17, 281, 41 + n * 17, paint: edge);
        }
      case 5:
        for (var n = 0; n < 5; n++)
          line(25, 210 + n * 3, 275, 210 + n * 3, paint: edge);
        line(274, 10, 274, 29, paint: edge);
        line(274, 29, 292, 29, paint: edge);
        c.drawCircle(
          const Offset(21, 24),
          3,
          fill(accent.withValues(alpha: .35)),
        );
      case 6:
        line(20, 38, 280, 29, paint: edge);
        line(20, 210, 274, 218, paint: edge);
        final seal = Path()
          ..moveTo(251, 9)
          ..lineTo(249, 38)
          ..lineTo(289, 35);
        c.drawPath(seal, edge);
        for (var n = 0; n < 3; n++)
          line(23 + n * 4, 28, 25 + n * 4, 52, paint: edge);
      case 7:
        for (var n = 0; n < 15; n++)
          line(27 + n * 17, 30, 33 + n * 17, 30, paint: edge);
        for (var n = 0; n < 15; n++)
          line(27 + n * 17, 210, 33 + n * 17, 210, paint: edge);
        line(25, 37, 25, 203, paint: edge);
        line(276, 37, 276, 203, paint: edge);
      default:
        line(88, 18, 88, 33, paint: edge);
        line(204, 25, 204, 40, paint: edge);
        line(88, 209, 88, 223, paint: edge);
        line(204, 214, 204, 229, paint: edge);
        for (var n = 0; n < 7; n++)
          line(20 + n * 39, 214, 31 + n * 39, 214, paint: edge);
        c.drawPath(
          Path()
            ..moveTo(270, 21)
            ..lineTo(276, 34)
            ..lineTo(264, 34)
            ..close(),
          edge,
        );
    }
  } else {
    _hobbyMotif(c, mode, ink, accent);
  }
  c.restore();
}

void _hobbyMotif(Canvas c, int mode, Color ink, Color accent) {
  final p = Paint()
    ..color = ink.withValues(alpha: .86)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final fine = Paint()
    ..color = accent.withValues(alpha: .75)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..strokeCap = StrokeCap.round;
  Paint fill(Color color) => Paint()..color = color;
  void line(double x, double y, double xx, double yy, {Paint? paint}) =>
      c.drawLine(Offset(x, y), Offset(xx, yy), paint ?? p);
  void oval(Rect rect, {Paint? paint}) => c.drawOval(rect, paint ?? p);
  switch (mode) {
    case 0: // A potter's wheel, thumb-marked bowl and companion vase.
      oval(
        const Rect.fromLTWH(37, 154, 226, 53),
        paint: fill(accent.withValues(alpha: .15)),
      );
      oval(const Rect.fromLTWH(37, 154, 226, 53));
      final bowl = Path()
        ..moveTo(71, 112)
        ..quadraticBezierTo(150, 90, 229, 112)
        ..quadraticBezierTo(220, 166, 150, 175)
        ..quadraticBezierTo(80, 166, 71, 112)
        ..close();
      c.drawPath(bowl, fill(Color.lerp(const Color(0xFFE4C8AA), accent, .25)!));
      c.drawPath(bowl, p);
      oval(const Rect.fromLTWH(71, 95, 158, 32));
      for (var n = 0; n < 5; n++)
        c.drawArc(
          Rect.fromLTWH(86, 111 + n * 9, 128, 25),
          0,
          math.pi,
          false,
          fine,
        );
      line(95, 197, 85, 224);
      line(205, 197, 215, 224);
      line(148, 207, 148, 227);
      c.drawPath(
        Path()
          ..moveTo(55, 117)
          ..cubicTo(28, 89, 38, 54, 65, 45)
          ..lineTo(87, 45)
          ..cubicTo(109, 61, 94, 85, 104, 94),
        fine,
      );
    case 1: // Two botanical stems with individually drawn leaves and veins.
      final stem = Path()
        ..moveTo(137, 219)
        ..cubicTo(149, 152, 163, 90, 146, 22);
      c.drawPath(stem, p);
      for (var n = 0; n < 5; n++) {
        final y = 55.0 + n * 30;
        final left = n.isEven;
        final x = left ? 85.0 : 194.0;
        final leaf = Path()
          ..moveTo(148, y + 18)
          ..quadraticBezierTo(x, y - 35, x + (left ? -10 : 12), y - 15)
          ..quadraticBezierTo(x + (left ? 20 : -20), y + 32, 148, y + 18)
          ..close();
        c.drawPath(leaf, fill(accent.withValues(alpha: .22)));
        c.drawPath(leaf, p);
        line(148, y + 18, x, y - 7, paint: fine);
      }
      c.drawPath(
        Path()
          ..moveTo(112, 220)
          ..quadraticBezierTo(79, 159, 65, 129),
        fine,
      );
      c.drawCircle(
        const Offset(63, 126),
        5,
        fill(accent.withValues(alpha: .65)),
      );
    case 2: // A metal film canister and contact strip with real negative space.
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(36, 63, 91, 135),
          const Radius.circular(12),
        ),
        fill(ink.withValues(alpha: .12)),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(36, 63, 91, 135),
          const Radius.circular(12),
        ),
        p,
      );
      oval(const Rect.fromLTWH(35, 44, 93, 35));
      line(50, 50, 50, 29);
      line(112, 50, 112, 29);
      oval(const Rect.fromLTWH(50, 21, 62, 20));
      for (var n = 0; n < 3; n++)
        line(53, 104 + n * 11, 112, 104 + n * 11, paint: fine);
      c.drawPath(
        Path()
          ..moveTo(126, 79)
          ..lineTo(270, 79)
          ..lineTo(270, 206)
          ..lineTo(126, 206),
        p,
      );
      for (var n = 0; n < 5; n++) {
        c.drawRect(Rect.fromLTWH(144 + n * 25, 86, 11, 7), fine);
        c.drawRect(Rect.fromLTWH(144 + n * 25, 191, 11, 7), fine);
      }
      c.drawRect(const Rect.fromLTWH(145, 106, 48, 67), fine);
      c.drawRect(const Rect.fromLTWH(207, 106, 48, 67), fine);
    case 3: // Bread scoring, a whisk and restrained steam, not a generic star.
      final bread = Path()
        ..moveTo(37, 174)
        ..cubicTo(31, 104, 97, 74, 160, 90)
        ..cubicTo(223, 104, 253, 143, 251, 180)
        ..quadraticBezierTo(148, 219, 37, 174)
        ..close();
      c.drawPath(bread, fill(const Color(0xFFE7BC81)));
      c.drawPath(bread, p);
      for (var n = 0; n < 4; n++)
        c.drawPath(
          Path()
            ..moveTo(78 + n * 37, 106 + n * 5)
            ..quadraticBezierTo(
              66 + n * 37,
              126 + n * 5,
              91 + n * 37,
              146 + n * 5,
            ),
          fine,
        );
      line(207, 89, 250, 38);
      oval(const Rect.fromLTWH(215, 18, 56, 53));
      line(226, 29, 257, 64, paint: fine);
      line(241, 24, 248, 69, paint: fine);
      for (var n = 0; n < 3; n++)
        c.drawPath(
          Path()
            ..moveTo(73 + n * 32, 77)
            ..cubicTo(47 + n * 32, 56, 97 + n * 32, 46, 78 + n * 32, 26),
          fine,
        );
    case 4: // A winding yarn ball, crossed needles and a deliberately loose end.
      oval(
        const Rect.fromLTWH(57, 62, 150, 136),
        paint: fill(accent.withValues(alpha: .14)),
      );
      oval(const Rect.fromLTWH(57, 62, 150, 136));
      for (var n = 0; n < 6; n++)
        c.drawArc(
          Rect.fromLTWH(61 + n * 9, 64, 134 - n * 12, 132),
          -.7,
          4.8,
          false,
          fine,
        );
      for (var n = 0; n < 4; n++)
        c.drawArc(
          Rect.fromLTWH(58, 75 + n * 20, 150, 47),
          -.3,
          3.5,
          false,
          fine,
        );
      line(61, 53, 239, 207);
      line(221, 36, 46, 211);
      c.drawCircle(const Offset(61, 53), 5, p);
      c.drawCircle(const Offset(221, 36), 5, p);
      c.drawPath(
        Path()
          ..moveTo(203, 166)
          ..cubicTo(281, 161, 220, 229, 274, 215),
        fine,
      );
    case 5: // Staff, quarter notes and a tuning fork with precise open spaces.
      for (var n = 0; n < 5; n++)
        line(30, 116 + n * 14, 271, 116 + n * 14, paint: fine);
      oval(const Rect.fromLTWH(78, 150, 28, 18), paint: fill(ink));
      line(103, 157, 103, 68);
      oval(const Rect.fromLTWH(143, 135, 28, 18), paint: fill(ink));
      line(168, 142, 168, 52);
      line(103, 68, 168, 52);
      c.drawPath(
        Path()
          ..moveTo(230, 45)
          ..lineTo(230, 83)
          ..quadraticBezierTo(230, 102, 249, 102)
          ..quadraticBezierTo(268, 102, 268, 83)
          ..lineTo(268, 45),
        p,
      );
      line(249, 103, 249, 204);
      c.drawCircle(const Offset(249, 209), 5, p);
    case 6: // A layered paper corner and functional scissors, not sticker noise.
      final sheet = Path()
        ..moveTo(54, 46)
        ..lineTo(221, 35)
        ..lineTo(246, 183)
        ..lineTo(68, 203)
        ..close();
      c.drawPath(sheet, fill(const Color(0xFFE5D4BA)));
      c.drawPath(sheet, p);
      c.drawRect(
        const Rect.fromLTWH(93, 68, 119, 100),
        fill(accent.withValues(alpha: .18)),
      );
      line(107, 88, 191, 88, paint: fine);
      line(107, 102, 183, 102, paint: fine);
      line(107, 116, 192, 116, paint: fine);
      oval(const Rect.fromLTWH(31, 151, 42, 32));
      oval(const Rect.fromLTWH(53, 185, 42, 32));
      line(68, 166, 153, 218);
      line(75, 198, 123, 130);
      c.drawCircle(const Offset(87, 180), 4, p);
      c.drawPath(
        Path()
          ..moveTo(213, 34)
          ..lineTo(207, 62)
          ..lineTo(225, 60),
        fine,
      );
    case 7: // A gallery wall, small art spaces and a perforated admission stub.
      final wall = Path()
        ..moveTo(38, 43)
        ..lineTo(241, 43)
        ..lineTo(269, 76)
        ..lineTo(269, 202)
        ..lineTo(38, 202)
        ..close();
      c.drawPath(wall, p);
      line(241, 43, 241, 175);
      line(241, 175, 269, 202, paint: fine);
      line(38, 175, 241, 175, paint: fine);
      c.drawRect(const Rect.fromLTWH(60, 68, 67, 66), p);
      c.drawRect(const Rect.fromLTWH(146, 81, 66, 47), p);
      c.drawPath(
        Path()
          ..moveTo(66, 124)
          ..lineTo(89, 97)
          ..lineTo(106, 111)
          ..lineTo(121, 91),
        fine,
      );
      final ticket = const Rect.fromLTWH(106, 188, 136, 32);
      c.drawRect(ticket, fill(accent.withValues(alpha: .16)));
      c.drawRect(ticket, fine);
      for (var n = 0; n < 6; n++)
        line(210, 192 + n * 4, 210, 194 + n * 4, paint: fine);
    default: // Canvas tent, pegged guy-lines and a freestanding lantern.
      final tent = Path()
        ..moveTo(24, 188)
        ..lineTo(120, 46)
        ..lineTo(222, 188)
        ..close();
      c.drawPath(tent, fill(accent.withValues(alpha: .18)));
      c.drawPath(tent, p);
      c.drawPath(
        Path()
          ..moveTo(64, 188)
          ..lineTo(120, 83)
          ..lineTo(176, 188),
        p,
      );
      line(120, 83, 120, 187, paint: fine);
      line(120, 46, 161, 54);
      line(161, 54, 222, 188, paint: fine);
      line(54, 144, 14, 203, paint: fine);
      line(203, 147, 237, 201, paint: fine);
      line(10, 204, 27, 204);
      line(232, 203, 247, 203);
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(240, 115, 39, 68),
          const Radius.circular(8),
        ),
        p,
      );
      c.drawArc(
        const Rect.fromLTWH(242, 96, 35, 35),
        math.pi,
        math.pi,
        false,
        p,
      );
      line(246, 135, 274, 135, paint: fine);
      line(246, 166, 274, 166, paint: fine);
      line(260, 141, 260, 160, paint: fine);
  }
}
