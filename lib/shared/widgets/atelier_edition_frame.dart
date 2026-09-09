import 'dart:math' as math;
import 'package:flutter/material.dart';

/// One replaceable photo is visible through the mat's openings, not flattened.
class AtelierEditionFrame extends StatelessWidget {
  const AtelierEditionFrame({
    super.key,
    required this.style,
    required this.child,
  });
  final String style;
  final Widget child;

  static EdgeInsets insets(String style, Size s) {
    final u = math.min(s.width, s.height);
    return switch (style) {
      'atelierDeepMat' => EdgeInsets.all(u * .14),
      'atelierFolio' => EdgeInsets.fromLTRB(
        u * .16,
        u * .065,
        u * .16,
        u * .08,
      ),
      'atelierNegative' => EdgeInsets.symmetric(
        horizontal: u * .115,
        vertical: u * .07,
      ),
      'atelierEnvelope' => EdgeInsets.fromLTRB(
        u * .08,
        u * .055,
        u * .08,
        u * .24,
      ),
      'atelierCoastline' => EdgeInsets.all(u * .065),
      'atelierAccordion' => EdgeInsets.all(u * .065),
      'atelierDeco' => EdgeInsets.all(u * .12),
      _ => EdgeInsets.all(u * .09),
    };
  }

  static Path outer(String style, Size s) {
    final r = Offset.zero & s, u = math.min(s.width, s.height);
    if (style == 'atelierCoastline') return _coast(s);
    if (style == 'atelierKeyhole') return _keyhole(s);
    if (style == 'atelierDeco') return _stepped(s);
    if (style == 'atelierCornerFold') {
      return Path()
        ..moveTo(0, 0)
        ..lineTo(s.width - u * .17, 0)
        ..lineTo(s.width, u * .17)
        ..lineTo(s.width, s.height)
        ..lineTo(0, s.height)
        ..close();
    }
    final body = Path()
      ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(u * .006)));
    if (style != 'atelierNegative') return body;
    final holes = Path();
    final n = math.max(5, (s.height / u * 9).round());
    for (var i = 0; i < n; i++) {
      for (final x in [u * .048, s.width - u * .048]) {
        holes.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(x, s.height * (.04 + .92 * i / (n - 1))),
              width: u * .037,
              height: u * .042,
            ),
            Radius.circular(u * .004),
          ),
        );
      }
    }
    return Path.combine(PathOperation.difference, body, holes);
  }

  static Path aperture(String style, Size s) {
    if (style == 'atelierKeyhole') return _keyhole(s);
    if (style == 'atelierCoastline') return _coast(s);
    if (style == 'atelierDeco') return _stepped(s);
    final r = Offset.zero & s;
    if (style == 'atelierAccordion') {
      final p = Path(), gap = s.width * .033, w = (s.width - gap * 2) / 3;
      for (var i = 0; i < 3; i++) {
        final d = s.height * (i == 1 ? 0 : .065);
        p.addRect(Rect.fromLTWH(i * (w + gap), d, w, s.height - d * 2));
      }
      return p;
    }
    return Path()..addRect(r);
  }

  static Path _keyhole(Size s) => Path()
    ..moveTo(0, s.height)
    ..lineTo(0, s.height * .49)
    ..lineTo(s.width * .14, s.height * .49)
    ..lineTo(s.width * .14, s.height * .27)
    ..cubicTo(
      s.width * .14,
      -s.height * .09,
      s.width * .86,
      -s.height * .09,
      s.width * .86,
      s.height * .27,
    )
    ..lineTo(s.width * .86, s.height * .49)
    ..lineTo(s.width, s.height * .49)
    ..lineTo(s.width, s.height)
    ..close();

  static Path _stepped(Size s) {
    final k = math.min(s.width, s.height) * .10;
    return Path()
      ..moveTo(k * 2, 0)
      ..lineTo(s.width - k * 2, 0)
      ..lineTo(s.width - k * 2, k)
      ..lineTo(s.width - k, k)
      ..lineTo(s.width - k, k * 2)
      ..lineTo(s.width, k * 2)
      ..lineTo(s.width, s.height - k * 2)
      ..lineTo(s.width - k, s.height - k * 2)
      ..lineTo(s.width - k, s.height - k)
      ..lineTo(s.width - k * 2, s.height - k)
      ..lineTo(s.width - k * 2, s.height)
      ..lineTo(k * 2, s.height)
      ..lineTo(k * 2, s.height - k)
      ..lineTo(k, s.height - k)
      ..lineTo(k, s.height - k * 2)
      ..lineTo(0, s.height - k * 2)
      ..lineTo(0, k * 2)
      ..lineTo(k, k * 2)
      ..lineTo(k, k)
      ..lineTo(k * 2, k)
      ..close();
  }

  static Path _coast(Size s) => Path()
    ..moveTo(s.width * .08, s.height * .06)
    ..cubicTo(
      s.width * .32,
      s.height * .02,
      s.width * .63,
      s.height * .13,
      s.width * .89,
      0,
    )
    ..cubicTo(
      s.width * .98,
      s.height * .25,
      s.width * .87,
      s.height * .42,
      s.width,
      s.height * .61,
    )
    ..lineTo(s.width * .94, s.height * .92)
    ..cubicTo(
      s.width * .69,
      s.height,
      s.width * .39,
      s.height * .87,
      s.width * .13,
      s.height,
    )
    ..cubicTo(
      0,
      s.height * .79,
      s.width * .11,
      s.height * .48,
      0,
      s.height * .24,
    )
    ..close();

  static Color paperColor(String style) => switch (style) {
    'atelierFolio' => const Color(0xFF586B61),
    'atelierKeyhole' => const Color(0xFFE1D7D9),
    'atelierCrossRibbon' => const Color(0xFFF2EEE6),
    'atelierNegative' => const Color(0xFF25282B),
    'atelierOxford' => const Color(0xFFE5EAF1),
    'atelierCoastline' => const Color(0xFFCCDADC),
    'atelierWeave' => const Color(0xFFDDE1CD),
    'atelierDeco' => const Color(0xFF3C5551),
    'atelierAccordion' => const Color(0xFFE8DCCE),
    'atelierCornerFold' => const Color(0xFFCBCFED),
    _ => const Color(0xFFF5F2EB),
  };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) => ClipPath(
      clipper: _AtelierFrameClip(style, true),
      child: ColoredBox(
        color: paperColor(style),
        child: CustomPaint(
          foregroundPainter: _AtelierFrameDetail(style),
          child: Padding(
            padding: insets(style, box.biggest),
            child: ClipPath(
              clipper: _AtelierFrameClip(style, false),
              child: SizedBox.expand(child: child),
            ),
          ),
        ),
      ),
    ),
  );
}

