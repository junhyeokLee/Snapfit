import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Nine lightweight, book-specific mounts. Their print stock and markings are
/// clipped away from a single rectangular picture aperture. No image, texture,
/// animation, blur layer or per-frame cache is allocated by this renderer.
class DiversityPhotoFrame extends StatelessWidget {
  const DiversityPhotoFrame({
    super.key,
    required this.style,
    required this.child,
  });

  final String style;
  final Widget child;

  static EdgeInsets insets(String style, Size size) {
    final u = math.min(size.width, size.height);
    final factors = switch (style) {
      'clayContour' => const EdgeInsets.fromLTRB(.065, .065, .075, .12),
      'leafHerbarium' => const EdgeInsets.fromLTRB(.085, .10, .065, .115),
      'filmContactRail' => const EdgeInsets.fromLTRB(.13, .045, .045, .17),
      'bakeRecipe' => const EdgeInsets.fromLTRB(.065, .055, .065, .165),
      'knitStitch' => const EdgeInsets.fromLTRB(.10, .075, .075, .135),
      'musicSleeve' => const EdgeInsets.fromLTRB(.075, .055, .14, .14),
      'paperNotch' => const EdgeInsets.fromLTRB(.055, .105, .105, .12),
      'galleryRegistration' => const EdgeInsets.fromLTRB(.10, .10, .10, .16),
      'campMap' => const EdgeInsets.fromLTRB(.135, .06, .065, .145),
      _ => EdgeInsets.zero,
    };
    return EdgeInsets.fromLTRB(
      factors.left * u,
      factors.top * u,
      factors.right * u,
      factors.bottom * u,
    );
  }

  static Path outer(String style, Size size) {
    final u = math.min(size.width, size.height);
    final w = size.width, h = size.height;
    if (u <= 0) return Path();
    switch (style) {
      case 'clayContour':
        return Path()
          ..moveTo(u * .025, u * .006)
          ..cubicTo(w * .30, u * .018, w * .68, 0, w - u * .024, u * .012)
          ..quadraticBezierTo(w, u * .018, w - u * .005, u * .052)
          ..cubicTo(
            w - u * .018,
            h * .37,
            w - u * .001,
            h * .67,
            w - u * .014,
            h - u * .032,
          )
          ..quadraticBezierTo(w - u * .017, h, w - u * .05, h - u * .007)
          ..cubicTo(w * .64, h - u * .018, w * .30, h, u * .032, h - u * .012)
          ..quadraticBezierTo(0, h - u * .014, u * .008, h - u * .05)
          ..cubicTo(u * .019, h * .66, u * .001, h * .32, u * .009, u * .035)
          ..quadraticBezierTo(u * .01, 0, u * .025, u * .006)
          ..close();
      case 'leafHerbarium':
        return Path()
          ..moveTo(u * .035, 0)
          ..lineTo(w - u * .025, 0)
          ..lineTo(w, u * .025)
          ..lineTo(w, h - u * .055)
          ..lineTo(w - u * .055, h)
          ..lineTo(u * .015, h)
          ..lineTo(0, h - u * .015)
          ..lineTo(0, u * .035)
          ..close();
      case 'filmContactRail':
        return Path()
          ..moveTo(0, 0)
          ..lineTo(w, 0)
          ..lineTo(w, h - u * .055)
          ..lineTo(w - u * .055, h)
          ..lineTo(0, h)
          ..close();
      case 'bakeRecipe':
        final path = Path()
          ..moveTo(0, u * .018)
          ..quadraticBezierTo(0, 0, u * .018, 0)
          ..lineTo(w - u * .018, 0)
          ..quadraticBezierTo(w, 0, w, u * .018)
          ..lineTo(w, h - u * .025);
        for (var i = 11; i >= 0; i--) {
          final right = w * (i + 1) / 12, left = w * i / 12;
          path.quadraticBezierTo((left + right) / 2, h, left, h - u * .025);
        }
        return path..close();
      case 'knitStitch':
        final path = Path()..moveTo(u * .018, u * .018);
        for (var i = 0; i < 12; i++) {
          path.quadraticBezierTo(
            w * (i + .5) / 12,
            0,
            w * (i + 1) / 12 - (i == 11 ? u * .018 : 0),
            u * .018,
          );
        }
        for (var i = 0; i < 8; i++) {
          path.quadraticBezierTo(
            w,
            h * (i + .5) / 8,
            w - u * .018,
            h * (i + 1) / 8 - (i == 7 ? u * .018 : 0),
          );
        }
        for (var i = 11; i >= 0; i--) {
          path.quadraticBezierTo(
            w * (i + .5) / 12,
            h,
            w * i / 12 + (i == 0 ? u * .018 : 0),
            h - u * .018,
          );
        }
        for (var i = 7; i >= 0; i--) {
          path.quadraticBezierTo(
            0,
            h * (i + .5) / 8,
            u * .018,
            h * i / 8 + (i == 0 ? u * .018 : 0),
          );
        }
        return path..close();
      case 'musicSleeve':
        return Path.combine(
          PathOperation.difference,
          Path()..addRect(Offset.zero & size),
          Path()..addOval(
            Rect.fromCircle(center: Offset(w, h * .43), radius: u * .045),
          ),
        );
      case 'paperNotch':
        return Path()
          ..moveTo(0, 0)
          ..lineTo(w - u * .09, 0)
          ..lineTo(w, u * .09)
          ..lineTo(w, h)
          ..lineTo(u * .04, h)
          ..lineTo(0, h - u * .04)
          ..close();
      case 'galleryRegistration':
        final cut = u * .024;
        return Path()
          ..moveTo(cut, 0)
          ..lineTo(w - cut, 0)
          ..lineTo(w, cut)
          ..lineTo(w, h - cut)
          ..lineTo(w - cut, h)
          ..lineTo(cut, h)
          ..lineTo(0, h - cut)
          ..lineTo(0, cut)
          ..close();
      case 'campMap':
        final paper = Path()
          ..moveTo(u * .02, 0)
          ..lineTo(w - u * .025, 0)
          ..lineTo(w, u * .025)
          ..lineTo(w, h - u * .032)
          ..lineTo(w - u * .032, h)
          ..lineTo(0, h)
          ..lineTo(0, u * .02)
          ..close();
        final eyes = Path();
        for (final y in [h * .19, h * .50, h * .81]) {
          eyes.addOval(
            Rect.fromCircle(center: Offset(u * .045, y), radius: u * .012),
          );
        }
        return Path.combine(PathOperation.difference, paper, eyes);
      default:
        return Path()..addRect(Offset.zero & size);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final size = constraints.biggest;
      if (!size.isFinite || size.isEmpty) return const SizedBox.shrink();
      return ClipPath(
        clipper: _DiversityFrameClipper(style),
        child: CustomPaint(
          painter: _DiversityFramePainter(style),
          child: Padding(
            padding: insets(style, size),
            child: ClipRect(child: SizedBox.expand(child: child)),
          ),
        ),
      );
    },
  );
}

