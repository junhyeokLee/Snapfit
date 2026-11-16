import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/templates/premium_quartet_frame_catalog.dart';

/// Sixteen stocks surround one uncut, replaceable rectangular picture window.
/// No bitmap, blur layer, animation or persistent image cache is allocated.
class PremiumQuartetFrame extends StatelessWidget {
  const PremiumQuartetFrame({
    super.key,
    required this.style,
    required this.child,
  });
  final String style;
  final Widget child;

  /// The store's landscape sample remains whole inside the asymmetric stock.
  static double previewAspectRatio(String style) {
    final padding = insets(style, const Size(1, 1));
    return 1.5 * (1 - padding.vertical) + padding.horizontal;
  }

  static EdgeInsets insets(String style, Size size) {
    final frame = premiumQuartetFramesById[style];
    if (frame == null) return EdgeInsets.zero;
    final u = math.min(size.width, size.height);
    final values = switch (frame.kind % 16) {
      0 => const [0.07, 0.065, 0.09, 0.12],
      1 => const [0.11, 0.07, 0.06, 0.10],
      2 => const [0.14, 0.06, 0.055, 0.075],
      3 => const [0.075, 0.105, 0.08, 0.06],
      4 => const [0.06, 0.06, 0.06, 0.09],
      5 => const [0.09, 0.075, 0.09, 0.13],
      6 => const [0.055, 0.055, 0.055, 0.16],
      7 => const [0.16, 0.06, 0.055, 0.09],
      8 => const [0.12, 0.08, 0.06, 0.12],
      9 => const [0.055, 0.13, 0.055, 0.12],
      10 => const [0.08, 0.085, 0.08, 0.115],
      11 => const [0.075, 0.075, 0.075, 0.11],
      12 => const [0.11, 0.06, 0.06, 0.11],
      13 => const [0.075, 0.065, 0.065, 0.14],
      14 => const [0.06, 0.06, 0.06, 0.20],
      _ => const [0.08, 0.065, 0.085, 0.14],
    };
    final shift = (frame.variant % 3) * .002;
    return EdgeInsets.fromLTRB(
      u * (values[0] + shift),
      u * values[1],
      u * values[2],
      u * (values[3] + shift),
    );
  }

