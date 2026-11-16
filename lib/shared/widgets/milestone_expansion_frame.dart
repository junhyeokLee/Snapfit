import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Each transition has its own replaceable, unobstructed photo window.
class MilestoneExpansionFrame extends StatelessWidget {
  const MilestoneExpansionFrame({
    super.key,
    required this.style,
    required this.child,
  });
  final String style;
  final Widget child;
  static const styles = {
    'milestoneConfettiMat',
    'milestoneBlueprintMount',
    'milestonePortfolioTab',
    'milestoneLinenMedal',
    'milestoneGalleryLabel',
  };
  static EdgeInsets insets(String style, Size size) {
    final u = math.min(size.width, size.height);
    return switch (style) {
      'milestoneConfettiMat' => EdgeInsets.fromLTRB(
        u * .07,
        u * .07,
        u * .07,
        u * .16,
      ),
      'milestoneBlueprintMount' => EdgeInsets.fromLTRB(
        u * .13,
        u * .055,
        u * .06,
        u * .11,
      ),
      'milestonePortfolioTab' => EdgeInsets.fromLTRB(
        u * .12,
        u * .07,
        u * .05,
        u * .13,
      ),
      'milestoneLinenMedal' => EdgeInsets.fromLTRB(
        u * .10,
        u * .08,
        u * .10,
        u * .14,
      ),
      _ => EdgeInsets.fromLTRB(u * .06, u * .06, u * .06, u * .19),
    };
  }

  static Path outer(String style, Size size) {
    final u = math.min(size.width, size.height),
        w = size.width,
        h = size.height;
    if (style == 'milestoneConfettiMat') {
      final p = Path()
        ..moveTo(0, 0)
        ..lineTo(w, 0)
        ..lineTo(w, h - u * .018);
      for (var n = 24; n >= 0; n--) {
        p.lineTo(w * n / 24, h - (n.isEven ? u * .018 : 0));
      }
      return p
        ..lineTo(0, 0)
        ..close();
    }
    if (style == 'milestonePortfolioTab') {
      return Path()
        ..moveTo(0, u * .035)
        ..lineTo(w * .26, u * .035)
        ..lineTo(w * .29, 0)
        ..lineTo(w * .57, 0)
        ..lineTo(w * .60, u * .035)
        ..lineTo(w, u * .035)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
    }
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(style == 'milestoneLinenMedal' ? u * .025 : u * .008),
        ),
      );
    return path;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) {
      final size = box.biggest;
      if (!size.isFinite || size.isEmpty) return const SizedBox.shrink();
      return ClipPath(
        clipper: _MilestoneFrameClipper(style),
        child: CustomPaint(
          painter: _MilestoneFramePainter(style),
          child: Padding(
            padding: insets(style, size),
            child: ClipRect(child: SizedBox.expand(child: child)),
          ),
        ),
      );
    },
  );
}

class _MilestoneFrameClipper extends CustomClipper<Path> {
  const _MilestoneFrameClipper(this.style);
  final String style;
  @override
  Path getClip(Size size) => MilestoneExpansionFrame.outer(style, size);
  @override
  bool shouldReclip(_MilestoneFrameClipper old) => old.style != style;
}