class _DiversityFrameClipper extends CustomClipper<Path> {
  const _DiversityFrameClipper(this.style);
  final String style;

  @override
  Path getClip(Size size) => DiversityPhotoFrame.outer(style, size);

  @override
  bool shouldReclip(_DiversityFrameClipper old) => old.style != style;
}

class _DiversityFramePainter extends CustomPainter {
  const _DiversityFramePainter(this.style);
  final String style;

  @override
  void paint(Canvas canvas, Size size) {
    final u = math.min(size.width, size.height);
    if (u <= 0) return;
    final w = size.width, h = size.height;
    final photo = DiversityPhotoFrame.insets(
      style,
      size,
    ).deflateRect(Offset.zero & size);
    final stock = switch (style) {
      'clayContour' => const Color(0xFFD8B49C),
      'leafHerbarium' => const Color(0xFFE3E5CE),
      'filmContactRail' => const Color(0xFF23282A),
      'bakeRecipe' => const Color(0xFFF3E8D2),
      'knitStitch' => const Color(0xFFD9CDC7),
      'musicSleeve' => const Color(0xFF2D455D),
      'paperNotch' => const Color(0xFFE4CFB5),
      'galleryRegistration' => const Color(0xFFF5F4EF),
      _ => const Color(0xFFCCD1B4),
    };
    final ink = switch (style) {
      'clayContour' => const Color(0xFF8E6048),
      'leafHerbarium' => const Color(0xFF69754C),
      'filmContactRail' => const Color(0xFFC89C55),
      'bakeRecipe' => const Color(0xFFB36D59),
      'knitStitch' => const Color(0xFF8C6170),
      'musicSleeve' => const Color(0xFFB6C9D9),
      'paperNotch' => const Color(0xFF937255),
      'galleryRegistration' => const Color(0xFF697278),
      _ => const Color(0xFF667355),
    };
    canvas.save();
    // Even if a motif is enlarged, no ink can enter the photo aperture.
    final mount = Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(DiversityPhotoFrame.outer(style, size), Offset.zero)
      ..addRect(photo);
    canvas.clipPath(mount);
    canvas.drawRect(Offset.zero & size, Paint()..color = stock);
    final rule = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * .002
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void line(double x, double y, double xx, double yy, {Paint? paint}) =>
        canvas.drawLine(Offset(x, y), Offset(xx, yy), paint ?? rule);
    void dot(double x, double y, double radius, {Color? color}) =>
        canvas.drawCircle(Offset(x, y), radius, Paint()..color = color ?? ink);
    switch (style) {
      case 'clayContour':
        canvas.drawRect(
          photo.inflate(u * .014),
          rule..color = ink.withValues(alpha: .35),
        );
        final glaze = Paint()
          ..color = const Color(0xFFF0D3B6).withValues(alpha: .52)
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * .009;
        for (var i = 0; i < 5; i++) {
          final y = h - u * (.035 + i * .009);
          final path = Path()
            ..moveTo(w * .18, y)
            ..quadraticBezierTo(w * .38, y - u * .018, w * .58, y);
          canvas.drawPath(path, glaze);
        }
        for (var i = 0; i < 19; i++) {
          dot(
            u * (.019 + i % 3 * .012),
            h * (i + 1) / 20,
            u * (.001 + i % 2 * .0007),
            color: ink.withValues(alpha: .35),
          );
        }
        for (var i = 0; i < 3; i++) {
          dot(
            w - u * (.05 + i * .021),
            h - u * .052,
            u * .006,
            color: [
              const Color(0xFF9D6C52),
              const Color(0xFFCA8F6E),
              const Color(0xFFEAD1AD),
            ][i],
          );
        }
      case 'leafHerbarium':
        canvas.drawRect(
          photo.inflate(u * .012),
          rule..color = ink.withValues(alpha: .45),
        );
        final stemX = u * .038;
        line(stemX, h * .18, stemX, h * .80);
        for (var i = 0; i < 7; i++) {
          final y = h * (.23 + i * .075);
          final side = i.isEven ? 1 : -1;
          final leaf = Path()
            ..moveTo(stemX, y)
            ..quadraticBezierTo(
              stemX + side * u * .023,
              y - u * .019,
              stemX + side * u * .022,
              y - u * .031,
            )
            ..quadraticBezierTo(
              stemX - side * u * .004,
              y - u * .023,
              stemX,
              y,
            );
          canvas.drawPath(leaf, Paint()..color = ink.withValues(alpha: .45));
        }
        for (final x in [photo.left + u * .01, photo.right - u * .01]) {
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(x, u * .035),
              width: u * .052,
              height: u * .018,
            ),
            Paint()..color = const Color(0xFFC8B990),
          );
        }
        line(photo.left, h - u * .055, w * .62, h - u * .055);
        for (var i = 0; i < 4; i++) {
          line(
            w * .73 + i * u * .018,
            h - u * .068,
            w * .73 + i * u * .018,
            h - u * .038,
          );
        }
      case 'filmContactRail':
        canvas.drawRect(
          Rect.fromLTWH(0, 0, u * .095, h),
          Paint()..color = const Color(0xFF131819),
        );
        for (var i = 0; i < 10; i++) {
          final y = h * (i + .5) / 10;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(u * .045, y),
                width: u * .032,
                height: u * .044,
              ),
              Radius.circular(u * .004),
            ),
            Paint()..color = const Color(0xFFCEC7AF),
          );
        }
        line(u * .11, u * .025, u * .11, h - u * .025);
        line(photo.left, h - u * .11, photo.right, h - u * .11);
        for (var i = 0; i < 17; i++) {
          final x = photo.left + u * .02 + i * u * .019;
          line(x, h - u * .076, x, h - u * (i % 3 == 0 ? .036 : .049));
        }
        canvas.drawRect(
          Rect.fromLTWH(photo.right - u * .10, h - u * .073, u * .08, u * .026),
          Paint()..color = ink,
        );
      case 'bakeRecipe':
        final check = Paint()..color = ink.withValues(alpha: .18);
        final pitch = u * .028;
        for (var y = h - u * .115; y < h; y += pitch) {
          for (var x = 0.0; x < w; x += pitch) {
            final row = ((y - (h - u * .115)) / pitch).round();
            final column = (x / pitch).round();
            if ((row + column).isEven) {
              canvas.drawRect(Rect.fromLTWH(x, y, pitch, pitch), check);
            }
          }
        }
        line(photo.left, h - u * .13, photo.right, h - u * .13);
        for (var i = 0; i < 4; i++) {
          final x = w * .75 + i * u * .024;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, h - u * .09, u * .015, u * .035),
              Radius.circular(u * .003),
            ),
            rule,
          );
        }
        line(photo.left, u * .022, w * .40, u * .022);
      case 'knitStitch':
        final seam = photo.inflate(u * .027);
        final stitch = Paint()
          ..color = ink.withValues(alpha: .72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * .003
          ..strokeCap = StrokeCap.round;
        for (var x = seam.left; x < seam.right; x += u * .022) {
          for (final y in [seam.top, seam.bottom]) {
            line(x, y + u * .006, x + u * .009, y - u * .006, paint: stitch);
          }
        }
        for (var y = seam.top; y < seam.bottom; y += u * .022) {
          for (final x in [seam.left, seam.right]) {
            line(x - u * .006, y, x + u * .006, y + u * .009, paint: stitch);
          }
        }
        for (var i = 0; i < 6; i++) {
          final x = w * .24 + i * u * .033;
          final y = h - u * .06;
          final loop = Path()
            ..moveTo(x, y)
            ..quadraticBezierTo(
              x - u * .015,
              y - u * .027,
              x + u * .013,
              y - u * .02,
            )
            ..quadraticBezierTo(
              x + u * .025,
              y - u * .006,
              x + u * .007,
              y + u * .009,
            );
          canvas.drawPath(loop, stitch);
        }
      case 'musicSleeve':
        canvas.drawRect(photo.inflate(u * .014), rule);
        final disc = Offset(w * .68, h + u * .07);
        for (var i = 0; i < 7; i++) {
          canvas.drawCircle(
            disc,
            u * (.13 + i * .014),
            rule..color = ink.withValues(alpha: .34),
          );
        }
        final side = Rect.fromLTWH(w - u * .094, u * .06, u * .033, h * .34);
        canvas.drawRect(side, Paint()..color = const Color(0xFFDD9B67));
        for (var i = 0; i < 5; i++) {
          final x = photo.left + i * u * .035;
          line(x, h - u * .075, x + u * .021, h - u * .075);
        }
        line(photo.left, h - u * .049, w * .40, h - u * .049);
      case 'paperNotch':
        final fold = Path()
          ..moveTo(w - u * .09, 0)
          ..lineTo(w - u * .09, u * .09)
          ..lineTo(w, u * .09);
        canvas.drawPath(fold, rule);
        canvas.drawPath(
          Path()
            ..moveTo(w - u * .09, 0)
            ..lineTo(w - u * .09, u * .09)
            ..lineTo(w, u * .09)
            ..close(),
          Paint()..color = const Color(0xFFC4A881),
        );
        for (var i = 0; i < 4; i++) {
          line(u * (.13 + i * .035), u * .035, u * (.14 + i * .035), u * .06);
        }
        final strip = Rect.fromLTWH(w * .11, h - u * .075, w * .32, u * .03);
        canvas.drawRect(strip, Paint()..color = const Color(0xFFF5E7D1));
        line(w * .51, h - u * .06, w * .84, h - u * .06);
        dot(w - u * .043, h - u * .045, u * .009);
      case 'galleryRegistration':
        canvas.drawRect(
          photo.inflate(u * .018),
          rule..color = const Color(0xFFBEC4C4),
        );
        final positions = [
          Offset(u * .045, u * .045),
          Offset(w - u * .045, u * .045),
          Offset(u * .045, h - u * .045),
          Offset(w - u * .045, h - u * .045),
        ];
        for (final p in positions) {
          line(p.dx - u * .014, p.dy, p.dx + u * .014, p.dy);
          line(p.dx, p.dy - u * .014, p.dx, p.dy + u * .014);
          canvas.drawCircle(p, u * .008, rule);
        }
        for (var i = 0; i < 5; i++) {
          canvas.drawRect(
            Rect.fromLTWH(
              w * .55 + i * u * .025,
              h - u * .079,
              u * .018,
              u * .025,
            ),
            Paint()
              ..color = Color.lerp(
                const Color(0xFF283435),
                const Color(0xFFD5DBD8),
                i / 4,
              )!,
          );
        }
        line(photo.left, h - u * .054, w * .42, h - u * .054);
      case 'campMap':
        final contour = Paint()
          ..color = ink.withValues(alpha: .18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * .0018;
        for (var i = 0; i < 7; i++) {
          final path = Path()..moveTo(w * .18, h - u * (.013 + i * .014));
          path.cubicTo(
            w * .34,
            h - u * (.10 + i * .012),
            w * .51,
            h - u * (.015 + i * .013),
            w * .72,
            h - u * (.055 + i * .013),
          );
          canvas.drawPath(path, contour);
        }
        for (final y in [h * .19, h * .50, h * .81]) {
          canvas.drawCircle(
            Offset(u * .045, y),
            u * .023,
            Paint()..color = const Color(0xFF929979),
          );
          canvas.drawCircle(
            Offset(u * .045, y),
            u * .016,
            rule..color = const Color(0xFF586347),
          );
        }
        for (var y = u * .045; y < h - u * .045; y += u * .03) {
          line(
            u * .102,
            y,
            u * .102,
            y + u * .014,
            paint: rule..color = ink.withValues(alpha: .58),
          );
        }
        final arrow = Path()
          ..moveTo(w - u * .035, h - u * .11)
          ..lineTo(w - u * .056, h - u * .058)
          ..lineTo(w - u * .035, h - u * .068)
          ..lineTo(w - u * .014, h - u * .058)
          ..close();
        canvas.drawPath(arrow, Paint()..color = ink);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DiversityFramePainter old) => old.style != style;
}
