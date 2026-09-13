import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../core/templates/studio_photo_frame_catalog.dart';
import 'study_photo_frame.dart';
import 'edition_photo_frame.dart';
import 'keepsake_photo_frame.dart';
import 'atelier_edition_frame.dart';

/// Normalized paths keep the same cut edge in thumbnails, editor and reader.
class StudioMaterial extends StatelessWidget {
  const StudioMaterial({
    super.key,
    required this.style,
    required this.child,
    this.paperColor = Colors.white,
    this.printImages,
  });

  final String style;
  final Widget child;
  final Color paperColor;
  final Map<String, ui.Image>? printImages;

  static const newPhotoStyles = newStudioPhotoFrames;
  static const photoStyles = studioPhotoFrames;
  static const decorationStyles = {
    'studioTape',
    'studioSeal',
    'studioSpark',
    'studioPetal',
  };

  static EdgeInsets photoInsets(String style, Size size) {
    if (atelierEditionPhotoFrames.contains(style))
      return AtelierEditionFrame.insets(style, size);
    if (keepsakePhotoFrames.contains(style))
      return KeepsakePhotoFrame.insets(style, size);
    if (editionPhotoFrames.contains(style))
      return EditionPhotoFrame.insets(style, size);
    if (studyPhotoFrames.contains(style))
      return StudyPhotoFrame.photoInsets(style, size);
    final u = math.min(size.width, size.height);
    return switch (style) {
      'studioDoubleMat' => EdgeInsets.all(u * .095),
      'studioPhotoCorners' => EdgeInsets.all(u * .035),
      'studioOvalMat' => EdgeInsets.symmetric(
        horizontal: u * .09,
        vertical: u * .07,
      ),
      'studioLinen' => EdgeInsets.all(u * .085),
      'studioPostcard' => EdgeInsets.all(u * .075),
      'studioPostage' => EdgeInsets.all(u * .09),
      'studioGallery' => EdgeInsets.all(u * .075),
      'studioDeckle' => EdgeInsets.all(u * .055),
      'studioInstant' => EdgeInsets.fromLTRB(
        u * .045,
        u * .045,
        u * .045,
        u * .16,
      ),
      'studioFilm' =>
        size.width > size.height
            ? EdgeInsets.symmetric(horizontal: u * .035, vertical: u * .105)
            : EdgeInsets.symmetric(horizontal: u * .105, vertical: u * .035),
      _ => EdgeInsets.zero,
    };
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (atelierEditionPhotoFrames.contains(style))
        return AtelierEditionFrame(style: style, child: child);
      if (keepsakePhotoFrames.contains(style)) {
        final path = keepsakeFrameAssets[style];
        final loaded = path == null ? null : printImages?['asset:$path'];
        if (printImages != null && path != null && loaded == null)
          throw StateError('print_frame_material_not_loaded:$style');
        return KeepsakePhotoFrame(
          style: style,
          materialImage: loaded,
          child: child,
        );
      }
      if (editionPhotoFrames.contains(style))
        return EditionPhotoFrame(style: style, child: child);
      if (studyPhotoFrames.contains(style))
        return StudyPhotoFrame(style: style, child: child);
      final size = constraints.biggest;
      final padding = photoInsets(style, size);
      if (padding != EdgeInsets.zero) {
        return ClipPath(
          clipper: StudioMaterialClipper(style),
          child: ColoredBox(
            color: switch (style) {
              'studioFilm' => const Color(0xFF232526),
              'studioLinen' => const Color(0xFFE8ECE7),
              _ => paperColor,
            },
            child: CustomPaint(
              foregroundPainter: _FramePaperDetail(style, padding),
              child: Padding(
                padding: padding,
                child: style == 'studioOvalMat'
                    ? ClipOval(child: SizedBox.expand(child: child))
                    : ClipRect(child: SizedBox.expand(child: child)),
              ),
            ),
          ),
        );
      }
      final inset =
          math.min(size.width, size.height) *
          (style == 'studioSticker' ? .04 : .022);
      final isPaper = style == 'studioSticker' || style == 'studioScallop';
      if (!isPaper) {
        return ClipPath(
          clipper: StudioMaterialClipper(style),
          child: SizedBox.expand(child: child),
        );
      }
      return ClipPath(
        clipper: StudioMaterialClipper(style),
        child: ColoredBox(
          color: paperColor,
          child: Padding(
            padding: EdgeInsets.all(inset),
            child: ClipPath(
              clipper: StudioMaterialClipper(style),
              child: SizedBox.expand(child: child),
            ),
          ),
        ),
      );
    },
  );
}

