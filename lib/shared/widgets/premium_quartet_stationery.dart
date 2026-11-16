import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/templates/story_edition_catalog.dart';

/// Print-native paper and a distinct object silhouette for every paid volume.
/// The writing rectangle stays blank; all stock details occupy its margins.
class PremiumQuartetStationery extends StatelessWidget {
  const PremiumQuartetStationery({super.key, required this.id});
  final String id;

  static const supportedMotifs = {
    'norigaeKnot',
    'keyAndSeal',
    'handmadeInvitation',
    'doubleOliveRing',
    'snowCompass',
    'steamBowl',
    'desertMoon',
    'bookshopAwning',
    'lunchboxWrap',
    'umbrellaRoute',
    'sewingSpool',
    'marketBasket',
    'acornLunch',
    'mittenSnowflake',
    'speechAlphabet',
    'tinyButton',
    'houseKeyRing',
    'filmProjector',
    'candleGarland',
    'marketRoutePin',
    'pairedEnvelopes',
    'anniversaryDial',
    'foldingRuler',
    'twinSpoons',
    'adoptionNameTag',
    'softHarness',
    'rabbitHayBasket',
    'shellLeash',
    'raceMedal',
    'yogaBlock',
    'barbellPlate',
    'surfFin',
    'thesisBinding',
    'luggageCompass',
    'uniformRibbon',
    'embossSeal',
    'choirScore',
    'woodenGameTiles',
    'potluckCarrier',
    'repairToolRoll',
    'watercolorTin',
    'joinerySquare',
    'embroideryHoop',
    'recordSleeve',
  };

  static Rect recordTextBounds(Size size) => Rect.fromLTWH(
    size.width * .14,
    size.height * .18,
    size.width * .72,
    size.height * .62,
  );

  static Path paperOuter(int kind, Size size) {
    final w = size.width, h = size.height, u = math.min(w, h);
    if (!size.isFinite || size.isEmpty) return Path();
    Path poly(List<Offset> points) => Path()..addPolygon(points, true);
    final rect = Offset.zero & size;
    switch (kind % 16) {
      case 0:
        final p = Path()..moveTo(0, u * .009);
        for (var n = 0; n <= 24; n++) {
          p.lineTo(w * n / 24, u * (n.isEven ? .005 : .014));
        }
        p.lineTo(w, h - u * .008);
        for (var n = 24; n >= 0; n--) {
          p.lineTo(w * n / 24, h - u * (n.isEven ? .005 : .013));
        }
        return p..close();
      case 1:
        return Path()
          ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(u * .025)));
      case 2:
        return poly([
          Offset.zero,
          Offset(w - u * .07, 0),
          Offset(w, u * .07),
          Offset(w, h),
          Offset(0, h),
        ]);
      case 3:
        return poly([
          Offset(0, u * .035),
          Offset(w * .57, u * .035),
          Offset(w * .60, 0),
          Offset(w * .83, 0),
          Offset(w * .86, u * .035),
          Offset(w, u * .035),
          Offset(w, h),
          Offset(0, h),
        ]);
      case 4:
        final stock = Path()..addRect(rect);
        final holes = Path();
        for (var n = 0; n < 5; n++)
          holes.addOval(
            Rect.fromCircle(
              center: Offset(u * .035, h * (.20 + n * .15)),
              radius: u * .008,
            ),
          );
        return Path.combine(PathOperation.difference, stock, holes);
      case 5:
        final c = u * .035;
        return poly([
          Offset(c, 0),
          Offset(w - c, 0),
          Offset(w, c),
          Offset(w, h - c),
          Offset(w - c, h),
          Offset(c, h),
          Offset(0, h - c),
          Offset(0, c),
        ]);
      case 6:
        final p = Path()
          ..moveTo(0, 0)
          ..lineTo(w, 0)
          ..lineTo(w, h - u * .015);
        for (var n = 30; n >= 0; n--)
          p.lineTo(w * n / 30, h - u * (n.isEven ? .015 : 0));
        return p..close();
      case 7:
        return poly([
          Offset(u * .03, 0),
          Offset(w, 0),
          Offset(w, h - u * .045),
          Offset(w - u * .045, h),
          Offset(0, h),
          Offset(0, u * .03),
        ]);
      case 8:
        final stock = Path()
          ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(u * .015)));
        final cut = Path()
          ..addOval(Rect.fromCircle(center: Offset(0, h * .5), radius: u * .03))
          ..addOval(
            Rect.fromCircle(center: Offset(w, h * .5), radius: u * .03),
          );
        return Path.combine(PathOperation.difference, stock, cut);
      case 9:
        return poly([
          Offset(u * .015, 0),
          Offset(w, u * .012),
          Offset(w - u * .015, h),
          Offset(0, h - u * .012),
        ]);
      case 10:
        return Path()
          ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(u * .035)));
      case 11:
        return poly([
          Offset(u * .025, 0),
          Offset(w - u * .025, 0),
          Offset(w, u * .025),
          Offset(w, h),
          Offset(u * .025, h),
          Offset(0, h - u * .025),
          Offset(0, u * .025),
        ]);
      case 12:
        return poly([
          Offset.zero,
          Offset(w - u * .055, 0),
          Offset(w, u * .055),
          Offset(w, h),
          Offset(u * .055, h),
          Offset(0, h - u * .055),
        ]);
      case 13:
        return Path()
          ..moveTo(u * .015, u * .008)
          ..cubicTo(w * .30, u * .02, w * .65, 0, w - u * .02, u * .01)
          ..quadraticBezierTo(w, u * .015, w - u * .005, u * .04)
          ..lineTo(w - u * .008, h - u * .02)
          ..quadraticBezierTo(w - u * .01, h, w - u * .04, h - u * .008)
          ..lineTo(u * .025, h - u * .01)
          ..quadraticBezierTo(0, h - u * .015, u * .005, h - u * .04)
          ..lineTo(u * .008, u * .03)
          ..quadraticBezierTo(0, 0, u * .015, u * .008)
          ..close();
      case 14:
        return poly([
          Offset.zero,
          Offset(w, 0),
          Offset(w, h - u * .035),
          Offset(w - u * .035, h),
          Offset(u * .035, h),
          Offset(0, h - u * .035),
        ]);
      default:
        final stock = Path()..addRect(rect);
        final cut = Path()
          ..addOval(
            Rect.fromCircle(center: Offset(w * .5, 0), radius: u * .035),
          );
        return Path.combine(PathOperation.difference, stock, cut);
    }
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _QuartetStationeryPainter(id),
    child: const SizedBox.expand(),
  );
}

class _QuartetStationeryPainter extends CustomPainter {
  const _QuartetStationeryPainter(this.id);
  final String id;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.isFinite) return;
    final spec = premiumQuartetSpecForMaterial(id);
    if (spec == null) return;
    final paper = id == '${spec.id}-paper' || id == '${spec.id}-vellum';
    if (paper) {
      _paintQuartetPaper(canvas, size, spec, id.endsWith('-vellum'));
    } else {
      final scale = math.min(size.width, size.height) / 500;
      canvas.save();
      canvas.translate(
        (size.width - 500 * scale) / 2,
        (size.height - 500 * scale) / 2,
      );
      canvas.scale(scale);
      _paintQuartetObject(canvas, spec);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_QuartetStationeryPainter old) => old.id != id;
}

Color _quartetColor(String hex) =>
    Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

