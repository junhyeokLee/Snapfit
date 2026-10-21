import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared live-photo geometry for the editor, catalog and print renderer.
class AtelierStoryFrame extends StatelessWidget {
  const AtelierStoryFrame({
    super.key,
    required this.style,
    required this.child,
  });

  final String style;
  final Widget child;

  static EdgeInsets insets(String style, Size size) {
    final u = math.min(size.width, size.height);
    return switch (style) {
      'storyVowGate' => EdgeInsets.fromLTRB(
        u * .105,
        u * .065,
        u * .105,
        u * .105,
      ),
      'storyVowCotton' => EdgeInsets.all(u * .075),
      'storyDiscoverySlide' => EdgeInsets.fromLTRB(
        u * .06,
        u * .105,
        u * .115,
        u * .08,
      ),
      _ => EdgeInsets.fromLTRB(u * .07, u * .08, u * .07, u * .105),
    };
  }

  static Path outer(String style, Size size) {
    final u = math.min(size.width, size.height),
        w = size.width,
        h = size.height;
    if (style == 'storyVowCotton') return Path()..addOval(Offset.zero & size);
    if (style == 'storyDiscoverySlide') {
      return Path()
        ..moveTo(0, u * .04)
        ..lineTo(w * .48, u * .04)
        ..lineTo(w * .48, 0)
        ..lineTo(w * .80, 0)
        ..lineTo(w * .80, u * .04)
        ..lineTo(w, u * .04)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
    }
    return Path()..addRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(u * .018)),
    );
  }

  static Path aperture(String style, Size size) {
    final bounds = Offset.zero & size;
    if (style == 'storyVowCotton') return Path()..addOval(bounds);
    if (style == 'storyDiscoverySlide') {
      final cut = math.min(size.width, size.height) * .08;
      return Path()
        ..moveTo(0, 0)
        ..lineTo(size.width - cut, 0)
        ..lineTo(size.width, cut)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    }
    return Path()..addRRect(
      RRect.fromRectAndRadius(
        bounds,
        Radius.circular(math.min(size.width, size.height) * .012),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final size = constraints.biggest;
      if (!size.isFinite || size.isEmpty) return const SizedBox.shrink();
      return ClipPath(
        clipper: _StoryClipper(style, exterior: true),
        child: CustomPaint(
          painter: _StoryFramePainter(style, foreground: false),
          foregroundPainter: _StoryFramePainter(style, foreground: true),
          child: Padding(
            padding: insets(style, size),
            child: ClipPath(
              clipper: _StoryClipper(style, exterior: false),
              child: SizedBox.expand(child: child),
            ),
          ),
        ),
      );
    },
  );
}

class _StoryClipper extends CustomClipper<Path> {
  const _StoryClipper(this.style, {required this.exterior});
  final String style;
  final bool exterior;
  @override
  Path getClip(Size size) => exterior
      ? AtelierStoryFrame.outer(style, size)
      : AtelierStoryFrame.aperture(style, size);
  @override
  bool shouldReclip(_StoryClipper old) =>
      old.style != style || old.exterior != exterior;
}