class StudioMaterialClipper extends CustomClipper<Path> {
  const StudioMaterialClipper(this.style);
  final String style;

  @override
  Path getClip(Size size) {
    if (atelierEditionPhotoFrames.contains(style))
      return AtelierEditionFrame.outer(style, size);
    if (keepsakePhotoFrames.contains(style))
      return KeepsakePhotoFrame.outer(style, size);
    final w = size.width, h = size.height;
    final unit = math.min(w, h);
    switch (style) {
      case 'studioPostage':
        final holes = Path();
        for (var edge = 0; edge < 4; edge++) {
          final length = edge.isEven ? w : h;
          final count = (length / unit * 12).round();
          for (var i = 0; i < count; i++) {
            final along = length * (i + .5) / count;
            holes.addOval(
              Rect.fromCircle(
                center: switch (edge) {
                  0 => Offset(along, 0),
                  1 => Offset(w, along),
                  2 => Offset(along, h),
                  _ => Offset(0, along),
                },
                radius: unit * .022,
              ),
            );
          }
        }
        return Path.combine(
          PathOperation.difference,
          Path()..addRect(Offset.zero & size),
          holes,
        );
      case 'studioCapsule':
        return Path()..addRRect(
          RRect.fromRectAndRadius(
            Offset.zero & size,
            Radius.circular(unit * .5),
          ),
        );
      case 'studioDiagonal':
        return Path()..addRRect(
          RRect.fromRectAndCorners(
            Offset.zero & size,
            topLeft: Radius.circular(unit * .28),
            bottomRight: Radius.circular(unit * .28),
            topRight: Radius.circular(unit * .025),
            bottomLeft: Radius.circular(unit * .025),
          ),
        );
      case 'studioTicket':
        final paper = Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Offset.zero & size,
              Radius.circular(unit * .04),
            ),
          );
        final notches = Path()
          ..addOval(
            Rect.fromCircle(center: Offset(0, h * .5), radius: unit * .09),
          )
          ..addOval(
            Rect.fromCircle(center: Offset(w, h * .5), radius: unit * .09),
          );
        return Path.combine(PathOperation.difference, paper, notches);
      case 'studioFilm':
        final paper = Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Offset.zero & size,
              Radius.circular(unit * .018),
            ),
          );
        final holes = Path();
        final horizontal = w > h;
        final length = horizontal ? w : h;
        final count = (length / unit * 8).round().clamp(6, 20);
        for (var i = 0; i < count; i++) {
          final along = length * (.065 + .87 * i / (count - 1));
          for (final cross in [unit * .052, unit * .948]) {
            holes.addRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(
                  center: horizontal
                      ? Offset(along, cross)
                      : Offset(cross, along),
                  width: unit * (horizontal ? .05 : .032),
                  height: unit * (horizontal ? .032 : .05),
                ),
                Radius.circular(unit * .006),
              ),
            );
          }
        }
        return Path.combine(PathOperation.difference, paper, holes);
      case 'studioGallery':
      case 'studioInstant':
        return Path()..addRRect(
          RRect.fromRectAndRadius(
            Offset.zero & size,
            Radius.circular(unit * .012),
          ),
        );
      case 'studioWave':
      case 'studioDeckle':
        // Inset corners keep every sample within the saved layer bounds.
        final depth = unit * (style == 'studioWave' ? .025 : .009);
        final points = [
          Offset(depth, depth),
          Offset(w - depth, depth),
          Offset(w - depth, h - depth),
          Offset(depth, h - depth),
        ];
        final path = Path();
        for (var edge = 0; edge < 4; edge++) {
          final start = points[edge], end = points[(edge + 1) % 4];
          final normal = switch (edge) {
            0 => const Offset(0, 1),
            1 => const Offset(-1, 0),
            2 => const Offset(0, -1),
            _ => const Offset(1, 0),
          };
          for (var i = 0; i <= 160; i++) {
            final t = i / 160;
            final wave = style == 'studioWave'
                ? math.sin(t * math.pi * 8)
                : .42 * math.sin(t * math.pi * 46 + edge) +
                      .28 * math.sin(t * math.pi * 98) +
                      .19 * math.sin(t * math.pi * 174 + edge * 3);
            final p =
                Offset.lerp(start, end, t)! +
                normal * (depth * wave * math.sin(t * math.pi));
            if (edge == 0 && i == 0) {
              path.moveTo(p.dx, p.dy);
            } else {
              path.lineTo(p.dx, p.dy);
            }
          }
        }
        return path..close();
      case 'studioOval':
        return Path()..addOval(Offset.zero & size);
      case 'studioRounded':
        return Path()..addRRect(
          RRect.fromRectAndRadius(
            Offset.zero & size,
            Radius.circular(unit * .12),
          ),
        );
      case 'studioArch':
        return Path()
          ..moveTo(0, h)
          ..lineTo(0, h * .48)
          ..cubicTo(0, -h * .16, w, -h * .16, w, h * .48)
          ..lineTo(w, h)
          ..close();
      case 'studioSticker':
        return Path()
          ..moveTo(w * .46, h * .01)
          ..cubicTo(w * .82, -h * .02, w * .99, h * .20, w * .97, h * .47)
          ..cubicTo(w * 1.02, h * .83, w * .75, h, w * .43, h * .99)
          ..cubicTo(w * .08, h, 0, h * .77, w * .025, h * .49)
          ..cubicTo(-w * .025, h * .20, w * .15, h * .025, w * .46, h * .01)
          ..close();
      case 'studioSeal':
      case 'studioPetal':
        final lobes = style == 'studioPetal' ? 8 : 18;
        final path = Path();
        for (var i = 0; i <= 360; i++) {
          final a = i * math.pi / 180;
          final r = .44 + .055 * math.cos(lobes * a);
          final p = Offset(
            w * (.5 + r * math.cos(a)),
            h * (.5 + r * math.sin(a)),
          );
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        return path..close();
      case 'studioSpark':
        return Path()
          ..moveTo(w * .5, 0)
          ..quadraticBezierTo(w * .56, h * .44, w, h * .5)
          ..quadraticBezierTo(w * .56, h * .56, w * .5, h)
          ..quadraticBezierTo(w * .44, h * .56, 0, h * .5)
          ..quadraticBezierTo(w * .44, h * .44, w * .5, 0)
          ..close();
      case 'studioTorn':
      case 'studioTape':
      case 'studioScallop':
        final path = Path();
        const edges = [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)];
        final depth =
            unit *
            (style == 'studioTape'
                ? .07
                : (style == 'studioTorn' ? .014 : .024));
        for (var edge = 0; edge < 4; edge++) {
          final start = edges[edge], end = edges[(edge + 1) % 4];
          final steps = edge.isEven ? 64 : 48;
          for (var i = 0; i <= steps; i++) {
            final t = i / steps;
            final noise = math.sin(i * 12.9898 + edge * 78.233) * 43758.5453;
            final wave = style == 'studioScallop'
                ? (.5 + .5 * math.cos(t * math.pi * 24))
                : .25 + .25 * math.sin(i * .7) + .5 * (noise - noise.floor());
            final d = (i == 0 || i == steps) ? depth * .5 : depth * wave;
            final x = (start.dx + (end.dx - start.dx) * t) * w;
            final y = (start.dy + (end.dy - start.dy) * t) * h;
            final dx = edge == 1 ? -d : (edge == 3 ? d : 0.0);
            final dy = edge == 0 ? d : (edge == 2 ? -d : 0.0);
            if (edge == 0 && i == 0) {
              path.moveTo(x + dx, y + dy);
            } else {
              path.lineTo(x + dx, y + dy);
            }
          }
        }
        return path..close();
      default:
        return Path()..addRect(Offset.zero & size);
    }
  }

  @override
  bool shouldReclip(StudioMaterialClipper oldClipper) =>
      oldClipper.style != style;
}