class _MilestoneFramePainter extends CustomPainter {
  const _MilestoneFramePainter(this.style);
  final String style;
  @override
  void paint(Canvas canvas, Size size) {
    final u = math.min(size.width, size.height),
        w = size.width,
        h = size.height;
    final hole = MilestoneExpansionFrame.insets(
      style,
      size,
    ).deflateRect(Offset.zero & size);
    final paper = switch (style) {
      'milestoneConfettiMat' => const Color(0xFFF4E4BA),
      'milestoneBlueprintMount' => const Color(0xFFE4F0ED),
      'milestonePortfolioTab' => const Color(0xFF344E5D),
      'milestoneLinenMedal' => const Color(0xFFE8E1CF),
      _ => const Color(0xFFF8F5ED),
    };
    final ink = style == 'milestonePortfolioTab'
        ? const Color(0xFFC9D4D4)
        : const Color(0xFF8B7964);
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    final line = Paint()
      ..color = ink.withValues(alpha: .62)
      ..strokeWidth = u * .002
      ..style = PaintingStyle.stroke;
    canvas.drawRect(hole.inflate(u * .009), line);
    switch (style) {
      case 'milestoneConfettiMat':
        const colors = [
          Color(0xFFCF6B45),
          Color(0xFF6C9274),
          Color(0xFFDAB64A),
        ];
        for (var n = 0; n < 12; n++) {
          final x = w * (.09 + n * .073), y = h - u * (.05 + (n % 3) * .015);
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate((n % 4 - 1) * .3);
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: u * .018,
              height: u * .009,
            ),
            Paint()..color = colors[n % 3],
          );
          canvas.restore();
        }
        for (var n = 0; n < 5; n++) {
          canvas.drawCircle(
            Offset(w * (.14 + n * .18), u * .03),
            u * .006,
            Paint()..color = colors[n % 3],
          );
        }
      case 'milestoneBlueprintMount':
        for (var n = 0; n < 10; n++) {
          final y = h * (.12 + n * .078);
          canvas.drawLine(Offset(u * .025, y), Offset(u * .10, y), line);
        }
        for (var n = 0; n < 3; n++)
          canvas.drawLine(
            Offset(u * (.03 + n * .027), u * .035),
            Offset(u * (.03 + n * .027), h - u * .04),
            line..color = ink.withValues(alpha: .24),
          );
        canvas.drawLine(
          Offset(hole.left, h - u * .05),
          Offset(w - u * .04, h - u * .05),
          line..color = ink.withValues(alpha: .65),
        );
        canvas.drawLine(
          Offset(w - u * .035, u * .025),
          Offset(w - u * .035, u * .045),
          line,
        );
      case 'milestonePortfolioTab':
        final metal = Paint()..color = const Color(0xFFBE9B70);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(u * .025, h * .21, u * .053, u * .19),
            Radius.circular(u * .015),
          ),
          metal,
        );
        for (var n = 0; n < 5; n++)
          canvas.drawLine(
            Offset(u * .033, h * (.50 + n * .077)),
            Offset(u * .083, h * (.50 + n * .077)),
            line,
          );
        canvas.drawRect(
          Rect.fromLTWH(hole.left, h - u * .072, w * .24, u * .013),
          metal,
        );
      case 'milestoneLinenMedal':
        final fibre = Paint()
          ..color = const Color(0xFF8F8879).withValues(alpha: .17)
          ..strokeWidth = u * .001;
        for (var n = 0; n < 28; n++) {
          final x = w * n / 28;
          canvas.drawLine(Offset(x, 0), Offset(x, hole.top), fibre);
          canvas.drawLine(Offset(x, hole.bottom), Offset(x, h), fibre);
        }
        for (var n = 0; n < 22; n++) {
          final y = h * n / 22;
          canvas.drawLine(Offset(0, y), Offset(hole.left, y), fibre);
          canvas.drawLine(Offset(hole.right, y), Offset(w, y), fibre);
        }
        canvas.drawCircle(Offset(w - u * .055, h - u * .055), u * .025, line);
        canvas.drawCircle(Offset(w - u * .055, h - u * .055), u * .019, line);
      default:
        canvas.drawLine(
          Offset(hole.left, h - u * .10),
          Offset(w * .56, h - u * .10),
          line,
        );
        canvas.drawLine(
          Offset(hole.left, h - u * .063),
          Offset(w * .39, h - u * .063),
          line..strokeWidth = u * .001,
        );
        canvas.drawRect(
          Rect.fromLTWH(w - u * .12, h - u * .12, u * .05, u * .035),
          Paint()..color = const Color(0xFF8A5D49),
        );
        for (var n = 0; n < 5; n++)
          canvas.drawLine(
            Offset(w - u * (.12 - n * .012), h - u * .06),
            Offset(w - u * (.12 - n * .012), h - u * .035),
            line,
          );
    }
  }

  @override
  bool shouldRepaint(_MilestoneFramePainter old) => old.style != style;
}