class _AtelierFrameClip extends CustomClipper<Path> {
  const _AtelierFrameClip(this.style, this.exterior);
  final String style;
  final bool exterior;
  @override
  Path getClip(Size s) => exterior
      ? AtelierEditionFrame.outer(style, s)
      : AtelierEditionFrame.aperture(style, s);
  @override
  bool shouldReclip(_AtelierFrameClip old) =>
      old.style != style || old.exterior != exterior;
}

class _AtelierFrameDetail extends CustomPainter {
  const _AtelierFrameDetail(this.style);
  final String style;
  @override
  void paint(Canvas c, Size s) {
    final u = math.min(s.width, s.height);
    final r = AtelierEditionFrame.insets(style, s).deflateRect(Offset.zero & s);
    final open = AtelierEditionFrame.aperture(style, r.size).shift(r.topLeft);
    final outer = AtelierEditionFrame.outer(style, s);
    void line(Offset a, Offset b, Color color, [double width = .002]) =>
        c.drawLine(
          a,
          b,
          Paint()
            ..color = color
            ..strokeWidth = u * width,
        );
    void stroke(Path p, Color color, [double width = .002]) => c.drawPath(
      p,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * width,
    );
    c.save();
    // Preserve the aperture across CanvasKit and native renderers without path ops.
    c.clipPath(outer);
    c.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addPath(outer, Offset.zero)
        ..addPath(open, Offset.zero),
    );
    final grain = math.Random(581);
    for (var i = 0; i < 1100; i++) {
      final p = Offset(
        grain.nextDouble() * s.width,
        grain.nextDouble() * s.height,
      );
      line(
        p,
        p + Offset(u * .003, u * .001),
        i.isEven ? const Color(0x1FFFFFFF) : const Color(0x143B4546),
        .001,
      );
    }
    if (style == 'atelierDeepMat') {
      for (var i = 1; i <= 3; i++) {
        final d = r.inflate(u * .021 * i);
        stroke(
          Path()..addRect(d),
          i == 3 ? const Color(0xFF777F77) : const Color(0xFFD3D0C7),
          .004,
        );
        line(d.topLeft, d.topRight, const Color(0xEEFFFFFF), .006);
      }
    } else if (style == 'atelierOxford' || style == 'atelierWeave') {
      final woven = style == 'atelierWeave';
      for (var x = u * .012; x < s.width; x += u * (woven ? .024 : .045)) {
        line(
          Offset(x, 0),
          Offset(x, s.height),
          woven ? const Color(0x55778263) : const Color(0x554570A5),
          woven ? .008 : .002,
        );
      }
      for (var y = 0.0; y < s.height; y += u * (woven ? .024 : .045)) {
        line(
          Offset(0, y),
          Offset(s.width, y),
          woven ? const Color(0x99F2F2D9) : const Color(0x554570A5),
          woven ? .009 : .002,
        );
      }
      stroke(Path()..addRect(r.inflate(u * .015)), const Color(0xFF687F8C));
    } else if (style == 'atelierFolio') {
      for (final x in [r.left - u * .025, r.right + u * .025]) {
        line(Offset(x, 0), Offset(x, s.height), const Color(0x8034433A), .006);
        line(
          Offset(x + u * .009, 0),
          Offset(x + u * .009, s.height),
          const Color(0x5597A38B),
        );
        for (var y = u * .06; y < s.height - u * .04; y += u * .028) {
          line(
            Offset(x + u * .03, y),
            Offset(x + u * .03, y + u * .012),
            const Color(0xCCDBDDCC),
          );
        }
      }
    } else if (style == 'atelierNegative') {
      for (final x in [u * .083, s.width - u * .083]) {
        line(Offset(x, 0), Offset(x, s.height), const Color(0xBFCEA673));
      }
      for (var i = 0; i < 20; i++) {
        final x = r.left + i * u * .013;
        line(
          Offset(x, s.height - u * .032),
          Offset(x, s.height - u * .016),
          const Color(0xBFCEA673),
          i % 3 == 0 ? .004 : .001,
        );
      }
    } else if (style == 'atelierDeco' || style == 'atelierKeyhole') {
      for (var i = 1; i <= 3; i++) {
        final d = r.inflate(u * .016 * i);
        stroke(
          AtelierEditionFrame.aperture(style, d.size).shift(d.topLeft),
          style == 'atelierDeco'
              ? const Color(0xBBD1C99E)
              : const Color(0xA0806770),
        );
      }
    } else if (style == 'atelierAccordion') {
      for (final t in [1 / 3, 2 / 3]) {
        line(
          Offset(s.width * t, 0),
          Offset(s.width * t, s.height),
          const Color(0x5586735A),
          .007,
        );
        line(
          Offset(s.width * t + u * .008, 0),
          Offset(s.width * t + u * .008, s.height),
          const Color(0xCCFFFFFF),
          .003,
        );
      }
    }
    c.restore();
    stroke(
      open,
      style == 'atelierNegative'
          ? const Color(0xFFC1A17B)
          : const Color(0x6650544B),
      .003,
    );
    if (style == 'atelierEnvelope') {
      final y = r.bottom - u * .045;
      final flap = Path()
        ..moveTo(0, s.height * .57)
        ..lineTo(s.width * .5, y + u * .11)
        ..lineTo(s.width, s.height * .57)
        ..lineTo(s.width, s.height)
        ..lineTo(0, s.height)
        ..close();
      c.drawPath(flap, Paint()..color = const Color(0xFFF1E9DB));
      line(
        Offset(0, s.height),
        Offset(s.width * .5, y + u * .05),
        const Color(0x558D806E),
      );
      line(
        Offset(s.width, s.height),
        Offset(s.width * .5, y + u * .05),
        const Color(0x558D806E),
      );
      line(
        Offset(0, s.height * .57),
        Offset(s.width * .5, y + u * .11),
        const Color(0xFFC7B9A3),
      );
      line(
        Offset(s.width, s.height * .57),
        Offset(s.width * .5, y + u * .11),
        const Color(0xFFC7B9A3),
      );
    } else if (style == 'atelierCrossRibbon') {
      final p = Path()
        ..moveTo(0, u * .17)
        ..lineTo(u * .17, 0)
        ..lineTo(u * .27, 0)
        ..lineTo(0, u * .27)
        ..close();
      c.drawPath(p, Paint()..color = const Color(0xE9AFBDB6));
      c.save();
      c.translate(s.width, s.height);
      c.rotate(math.pi);
      c.drawPath(p, Paint()..color = const Color(0xE9AFBDB6));
      c.restore();
      line(Offset(0, u * .19), Offset(u * .19, 0), const Color(0x99F8F8EC));
    } else if (style == 'atelierCornerFold') {
      final k = u * .17;
      c.drawPath(
        Path()
          ..moveTo(s.width - k, 0)
          ..lineTo(s.width - k, k)
          ..lineTo(s.width, k)
          ..close(),
        Paint()..color = const Color(0xFF939CBC),
      );
      line(
        Offset(s.width - k, k),
        Offset(s.width, k),
        const Color(0xAA7C83A8),
        .004,
      );
    }
  }

  @override
  bool shouldRepaint(_AtelierFrameDetail old) => old.style != style;
}