  static Path outer(String style, Size size) {
    final spec = premiumQuartetFramesById[style];
    final rect = Offset.zero & size;
    if (size.isEmpty || !size.isFinite) return Path();
    if (spec == null) return Path()..addRect(rect);
    final w = size.width,
        h = size.height,
        u = math.min(size.width, size.height);
    Path polygon(List<Offset> points) => Path()..addPolygon(points, true);
    Path chamfer(double c) => polygon([
      Offset(c, 0),
      Offset(w - c, 0),
      Offset(w, c),
      Offset(w, h - c),
      Offset(w - c, h),
      Offset(c, h),
      Offset(0, h - c),
      Offset(0, c),
    ]);
    switch (spec.kind % 16) {
      case 0:
        return Path()
          ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(u * .014)));
      case 1:
        return polygon([
          Offset(u * .025, 0),
          Offset(w, 0),
          Offset(w, h - u * .05),
          Offset(w - u * .05, h),
          Offset(0, h),
          Offset(0, u * .025),
        ]);
      case 2:
        final body = Path()
          ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(u * .018)));
        final y = h * (.30 + (spec.variant % 3) * .16);
        final bites = Path()
          ..addOval(Rect.fromCircle(center: Offset(0, y), radius: u * .026))
          ..addOval(Rect.fromCircle(center: Offset(w, y), radius: u * .026));
        return Path.combine(PathOperation.difference, body, bites);
      case 3:
        final tab = .28 + (spec.variant % 3) * .13;
        return polygon([
          Offset(0, u * .035),
          Offset(w * tab, u * .035),
          Offset(w * tab + u * .025, 0),
          Offset(w * tab + u * .17, 0),
          Offset(w * tab + u * .195, u * .035),
          Offset(w, u * .035),
          Offset(w, h),
          Offset(0, h),
        ]);
      case 4:
        final p = Path()..moveTo(0, u * .009);
        for (var n = 0; n <= 20; n++) {
          p.lineTo(w * n / 20, u * ((n + spec.variant).isEven ? .006 : .014));
        }
        p.lineTo(w, h - u * .01);
        for (var n = 20; n >= 0; n--) {
          p.lineTo(
            w * n / 20,
            h - u * ((n + spec.variant).isEven ? .006 : .015),
          );
        }
        return p..close();
      case 5:
        final count = 10 + (spec.variant % 3) * 2;
        final p = Path()..moveTo(u * .016, u * .016);
        for (var n = 0; n < count; n++) {
          p.quadraticBezierTo(
            w * (n + .5) / count,
            0,
            w * (n + 1) / count - (n == count - 1 ? u * .016 : 0),
            u * .016,
          );
        }
        p.lineTo(w - u * .016, h - u * .016);
        for (var n = count - 1; n >= 0; n--) {
          p.quadraticBezierTo(
            w * (n + .5) / count,
            h,
            w * n / count + (n == 0 ? u * .016 : 0),
            h - u * .016,
          );
        }
        return p..close();
      case 6:
        return polygon([
          Offset.zero,
          Offset(w, 0),
          Offset(w, h - u * .045),
          Offset(w - u * .045, h),
          Offset(u * .045, h),
          Offset(0, h - u * .045),
        ]);
      case 7:
        return polygon([
          Offset(u * .035, 0),
          Offset(w, 0),
          Offset(w, h),
          Offset(u * .035, h),
          Offset(0, h - u * .04),
          Offset(0, u * .04),
        ]);
      case 8:
        final body = chamfer(u * .04);
        final holes = Path();
        for (final t in [.20, .50, .80]) {
          holes.addOval(
            Rect.fromCircle(center: Offset(u * .035, h * t), radius: u * .009),
          );
        }
        return Path.combine(PathOperation.difference, body, holes);
      case 9:
        return polygon([
          Offset.zero,
          Offset(w, 0),
          Offset(w, h - u * .035),
          Offset(w - u * .035, h),
          Offset(0, h),
        ]);
      case 10:
        return polygon([
          Offset(u * .02, 0),
          Offset(w - u * .02, 0),
          Offset(w, u * .02),
          Offset(w, h - u * .02),
          Offset(w - u * .02, h),
          Offset(u * .02, h),
          Offset(0, h - u * .02),
          Offset(0, u * .02),
        ]);
      case 11:
        return chamfer(u * .045);
      case 12:
        return polygon([
          Offset(0, u * .035),
          Offset(w - u * .05, u * .035),
          Offset(w, u * .085),
          Offset(w, h),
          Offset(u * .025, h),
          Offset(0, h - u * .025),
        ]);
      case 13:
        return Path()
          ..moveTo(u * .02, u * .012)
          ..cubicTo(w * .30, 0, w * .70, u * .024, w - u * .025, u * .008)
          ..quadraticBezierTo(w, u * .015, w - u * .008, u * .045)
          ..cubicTo(
            w,
            h * .42,
            w - u * .022,
            h * .73,
            w - u * .011,
            h - u * .035,
          )
          ..quadraticBezierTo(w - u * .018, h, w - u * .05, h - u * .008)
          ..cubicTo(w * .65, h - u * .02, w * .30, h, u * .032, h - u * .012)
          ..quadraticBezierTo(0, h - u * .018, u * .008, h - u * .05)
          ..cubicTo(u * .02, h * .66, 0, h * .30, u * .009, u * .035)
          ..quadraticBezierTo(0, u * .01, u * .02, u * .012)
          ..close();
      case 14:
        return polygon([
          Offset.zero,
          Offset(w * .42, 0),
          Offset(w * .5, u * .025),
          Offset(w * .58, 0),
          Offset(w, 0),
          Offset(w, h),
          Offset(0, h),
        ]);
      default:
        return polygon([
          Offset(u * .03, 0),
          Offset(w, 0),
          Offset(w, h - u * .06),
          Offset(w - u * .06, h),
          Offset(0, h),
          Offset(0, u * .03),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, bounds) {
      final spec = premiumQuartetFramesById[style];
      final size = bounds.biggest;
      if (spec == null || !size.isFinite || size.isEmpty) return child;
      return ClipPath(
        clipper: _PremiumQuartetClipper(style),
        child: CustomPaint(
          painter: _PremiumQuartetFramePainter(spec),
          child: Padding(
            padding: insets(style, size),
            child: ClipRect(child: SizedBox.expand(child: child)),
          ),
        ),
      );
    },
  );
}

class _PremiumQuartetClipper extends CustomClipper<Path> {
  const _PremiumQuartetClipper(this.style);
  final String style;
  @override
  Path getClip(Size size) => PremiumQuartetFrame.outer(style, size);
  @override
  bool shouldReclip(_PremiumQuartetClipper old) => old.style != style;
}