class _StoryFramePainter extends CustomPainter {
  const _StoryFramePainter(this.style, {required this.foreground});
  final String style;
  final bool foreground;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width,
        h = size.height,
        u = math.min(size.width, size.height);
    final bounds = Offset.zero & size;
    final photo = AtelierStoryFrame.insets(style, size).deflateRect(bounds);
    final opening = AtelierStoryFrame.aperture(
      style,
      photo.size,
    ).shift(photo.topLeft);
    void fill(Path p, Color color) =>
        canvas.drawPath(p, Paint()..color = color);
    void line(Offset a, Offset b, Color color, [double weight = .0018]) =>
        canvas.drawLine(
          a,
          b,
          Paint()
            ..color = color
            ..strokeWidth = u * weight,
        );
    void stroke(Path p, Color color, [double weight = .0016]) =>
        canvas.drawPath(
          p,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = u * weight,
        );
    Path rect(Rect r, [double radius = .006]) =>
        Path()
          ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(u * radius)));
    Path poly(List<Offset> points) => Path()..addPolygon(points, true);
    void paper(Path p, Color color) {
      fill(p.shift(Offset(0, u * .004)), const Color(0x17262B31));
      fill(p, color);
      stroke(p, const Color(0x306E6A62), .0012);
    }

    canvas.save();
    canvas.clipPath(AtelierStoryFrame.outer(style, size));
    if (!foreground) {
      switch (style) {
        case 'storyVowGate':
          fill(Path()..addRect(bounds), const Color(0xFF613C4C));
          paper(
            rect(Rect.fromLTRB(u * .028, u * .02, w - u * .028, h - u * .022)),
            const Color(0xFFE6D8D6),
          );
          for (final x in [u * .061, w - u * .061]) {
            line(
              Offset(x, u * .03),
              Offset(x, h - u * .032),
              const Color(0x774E3441),
              .003,
            );
            line(
              Offset(x + u * .004, u * .03),
              Offset(x + u * .004, h - u * .032),
              const Color(0xB8FFF9F1),
              .002,
            );
          }
          paper(rect(photo.inflate(u * .018)), const Color(0xFFFAF5ED));
        case 'storyVowCotton':
          fill(Path()..addOval(bounds), const Color(0xFFE3D4D4));
          for (final (inset, color) in [
            (.013, const Color(0xFFF8F3EB)),
            (.028, const Color(0xFFD5BCBE)),
            (.034, const Color(0xFFFAF6F0)),
            (.049, const Color(0xFFE7DEDA)),
          ]) {
            final oval = Path()..addOval(bounds.deflate(u * inset));
            if (inset == .013 || inset == .034)
              fill(oval, color);
            else
              stroke(oval, color, .003);
          }
        case 'storyDiscoverySlide':
          fill(Path()..addRect(bounds), const Color(0xFF2C4DAD));
          paper(
            rect(
              Rect.fromLTRB(u * .02, u * .054, w - u * .071, h - u * .021),
              .004,
            ),
            const Color(0xFFF1EBB4),
          );
          fill(
            rect(Rect.fromLTRB(w * .50, u * .012, w * .78, u * .041), .002),
            const Color(0xFFE8A28F),
          );
          for (var i = 0; i < 9; i++) {
            final y = h * .14 + i * h * .077;
            line(
              Offset(w - u * .061, y),
              Offset(w - u * (i.isEven ? .027 : .039), y),
              const Color(0xBBCDD6F2),
              .002,
            );
          }
          stroke(
            opening.shift(Offset(u * .002, u * .002)),
            const Color(0x6F8D8559),
            .005,
          );
        default:
          fill(Path()..addRect(bounds), const Color(0xFFCFDDE0));
          paper(rect(bounds.deflate(u * .022), .022), const Color(0xFFE7EDF0));
          for (var i = 0; i < 15; i++) {
            final x = w * (.06 + i * .063);
            fill(
              Path()..addOval(
                Rect.fromCircle(center: Offset(x, u * .026), radius: u * .009),
              ),
              const Color(0xFFBACAD0),
            );
          }
          paper(rect(photo.inflate(u * .013), .016), const Color(0xFFFFFBED));
      }
      final grain = Path();
      for (var i = 0; i < 100; i++) {
        final x = ((i * 43 + 13) % 211) / 211 * w;
        final y = ((i * 97 + 17) % 223) / 223 * h;
        grain
          ..moveTo(x, y)
          ..lineTo(x + u * .004, y + u * .0006);
      }
      stroke(grain, const Color(0x164B4B50), .0007);
    } else {
      stroke(opening, const Color(0x66595756), .0018);
      switch (style) {
        case 'storyVowGate':
          final corner = poly([
            photo.bottomRight + Offset(u * .015, -u * .102),
            photo.bottomRight + Offset(-u * .10, u * .016),
            Offset(w - u * .027, h - u * .023),
          ]);
          paper(corner, const Color(0xB5F8F3E8));
          line(
            photo.bottomRight + Offset(u * .015, -u * .102),
            photo.bottomRight + Offset(-u * .10, u * .016),
            const Color(0x7A8E7A78),
          );
          line(
            Offset(w * .36, h - u * .043),
            Offset(w * .64, h - u * .043),
            const Color(0xFF865366),
            .003,
          );
        case 'storyVowCotton':
          for (final side in [-1.0, 1.0]) {
            final x = w * .5 + side * (w * .5 - u * .031);
            for (var i = 0; i < 5; i++) {
              final y = h * (.41 + i * .04);
              line(
                Offset(x - u * .009, y - u * .003),
                Offset(x + u * .009, y + u * .003),
                const Color(0xAA8C5662),
                .0018,
              );
            }
          }
        case 'storyDiscoverySlide':
          final a = photo.topRight - Offset(u * .075, 0),
              b = photo.topRight + Offset(0, u * .075);
          paper(poly([a, b, photo.topRight]), const Color(0xFFF2AD94));
          line(a, b, const Color(0x9E9D5E53));
        default:
          for (var i = 0; i < 22; i++) {
            final x = w * (.06 + .88 * i / 22);
            line(
              Offset(x, h - u * .034),
              Offset(x + u * .012, h - u * .034),
              const Color(0xCFB96C60),
              .002,
            );
          }
          paper(
            poly([
              Offset(w - u * .066, u * .025),
              Offset(w - u * .027, u * .071),
              Offset(w - u * .066, u * .071),
            ]),
            const Color(0xFFF3B5A1),
          );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StoryFramePainter old) =>
      old.style != style || old.foreground != foreground;
}
