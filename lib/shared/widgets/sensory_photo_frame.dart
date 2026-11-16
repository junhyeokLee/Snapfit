import 'dart:math' as math;
import 'package:flutter/material.dart';

/// All six frames keep a single replaceable rectangular photo aperture. Their
/// bindings, perforations and offset stock stay entirely outside that aperture.
class SensoryPhotoFrame extends StatelessWidget {
  const SensoryPhotoFrame({
    super.key,
    required this.style,
    required this.child,
  });
  final String style;
  final Widget child;

  static EdgeInsets insets(String style, Size size) {
    final u = math.min(size.width, size.height);
    return switch (style) {
      'cafeLedgerMat' => EdgeInsets.fromLTRB(
        u * .09,
        u * .07,
        u * .06,
        u * .14,
      ),
      'cafeReceiptFold' => EdgeInsets.fromLTRB(
        u * .055,
        u * .055,
        u * .055,
        u * .19,
      ),
      'cafeGlassine' => EdgeInsets.fromLTRB(u * .09, u * .09, u * .09, u * .09),
      'nocturneContact' => EdgeInsets.fromLTRB(
        u * .045,
        u * .12,
        u * .045,
        u * .15,
      ),
      'nocturneTransit' => EdgeInsets.fromLTRB(
        u * .17,
        u * .06,
        u * .06,
        u * .10,
      ),
      _ => EdgeInsets.fromLTRB(u * .09, u * .065, u * .065, u * .12),
    };
  }

  static Path outer(String style, Size size) {
    final rect = Offset.zero & size;
    final u = math.min(size.width, size.height);
    if (style == 'cafeReceiptFold') {
      final p = Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height - u * .018);
      for (var i = 20; i >= 0; i--) {
        p.lineTo(size.width * i / 20, size.height - (i.isEven ? u * .018 : 0));
      }
      return p..close();
    }
    final p = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(u * .014)));
    if (style != 'nocturneTransit') return p;
    final cuts = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(0, size.height * .32), radius: u * .025),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width, size.height * .32),
          radius: u * .025,
        ),
      );
    return Path.combine(PathOperation.difference, p, cuts);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final size = constraints.biggest;
      if (!size.isFinite || size.isEmpty) return const SizedBox.shrink();
      return ClipPath(
        clipper: _SensoryFrameClipper(style),
        child: CustomPaint(
          painter: _SensoryFramePainter(style),
          child: Padding(
            padding: insets(style, size),
            child: ClipRect(child: SizedBox.expand(child: child)),
          ),
        ),
      );
    },
  );
}

class _SensoryFrameClipper extends CustomClipper<Path> {
  const _SensoryFrameClipper(this.style);
  final String style;
  @override
  Path getClip(Size size) => SensoryPhotoFrame.outer(style, size);
  @override
  bool shouldReclip(_SensoryFrameClipper old) => old.style != style;
}

