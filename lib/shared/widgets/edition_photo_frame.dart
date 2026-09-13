import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'zine_material.dart';

/// A single photo remains continuous under the triptych's three apertures.
class EditionPhotoFrame extends StatelessWidget {
  const EditionPhotoFrame({
    super.key,
    required this.style,
    required this.child,
  });
  final String style;
  final Widget child;
  static EdgeInsets insets(String style, Size s) => style.startsWith('zine')
      ? ZinePhotoFrame.insets(style, s)
      : style == 'editionLace'
      ? EdgeInsets.fromLTRB(
          s.width * .192,
          s.height * .195,
          s.width * .192,
          s.height * .195,
        )
      : EdgeInsets.all(
          math.min(s.width, s.height) *
              (style == 'editionScallop' || style == 'editionPostage'
                  ? .09
                  : .055),
        );

  static Path outer(String style, Size s) {
    if (style.startsWith('zine')) return ZinePhotoFrame.outline(style, s);
    final r = Offset.zero & s, u = math.min(s.width, s.height);
    if (style == 'editionHeart') return aperture(style, s);
    if (style == 'editionPostage') {
      final holes = Path();
      for (var edge = 0; edge < 4; edge++) {
        final length = edge.isEven ? s.width : s.height;
        final n = (length / u * 13).round();
        for (var i = 0; i < n; i++) {
          final d = length * (i + .5) / n;
          holes.addOval(
            Rect.fromCircle(
              center: switch (edge) {
                0 => Offset(d, 0),
                1 => Offset(s.width, d),
                2 => Offset(d, s.height),
                _ => Offset(0, d),
              },
              radius: u * .022,
            ),
          );
        }
      }
      return Path.combine(PathOperation.difference, Path()..addRect(r), holes);
    }
    if (style != 'editionScallop') return Path()..addRect(r);
    final path = Path();
    final a = u * .023;
    final w = s.width - 2 * a, h = s.height - 2 * a;
    final nx = math.max(4, (w / (u * .1)).round());
    final ny = math.max(4, (h / (u * .1)).round());
    path.moveTo(a, a);
    for (var i = 0; i < nx; i++) {
      path.quadraticBezierTo(
        a + w * (i + .5) / nx,
        -a,
        a + w * (i + 1) / nx,
        a,
      );
    }
    for (var i = 0; i < ny; i++) {
      path.quadraticBezierTo(
        s.width + a,
        a + h * (i + .5) / ny,
        s.width - a,
        a + h * (i + 1) / ny,
      );
    }
    for (var i = 0; i < nx; i++) {
      path.quadraticBezierTo(
        s.width - a - w * (i + .5) / nx,
        s.height + a,
        s.width - a - w * (i + 1) / nx,
        s.height - a,
      );
    }
    for (var i = 0; i < ny; i++) {
      path.quadraticBezierTo(
        -a,
        s.height - a - h * (i + .5) / ny,
        a,
        s.height - a - h * (i + 1) / ny,
      );
    }
    return path..close();
  }

  static Path aperture(String style, Size s) {
    final w = s.width, h = s.height, u = math.min(w, h);
    if (style == 'editionHeart') {
      return Path()
        ..moveTo(w * .5, h * .98)
        ..cubicTo(w * .42, h * .85, 0, h * .58, 0, h * .28)
        ..cubicTo(0, -h * .015, w * .33, -h * .055, w * .5, h * .20)
        ..cubicTo(w * .67, -h * .055, w, -h * .015, w, h * .28)
        ..cubicTo(w, h * .58, w * .58, h * .85, w * .5, h * .98)
        ..close();
    }
    if (style == 'editionTriptych') {
      final gap = u * .055, side = w * .23;
      final p = Path();
      for (final r in [
        Rect.fromLTWH(0, h * .12, side, h * .76),
        Rect.fromLTWH(side + gap, 0, w - 2 * side - 2 * gap, h),
        Rect.fromLTWH(w - side, h * .12, side, h * .76),
      ]) {
        p.addRRect(
          RRect.fromRectAndRadius(
            r,
            Radius.circular(math.min(r.width * .5, r.height * .22)),
          ),
        );
      }
      return p;
    }
    if (style == 'editionCameo') {
      // Concave shoulders and a shallow crowned top are unlike a round rect.
      return Path()
        ..moveTo(w * .17, 0)
        ..lineTo(w * .83, 0)
        ..quadraticBezierTo(w * .83, h * .11, w, h * .11)
        ..lineTo(w, h * .89)
        ..quadraticBezierTo(w * .83, h * .89, w * .83, h)
        ..lineTo(w * .17, h)
        ..quadraticBezierTo(w * .17, h * .89, 0, h * .89)
        ..lineTo(0, h * .11)
        ..quadraticBezierTo(w * .17, h * .11, w * .17, 0)
        ..close();
    }
    return Path()..addRect(Offset.zero & s);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) {
      if (style.startsWith('zine'))
        return ZinePhotoFrame(style: style, child: child);
      final padding = insets(style, box.biggest);
      if (style == 'editionLace') {
        return Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: padding,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(box.maxWidth * .025),
                child: SizedBox.expand(child: child),
              ),
            ),
            IgnorePointer(
              child: Image.asset(
                'assets/sticker/studio/luminous_lace_frame.png',
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
              ),
            ),
          ],
        );
      }
      return ClipPath(
        clipper: _EditionClip(style, exterior: true),
        child: ColoredBox(
          color: style == 'editionHeart'
              ? const Color(0xFFFCF4AD)
              : style == 'editionTriptych'
              ? const Color(0xFFF2EEBE)
              : const Color(0xFFFFFEF8),
          child: CustomPaint(
            foregroundPainter: _EditionDetail(style, padding),
            child: Padding(
              padding: padding,
              child: ClipPath(
                clipper: _EditionClip(style),
                child: SizedBox.expand(child: child),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _EditionClip extends CustomClipper<Path> {
  const _EditionClip(this.style, {this.exterior = false});
  final String style;
  final bool exterior;
  @override
  Path getClip(Size s) => exterior
      ? EditionPhotoFrame.outer(style, s)
      : EditionPhotoFrame.aperture(style, s);
  @override
  bool shouldReclip(_EditionClip old) =>
      style != old.style || exterior != old.exterior;
}

class _EditionDetail extends CustomPainter {
  const _EditionDetail(this.style, this.padding);
  final String style;
  final EdgeInsets padding;
  @override
  void paint(Canvas canvas, Size s) {
    final u = math.min(s.width, s.height);
    final r = padding.deflateRect(Offset.zero & s);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * .004
      ..color = const Color(0xFF747B68);
    canvas.drawPath(
      EditionPhotoFrame.aperture(style, r.size).shift(r.topLeft),
      p,
    );
    final rr = r.inflate(u * .018);
    canvas.drawPath(
      EditionPhotoFrame.aperture(style, rr.size).shift(rr.topLeft),
      p
        ..strokeWidth = u * .002
        ..color = const Color(0xFFC6A37B),
    );
    if (style == 'editionScallop') {
      canvas.save();
      canvas.translate(u * .014, u * .014);
      canvas.scale(
        (s.width - u * .028) / s.width,
        (s.height - u * .028) / s.height,
      );
      canvas.drawPath(
        EditionPhotoFrame.outer(style, s),
        p..color = const Color(0xFF922E3C),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_EditionDetail old) =>
      style != old.style || padding != old.padding;
}
