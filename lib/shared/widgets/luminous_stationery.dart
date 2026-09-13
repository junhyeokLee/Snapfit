import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Resolution-independent paper cuts used by both editable pages and the tray.
class LuminousStationery extends StatelessWidget {
  const LuminousStationery({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _LuminousPaperPainter(id),
    child: const SizedBox.expand(),
  );
}

class _LuminousPaperPainter extends CustomPainter {
  const _LuminousPaperPainter(this.id);
  final String id;
  static const red = Color(0xFFC72F48),
      pink = Color(0xFFF5D3DF),
      mint = Color(0xFFC4DED0),
      white = Color(0xFFFFFEF5),
      ink = Color(0xFF8D2940);
  @override
  void paint(Canvas canvas, Size s) {
    if (s.isEmpty) return;
    final w = s.width, h = s.height, u = math.min(w, h);
    final r = (Offset.zero & s).deflate(u * .025);
    final fill = Paint()..color = white;
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * .008
      ..color = ink;
    if (id == 'luminousGingham' || id == 'luminousMintStripe') {
      canvas.drawRect(
        Offset.zero & s,
        fill..color = id == 'luminousGingham' ? pink : white,
      );
      final step = u / 12;
      for (var x = 0.0; x < w; x += step * 2) {
        canvas.drawRect(
          Rect.fromLTWH(x, 0, step, h),
          fill
            ..color = id == 'luminousGingham'
                ? red.withValues(alpha: .24)
                : mint,
        );
      }
      if (id == 'luminousGingham') {
        for (var y = 0.0; y < h; y += step * 2) {
          canvas.drawRect(
            Rect.fromLTWH(0, y, w, step),
            fill..color = red.withValues(alpha: .20),
          );
        }
      }
    } else if (id == 'luminousRibbon') {
      final tail = Path()
        ..moveTo(0, h * .20)
        ..lineTo(w * .19, h * .20)
        ..lineTo(w * .19, h * .92)
        ..lineTo(0, h * .92)
        ..lineTo(w * .06, h * .58)
        ..close();
      canvas.drawPath(tail, fill..color = ink);
      canvas.save();
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
      canvas.drawPath(tail, fill);
      canvas.restore();
      final front = Rect.fromLTRB(w * .09, h * .05, w * .91, h * .78);
      canvas.drawRect(front, fill..color = red);
      canvas.drawRect(
        front.deflate(u * .07),
        pen
          ..color = pink
          ..strokeWidth = u * .015,
      );
      for (var x = front.left + u * .15; x < front.right; x += u * .19) {
        canvas.drawCircle(Offset(x, h * .16), u * .01, fill..color = white);
        canvas.drawCircle(Offset(x, h * .68), u * .01, fill);
      }
    } else if (id == 'luminousRosette' || id == 'luminousStar') {
      final c = s.center(Offset.zero), n = id == 'luminousStar' ? 12 : 36;
      final p = Path();
      for (var i = 0; i < n * 2; i++) {
        final a = i * math.pi / n - math.pi / 2;
        final radius =
            u *
            (i.isEven
                ? .475
                : id == 'luminousStar'
                ? .33
                : .43);
        final pt = c + Offset(math.cos(a), math.sin(a)) * radius;
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      p.close();
      canvas.drawPath(
        p,
        fill..color = id == 'luminousStar' ? const Color(0xFFFFE899) : white,
      );
      canvas.drawPath(
        p,
        pen
          ..color = red
          ..strokeWidth = u * .006,
      );
      canvas.drawCircle(c, u * .35, pen);
      canvas.drawCircle(c, u * .31, pen..strokeWidth = u * .003);
      if (id == 'luminousRosette') {
        for (var i = 0; i < 36; i++) {
          final a = i * math.pi / 18;
          canvas.drawCircle(
            c + Offset(math.cos(a), math.sin(a)) * u * .397,
            u * .013,
            fill..color = pink,
          );
        }
      }
    } else if (id == 'luminousHeart') {
      final p = Path()
        ..moveTo(w * .5, h * .91)
        ..cubicTo(w * .2, h * .69, w * .03, h * .52, w * .04, h * .30)
        ..cubicTo(w * .06, h * .02, w * .36, h * .015, w * .5, h * .24)
        ..cubicTo(w * .64, h * .015, w * .94, h * .02, w * .96, h * .30)
        ..cubicTo(w * .97, h * .52, w * .8, h * .69, w * .5, h * .91)
        ..close();
      canvas.drawPath(p, fill..color = red);
      canvas.drawPath(
        p,
        pen
          ..color = white
          ..strokeWidth = u * .024,
      );
      canvas.save();
      canvas.translate(w * .075, h * .075);
      canvas.scale(.85);
      canvas.drawPath(
        p,
        pen
          ..color = pink
          ..strokeWidth = u * .01,
      );
      canvas.restore();
    } else if (id == 'luminousPostmark') {
      final c = Offset(w * .31, h * .5);
      for (final radius in [u * .43, u * .37]) {
        canvas.drawCircle(
          c,
          radius,
          pen
            ..color = ink
            ..strokeWidth = u * .01,
        );
      }
      for (var j = 0; j < 5; j++) {
        final y = h * (.27 + j * .11);
        final p = Path()..moveTo(w * .58, y);
        for (var i = 0; i < 3; i++) {
          final x = w * (.58 + i * .13);
          p.cubicTo(
            x + w * .04,
            y - h * .08,
            x + w * .08,
            y + h * .08,
            x + w * .13,
            y,
          );
        }
        canvas.drawPath(p, pen..strokeWidth = u * .012);
      }
      canvas.drawLine(
        Offset(w * .11, h * .42),
        Offset(w * .5, h * .42),
        pen..strokeWidth = u * .005,
      );
      canvas.drawLine(Offset(w * .11, h * .61), Offset(w * .5, h * .61), pen);
    } else if (id == 'luminousNote') {
      final p = Path()
        ..moveTo(r.left, r.top)
        ..lineTo(r.right, r.top)
        ..lineTo(r.right, r.bottom - u * .02);
      for (var i = 20; i >= 0; i--) {
        p.lineTo(
          r.left + r.width * i / 20,
          r.bottom - u * (i.isEven ? .016 : .04),
        );
      }
      p.close();
      canvas.drawPath(p, fill..color = white);
      for (var y = h * .18; y < h * .9; y += h * .115) {
        canvas.drawLine(
          Offset(w * .08, y),
          Offset(w * .93, y),
          pen
            ..color = mint
            ..strokeWidth = u * .003,
        );
      }
      canvas.drawLine(
        Offset(w * .14, h * .05),
        Offset(w * .14, h * .9),
        pen..color = pink,
      );
    }
  }

  @override
  bool shouldRepaint(_LuminousPaperPainter old) => old.id != id;
}