void _paintQuartetPaper(
  Canvas canvas,
  Size size,
  PremiumQuartetSpec spec,
  bool vellum,
) {
  final kind = spec.paperKinds[vellum ? 1 : 0] % 16;
  final ink = _quartetColor(spec.ink), tint = _quartetColor(spec.tint);
  final accent = _quartetColor(spec.accent),
      secondary = _quartetColor(spec.paperAccent);
  canvas.save();
  canvas.scale(size.width / 500, size.height / 400);
  final outer = PremiumQuartetStationery.paperOuter(kind, const Size(500, 400));
  final stock = Color.lerp(
    const Color(0xFFFFFCF4),
    vellum ? secondary : tint,
    vellum ? .36 : .62,
  )!;
  canvas.drawPath(outer, Paint()..color = stock);
  canvas.drawPath(
    outer,
    Paint()
      ..color = ink.withValues(alpha: .20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2,
  );
  canvas.clipPath(outer);
  final safe = PremiumQuartetStationery.recordTextBounds(const Size(500, 400));
  canvas.clipPath(
    Path.combine(
      PathOperation.difference,
      Path()..addRect(const Rect.fromLTWH(0, 0, 500, 400)),
      Path()..addRect(safe),
    ),
  );
  final pen = Paint()
    ..color = accent.withValues(alpha: .62)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  void line(double x, double y, double xx, double yy, {Paint? paint}) =>
      canvas.drawLine(Offset(x, y), Offset(xx, yy), paint ?? pen);
  switch (kind) {
    case 0:
      for (var n = 0; n < 32; n++) {
        final x = 12.0 + n * 15;
        line(x, 18 + n % 3 * 3, x + 5, 27 + n % 4 * 2);
        line(x, 374 - n % 3 * 3, x + 6, 383 - n % 4 * 2);
      }
      line(25, 350, 475, 350);
    case 1:
      for (var n = 0; n < 28; n++) {
        final x = 22.0 + n * 17;
        line(x - 3, 25, x + 3, 31);
        line(x - 3, 375, x + 3, 369);
      }
      for (var n = 0; n < 18; n++) {
        final y = 29.0 + n * 20;
        line(20, y - 3, 26, y + 3);
        line(480, y - 3, 474, y + 3);
      }
    case 2:
      final fold = Path()
        ..moveTo(472, 0)
        ..lineTo(472, 28)
        ..lineTo(500, 28)
        ..close();
      canvas.drawPath(fold, Paint()..color = secondary.withValues(alpha: .65));
      line(30, 350, 470, 350);
      line(30, 359, 295, 359);
    case 3:
      for (var n = 0; n < 3; n++) {
        final x = 38.0 + n * 120;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 21, 86, 23),
            const Radius.circular(3),
          ),
          Paint()..color = accent.withValues(alpha: .14 + n * .06),
        );
        line(x + 12, 32, x + 63, 32);
      }
      line(32, 349, 468, 349);
    case 4:
      line(48, 20, 48, 380);
      for (var n = 0; n < 5; n++) {
        final y = 80.0 + n * 60;
        canvas.drawCircle(Offset(14, y), 7, pen);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(28, y), width: 29, height: 10),
          pen,
        );
      }
    case 5:
      for (var n = 0; n < 18; n++) {
        final x = 22.0 + n * 27;
        line(x, 10, x, 57);
        line(x, 345, x, 390);
      }
      for (final y in [18.0, 35.0, 52.0, 348.0, 365.0, 382.0])
        line(12, y, 488, y);
    case 6:
      for (var n = 0; n < 40; n++) {
        final x = 15.0 + n * 12;
        line(x, 352, x + 5, 352);
      }
      line(35, 33, 300, 33);
      line(35, 42, 230, 42);
    case 7:
      line(0, 18, 56, 64);
      line(500, 18, 444, 64);
      line(0, 383, 56, 336);
      line(500, 383, 444, 336);
      canvas.drawRect(const Rect.fromLTWH(30, 24, 128, 26), pen);
    case 8:
      for (var n = 0; n < 23; n++) {
        final y = 30.0 + n * 15;
        line(32, y, 46 + (n % 3) * 7, y);
        line(468, y, 456 - (n % 3) * 7, y);
      }
      for (var n = 0; n < 9; n++)
        line(184 + n * 11, 360, 184 + n * 11, 377 - n % 2 * 7);
    case 9:
      for (var n = 0; n < 50; n++) {
        final x = n * 11.0;
        line(x, 0, x + 30, 52);
        line(x, 400, x + 30, 348);
      }
      for (var n = 0; n < 38; n++) {
        final y = n * 11.0;
        line(0, y, 54, y + 30);
        line(500, y, 446, y + 30);
      }
    case 10:
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(13, 13, 474, 374),
          const Radius.circular(10),
        ),
        pen,
      );
      canvas.drawRect(
        const Rect.fromLTWH(24, 24, 450, 350),
        Paint()..color = secondary.withValues(alpha: .1),
      );
      for (var n = 0; n < 3; n++)
        line(36, 350.0 + n * 10, 320.0 - n * 35, 350.0 + n * 10);
    case 11:
      for (final x in [36.0, 50.0, 450.0, 464.0]) line(x, 15, x, 385);
      for (final y in [90.0, 200.0, 310.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(28, y, 30, 12),
            const Radius.circular(3),
          ),
          pen,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(442, y, 30, 12),
            const Radius.circular(3),
          ),
          pen,
        );
      }
    case 12:
      for (var n = 0; n < 5; n++) {
        final p = Path()
          ..moveTo(8, 12.0 + n * 9)
          ..cubicTo(155, 60.0 - n * 4, 260, 5.0 + n * 8, 492, 48.0 - n * 6);
        canvas.drawPath(p, pen);
        final q = Path()
          ..moveTo(8, 388.0 - n * 9)
          ..cubicTo(155, 340.0 + n * 4, 260, 395.0 - n * 8, 492, 352.0 + n * 6);
        canvas.drawPath(q, pen);
      }
    case 13:
      for (var n = 0; n < 30; n++) {
        final x = 12.0 + n * 16;
        line(x, 8, x + 4, 19);
        line(x, 391, x + 6, 379);
      }
      line(28, 350, 472, 350);
    case 14:
      final flap = Path()
        ..moveTo(0, 348)
        ..lineTo(250, 393)
        ..lineTo(500, 348);
      canvas.drawPath(flap, pen);
      line(0, 339, 500, 339);
      canvas.drawCircle(
        const Offset(250, 365),
        11,
        Paint()..color = accent.withValues(alpha: .24),
      );
    default:
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(28, 21, 152, 29),
          const Radius.circular(3),
        ),
        pen,
      );
      for (var n = 0; n < 3; n++)
        line(48, 344.0 + n * 12, 330.0 - n * 45, 344.0 + n * 12);
  }
  // A miniature of the actual book object makes otherwise related stocks
  // recognizable while remaining entirely above the record-writing region.
  canvas.save();
  canvas.translate(433, 6);
  canvas.scale(.112);
  _paintQuartetObject(canvas, spec);
  canvas.restore();
  canvas.restore();
}

class _ObjectInk {
  _ObjectInk(this.c, this.spec)
    : ink = _quartetColor(spec.ink),
      tint = _quartetColor(spec.tint),
      accent = _quartetColor(spec.accent),
      paper = _quartetColor(spec.paperAccent);
  final Canvas c;
  final PremiumQuartetSpec spec;
  final Color ink, tint, accent, paper;
  Paint pen([double width = 4, Color? color]) => Paint()
    ..color = color ?? ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  void line(
    double x,
    double y,
    double xx,
    double yy, {
    double width = 4,
    Color? color,
  }) => c.drawLine(Offset(x, y), Offset(xx, yy), pen(width, color));
  void path(Path p, {Color? fill, double width = 4, Color? color}) {
    if (fill != null) c.drawPath(p, Paint()..color = fill);
    c.drawPath(p, pen(width, color));
  }