class _FramePaperDetail extends CustomPainter {
  const _FramePaperDetail(this.style, this.insets);
  final String style;
  final EdgeInsets insets;

  @override
  void paint(Canvas canvas, Size size) {
    if (style == 'studioFilm') return;
    final u = math.min(size.width, size.height);
    final photo = insets.deflateRect(Offset.zero & size);
    if (atelierPhotoFrames.contains(style)) {
      _paintAtelier(canvas, size, photo, u);
      return;
    }
    canvas.drawRect(
      photo,
      Paint()
        ..color = const Color(0x18242B29)
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * .0015,
    );
    if (style != 'studioDeckle') return;
    final paint = Paint()
      ..color = const Color(0x102F3933)
      ..strokeWidth = u * .0008;
    // Deterministic, matte fibres confined to the paper border, never the photo.
    for (var i = 0; i < 230; i++) {
      final p = Offset(
        size.width * ((i * .6180339887) % 1),
        size.height * ((i * .4142135623) % 1),
      );
      final end = p + Offset(u * .004, u * .002);
      if (!photo.inflate(u * .006).contains(p)) canvas.drawLine(p, end, paint);
    }
  }

  void _paintAtelier(Canvas canvas, Size size, Rect photo, double u) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * .002
      ..color = const Color(0x503F5149);
    if (style == 'studioOvalMat') {
      canvas.drawOval(photo.inflate(u * .012), line);
      canvas.drawOval(
        photo.inflate(u * .025),
        line..color = const Color(0x203F5149),
      );
      return;
    }
    canvas.drawRect(photo, line..color = const Color(0x203F5149));
    if (style == 'studioDoubleMat') {
      canvas.drawRect(
        photo.inflate(u * .018),
        Paint()
          ..color = const Color(0xFFC7D2C8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * .018,
      );
      canvas.drawRect(photo.inflate(u * .03), line);
    } else if (style == 'studioPhotoCorners') {
      // Mounts overlap only the very corner of the photograph.
      for (final corner in [
        photo.topLeft,
        photo.topRight,
        photo.bottomRight,
        photo.bottomLeft,
      ]) {
        final sx = corner.dx == photo.left ? 1.0 : -1.0;
        final sy = corner.dy == photo.top ? 1.0 : -1.0;
        final p = Path()
          ..moveTo(corner.dx - sx * u * .015, corner.dy - sy * u * .015)
          ..lineTo(corner.dx + sx * u * .085, corner.dy - sy * u * .015)
          ..lineTo(corner.dx - sx * u * .015, corner.dy + sy * u * .085)
          ..close();
        canvas.drawPath(p, Paint()..color = const Color(0xFF334D48));
        canvas.drawLine(
          corner + Offset(sx * u * .067, 0),
          corner + Offset(0, sy * u * .067),
          line..color = const Color(0xFF698079),
        );
      }
    } else if (style == 'studioLinen') {
      canvas.save();
      canvas.clipPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(Offset.zero & size),
          Path()..addRect(photo),
        ),
      );
      final weave = Paint()
        ..color = const Color(0x183D5647)
        ..strokeWidth = u * .001;
      for (double x = 0; x < size.width; x += u * .008) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), weave);
      }
      for (double y = 0; y < size.height; y += u * .008) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), weave);
      }
      canvas.restore();
      final rect = photo.inflate(u * .027);
      final metric = (Path()..addRect(rect)).computeMetrics().first;
      for (double start = 0; start < metric.length; start += u * .026) {
        canvas.drawPath(
          metric.extractPath(start, math.min(start + u * .013, metric.length)),
          line
            ..color = const Color(0x88718272)
            ..strokeWidth = u * .0025,
        );
      }
    } else if (style == 'studioPostcard') {
      final rect = (Offset.zero & size).deflate(u * .024);
      final metric = (Path()..addRect(rect)).computeMetrics().first;
      var index = 0;
      for (double start = 0; start < metric.length; start += u * .085) {
        canvas.drawPath(
          metric.extractPath(start, math.min(start + u * .046, metric.length)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = u * .021
            ..color = (index++).isEven
                ? const Color(0xFFBD524E)
                : const Color(0xFF3D727A),
        );
      }
    } else if (style == 'studioPostage') {
      canvas.drawRect(
        photo.inflate(u * .018),
        line..color = const Color(0xFF7B9293),
      );
    }
  }

  @override
  bool shouldRepaint(_FramePaperDetail oldDelegate) =>
      oldDelegate.style != style || oldDelegate.insets != insets;
}
