import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Physical proportions, not screen-pixel constants, define these study mounts.
class StudyPhotoFrame extends StatelessWidget {
  const StudyPhotoFrame({super.key, required this.style, required this.child});
  final String style;
  final Widget child;

  static EdgeInsets photoInsets(String style, Size size) {
    final u = math.min(size.width, size.height);
    return switch (style) {
      'studyArchWindow' => EdgeInsets.fromLTRB(
        u * .058,
        u * .064,
        u * .058,
        u * .085,
      ),
      'studyFloatMount' => EdgeInsets.fromLTRB(
        u * .045,
        u * .045,
        u * .045,
        u * .105,
      ),
      _ => EdgeInsets.all(u * .065),
    };
  }

  static Path windowPath(String style, Size size) {
    final w = size.width,
        h = size.height,
        u = math.min(size.width, size.height);
    if (style == 'studyArchWindow') {
      final rise = math.min(w * .5, h * .31);
      return Path()
        ..moveTo(0, h)
        ..lineTo(0, rise)
        ..cubicTo(0, rise * .36, w * .22, 0, w * .5, 0)
        ..cubicTo(w * .78, 0, w, rise * .36, w, rise)
        ..lineTo(w, h)
        ..close();
    }
    if (style == 'studyNotchedMat') {
      final c = u * .046;
      return Path()
        ..moveTo(c, 0)
        ..lineTo(w - c, 0)
        ..lineTo(w, c)
        ..lineTo(w, h - c)
        ..lineTo(w - c, h)
        ..lineTo(c, h)
        ..lineTo(0, h - c)
        ..lineTo(0, c)
        ..close();
    }
    return Path()..addRect(Offset.zero & size);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final insets = photoInsets(style, box.biggest);
      return ClipRect(
        child: ColoredBox(
          color: const Color(0xFFFCFCF9),
          child: CustomPaint(
            foregroundPainter: _MountDetail(style, insets),
            child: Padding(
              padding: insets,
              child: ClipPath(
                clipper: _WindowClipper(style),
                child: SizedBox.expand(child: child),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _WindowClipper extends CustomClipper<Path> {
  const _WindowClipper(this.style);
  final String style;
  @override
  Path getClip(Size size) => StudyPhotoFrame.windowPath(style, size);
  @override
  bool shouldReclip(_WindowClipper old) => old.style != style;
}

class _MountDetail extends CustomPainter {
  const _MountDetail(this.style, this.insets);
  final String style;
  final EdgeInsets insets;
  @override
  void paint(Canvas canvas, Size size) {
    final u = math.min(size.width, size.height);
    final window = insets.deflateRect(Offset.zero & size);
    final path = StudyPhotoFrame.windowPath(
      style,
      window.size,
    ).shift(window.topLeft);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * .002;
    canvas.drawRect(
      (Offset.zero & size).deflate(u * .003),
      edge..color = const Color(0xFFD4DBD7),
    );
    // A narrow dark cut edge and a light upper bevel; no gloss over the photo.
    canvas.drawPath(
      path,
      edge
        ..color = const Color(0xFF9FAB9F)
        ..strokeWidth = u * .003,
    );
    canvas.drawPath(
      path.shift(Offset(0, -u * .0025)),
      edge
        ..color = const Color(0xFFFFFFFF)
        ..strokeWidth = u * .002,
    );
    if (style == 'studyArchWindow') {
      final surround = window.inflate(u * .018);
      canvas.drawPath(
        StudyPhotoFrame.windowPath(
          style,
          surround.size,
        ).shift(surround.topLeft),
        edge
          ..color = const Color(0xFFBBC7C0)
          ..strokeWidth = u * .0018,
      );
    } else if (style == 'studyFloatMount') {
      final y = size.height - insets.bottom * .43;
      canvas.drawLine(
        Offset(window.left, y),
        Offset(window.left + u * .10, y),
        edge
          ..color = const Color(0xFF9FACAA)
          ..strokeWidth = u * .002,
      );
      canvas.drawLine(
        Offset(window.right - u * .025, y),
        Offset(window.right, y),
        edge,
      );
    } else {
      final length = u * .08, offset = u * .020;
      for (final x in [window.left - offset, window.right + offset]) {
        final sign = x < size.width / 2 ? 1.0 : -1.0;
        canvas.drawLine(
          Offset(x, window.top - offset),
          Offset(x + length * sign, window.top - offset),
          edge
            ..color = const Color(0xFFBDCAC4)
            ..strokeWidth = u * .002,
        );
        canvas.drawLine(
          Offset(x, window.bottom + offset),
          Offset(x + length * sign, window.bottom + offset),
          edge,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MountDetail old) =>
      old.style != style || old.insets != insets;
}
