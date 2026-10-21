import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/templates/studio_decoration_catalog.dart';

/// Transparent apertures keep replacement photographs and captions editable.
class AtelierLayeredPaper extends StatelessWidget {
  const AtelierLayeredPaper({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _LayeredPaperPainter(id),
    child: const SizedBox.expand(),
  );
}

class _LayeredPaperPainter extends CustomPainter {
  const _LayeredPaperPainter(this.id);
  final String id;
  String get theme =>
      id.substring(7).replaceFirst(RegExp(r'(Paper|Mount|Band)$'), '');
  Color get ink => switch (theme) {
    'Garden' => const Color(0xFF26384E),
    'Rail' => const Color(0xFF854F46),
    'Herbarium' => const Color(0xFF49644B),
    'Orbit' => const Color(0xFF52768E),
    'Kitchen' => const Color(0xFF637B51),
    'Cinema' => const Color(0xFF633640),
    _ => const Color(0xFF547A69),
  };
  Color get stock => switch (theme) {
    'Garden' => const Color(0xFFE9E9E0),
    'Rail' => const Color(0xFFDCE9E9),
    'Herbarium' => const Color(0xFFE4E8D5),
    'Orbit' => const Color(0xFFDCE8EF),
    'Kitchen' => const Color(0xFFF0E8CE),
    'Cinema' => const Color(0xFFE7D9D0),
    _ => const Color(0xFFE6DFEE),
  };
  static const gold = Color(0xFFB7A178);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.scale(size.width / 500);
    final h = size.height * 500 / size.width;
    if (id.endsWith('Mount')) {
      _mount(canvas, h);
    } else if (id.endsWith('Band')) {
      _band(canvas, h);
    } else {
      _paper(canvas, h);
    }
    canvas.restore();
  }

  void _line(Canvas c, Offset a, Offset b, Color color, [double width = 1]) =>
      c.drawLine(
        a,
        b,
        Paint()
          ..color = color
          ..strokeWidth = width,
      );
  void _stroke(Canvas c, Path p, Color color, [double width = 1]) => c.drawPath(
    p,
    Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = width,
  );
  void _dashes(Canvas c, Offset a, Offset b, Color color, {double step = 10}) {
    final delta = b - a, distance = delta.distance;
    if (distance == 0) return;
    for (var d = 0.0; d < distance; d += step) {
      _line(
        c,
        a + delta * (d / distance),
        a + delta * (math.min(d + step * .45, distance) / distance),
        color,
        .8,
      );
    }
  }

  void _grain(Canvas c, Path clip, double h) {
    c.save();
    c.clipPath(clip);
    final random = math.Random(619);
    final paint = Paint()
      ..color = const Color(0x102A342A)
      ..strokeWidth = .7;
    for (var i = 0; i < 260; i++) {
      final p = Offset(
        8 + random.nextDouble() * 484,
        8 + random.nextDouble() * (h - 16),
      );
      c.drawLine(p, p + Offset(random.nextDouble() * 3 + 1, .4), paint);
    }
    c.restore();
  }

