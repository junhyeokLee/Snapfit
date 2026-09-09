import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A frame owns one continuous editable photo, even when its mat has two windows.
class KeepsakePhotoFrame extends StatelessWidget {
  const KeepsakePhotoFrame({
    super.key,
    required this.style,
    required this.child,
    this.materialImage,
  });
  final String style;
  final Widget child;
  final ui.Image? materialImage;

  Widget _image(String path, BoxFit fit) => materialImage == null
      ? Image.asset(path, fit: fit, filterQuality: FilterQuality.high)
      : RawImage(
          image: materialImage,
          fit: fit,
          filterQuality: FilterQuality.high,
        );

  static EdgeInsets insets(String style, Size s) {
    final u = math.min(s.width, s.height);
    return switch (style) {
      'materialLaceMount' => EdgeInsets.fromLTRB(
        u * .075,
        u * .075,
        u * .075,
        u * .11,
      ),
      'materialNotebookMount' => EdgeInsets.fromLTRB(
        u * .16,
        u * .055,
        u * .065,
        u * .08,
      ),
      'materialSlideMount' => EdgeInsets.symmetric(
        horizontal: u * .12,
        vertical: u * .15,
      ),
      _ => EdgeInsets.all(u * .085),
    };
  }

  static Path outer(String style, Size s) {
    final r = Offset.zero & s, u = math.min(s.width, s.height);
    if (style == 'materialLinenOval') return Path()..addOval(r);
    if (style == 'materialScallopMount') {
      final p = Path();
      final a = u * .027;
      final inset = r.deflate(a);
      p.moveTo(inset.left, inset.top);
      for (var edge = 0; edge < 4; edge++) {
        final length = edge.isEven ? inset.width : inset.height;
        final n = math.max(4, (length / (u * .12)).round());
        for (var i = 0; i < n; i++) {
          final m = length * (i + .5) / n, end = length * (i + 1) / n;
          switch (edge) {
            case 0:
              p.quadraticBezierTo(a + m, -a, a + end, a);
            case 1:
              p.quadraticBezierTo(s.width + a, a + m, s.width - a, a + end);
            case 2:
              p.quadraticBezierTo(
                s.width - a - m,
                s.height + a,
                s.width - a - end,
                s.height - a,
              );
            case 3:
              p.quadraticBezierTo(-a, s.height - a - m, a, s.height - a - end);
          }
        }
      }
      return p..close();
    }
    final p = Path()
      ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(u * .018)));
    if (style != 'materialNotebookMount') return p;
    final holes = Path();
    for (var y = s.height * .13; y < s.height * .9; y += s.height * .148) {
      holes.addOval(
        Rect.fromCenter(
          center: Offset(u * .061, y),
          width: u * .048,
          height: u * .035,
        ),
      );
    }
    return Path.combine(PathOperation.difference, p, holes);
  }

  static Path aperture(String style, Size s) {
    final r = Offset.zero & s, u = math.min(s.width, s.height);
    if (style == 'materialLinenOval') return Path()..addOval(r);
    if (style == 'materialTwinWindow') {
      final gap = u * .055, left = (s.width - gap) * .56;
      return Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, left, s.height),
            Radius.circular(u * .08),
          ),
        )
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              left + gap,
              s.height * .14,
              s.width - left - gap,
              s.height * .72,
            ),
            Radius.circular(u * .055),
          ),
        );
    }
    if (style == 'materialSlideMount') {
      final k = u * .05;
      return Path()
        ..moveTo(k, 0)
        ..lineTo(s.width - k, 0)
        ..lineTo(s.width, k)
        ..lineTo(s.width, s.height - k)
        ..lineTo(s.width - k, s.height)
        ..lineTo(k, s.height)
        ..lineTo(0, s.height - k)
        ..lineTo(0, k)
        ..close();
    }
    return Path()..addRRect(
      RRect.fromRectAndRadius(
        r,
        Radius.circular(u * (style == 'materialScallopMount' ? .055 : .008)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) {
      final s = box.biggest, padding = insets(style, box.biggest);
      return ClipPath(
        clipper: _MaterialClip(style, exterior: true),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: switch (style) {
                'materialTwinWindow' => const Color(0xFFC9D9D9),
                'materialScallopMount' => const Color(0xFFE8CBD2),
                'materialSlideMount' => const Color(0xFFEAECE6),
                _ => const Color(0xFFF8F7F1),
              },
            ),
            if (style == 'materialLinenOval')
              Transform.scale(
                scale: 1.6,
                child: _image(
                  'assets/sticker/studio/material_linen.png',
                  BoxFit.cover,
                ),
              ),
            Padding(
              padding: padding,
              child: ClipPath(
                clipper: _MaterialClip(style),
                child: SizedBox.expand(child: child),
              ),
            ),
            IgnorePointer(
              child: CustomPaint(painter: _MaterialFrameDetail(style)),
            ),
            if (style == 'materialLaceMount')
              Positioned(
                left: 0,
                bottom: 0,
                width: s.width * .42,
                height: s.height * .42,
                child: IgnorePointer(
                  child: _image(
                    'assets/sticker/studio/material_lace.png',
                    BoxFit.contain,
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _MaterialClip extends CustomClipper<Path> {
  const _MaterialClip(this.style, {this.exterior = false});
  final String style;
  final bool exterior;
  @override
  Path getClip(Size size) => exterior
      ? KeepsakePhotoFrame.outer(style, size)
      : KeepsakePhotoFrame.aperture(style, size);
  @override
  bool shouldReclip(_MaterialClip old) =>
      old.style != style || old.exterior != exterior;
}

class _MaterialFrameDetail extends CustomPainter {
  const _MaterialFrameDetail(this.style);
  final String style;
  @override
  void paint(Canvas c, Size s) {
    final u = math.min(s.width, s.height);
    final r = KeepsakePhotoFrame.insets(style, s).deflateRect(Offset.zero & s);
    final opening = KeepsakePhotoFrame.aperture(style, r.size).shift(r.topLeft);
    c.drawPath(
      opening,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * .005
        ..color = const Color(0x66505B50),
    );
    c.save();
    c.clipPath(
      Path.combine(
        PathOperation.difference,
        KeepsakePhotoFrame.outer(style, s),
        opening,
      ),
    );
    final random = math.Random(708);
    final grain = Paint()..strokeWidth = .5;
    for (var i = 0; i < 1400; i++) {
      final p = Offset(
        random.nextDouble() * s.width,
        random.nextDouble() * s.height,
      );
      grain.color = i.isEven
          ? const Color(0x23FFFFFF)
          : const Color(0x104B5C54);
      c.drawLine(p, p + Offset(u * .003, u * .001), grain);
    }
    if (style == 'materialLinenOval') {
      for (var i = 0; i < 100; i++) {
        final a = i * math.pi * 2 / 100;
        final p = Offset(
          s.width / 2 + (s.width / 2 - u * .03) * math.cos(a),
          s.height / 2 + (s.height / 2 - u * .03) * math.sin(a),
        );
        c.drawLine(
          p,
          p + Offset(math.cos(a) * u * .012, math.sin(a) * u * .012),
          Paint()
            ..color = const Color(0xFFECEBDC)
            ..strokeWidth = u * .002,
        );
      }
    } else if (style == 'materialNotebookMount') {
      c.drawLine(
        Offset(u * .115, 0),
        Offset(u * .115, s.height),
        Paint()
          ..color = const Color(0x75C08B80)
          ..strokeWidth = u * .003,
      );
      for (var y = u * .05; y < s.height; y += u * .035) {
        c.drawLine(
          Offset(0, y),
          Offset(s.width, y),
          Paint()
            ..color = const Color(0x298BABA6)
            ..strokeWidth = .5,
        );
      }
    } else if (style == 'materialSlideMount') {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * .002
        ..color = const Color(0x507C8C83);
      c.drawRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & s).deflate(u * .025),
          Radius.circular(u * .016),
        ),
        p,
      );
      for (final x in [u * .06, s.width - u * .06]) {
        c.drawCircle(Offset(x, u * .065), u * .012, p);
        c.drawCircle(Offset(x, s.height - u * .065), u * .012, p);
      }
      final t = TextPainter(
        text: TextSpan(
          text: 'SLIDE  /  01',
          style: TextStyle(
            fontFamily: 'NotoSans',
            fontSize: u * .027,
            letterSpacing: 0,
            color: const Color(0xFF7B8C80),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: s.width * .7);
      t.paint(c, Offset(s.width * .16, s.height - u * .085));
      t.dispose();
    } else {
      final rim = r.inflate(u * .018);
      c.drawPath(
        KeepsakePhotoFrame.aperture(style, rim.size).shift(rim.topLeft),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * .002
          ..color = const Color(0x998C9690),
      );
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_MaterialFrameDetail old) => old.style != style;
}