  void rect(
    double x,
    double y,
    double w,
    double h, {
    double radius = 6,
    Color? fill,
    double width = 4,
    Color? color,
  }) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      Radius.circular(radius),
    );
    if (fill != null) c.drawRRect(r, Paint()..color = fill);
    c.drawRRect(r, pen(width, color));
  }

  void oval(
    double x,
    double y,
    double w,
    double h, {
    Color? fill,
    double width = 4,
    Color? color,
  }) {
    final r = Rect.fromLTWH(x, y, w, h);
    if (fill != null) c.drawOval(r, Paint()..color = fill);
    c.drawOval(r, pen(width, color));
  }

  void circle(
    double x,
    double y,
    double r, {
    Color? fill,
    double width = 4,
    Color? color,
  }) =>
      oval(x - r, y - r, r * 2, r * 2, fill: fill, width: width, color: color);
  void poly(
    List<Offset> points, {
    Color? fill,
    double width = 4,
    Color? color,
  }) => path(
    Path()..addPolygon(points, true),
    fill: fill,
    width: width,
    color: color,
  );
  void leaf(
    double x,
    double y,
    double angle, {
    double length = 55,
    double breadth = 22,
    Color? fill,
  }) {
    c.save();
    c.translate(x, y);
    c.rotate(angle);
    path(
      Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(length * .44, -breadth, length, 0)
        ..quadraticBezierTo(length * .44, breadth, 0, 0)
        ..close(),
      fill: fill ?? tint,
      width: 2.5,
    );
    line(0, 0, length * .82, 0, width: 2);
    c.restore();
  }

  void ray(
    double x,
    double y,
    double radius,
    int count, {
    double inner = 0,
    double phase = 0,
    double width = 4,
    Color? color,
  }) {
    for (var n = 0; n < count; n++) {
      final a = phase + n * math.pi * 2 / count;
      line(
        x + math.cos(a) * inner,
        y + math.sin(a) * inner,
        x + math.cos(a) * radius,
        y + math.sin(a) * radius,
        width: width,
        color: color,
      );
    }
  }

  void dash(
    double x,
    double y,
    double xx,
    double yy, {
    int count = 12,
    Color? color,
  }) {
    for (var n = 0; n < count; n++) {
      final t = n / count, u = (n + .45) / count;
      line(
        x + (xx - x) * t,
        y + (yy - y) * t,
        x + (xx - x) * u,
        y + (yy - y) * u,
        width: 3,
        color: color,
      );
    }
  }

  void marks(double x, double y, double w, {int rows = 3}) {
    for (var n = 0; n < rows; n++)
      line(
        x,
        y + n * 15,
        x + w - (n % 3) * w * .13,
        y + n * 15,
        width: 2.5,
        color: ink.withValues(alpha: .55),
      );
  }
}