  void _stock(Canvas c, Path shape, Color color, double h) {
    c.drawPath(
      shape.shift(const Offset(1.5, 2)),
      Paint()
        ..color = const Color(0x20312B25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    c.drawPath(shape, Paint()..color = color);
    _grain(c, shape, h);
    _stroke(c, shape, const Color(0x4592897A), .7);
  }

  Path _edge(double h, {bool scallop = false}) {
    final p = Path()..moveTo(8, 8);
    if (!scallop) {
      final random = math.Random(27);
      for (var x = 8.0; x <= 492; x += 11) {
        p.lineTo(x, 8 + random.nextDouble() * 2);
      }
      p.lineTo(492, h - 8);
      for (var x = 492.0; x >= 8; x -= 11) {
        p.lineTo(x, h - 8 - random.nextDouble() * 2);
      }
      return p..close();
    }
    for (var x = 8.0; x < 492; x += 22) {
      p.quadraticBezierTo(x + 11, 1, math.min(x + 22, 492), 8);
    }
    for (var y = 8.0; y < h - 8; y += 22) {
      p.quadraticBezierTo(499, y + 11, 492, math.min(y + 22, h - 8));
    }
    for (var x = 492.0; x > 8; x -= 22) {
      p.quadraticBezierTo(x - 11, h - 1, math.max(x - 22, 8), h - 8);
    }
    for (var y = h - 8; y > 8; y -= 22) {
      p.quadraticBezierTo(1, y - 11, 8, math.max(y - 22, 8));
    }
    return p..close();
  }

  void _paper(Canvas c, double h) {
    final shape = _edge(h, scallop: theme == 'Orbit');
    _stock(c, shape, stock, h);
    c.save();
    c.clipPath(shape);
    final faint = ink.withValues(alpha: .12);
    switch (theme) {
      case 'Garden':
        _stroke(c, Path()..addRect(Rect.fromLTWH(27, 27, 446, h - 54)), faint);
        _line(c, Offset(43, 41), Offset(457, 41), gold.withValues(alpha: .45));
      case 'Rail':
        for (var x = 40.0; x < 500; x += 35) {
          _line(c, Offset(x, 8), Offset(x, h - 8), faint, .6);
        }
        for (var y = 35.0; y < h; y += 35) {
          _line(c, Offset(8, y), Offset(492, y), faint, .6);
        }
        for (final x in [166.0, 333.0]) {
          _line(
            c,
            Offset(x, 8),
            Offset(x, h - 8),
            Colors.white.withValues(alpha: .7),
            2,
          );
          _line(c, Offset(x + 2, 8), Offset(x + 2, h - 8), faint);
        }
      case 'Herbarium':
        _line(c, const Offset(47, 8), Offset(47, h - 8), faint);
        for (var y = 50.0; y < h; y += 24) {
          _line(c, Offset(20, y), Offset(480, y), faint, .55);
        }
        for (final y in [34.0, h / 2, h - 34]) {
          c.drawCircle(
            Offset(24, y),
            5,
            Paint()..color = ink.withValues(alpha: .24),
          );
        }
      case 'Orbit':
        _stroke(
          c,
          Path()..addOval(
            Rect.fromCenter(
              center: Offset(250, h / 2),
              width: 410,
              height: h - 90,
            ),
          ),
          faint,
        );
        for (var i = 0; i < 8; i++) {
          final x = i.isEven ? 38.0 : 462.0, y = 55 + i * (h - 110) / 7;
          _line(
            c,
            Offset(x - 3, y),
            Offset(x + 3, y),
            ink.withValues(alpha: .3),
          );
          _line(
            c,
            Offset(x, y - 3),
            Offset(x, y + 3),
            ink.withValues(alpha: .3),
          );
        }
      case 'Kitchen':
        _gingham(c, Rect.fromLTWH(8, 8, 484, h - 16), .10);
      case 'Cinema':
        for (final x in [25.0, 475.0]) {
          _line(c, Offset(x, 25), Offset(x, h - 25), faint);
          for (var y = 28.0; y < h - 25; y += 22) {
            _line(c, Offset(x - 4, y), Offset(x + 4, y), faint);
          }
        }
        for (var y = h * .68; y < h - 35; y += 22) {
          _line(c, Offset(50, y), Offset(450, y), faint, .6);
        }
      case 'Walk':
        _contours(c, h, faint);
    }
    c.restore();
  }

  Path _window(Rect r) => switch (theme) {
    'Garden' =>
      Path()
        ..moveTo(r.left, r.bottom)
        ..lineTo(r.left, r.top + r.width * .38)
        ..cubicTo(
          r.left,
          r.top - 8,
          r.right,
          r.top - 8,
          r.right,
          r.top + r.width * .38,
        )
        ..lineTo(r.right, r.bottom)
        ..close(),
    'Orbit' => Path()..addOval(r),
    'Walk' =>
      Path()
        ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(r.width * .30))),
    'Kitchen' =>
      Path()..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(12))),
    _ => Path()..addRect(r),
  };
  void _mount(Canvas c, double h) {
    final window = atelierMountWindow(id);
    final rect = Rect.fromLTWH(
      window.left * 500,
      window.top * h,
      window.width * 500,
      window.height * h,
    );
    final hole = _window(rect);
    final outer = theme == 'Orbit'
        ? (Path()..addOval(Rect.fromLTWH(8, 8, 484, h - 16)))
        : _edge(h, scallop: theme == 'Kitchen');
    var body = Path.combine(PathOperation.difference, outer, hole);
    if (theme == 'Cinema') {
      final sprockets = Path();
      for (var x = 22.0; x < 480; x += 30) {
        for (final y in [h * .065, h * .89]) {
          sprockets.addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, 14, h * .055),
              const Radius.circular(2),
            ),
          );
        }
      }
      body = Path.combine(PathOperation.difference, body, sprockets);
    }
    _stock(c, body, theme == 'Cinema' ? const Color(0xFF272629) : stock, h);
    _stroke(
      c,
      hole,
      theme == 'Garden' ? gold : ink.withValues(alpha: .55),
      1.3,
    );
    c.save();
    c.clipPath(body);
    if (theme == 'Garden') {
      _stroke(
        c,
        Path()..addRect(Rect.fromLTWH(24, 24, 452, h - 48)),
        gold,
        1.2,
      );
      _stroke(
        c,
        Path()..addRect(Rect.fromLTWH(31, 31, 438, h - 62)),
        gold.withValues(alpha: .6),
        .6,
      );
      for (final x in [42.0, 458.0]) {
        final flourish = Path()
          ..moveTo(x, h - 40)
          ..quadraticBezierTo(x + (x < 100 ? 38 : -38), h - 74, x, h - 90);
        _stroke(c, flourish, gold, 1.2);
      }
    } else if (theme == 'Orbit') {
      for (var i = 0; i < 110; i++) {
        final a = i * math.pi * 2 / 110;
        _line(
          c,
          Offset(250 + 225 * math.cos(a), h / 2 + (h / 2 - 25) * math.sin(a)),
          Offset(250 + 229 * math.cos(a), h / 2 + (h / 2 - 21) * math.sin(a)),
          ink.withValues(alpha: .65),
          1.2,
        );
      }
      _stroke(
        c,
        Path()..addOval(rect.inflate(6)),
        Colors.white.withValues(alpha: .8),
        1.3,
      );
    } else if (theme == 'Kitchen') {
      _gingham(c, Rect.fromLTWH(8, 8, 484, h - 16), .19);
      _dashes(c, Offset(22, h - 24), Offset(478, h - 24), ink);
    } else if (theme == 'Rail') {
      _dashes(c, const Offset(455, 12), Offset(455, h - 12), ink, step: 12);
      for (var y = h * .25; y < h * .75; y += 6) {
        _line(
          c,
          Offset(468, y),
          Offset(483, y),
          ink,
          y.toInt().isEven ? 1.8 : .7,
        );
      }
      _line(c, Offset(24, h - 28), Offset(426, h - 28), ink);
      _line(
        c,
        Offset(166, 10),
        Offset(166, h - 10),
        Colors.white.withValues(alpha: .7),
        2,
      );
    } else if (theme == 'Herbarium') {
      for (final y in [35.0, h / 2, h - 35]) {
        c.drawCircle(
          Offset(29, y),
          4,
          Paint()..color = ink.withValues(alpha: .3),
        );
      }
      _dashes(
        c,
        Offset(64, h - 48),
        Offset(436, h - 48),
        ink.withValues(alpha: .5),
      );
      _line(
        c,
        Offset(64, h - 31),
        Offset(436, h - 31),
        ink.withValues(alpha: .3),
      );
    } else if (theme == 'Cinema') {
      _line(
        c,
        Offset(28, h - 18),
        Offset(472, h - 18),
        gold.withValues(alpha: .7),
      );
      for (var i = 0; i < 6; i++) {
        c.drawCircle(
          Offset(435.0 + i * 5, h * .12),
          1.2,
          Paint()..color = gold,
        );
      }
    } else {
      _dashes(
        c,
        const Offset(28, 26),
        const Offset(472, 26),
        ink.withValues(alpha: .5),
      );
      _dashes(
        c,
        Offset(28, h - 27),
        Offset(472, h - 27),
        ink.withValues(alpha: .5),
      );
      _contours(c, h, ink.withValues(alpha: .15));
    }
    c.restore();
  }

  void _gingham(Canvas c, Rect r, double opacity) {
    c.save();
    c.clipRect(r);
    final p = Paint()
      ..color = ink.withValues(alpha: opacity)
      ..strokeWidth = 13;
    for (var x = 12.0; x < 500; x += 28) {
      c.drawLine(Offset(x, r.top), Offset(x, r.bottom), p);
    }
    for (var y = 12.0; y < r.bottom; y += 28) {
      c.drawLine(Offset(8, y), Offset(492, y), p);
    }
    c.restore();
  }

  void _contours(Canvas c, double h, Color color) {
    for (var i = 0; i < 8; i++) {
      final y = 20.0 + i * h / 7;
      _stroke(
        c,
        Path()
          ..moveTo(0, y)
          ..cubicTo(110, y - 60, 140, y + 70, 270, y + 5)
          ..cubicTo(380, y - 65, 440, y + 30, 500, y - 12),
        color,
        .8,
      );
    }
  }

  void _band(Canvas c, double h) {
    Path body = Path()..addRect(Rect.fromLTWH(8, 12, 484, h - 24));
    if (theme == 'Garden' || theme == 'Walk') {
      body = Path()
        ..moveTo(8, 12)
        ..lineTo(492, 12)
        ..lineTo(475, h / 2)
        ..lineTo(492, h - 12)
        ..lineTo(8, h - 12)
        ..lineTo(26, h / 2)
        ..close();
    }
    final dark = theme == 'Garden' || theme == 'Cinema';
    _stock(c, body, dark ? ink : stock, h);
    c.save();
    c.clipPath(body);
    if (theme == 'Garden') {
      _line(
        c,
        const Offset(36, 19),
        const Offset(464, 19),
        const Color(0xFF6F8198),
        2,
      );
      _line(
        c,
        Offset(36, h - 20),
        Offset(464, h - 20),
        const Color(0xFF111D30),
        3,
      );
      for (final x in [78.0, 422.0]) {
        _line(
          c,
          Offset(x, 12),
          Offset(x + 8, h - 12),
          const Color(0x44334455),
          2,
        );
      }
    } else if (theme == 'Rail' || theme == 'Cinema') {
      _dashes(
        c,
        const Offset(375, 14),
        Offset(375, h - 14),
        dark ? gold : ink,
        step: 9,
      );
      for (var i = 0; i < 13; i++) {
        final x = 402 + i * 5.0;
        _line(
          c,
          Offset(x, 34),
          Offset(x, h - 34),
          dark ? gold : ink,
          i % 3 == 0 ? 2 : .8,
        );
      }
      _line(c, const Offset(32, 27), const Offset(350, 27), dark ? gold : ink);
      _line(c, Offset(32, h - 27), Offset(350, h - 27), dark ? gold : ink);
    } else if (theme == 'Kitchen') {
      _gingham(c, Rect.fromLTWH(8, 12, 484, h - 24), .20);
      for (var x = 20.0; x < 490; x += 12) {
        for (final y in [22.0, h - 22]) {
          _line(c, Offset(x, y - 2), Offset(x + 4, y + 2), ink, .8);
          _line(c, Offset(x + 4, y - 2), Offset(x, y + 2), ink, .8);
        }
      }
    } else if (theme == 'Orbit') {
      for (var i = 0; i < 12; i++) {
        final x = 30 + i * 40.0;
        _line(
          c,
          Offset(x, 25),
          Offset(x, i % 3 == 0 ? h - 28 : h - 41),
          ink,
          1.1,
        );
        c.drawCircle(Offset(x, h - 23), 1.6, Paint()..color = gold);
      }
    } else {
      _dashes(
        c,
        const Offset(26, 23),
        const Offset(474, 23),
        ink.withValues(alpha: .65),
      );
      _dashes(
        c,
        Offset(26, h - 23),
        Offset(474, h - 23),
        ink.withValues(alpha: .65),
      );
      if (theme == 'Herbarium') {
        for (var x = 60.0; x < 460; x += 38) {
          _stroke(
            c,
            Path()
              ..moveTo(x, h * .72)
              ..quadraticBezierTo(x + 20, h * .45, x + 5, h * .25),
            ink.withValues(alpha: .4),
          );
        }
      } else {
        _line(
          c,
          Offset(250, 30),
          Offset(250, h - 30),
          Colors.white.withValues(alpha: .6),
          2,
        );
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _LayeredPaperPainter oldDelegate) =>
      oldDelegate.id != id;
}