class _SensoryFramePainter extends CustomPainter {
  const _SensoryFramePainter(this.style);
  final String style;
  @override
  void paint(Canvas canvas, Size size) {
    final u = math.min(size.width, size.height),
        w = size.width,
        h = size.height;
    final dark = style.startsWith('nocturne');
    final bounds = Offset.zero & size;
    final hole = SensoryPhotoFrame.insets(style, size).deflateRect(bounds);
    final paper = switch (style) {
      'cafeLedgerMat' => const Color(0xFFF0E4CF),
      'cafeReceiptFold' => const Color(0xFFFAF4E7),
      'cafeGlassine' => const Color(0xFFE8E0CC),
      'nocturneContact' => const Color(0xFF172239),
      'nocturneTransit' => const Color(0xFFE3E8EE),
      _ => const Color(0xFF2346AF),
    };
    canvas.drawRect(bounds, Paint()..color = paper);
    // Quiet, deterministic paper fibres are confined to the mount area.
    final fibres = Paint()
      ..color = (dark ? Colors.white : const Color(0xFF8B7355)).withValues(
        alpha: .10,
      )
      ..strokeWidth = u * .001;
    for (var i = 1; i < 48; i++) {
      final y = h * i / 49;
      canvas.drawLine(Offset(0, y), Offset(hole.left, y), fibres);
      canvas.drawLine(Offset(hole.right, y), Offset(w, y), fibres);
    }
    final rule = Paint()
      ..color = (dark ? const Color(0xFF9DAECC) : const Color(0xFFAA9679))
      ..strokeWidth = u * .002
      ..style = PaintingStyle.stroke;
    canvas.drawRect(hole.inflate(u * .012), rule);
    switch (style) {
      case 'cafeLedgerMat':
        for (var i = 0; i < 5; i++) {
          final y = h * (.17 + i * .15);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(u * .038, y),
              width: u * .028,
              height: u * .05,
            ),
            Paint()..color = const Color(0xFF9E7C47),
          );
          canvas.drawLine(
            Offset(u * .028, y - u * .012),
            Offset(u * .047, y + u * .013),
            rule,
          );
        }
        canvas.drawLine(
          Offset(hole.left, h - u * .064),
          Offset(w * .66, h - u * .064),
          rule,
        );
      case 'cafeReceiptFold':
        final y = h - u * .14;
        for (var x = u * .07; x < w - u * .05; x += u * .025) {
          canvas.drawLine(Offset(x, y), Offset(x + u * .012, y), rule);
        }
        canvas.drawLine(
          Offset(w * .12, h - u * .07),
          Offset(w * .54, h - u * .07),
          rule,
        );
        canvas.drawLine(
          Offset(w * .68, h - u * .07),
          Offset(w * .87, h - u * .07),
          rule,
        );
      case 'cafeGlassine':
        final corners = [
          bounds.topLeft + Offset(u * .025, u * .025),
          bounds.topRight + Offset(-u * .025, u * .025),
          bounds.bottomLeft + Offset(u * .025, -u * .025),
          bounds.bottomRight - Offset(u * .025, u * .025),
        ];
        for (final c in corners) {
          canvas.drawCircle(
            c,
            u * .007,
            Paint()..color = const Color(0xFFAF9870),
          );
        }
        canvas.drawRect(
          hole.inflate(u * .035),
          Paint()
            ..color = const Color(0xB3FFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = u * .025,
        );
      case 'nocturneContact':
        for (var i = 0; i < 9; i++) {
          final x = w * (i + .7) / 10;
          for (final y in [u * .045, h - u * .045]) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(
                  center: Offset(x, y),
                  width: u * .042,
                  height: u * .025,
                ),
                Radius.circular(u * .005),
              ),
              Paint()..color = const Color(0xFFE5E9E9),
            );
          }
        }
        canvas.drawRect(
          Rect.fromLTWH(w * .70, h - u * .107, w * .23, u * .018),
          Paint()..color = const Color(0xFFAABAD4),
        );
      case 'nocturneTransit':
        canvas.drawRect(
          Rect.fromLTWH(0, 0, u * .12, h),
          Paint()..color = const Color(0xFF3559D8),
        );
        for (var y = u * .06; y < h - u * .04; y += u * .035) {
          canvas.drawLine(
            Offset(u * .14, y),
            Offset(u * .14, y + u * .017),
            rule,
          );
        }
        for (var i = 0; i < 7; i++) {
          canvas.drawRect(
            Rect.fromLTWH(
              w - u * (.08 + i * .012),
              h - u * .07,
              u * .004,
              u * .025,
            ),
            Paint()..color = const Color(0xFF334568),
          );
        }
      default:
        canvas.drawRect(
          hole.inflate(u * .024),
          Paint()..color = const Color(0xFFB7C6DC),
        );
        canvas.drawRect(
          Rect.fromLTWH(w * .61, h - u * .084, w * .27, u * .013),
          Paint()..color = const Color(0xFFB9CCFF),
        );
        for (final x in [u * .035, w - u * .035]) {
          canvas.drawCircle(
            Offset(x, u * .03),
            u * .008,
            Paint()..color = const Color(0xFFC7D7EC),
          );
        }
    }
  }

  @override
  bool shouldRepaint(_SensoryFramePainter old) => old.style != style;
}