class _PremiumQuartetFramePainter extends CustomPainter {
  const _PremiumQuartetFramePainter(this.spec);
  final PremiumQuartetFrameSpec spec;
  @override
  void paint(Canvas canvas, Size size) {
    final u = math.min(size.width, size.height),
        w = size.width,
        h = size.height;
    if (u <= 0) return;
    Color color(String hex) =>
        Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    final ink = color(spec.ink),
        tint = color(spec.tint),
        accent = color(spec.accent);
    final stock = spec.kind == 9
        ? ink
        : Color.lerp(const Color(0xFFFFFBF2), tint, .64)!;
    final stroke = Paint()
      ..color = accent.withValues(alpha: .76)
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * .0026
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void line(double x, double y, double xx, double yy, {Paint? paint}) =>
        canvas.drawLine(Offset(x, y), Offset(xx, yy), paint ?? stroke);
    final outer = PremiumQuartetFrame.outer(spec.id, size);
    canvas.drawPath(outer, Paint()..color = stock);
    canvas.drawPath(
      outer,
      Paint()
        ..color = ink.withValues(alpha: .18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * .002,
    );
    final aperture = PremiumQuartetFrame.insets(
      spec.id,
      size,
    ).deflateRect(Offset.zero & size);
    canvas.drawRect(
      aperture.inflate(u * .008),
      Paint()..color = ink.withValues(alpha: .20),
    );
    // All decorative marks are clipped away from the entire photo window.
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRect(aperture),
    );
    canvas.save();
    canvas.clipPath(outside);
    switch (spec.kind % 16) {
      case 0:
        canvas.drawRect(aperture.inflate(u * .025), stroke);
        for (var n = 0; n < 4; n++)
          line(
            u * .016,
            h * (n + 1) / 5,
            aperture.left - u * .018,
            h * (n + 1) / 5,
          );
      case 1:
        for (var n = 1; n < 28; n++) {
          final y = h * n / 28;
          line(u * .025, y - u * .006, u * .075, y + u * .006);
        }
        line(u * .09, u * .03, u * .09, h - u * .03);
        for (var n = 1; n < 14; n++)
          line(w - u * .04, h * n / 14, w - u * .018, h * n / 14 + u * .01);
      case 2:
        line(u * .105, 0, u * .105, h);
        for (var n = 1; n < 17; n++) {
          canvas.drawCircle(
            Offset(u * .075, h * n / 17),
            u * .003,
            Paint()..color = ink.withValues(alpha: .55),
          );
        }
        for (var n = 0; n < 5; n++)
          line(
            w * .28 + n * u * .025,
            h - u * .032,
            w * .28 + n * u * .025,
            h - u * (.045 + (n.isEven ? .015 : 0)),
          );
      case 3:
        canvas.drawRect(
          Rect.fromLTWH(
            w * (.28 + spec.variant % 3 * .13),
            0,
            u * .19,
            u * .045,
          ),
          Paint()..color = accent.withValues(alpha: .5),
        );
        for (var n = 0; n < 3; n++)
          line(
            w * .34,
            u * (.067 + n * .007),
            w * .64 - n * u * .02,
            u * (.067 + n * .007),
          );
      case 4:
        for (var n = 0; n < 30; n++) {
          final x = w * (n + .5) / 30;
          line(
            x,
            h - u * .054,
            x + u * .008,
            h - u * .03,
            paint: Paint()
              ..color = ink.withValues(alpha: .14)
              ..strokeWidth = u * .0013,
          );
        }
        line(u * .07, h - u * .067, w - u * .07, h - u * .067);
      case 5:
        for (var n = 0; n < 22; n++) {
          final x = w * (n + .5) / 22;
          line(x - u * .005, u * .03, x + u * .005, u * .04);
          line(x - u * .005, h - u * .05, x + u * .005, h - u * .04);
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            aperture.inflate(u * .017),
            Radius.circular(u * .014),
          ),
          stroke,
        );
      case 6:
        for (final origin in [
          Offset(aperture.left, aperture.top),
          Offset(aperture.right, aperture.top),
          Offset(aperture.left, aperture.bottom),
          Offset(aperture.right, aperture.bottom),
        ]) {
          final left = origin.dx < w / 2, top = origin.dy < h / 2;
          final x = origin.dx, y = origin.dy;
          final p = Path()
            ..moveTo(x + (left ? -u : u) * .024, y + (top ? u : -u) * .045)
            ..lineTo(x + (left ? -u : u) * .024, y + (top ? -u : u) * .024)
            ..lineTo(x + (left ? u : -u) * .045, y + (top ? -u : u) * .024)
            ..close();
          canvas.drawPath(p, Paint()..color = accent.withValues(alpha: .55));
        }
        line(w * .23, h - u * .08, w * .77, h - u * .08);
      case 7:
        canvas.drawRect(
          Rect.fromLTWH(u * .02, 0, u * .07, h),
          Paint()..color = accent.withValues(alpha: .22),
        );
        line(u * .11, u * .025, u * .11, h - u * .025);
        for (var n = 1; n < 8; n++) {
          final y = h * n / 8;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(u * .065, y),
              width: u * .05,
              height: u * .015,
            ),
            stroke,
          );
        }
      case 8:
        for (final t in [.20, .50, .80]) {
          canvas.drawCircle(Offset(u * .035, h * t), u * .015, stroke);
        }
        for (var n = 1; n < 11; n++)
          line(u * .014, h * n / 11, u * .095, h * n / 11);
        for (var n = 1; n < 6; n++)
          line(w * n / 6, h - u * .09, w * n / 6 + u * .03, h - u * .025);
      case 9:
        final count = 8 + spec.variant % 4;
        for (var n = 0; n < count; n++) {
          final x = w * (n + .5) / count;
          for (final y in [u * .055, h - u * .055]) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(
                  center: Offset(x, y),
                  width: u * .045,
                  height: u * .03,
                ),
                Radius.circular(u * .004),
              ),
              Paint()..color = tint,
            );
          }
        }
        line(u * .06, h - u * .10, w - u * .06, h - u * .10);
      case 10:
        canvas.drawRect(
          Rect.fromLTWH(w * .68, 0, u * .055, h),
          Paint()..color = accent.withValues(alpha: .25),
        );
        final x = w * .68 + u * .027;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x, h - u * .055),
            width: u * .12,
            height: u * .045,
          ),
          stroke,
        );
        line(x, h - u * .03, x - u * .04, h - u * .005);
        line(x, h - u * .03, x + u * .04, h - u * .005);
      case 11:
        for (final point in [
          Offset(u * .03, u * .03),
          Offset(w - u * .03, u * .03),
          Offset(u * .03, h - u * .03),
          Offset(w - u * .03, h - u * .03),
        ]) {
          line(point.dx - u * .015, point.dy, point.dx + u * .015, point.dy);
          line(point.dx, point.dy - u * .015, point.dx, point.dy + u * .015);
        }
        canvas.drawRect(aperture.inflate(u * .014), stroke);
      case 12:
        canvas.drawRect(
          Rect.fromLTWH(0, u * .035, u * .07, h - u * .07),
          Paint()..color = accent.withValues(alpha: .18),
        );
        line(u * .085, u * .055, u * .085, h - u * .055);
        final p = Path()
          ..moveTo(w - u * .05, u * .035)
          ..lineTo(w - u * .05, u * .085)
          ..lineTo(w, u * .085)
          ..close();
        canvas.drawPath(p, Paint()..color = accent.withValues(alpha: .3));
      case 13:
        for (var n = 0; n < 4; n++) {
          final p = Path()
            ..moveTo(w * .16, h - u * (.045 + n * .014))
            ..cubicTo(
              w * .35,
              h - u * (.09 + n * .006),
              w * .65,
              h - u * (.02 + n * .016),
              w * .86,
              h - u * (.055 + n * .014),
            );
          canvas.drawPath(p, stroke);
        }
      case 14:
        final p = Path()
          ..moveTo(0, h - u * .13)
          ..lineTo(w * .5, h - u * .025)
          ..lineTo(w, h - u * .13);
        canvas.drawPath(p, stroke);
        line(0, h - u * .15, w, h - u * .15);
        canvas.drawCircle(
          Offset(w * .5, h - u * .065),
          u * .015,
          Paint()..color = accent.withValues(alpha: .5),
        );
      default:
        for (var n = 0; n < 4; n++)
          line(
            w * .20,
            h - u * (.04 + n * .012),
            w * (.80 - n * .07),
            h - u * (.04 + n * .012),
          );
        for (var n = 0; n < 5; n++)
          line(
            w - u * .035,
            h * (.22 + n * .11),
            w - u * .015,
            h * (.22 + n * .11),
          );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PremiumQuartetFramePainter old) => old.spec != spec;
}