/// Object topology, not a shared badge with a changing number or caption.
void _paintQuartetObject(Canvas canvas, PremiumQuartetSpec spec) {
  final p = _ObjectInk(canvas, spec), c = canvas;
  final ink = p.ink, tint = p.tint, accent = p.accent, paper = p.paper;
  switch (spec.motifCode) {
    case 'norigaeKnot':
      p.oval(220, 36, 60, 88, fill: paper);
      p.path(
        Path()
          ..moveTo(250, 105)
          ..cubicTo(150, 45, 140, 185, 250, 200)
          ..cubicTo(360, 185, 350, 45, 250, 105)
          ..cubicTo(170, 205, 320, 260, 250, 105),
        fill: tint,
      );
      p.poly([
        const Offset(250, 170),
        const Offset(310, 235),
        const Offset(250, 296),
        const Offset(190, 235),
      ], fill: accent.withValues(alpha: .28));
      p.circle(250, 305, 17, fill: paper);
      for (var n = 0; n < 13; n++)
        p.line(
          220 + n * 5,
          325,
          205 + n * 7,
          455,
          width: 3,
          color: n.isEven ? ink : accent,
        );
      p.line(210, 444, 294, 444, width: 7, color: accent);
    case 'keyAndSeal':
      for (final data in [
        const [165.0, 130.0, -.28],
        const [295.0, 142.0, .28],
      ]) {
        c.save();
        c.translate(data[0], data[1]);
        c.rotate(data[2]);
        p.circle(0, 0, 48, fill: tint);
        p.circle(0, 0, 23, width: 3);
        p.rect(-12, 45, 24, 220, fill: paper);
        p.poly([
          const Offset(12, 210),
          const Offset(49, 210),
          const Offset(49, 232),
          const Offset(12, 232),
        ], fill: accent.withValues(alpha: .4));
        p.line(13, 251, 39, 251, width: 9);
        c.restore();
      }
      p.circle(352, 375, 55, fill: accent.withValues(alpha: .16));
      p.circle(352, 375, 39, width: 2);
      p.poly([
        const Offset(352, 347),
        const Offset(377, 375),
        const Offset(352, 403),
        const Offset(327, 375),
      ], width: 3);
    case 'handmadeInvitation':
      p.rect(95, 55, 310, 236, fill: paper, radius: 3);
      p.marks(130, 95, 235, rows: 4);
      p.rect(65, 196, 370, 235, fill: tint, radius: 4);
      p.poly([
        const Offset(65, 196),
        const Offset(250, 328),
        const Offset(435, 196),
      ], fill: paper);
      p.line(65, 431, 209, 300);
      p.line(435, 431, 291, 300);
      p.line(250, 192, 250, 428, width: 3, color: accent);
      p.path(
        Path()
          ..moveTo(250, 318)
          ..cubicTo(163, 259, 180, 376, 250, 335)
          ..cubicTo(328, 378, 336, 267, 250, 318),
        width: 4,
        color: accent,
      );
    case 'doubleOliveRing':
      for (final x in [192.0, 307.0]) {
        p.circle(x, 257, 112, width: 5, color: accent);
        for (var n = 0; n < 7; n++) {
          final a = (-140 + n * 31) * math.pi / 180;
          p.leaf(
            x + math.cos(a) * 112,
            257 + math.sin(a) * 112,
            a + .8,
            length: 40,
            breadth: 15,
          );
        }
      }
      p.path(
        Path()
          ..moveTo(250, 362)
          ..cubicTo(161, 326, 174, 418, 248, 382)
          ..cubicTo(335, 424, 339, 331, 250, 362),
        fill: paper,
        color: accent,
      );
      p.line(242, 381, 218, 447, color: accent);
      p.line(258, 381, 282, 447, color: accent);
    case 'snowCompass':
      p.ray(250, 250, 209, 6, inner: 120, phase: math.pi / 6, color: accent);
      for (var n = 0; n < 6; n++) {
        final a = n * math.pi / 3 + math.pi / 6,
            x = 250 + math.cos(a) * 183,
            y = 250 + math.sin(a) * 183;
        p.line(
          x,
          y,
          x - math.cos(a - .7) * 29,
          y - math.sin(a - .7) * 29,
          width: 3,
        );
        p.line(
          x,
          y,
          x - math.cos(a + .7) * 29,
          y - math.sin(a + .7) * 29,
          width: 3,
        );
      }
      p.circle(250, 250, 128, fill: paper);
      p.circle(250, 250, 108, width: 2);
      p.poly([
        const Offset(250, 141),
        const Offset(284, 250),
        const Offset(250, 360),
        const Offset(216, 250),
      ], fill: tint);
      p.poly([
        const Offset(141, 250),
        const Offset(250, 216),
        const Offset(360, 250),
        const Offset(250, 284),
      ], fill: accent.withValues(alpha: .3));
      p.circle(250, 250, 12, fill: ink);
    case 'steamBowl':
      p.path(
        Path()
          ..moveTo(80, 270)
          ..quadraticBezierTo(95, 420, 250, 423)
          ..quadraticBezierTo(405, 420, 420, 270)
          ..close(),
        fill: tint,
      );
      p.oval(80, 215, 340, 110, fill: paper);
      p.oval(108, 238, 284, 63, width: 2, color: accent);
      for (final x in [150.0, 250.0, 350.0])
        p.path(
          Path()
            ..moveTo(x, 190)
            ..cubicTo(x - 43, 140, x + 42, 112, x, 55),
          width: 5,
          color: accent,
        );
      p.rect(328, 339, 110, 89, fill: paper, radius: 4);
      p.line(340, 356, 427, 356, width: 2);
      p.line(340, 371, 427, 371, width: 2);
    case 'desertMoon':
      final moon = Path.combine(
        PathOperation.difference,
        Path()..addOval(
          Rect.fromCircle(center: const Offset(346, 128), radius: 76),
        ),
        Path()..addOval(
          Rect.fromCircle(center: const Offset(373, 106), radius: 72),
        ),
      );
      p.path(moon, fill: accent.withValues(alpha: .45), width: 2);
      p.path(
        Path()
          ..moveTo(40, 345)
          ..quadraticBezierTo(173, 179, 307, 331)
          ..quadraticBezierTo(399, 261, 460, 344)
          ..lineTo(460, 444)
          ..lineTo(40, 444)
          ..close(),
        fill: tint,
      );
      p.path(
        Path()
          ..moveTo(40, 408)
          ..quadraticBezierTo(230, 275, 460, 414),
        width: 3,
        color: accent,
      );
      p.path(
        Path()
          ..moveTo(77, 423)
          ..quadraticBezierTo(235, 337, 425, 430),
        width: 2,
        color: accent,
      );
      p.ray(132, 105, 13, 4, phase: math.pi / 4);
      p.ray(210, 154, 8, 4, phase: math.pi / 4);
    case 'bookshopAwning':
      p.rect(105, 180, 290, 255, fill: paper, radius: 3);
      p.poly([
        const Offset(74, 185),
        const Offset(110, 89),
        const Offset(389, 89),
        const Offset(426, 185),
      ], fill: tint);
      for (var n = 0; n < 7; n++) {
        final x = 83 + n * 48.0;
        p.path(
          Path()
            ..moveTo(110 + n * 40.0, 90)
            ..lineTo(x, 184)
            ..quadraticBezierTo(x + 22, 212, x + 45, 184),
          fill: n.isEven ? paper : accent.withValues(alpha: .25),
          width: 2.5,
        );
      }
      p.rect(129, 239, 132, 150, fill: tint);
      for (var n = 0; n < 5; n++)
        p.line(
          145 + n * 22,
          263,
          145 + n * 22,
          374,
          width: 9,
          color: n.isEven ? accent : ink,
        );
      p.rect(293, 235, 73, 200, fill: paper);
      p.circle(349, 336, 4, fill: accent);
    case 'lunchboxWrap':
      p.poly([
        const Offset(52, 282),
        const Offset(164, 157),
        const Offset(336, 160),
        const Offset(453, 282),
        const Offset(382, 439),
        const Offset(112, 439),
      ], fill: tint);
      p.rect(105, 211, 290, 175, fill: paper, radius: 23);
      p.line(248, 218, 248, 380);
      p.line(252, 295, 386, 295);
      for (var n = 0; n < 5; n++)
        p.oval(127 + n % 2 * 39, 245 + n * 19, 24, 8, fill: tint, width: 2);
      p.oval(274, 237, 80, 35, fill: accent.withValues(alpha: .35));
      p.circle(289, 335, 20, fill: tint);
      p.circle(346, 339, 18, fill: tint);
      p.path(
        Path()
          ..moveTo(250, 174)
          ..cubicTo(142, 81, 158, 221, 248, 193)
          ..cubicTo(344, 226, 359, 87, 250, 174),
        fill: paper,
        color: accent,
      );
    case 'umbrellaRoute':
      p.path(
        Path()
          ..moveTo(68, 235)
          ..quadraticBezierTo(250, 6, 432, 235)
          ..quadraticBezierTo(374, 195, 315, 235)
          ..quadraticBezierTo(250, 192, 184, 235)
          ..quadraticBezierTo(126, 195, 68, 235)
          ..close(),
        fill: tint,
      );
      p.path(
        Path()
          ..moveTo(250, 81)
          ..quadraticBezierTo(188, 130, 184, 235),
        width: 2,
      );
      p.path(
        Path()
          ..moveTo(250, 81)
          ..quadraticBezierTo(310, 130, 315, 235),
        width: 2,
      );
      p.path(
        Path()
          ..moveTo(250, 82)
          ..lineTo(250, 376)
          ..cubicTo(250, 433, 321, 433, 321, 376),
        width: 7,
        color: accent,
      );
      p.dash(69, 439, 218, 439, count: 9);
      p.dash(347, 439, 435, 393, count: 6);
      for (final x in [100.0, 370.0, 414.0])
        p.line(x, 64, x - 12, 92, width: 3, color: accent);
    case 'sewingSpool':
      p.rect(104, 143, 161, 216, fill: tint, radius: 12);
      p.oval(83, 112, 204, 68, fill: paper);
      p.oval(83, 325, 204, 68, fill: paper);
      for (var n = 0; n < 11; n++)
        p.line(113, 174 + n * 14, 256, 156 + n * 14, width: 3, color: accent);
      p.line(331, 96, 403, 408, width: 8);
      p.oval(319, 65, 23, 56, width: 3);
      p.circle(368, 376, 56, fill: paper);
      for (final v in [
        const Offset(-15, -15),
        const Offset(15, -15),
        const Offset(-15, 15),
        const Offset(15, 15),
      ])
        p.circle(368 + v.dx, 376 + v.dy, 5, fill: ink, width: 2);
    case 'marketBasket':
      p.path(
        Path()
          ..moveTo(145, 251)
          ..cubicTo(120, 49, 382, 49, 357, 251),
        width: 13,
        color: accent,
      );
      for (var n = 0; n < 4; n++)
        p.leaf(
          218 + n * 20,
          247,
          -1.9 + n * .24,
          length: 159,
          breadth: 17,
          fill: n.isEven ? tint : paper,
        );
      p.poly([
        const Offset(72, 242),
        const Offset(430, 242),
        const Offset(389, 435),
        const Offset(112, 435),
      ], fill: paper);
      for (var n = 0; n < 6; n++)
        p.line(111, 269 + n * 28, 397, 269 + n * 28, width: 3, color: accent);
      for (var n = 0; n < 8; n++)
        p.line(114 + n * 39, 250, 127 + n * 35, 427, width: 3, color: accent);
    case 'acornLunch':
      p.rect(238, 241, 202, 180, fill: tint, radius: 25);
      p.path(
        Path()
          ..moveTo(283, 240)
          ..cubicTo(280, 168, 397, 168, 395, 240),
        width: 10,
      );
      p.line(253, 286, 424, 286);
      p.rect(324, 299, 29, 45, fill: paper);
      p.oval(68, 175, 182, 241, fill: paper);
      p.path(
        Path()
          ..moveTo(62, 231)
          ..quadraticBezierTo(160, 80, 258, 231)
          ..close(),
        fill: accent.withValues(alpha: .35),
      );
      p.line(160, 169, 168, 109, width: 11);
      p.leaf(172, 133, -.5, length: 75, breadth: 22);
    case 'mittenSnowflake':
      for (final shift in [0.0, 177.0]) {
        c.save();
        c.translate(shift, shift == 0 ? 0 : 27);
        p.path(
          Path()
            ..moveTo(87, 356)
            ..lineTo(88, 212)
            ..cubicTo(87, 101, 198, 98, 200, 207)
            ..lineTo(200, 239)
            ..cubicTo(257, 174, 289, 249, 211, 317)
            ..lineTo(211, 356)
            ..close(),
          fill: tint,
        );
        p.rect(83, 348, 134, 52, fill: paper);
        for (var n = 0; n < 6; n++)
          p.line(96 + n * 20, 355, 96 + n * 20, 391, width: 2.5);
        c.restore();
      }
      p.ray(263, 77, 39, 6);
      for (var n = 0; n < 6; n++) {
        final a = n * math.pi / 3;
        p.leaf(
          263 + math.cos(a) * 21,
          77 + math.sin(a) * 21,
          a + math.pi / 2,
          length: 14,
          breadth: 5,
          fill: paper,
        );
      }
    case 'speechAlphabet':
      p.path(
        Path()
          ..moveTo(75, 65)
          ..lineTo(305, 65)
          ..quadraticBezierTo(330, 65, 330, 90)
          ..lineTo(330, 179)
          ..quadraticBezierTo(330, 205, 305, 205)
          ..lineTo(174, 205)
          ..lineTo(126, 243)
          ..lineTo(132, 205)
          ..lineTo(75, 205)
          ..quadraticBezierTo(50, 205, 50, 179)
          ..lineTo(50, 90)
          ..quadraticBezierTo(50, 65, 75, 65)
          ..close(),
        fill: paper,
      );
      for (final data in [
        const [83.0, 300.0],
        const [227.0, 268.0],
        const [345.0, 326.0],
      ])
        p.rect(data[0], data[1], 106, 112, fill: tint, radius: 10);
      p.poly(
        [
          const Offset(103, 384),
          const Offset(137, 327),
          const Offset(170, 384),
        ],
        width: 6,
        color: accent,
      );
      p.circle(280, 323, 26, width: 6, color: accent);
      p.path(
        Path()
          ..moveTo(421, 357)
          ..cubicTo(360, 326, 356, 414, 421, 387),
        width: 6,
        color: accent,
      );
      p.marks(83, 105, 197, rows: 3);
    case 'tinyButton':
      p.circle(247, 286, 142, fill: paper);
      p.circle(247, 286, 122, width: 2, color: accent);
      for (final v in [
        const Offset(-36, -36),
        const Offset(36, -36),
        const Offset(-36, 36),
        const Offset(36, 36),
      ])
        p.circle(247 + v.dx, 286 + v.dy, 12, fill: tint);
      p.path(
        Path()
          ..moveTo(212, 250)
          ..lineTo(282, 322)
          ..moveTo(282, 250)
          ..lineTo(212, 322),
        width: 6,
        color: accent,
      );
      p.line(247, 145, 247, 91, width: 5);
      p.leaf(247, 112, -2.65, length: 71, breadth: 24);
      p.leaf(247, 112, -.5, length: 68, breadth: 24);
    case 'houseKeyRing':
      p.circle(171, 125, 65, width: 9, color: accent);
      p.circle(171, 125, 47, width: 2);
      p.rect(156, 191, 28, 226, fill: paper);
      p.line(185, 351, 224, 351, width: 18);
      p.line(185, 390, 210, 390, width: 18);
      p.poly([
        const Offset(260, 222),
        const Offset(345, 143),
        const Offset(433, 222),
        const Offset(418, 222),
        const Offset(418, 389),
        const Offset(276, 389),
        const Offset(276, 222),
      ], fill: tint);
      p.rect(326, 298, 39, 91, fill: paper);
      p.circle(345, 227, 13, fill: paper);
      p.path(
        Path()
          ..moveTo(212, 97)
          ..cubicTo(320, 58, 359, 80, 345, 142),
        width: 3,
        color: accent,
      );
    case 'filmProjector':
      for (final data in [
        const [166.0, 132.0, 74.0],
        const [322.0, 146.0, 59.0],
      ]) {
        p.circle(data[0], data[1], data[2], fill: tint);
        for (var n = 0; n < 5; n++) {
          final a = n * math.pi * 2 / 5;
          p.circle(
            data[0] + math.cos(a) * data[2] * .52,
            data[1] + math.sin(a) * data[2] * .52,
            data[2] * .13,
            fill: paper,
            width: 2,
          );
        }
      }
      p.rect(92, 220, 270, 163, fill: paper, radius: 16);
      p.poly([
        const Offset(362, 263),
        const Offset(443, 235),
        const Offset(443, 353),
        const Offset(362, 326),
      ], fill: tint);
      p.line(211, 385, 151, 456, width: 9);
      p.line(247, 385, 299, 456, width: 9);
      p.circle(140, 267, 15, fill: accent);
      p.marks(191, 271, 120, rows: 3);
    case 'candleGarland':
      p.path(
        Path()
          ..moveTo(38, 70)
          ..quadraticBezierTo(250, 190, 462, 70),
        color: accent,
      );
      for (var n = 0; n < 7; n++) {
        final x = 62 + n * 58.0, y = 87 + math.sin(n * math.pi / 6) * 48;
        p.poly(
          [Offset(x, y), Offset(x + 35, y + 7), Offset(x + 16, y + 47)],
          fill: n.isEven ? tint : paper,
          width: 2.5,
        );
      }
      p.rect(108, 331, 288, 93, fill: tint, radius: 14);
      p.line(108, 355, 396, 355, color: accent);
      for (final x in [164.0, 250.0, 336.0]) {
        p.rect(x - 13, 230, 26, 102, fill: paper, radius: 3);
        p.line(x - 8, 256, x + 8, 279, width: 2.5, color: accent);
        p.path(
          Path()
            ..moveTo(x, 215)
            ..cubicTo(x - 38, 181, x - 13, 172, x, 149)
            ..cubicTo(x + 34, 184, x + 28, 211, x, 215)
            ..close(),
          fill: accent.withValues(alpha: .4),
          width: 2.5,
        );
      }
    case 'marketRoutePin':
      p.poly([
        const Offset(55, 249),
        const Offset(181, 202),
        const Offset(315, 248),
        const Offset(445, 197),
        const Offset(445, 419),
        const Offset(315, 464),
        const Offset(181, 419),
        const Offset(55, 464),
      ], fill: tint);
      p.line(181, 211, 181, 410, width: 2);
      p.line(315, 255, 315, 454, width: 2);
      p.dash(86, 365, 166, 324, count: 7);
      p.dash(198, 328, 300, 378, count: 8);
      p.dash(333, 378, 416, 300, count: 7);
      p.path(
        Path()
          ..moveTo(327, 203)
          ..cubicTo(416, 76, 238, 21, 235, 135)
          ..cubicTo(235, 174, 284, 223, 287, 264)
          ..close(),
        fill: paper,
      );
      p.circle(292, 131, 31, fill: accent.withValues(alpha: .35));
    case 'pairedEnvelopes':
      for (final item in [
        const [209.0, 209.0, -.20],
        const [298.0, 322.0, .16],
      ]) {
        c.save();
        c.translate(item[0], item[1]);
        c.rotate(item[2]);
        p.rect(
          -144,
          -101,
          288,
          202,
          fill: item[1] < 250 ? tint : paper,
          radius: 5,
        );
        p.poly([
          const Offset(-144, -101),
          const Offset(0, 22),
          const Offset(144, -101),
        ], fill: paper);
        p.line(-144, 101, -37, -9, width: 3);
        p.line(144, 101, 37, -9, width: 3);
        p.circle(0, 20, 24, fill: accent.withValues(alpha: .32));
        c.restore();
      }
    case 'anniversaryDial':
      p.circle(250, 260, 164, fill: paper);
      p.circle(250, 260, 143, width: 2, color: accent);
      for (var n = 0; n < 24; n++) {
        final a = n * math.pi / 12;
        p.line(
          250 + math.cos(a) * 133,
          260 + math.sin(a) * 133,
          250 + math.cos(a) * (n.isEven ? 117 : 124),
          260 + math.sin(a) * (n.isEven ? 117 : 124),
          width: n.isEven ? 4 : 2,
        );
      }
      p.line(250, 260, 182, 177, width: 8, color: accent);
      p.line(250, 260, 348, 219, width: 6);
      p.circle(250, 260, 13, fill: accent);
      p.path(
        Path()
          ..moveTo(250, 61)
          ..cubicTo(209, 15, 171, 76, 250, 111)
          ..cubicTo(329, 76, 291, 15, 250, 61),
        fill: tint,
        width: 3,
      );
    case 'foldingRuler':
      final points = [
        const Offset(73, 344),
        const Offset(218, 150),
        const Offset(353, 330),
        const Offset(424, 103),
      ];
      for (var i = 0; i < 3; i++) {
        final a = points[i],
            b = points[i + 1],
            dx = b.dx - a.dx,
            dy = b.dy - a.dy,
            length = math.sqrt(dx * dx + dy * dy),
            nx = -dy / length,
            ny = dx / length;
        p.poly([
          a + Offset(nx * 21, ny * 21),
          b + Offset(nx * 21, ny * 21),
          b - Offset(nx * 21, ny * 21),
          a - Offset(nx * 21, ny * 21),
        ], fill: i.isEven ? paper : tint);
        for (var j = 1; j < 12; j++) {
          final t = j / 12;
          p.line(
            a.dx + dx * t,
            a.dy + dy * t,
            a.dx + dx * t + nx * (j.isEven ? 15 : 9),
            a.dy + dy * t + ny * (j.isEven ? 15 : 9),
            width: 2,
          );
        }
      }
      for (final point in points)
        p.circle(point.dx, point.dy, 10, fill: accent, width: 2);
    case 'twinSpoons':
      for (final data in [
        const [174.0, 146.0, -.12],
        const [331.0, 169.0, .15],
      ]) {
        c.save();
        c.translate(data[0], data[1]);
        c.rotate(data[2]);
        p.oval(-65, -87, 130, 174, fill: data[0] < 250 ? paper : tint);
        p.path(
          Path()
            ..moveTo(-17, 73)
            ..lineTo(-23, 265)
            ..quadraticBezierTo(0, 305, 23, 265)
            ..lineTo(17, 73)
            ..close(),
          fill: paper,
        );
        p.line(0, 98, 0, 261, width: 2, color: accent);
        c.restore();
      }
    case 'adoptionNameTag':
      p.circle(250, 100, 53, width: 8, color: accent);
      p.poly([
        const Offset(141, 178),
        const Offset(204, 143),
        const Offset(299, 143),
        const Offset(363, 178),
        const Offset(384, 376),
        const Offset(335, 426),
        const Offset(166, 426),
        const Offset(117, 376),
      ], fill: paper);
      p.circle(250, 179, 12, fill: tint, width: 3);
      p.oval(205, 296, 95, 71, fill: tint);
      for (final item in [
        const [186.0, 277.0],
        const [226.0, 250.0],
        const [273.0, 250.0],
        const [314.0, 277.0],
      ])
        p.oval(
          item[0] - 14,
          item[1] - 22,
          28,
          44,
          fill: accent.withValues(alpha: .4),
          width: 2,
        );
      p.line(174, 390, 327, 390, width: 2, color: accent);
    case 'softHarness':
      p.path(
        Path()
          ..moveTo(111, 125)
          ..lineTo(171, 99)
          ..lineTo(251, 245)
          ..lineTo(331, 99)
          ..lineTo(390, 125)
          ..lineTo(320, 303)
          ..lineTo(354, 406)
          ..lineTo(295, 430)
          ..lineTo(250, 337)
          ..lineTo(205, 430)
          ..lineTo(145, 406)
          ..lineTo(181, 303)
          ..close(),
        fill: tint,
      );
      p.oval(185, 217, 133, 155, fill: paper);
      p.rect(217, 263, 67, 52, fill: accent.withValues(alpha: .28));
      p.rect(234, 272, 32, 33, fill: paper, radius: 2);
      p.line(133, 142, 207, 283, width: 2);
      p.line(368, 142, 295, 283, width: 2);
    case 'rabbitHayBasket':
      p.oval(174, 64, 53, 191, fill: paper);
      p.oval(274, 54, 49, 200, fill: paper);
      p.oval(144, 180, 211, 176, fill: tint);
      p.circle(204, 250, 5, fill: ink);
      p.circle(295, 250, 5, fill: ink);
      p.poly([
        const Offset(237, 281),
        const Offset(263, 281),
        const Offset(250, 295),
      ], fill: accent);
      for (var n = 0; n < 8; n++)
        p.line(
          83 + n * 45,
          379,
          100 + n * 39,
          264 - (n % 3) * 24,
          width: 3,
          color: accent,
        );
      p.poly([
        const Offset(71, 328),
        const Offset(428, 328),
        const Offset(386, 445),
        const Offset(113, 445),
      ], fill: paper);
      for (var n = 0; n < 4; n++)
        p.line(103, 350 + n * 24, 397, 350 + n * 24, width: 2.5, color: accent);
    case 'shellLeash':
      p.path(
        Path()
          ..moveTo(222, 338)
          ..lineTo(71, 206)
          ..cubicTo(38, 92, 360, 57, 367, 201)
          ..lineTo(222, 338)
          ..close(),
        fill: tint,
      );
      for (var n = 0; n < 7; n++) {
        final a = (-160 + n * 23) * math.pi / 180;
        p.line(
          222,
          326,
          222 + math.cos(a) * 145,
          223 + math.sin(a) * 125,
          width: 3,
        );
      }
      p.path(
        Path()
          ..moveTo(239, 340)
          ..cubicTo(462, 460, 491, 148, 382, 244)
          ..cubicTo(326, 296, 421, 390, 440, 425),
        width: 10,
        color: accent,
      );
      p.rect(185, 325, 70, 42, fill: paper, radius: 10);
      p.oval(418, 410, 44, 55, width: 6);
    case 'raceMedal':
      p.poly([
        const Offset(113, 48),
        const Offset(193, 37),
        const Offset(286, 261),
        const Offset(223, 290),
      ], fill: tint);
      p.poly([
        const Offset(311, 37),
        const Offset(389, 48),
        const Offset(276, 290),
        const Offset(215, 261),
      ], fill: paper);
      p.circle(250, 337, 103, fill: accent.withValues(alpha: .24));
      p.circle(250, 337, 82, width: 2);
      p.circle(260, 289, 12, fill: ink);
      p.line(256, 307, 235, 347, width: 8);
      p.line(243, 330, 286, 344, width: 7);
      p.line(242, 345, 202, 391, width: 7);
      p.line(242, 345, 277, 392, width: 7);
      p.line(246, 314, 214, 310, width: 6);
    case 'yogaBlock':
      p.poly([
        const Offset(80, 247),
        const Offset(313, 144),
        const Offset(426, 252),
        const Offset(189, 356),
      ], fill: tint);
      p.poly([
        const Offset(80, 247),
        const Offset(189, 356),
        const Offset(189, 413),
        const Offset(80, 304),
      ], fill: paper);
      p.poly([
        const Offset(189, 356),
        const Offset(426, 252),
        const Offset(426, 311),
        const Offset(189, 413),
      ], fill: accent.withValues(alpha: .22));
      p.line(110, 283, 167, 340, width: 2);
      p.oval(273, 73, 49, 87, fill: paper);
      p.leaf(286, 145, -2.7, length: 68, breadth: 22);
      p.leaf(291, 146, -.4, length: 68, breadth: 22);
    case 'barbellPlate':
      p.rect(36, 227, 428, 52, fill: paper, radius: 8);
      final plate = Path()..addOval(const Rect.fromLTWH(105, 87, 290, 326));
      final holes = Path()..addOval(const Rect.fromLTWH(224, 217, 52, 65));
      for (var n = 0; n < 3; n++) {
        final a = n * math.pi * 2 / 3;
        holes.addOval(
          Rect.fromCenter(
            center: Offset(250 + math.cos(a) * 98, 250 + math.sin(a) * 104),
            width: 43,
            height: 64,
          ),
        );
      }
      p.path(Path.combine(PathOperation.difference, plate, holes), fill: tint);
      p.oval(125, 108, 250, 284, width: 2, color: accent);
      p.line(54, 233, 54, 272, width: 2);
      p.line(448, 233, 448, 272, width: 2);
    case 'surfFin':
      p.path(
        Path()
          ..moveTo(80, 409)
          ..cubicTo(197, 362, 220, 141, 333, 54)
          ..cubicTo(286, 215, 422, 274, 418, 409)
          ..close(),
        fill: tint,
      );
      p.path(
        Path()
          ..moveTo(135, 393)
          ..cubicTo(238, 289, 241, 187, 295, 110),
        width: 3,
        color: accent,
      );
      p.path(
        Path()
          ..moveTo(52, 449)
          ..quadraticBezierTo(134, 405, 215, 449)
          ..quadraticBezierTo(295, 489, 449, 436),
        width: 5,
        color: accent,
      );
    case 'thesisBinding':
      p.rect(96, 77, 300, 341, fill: paper, radius: 3);
      p.rect(119, 66, 286, 336, fill: tint, radius: 3);
      p.line(159, 72, 159, 397, width: 5, color: accent);
      for (var n = 0; n < 11; n++)
        p.oval(104, 84 + n * 27, 37, 15, fill: paper, width: 3);
      p.rect(194, 115, 172, 75, fill: paper, radius: 2);
      p.marks(210, 135, 130, rows: 3);
      p.line(198, 335, 361, 335, width: 2);
      p.line(198, 353, 314, 353, width: 2);
      p.poly(
        [const Offset(359, 66), const Offset(405, 112), const Offset(359, 112)],
        fill: paper,
        width: 2,
      );
    case 'luggageCompass':
      p.rect(74, 183, 285, 263, fill: tint, radius: 27);
      p.path(
        Path()
          ..moveTo(144, 183)
          ..lineTo(144, 131)
          ..quadraticBezierTo(215, 107, 287, 131)
          ..lineTo(287, 183),
        width: 12,
      );
      p.line(118, 194, 118, 437, width: 3);
      p.line(315, 194, 315, 437, width: 3);
      p.circle(129, 451, 15, fill: paper);
      p.circle(310, 451, 15, fill: paper);
      p.circle(363, 162, 79, fill: paper);
      p.ray(363, 162, 61, 8, inner: 53, width: 2);
      p.poly([
        const Offset(363, 101),
        const Offset(382, 162),
        const Offset(363, 223),
        const Offset(344, 162),
      ], fill: accent.withValues(alpha: .35));
    case 'uniformRibbon':
      p.poly([
        const Offset(246, 212),
        const Offset(92, 102),
        const Offset(67, 247),
        const Offset(239, 264),
      ], fill: tint);
      p.poly([
        const Offset(254, 212),
        const Offset(408, 102),
        const Offset(433, 247),
        const Offset(261, 264),
      ], fill: paper);
      p.poly([
        const Offset(218, 245),
        const Offset(279, 245),
        const Offset(238, 443),
        const Offset(185, 403),
      ], fill: paper);
      p.poly([
        const Offset(221, 245),
        const Offset(282, 245),
        const Offset(318, 403),
        const Offset(265, 443),
      ], fill: tint);
      p.rect(218, 206, 65, 71, fill: accent.withValues(alpha: .35), radius: 15);
      p.line(93, 137, 224, 231, width: 2);
      p.line(408, 137, 278, 231, width: 2);
    case 'embossSeal':
      p.rect(90, 365, 335, 63, fill: tint, radius: 18);
      p.path(
        Path()
          ..moveTo(145, 364)
          ..lineTo(192, 229)
          ..cubicTo(209, 186, 252, 153, 301, 154)
          ..lineTo(387, 154)
          ..lineTo(387, 205)
          ..lineTo(297, 205)
          ..quadraticBezierTo(271, 227, 263, 278)
          ..lineTo(244, 365)
          ..close(),
        fill: paper,
      );
      p.oval(230, 265, 118, 43, fill: accent.withValues(alpha: .3));
      p.line(289, 207, 289, 268, width: 13);
      p.circle(123, 191, 57, fill: paper);
      p.circle(123, 191, 43, width: 2);
      p.leaf(96, 210, -.8, length: 55, breadth: 14);
    case 'choirScore':
      p.path(
        Path()
          ..moveTo(64, 91)
          ..quadraticBezierTo(154, 64, 250, 104)
          ..quadraticBezierTo(346, 64, 436, 91)
          ..lineTo(436, 407)
          ..quadraticBezierTo(346, 380, 250, 420)
          ..quadraticBezierTo(154, 380, 64, 407)
          ..close(),
        fill: paper,
      );
      p.line(250, 107, 250, 418, width: 3);
      for (var n = 0; n < 5; n++) {
        p.line(88, 156 + n * 18, 224, 156 + n * 18, width: 2);
        p.line(276, 156 + n * 18, 411, 156 + n * 18, width: 2);
      }
      for (final data in [
        const [118.0, 210.0],
        const [181.0, 192.0],
        const [308.0, 228.0],
        const [372.0, 174.0],
      ]) {
        p.oval(data[0] - 10, data[1] - 5, 24, 14, fill: ink, width: 2);
        p.line(data[0] + 12, data[1], data[0] + 12, data[1] - 58, width: 3);
      }
      p.line(327, 48, 455, 106, width: 8, color: accent);
      p.line(90, 335, 217, 335, width: 2);
      p.line(278, 335, 410, 335, width: 2);
    case 'woodenGameTiles':
      for (final data in [
        const [92.0, 177.0, -.15],
        const [250.0, 101.0, .10],
        const [283.0, 309.0, -.12],
      ]) {
        c.save();
        c.translate(data[0], data[1]);
        c.rotate(data[2]);
        p.rect(-50, -51, 115, 119, fill: tint, radius: 11);
        if (data[1] < 150) {
          p.poly([
            const Offset(8, -24),
            const Offset(34, 16),
            const Offset(8, 47),
            const Offset(-19, 16),
          ], fill: paper);
        } else if (data[1] < 250) {
          p.circle(8, -5, 18, fill: paper);
          p.path(
            Path()
              ..moveTo(-21, 43)
              ..quadraticBezierTo(8, 3, 37, 43)
              ..close(),
            fill: paper,
          );
        } else {
          p.ray(8, 8, 36, 5, inner: 12, phase: -math.pi / 2, color: accent);
        }
        c.restore();
      }
      p.rect(78, 337, 112, 98, fill: paper, radius: 15);
      for (final xy in [
        const Offset(104, 360),
        const Offset(164, 360),
        const Offset(134, 386),
        const Offset(104, 412),
        const Offset(164, 412),
      ])
        p.circle(xy.dx, xy.dy, 6, fill: ink, width: 2);
    case 'potluckCarrier':
      p.path(
        Path()
          ..moveTo(65, 288)
          ..quadraticBezierTo(250, 134, 435, 288)
          ..lineTo(391, 432)
          ..quadraticBezierTo(250, 466, 109, 432)
          ..close(),
        fill: tint,
      );
      p.oval(95, 220, 309, 104, fill: paper);
      p.oval(116, 239, 100, 55, fill: accent.withValues(alpha: .25));
      p.oval(246, 230, 118, 63, fill: tint);
      p.path(
        Path()
          ..moveTo(250, 211)
          ..cubicTo(117, 59, 133, 253, 248, 235)
          ..cubicTo(362, 251, 378, 70, 250, 211),
        fill: paper,
      );
      p.line(111, 420, 249, 274, width: 2);
      p.line(391, 420, 261, 274, width: 2);
    case 'repairToolRoll':
      p.rect(84, 185, 341, 249, fill: tint, radius: 10);
      p.rect(100, 319, 309, 96, fill: paper, radius: 3);
      p.line(169, 327, 169, 406, width: 3);
      p.line(245, 327, 245, 406, width: 3);
      p.line(326, 327, 326, 406, width: 3);
      p.path(
        Path()
          ..moveTo(121, 329)
          ..lineTo(128, 169)
          ..cubicTo(78, 119, 111, 63, 137, 69)
          ..lineTo(132, 112)
          ..lineTo(160, 121)
          ..lineTo(182, 86)
          ..cubicTo(207, 113, 193, 151, 158, 171)
          ..lineTo(152, 329)
          ..close(),
        fill: paper,
      );
      p.rect(224, 80, 36, 113, fill: accent.withValues(alpha: .4), radius: 14);
      p.line(242, 194, 242, 324, width: 11);
      p.path(
        Path()
          ..moveTo(324, 326)
          ..lineTo(338, 206)
          ..lineTo(311, 137)
          ..lineTo(332, 106)
          ..lineTo(350, 164)
          ..lineTo(369, 103)
          ..lineTo(391, 132)
          ..lineTo(365, 209)
          ..lineTo(353, 326),
        fill: paper,
      );
      p.line(109, 211, 399, 211, width: 2);
      p.rect(76, 277, 21, 80, fill: paper, radius: 3);
      p.rect(413, 277, 21, 80, fill: paper, radius: 3);
    case 'watercolorTin':
      p.rect(65, 138, 365, 272, fill: paper, radius: 25);
      p.rect(75, 60, 345, 87, fill: tint, radius: 16);
      for (var row = 0; row < 2; row++)
        for (var col = 0; col < 5; col++) {
          final color = Color.lerp(accent, tint, (row * 5 + col) / 11)!;
          p.rect(
            89 + col * 63,
            170 + row * 97,
            50,
            72,
            fill: color,
            radius: 8,
            width: 2,
          );
        }
      p.path(
        Path()
          ..moveTo(206, 449)
          ..lineTo(382, 99)
          ..lineTo(395, 104)
          ..lineTo(222, 457)
          ..close(),
        fill: tint,
        width: 3,
      );
      p.path(
        Path()
          ..moveTo(381, 99)
          ..quadraticBezierTo(395, 50, 414, 49)
          ..quadraticBezierTo(411, 90, 395, 105)
          ..close(),
        fill: accent,
      );
    case 'joinerySquare':
      p.poly([
        const Offset(82, 72),
        const Offset(174, 72),
        const Offset(174, 330),
        const Offset(429, 330),
        const Offset(429, 424),
        const Offset(82, 424),
      ], fill: tint);
      p.line(102, 91, 102, 404, width: 2);
      p.line(124, 91, 124, 404, width: 2);
      p.line(184, 359, 408, 359, width: 2);
      for (var n = 0; n < 12; n++)
        p.line(
          151,
          91 + n * 26,
          169 - (n.isEven ? 11 : 4),
          91 + n * 26,
          width: 2,
        );
      for (var n = 0; n < 10; n++)
        p.line(
          190 + n * 23,
          333,
          190 + n * 23,
          350 + (n.isEven ? 9 : 0),
          width: 2,
        );
      p.poly(
        [
          const Offset(226, 77),
          const Offset(241, 65),
          const Offset(424, 275),
          const Offset(409, 286),
        ],
        fill: paper,
        width: 3,
      );
      p.poly(
        [
          const Offset(409, 286),
          const Offset(424, 275),
          const Offset(435, 304),
        ],
        fill: accent,
        width: 2,
      );
    case 'embroideryHoop':
      p.circle(250, 279, 153, fill: paper, width: 9, color: accent);
      p.circle(250, 279, 136, width: 2);
      p.rect(223, 80, 54, 49, fill: tint, radius: 4);
      p.line(204, 92, 296, 92, width: 8);
      p.circle(205, 92, 8, fill: paper);
      p.circle(295, 92, 8, fill: paper);
      for (var n = 0; n < 6; n++) {
        final a = n * math.pi / 3;
        p.leaf(250, 263, a, length: 75, breadth: 25, fill: tint);
      }
      p.circle(250, 263, 22, fill: accent.withValues(alpha: .4));
      p.line(250, 288, 250, 365, width: 4, color: accent);
      p.leaf(250, 338, -.5, length: 58, breadth: 17);
      p.path(
        Path()
          ..moveTo(351, 347)
          ..cubicTo(465, 346, 408, 441, 462, 445),
        width: 3,
        color: accent,
      );
    case 'recordSleeve':
      p.rect(58, 76, 326, 339, fill: paper, radius: 3);
      p.circle(250, 239, 96, fill: tint, width: 2);
      p.circle(337, 275, 131, fill: ink);
      for (final radius in [111.0, 98.0, 83.0, 68.0])
        p.circle(
          337,
          275,
          radius,
          width: 2,
          color: paper.withValues(alpha: .4),
        );
      p.circle(337, 275, 40, fill: accent);
      p.circle(337, 275, 8, fill: paper, width: 2);
      p.line(83, 113, 273, 113, width: 7, color: accent);
      p.line(83, 129, 224, 129, width: 2);
      p.marks(83, 359, 105, rows: 2);
    default:
      // Unknown objects deliberately render nothing rather than a generic badge.
      return;
  }
}
