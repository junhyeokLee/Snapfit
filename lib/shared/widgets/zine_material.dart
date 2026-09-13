import 'dart:math' as math;
import 'package:flutter/material.dart';

class ZineStationery extends StatelessWidget {
  const ZineStationery({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _ZinePaper(id));
}

Path _torn(Size s) {
  final u = math.min(s.width, s.height);
  double edge(int i) =>
      u * (.012 + .004 * math.sin(i * 2.4) + .003 * math.sin(i * .71));
  final p = Path()..moveTo(0, edge(0));
  for (var i = 1; i <= 96; i++) {
    p.lineTo(s.width * i / 96, edge(i));
  }
  p.lineTo(s.width, s.height - edge(100));
  for (var i = 95; i >= 0; i--) {
    p.lineTo(s.width * i / 96, s.height - edge(i + 100));
  }
  return p..close();
}

class _ZinePaper extends CustomPainter {
  _ZinePaper(this.id);
  final String id;
  @override
  void paint(Canvas c, Size s) {
    if (s.isEmpty) return;
    final w = s.width, h = s.height, u = math.min(w, h);
    final p = Paint();
    final rect = Offset.zero & s;
    c.save();
    c.clipRect(rect);
    switch (id) {
      case 'zineGridPaper':
        c.drawRect(rect, p..color = const Color(0xFFF7F9FD));
        p
          ..color = const Color(0xFFD3DDEE)
          ..strokeWidth = u * .002;
        for (var x = 0.0; x < w; x += u / 15) {
          c.drawLine(Offset(x, 0), Offset(x, h), p);
        }
        for (var y = 0.0; y < h; y += u / 15) {
          c.drawLine(Offset(0, y), Offset(w, y), p);
        }
      case 'zineTornBlue':
      case 'zineTape':
        c.clipPath(_torn(s));
        c.drawRect(
          rect,
          p
            ..color = id == 'zineTape'
                ? const Color(0xEAFE7E45)
                : const Color(0xFF2451E6),
        );
        p
          ..color = id == 'zineTape'
              ? const Color(0x28FAE4CA)
              : const Color(0x206E94F7)
          ..strokeWidth = u * .002;
        for (var i = 0; i < 70; i++) {
          final y = h * (i + .5) / 70;
          c.drawLine(
            Offset(w * (i % 5) / 20, y),
            Offset(w * (.6 + i % 4 / 10), y + h * .005),
            p,
          );
        }
      case 'zineChecker':
        c.drawRect(rect, p..color = const Color(0xFFF8F8F5));
        p.color = const Color(0xFF202020);
        final cell = h / 4;
        for (var y = 0; y < 4; y++) {
          for (var x = 0; x < (w / cell).ceil(); x++) {
            if ((x + y).isEven)
              c.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), p);
          }
        }
      case 'zineTicket':
        final holes = Path()
          ..addOval(Rect.fromCircle(center: Offset(0, h / 2), radius: h * .13))
          ..addOval(Rect.fromCircle(center: Offset(w, h / 2), radius: h * .13));
        c.drawPath(
          Path.combine(PathOperation.difference, Path()..addRect(rect), holes),
          p..color = const Color(0xFFE5F16C),
        );
        p
          ..color = const Color(0xFF222222)
          ..strokeWidth = u * .012;
        for (var i = 1; i < 10; i++) {
          c.drawLine(
            Offset(w * .8, h * i / 10),
            Offset(w * .8, h * (i + .45) / 10),
            p,
          );
        }
        for (var i = 0; i < 8; i++) {
          c.drawRect(
            Rect.fromLTWH(
              w * (.85 + i * .011),
              h * .28,
              w * (i.isEven ? .005 : .002),
              h * .44,
            ),
            p,
          );
        }
      case 'zineOrbit':
        p
          ..color = const Color(0xFFF44336)
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * .035
          ..strokeCap = StrokeCap.round;
        c.drawPath(
          Path()
            ..moveTo(w * .92, h * .3)
            ..cubicTo(w * .7, -h * .03, w * .07, h * .02, w * .03, h * .49)
            ..cubicTo(-w * .02, h, w * .78, h * 1.03, w * .96, h * .52)
            ..cubicTo(w * 1.02, h * .28, w * .78, h * .12, w * .60, h * .12),
          p,
        );
      case 'zineUnderline':
        p
          ..color = const Color(0xFF2451E6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * .065
          ..strokeCap = StrokeCap.round;
        c.drawPath(
          Path()
            ..moveTo(w * .02, h * .35)
            ..quadraticBezierTo(w * .6, h * .16, w * .98, h * .31)
            ..moveTo(w * .13, h * .70)
            ..quadraticBezierTo(w * .55, h * .49, w * .9, h * .62),
          p,
        );
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _ZinePaper oldDelegate) => oldDelegate.id != id;
}

class ZinePhotoFrame extends StatelessWidget {
  const ZinePhotoFrame({super.key, required this.style, required this.child});
  final String style;
  final Widget child;
  static EdgeInsets insets(String style, Size s) {
    final u = math.min(s.width, s.height);
    return style == 'zineContact'
        ? EdgeInsets.symmetric(horizontal: u * .055, vertical: u * .09)
        : EdgeInsets.all(u * (style == 'zineTab' ? .065 : .048));
  }

  static Path outline(String style, Size s) =>
      style == 'zineDeckle' ? _torn(s) : (Path()..addRect(Offset.zero & s));
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) {
      final padding = insets(style, box.biggest);
      return ClipPath(
        clipper: _ZineFrameClip(style),
        child: ColoredBox(
          color: style == 'zineContact'
              ? const Color(0xFF202020)
              : style == 'zineTab'
              ? const Color(0xFF2451E6)
              : const Color(0xFFFEFEFA),
          child: CustomPaint(
            foregroundPainter: _ZineFrameDetail(style),
            child: Padding(
              padding: padding,
              child: ClipRect(child: SizedBox.expand(child: child)),
            ),
          ),
        ),
      );
    },
  );
}

class _ZineFrameClip extends CustomClipper<Path> {
  _ZineFrameClip(this.style);
  final String style;
  @override
  Path getClip(Size size) => ZinePhotoFrame.outline(style, size);
  @override
  bool shouldReclip(covariant _ZineFrameClip oldClipper) =>
      oldClipper.style != style;
}

class _ZineFrameDetail extends CustomPainter {
  _ZineFrameDetail(this.style);
  final String style;
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height, u = math.min(s.width, s.height);
    if (u <= 0) return;
    final p = Paint()..color = const Color(0xFFF4F4D6);
    if (style == 'zineContact') {
      for (var x = u * .075; x < w - u * .075; x += u * .13) {
        for (final y in [u * .028, h - u * .055]) {
          c.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, u * .055, u * .025),
              Radius.circular(u * .004),
            ),
            p,
          );
        }
      }
    } else if (style == 'zineTab') {
      c.drawRect(
        Rect.fromLTWH(w - u * .055, h * .15, u * .038, h * .2),
        p..color = const Color(0xFFE5F16C),
      );
      c.drawRect(
        Rect.fromLTWH(w * .08, h - u * .051, w * .16, u * .035),
        p..color = const Color(0xFFFF7344),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ZineFrameDetail oldDelegate) =>
      oldDelegate.style != style;
}
