import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Preview-only geometry. The flat front resumes at exactly the same image UV.
abstract final class AlbumSpineSurface {
  static const double spineEnd = .032;
  static const double flatStart = .049;
  static const int segments = 48;
  static const double _rollAngle = 1.32;
  static const double referenceSideInset = .0015;

  // Width-normalized diffuse light sampled from the approved B binding.
  // Positive values mix white; negative values shade the existing photograph.
  static const _referenceLight = <(double, double)>[
    (.004, -.188),
    (.006, -.025),
    (.008, .053),
    (.010, .075),
    (.014, .068),
    (.018, .053),
    (.022, .060),
    (.024, .120),
    (.026, .208),
    (.030, .208),
    (.032, .173),
    (.034, .060),
    (.036, .060),
    (.038, -.164),
    (.040, -.268),
    (.042, -.197),
    (.044, -.197),
    (.046, -.049),
    (.048, -.008),
    (.050, 0),
  ];

  static double projectedX(double u) {
    if (u >= flatStart) return u;
    if (u <= spineEnd) {
      final angle = _rollAngle * (u / spineEnd - 1);
      return spineEnd * (1 + math.sin(angle) / math.sin(_rollAngle));
    }
    final t = (u - spineEnd) / (flatStart - spineEnd);
    return u + .0002 * math.sin(t * math.pi * 2);
  }

  static double edgeInset(double u) {
    if (u >= flatStart) return 0;
    if (u <= spineEnd) {
      final angle = _rollAngle * (u / spineEnd - 1);
      return .006 * (1 - math.cos(angle));
    }
    final t = (u - spineEnd) / (flatStart - spineEnd);
    return .0015 * math.pow(math.sin(t * math.pi), 2);
  }

  static double light(double u) {
    if (u >= flatStart) return 0;
    final x = projectedX(u) + referenceSideInset;
    for (var i = 1; i < _referenceLight.length; i++) {
      final left = _referenceLight[i - 1];
      final right = _referenceLight[i];
      if (x <= right.$1) {
        final t = ((x - left.$1) / (right.$1 - left.$1)).clamp(0.0, 1.0);
        return left.$2 + (right.$2 - left.$2) * t;
      }
    }
    return 0;
  }
}

/// Uses Image's live, cached image stream, not an asynchronously captured cover.
class AlbumSpineImage extends StatelessWidget {
  const AlbumSpineImage({
    super.key,
    required this.image,
    this.alignment = Alignment.center,
    this.zoom = 1,
  });

  final ImageProvider image;
  final Alignment alignment;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      child: Image(
        image: image,
        fit: BoxFit.cover,
        alignment: alignment,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
        frameBuilder: (context, child, frame, synchronous) {
          if (child is! RawImage || child.image == null) return child;
          final decoded = child.image!;
          return CustomPaint(
            size: Size(
              decoded.width / child.scale,
              decoded.height / child.scale,
            ),
            painter: AlbumSpineImagePainter(
              image: decoded,
              imageScale: child.scale,
              alignment: alignment,
              zoom: zoom,
              invertColors: child.invertColors,
            ),
          );
        },
      ),
    );
  }
}

class AlbumSpineImagePainter extends CustomPainter {
  AlbumSpineImagePainter({
    required this.image,
    this.imageScale = 1,
    this.alignment = Alignment.center,
    this.zoom = 1,
    this.invertColors = false,
  });

  final ui.Image image;
  final double imageScale;
  final Alignment alignment;
  final double zoom;
  final bool invertColors;

  Size? _meshSize;
  ui.Vertices? _mesh;

  Rect sourceRectFor(Size size) {
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final fitted = applyBoxFit(BoxFit.cover, imageSize / imageScale, size);
    final crop = alignment.inscribe(
      fitted.source * imageScale,
      Offset.zero & imageSize,
    );
    return alignment.inscribe(crop.size / zoom.clamp(1, 4), crop);
  }

  ui.Vertices _vertices(Size size, Rect source) {
    if (_meshSize == size && _mesh != null) return _mesh!;
    final points = <Offset>[];
    final texture = <Offset>[];
    // One continuous triangle strip avoids gaps or doubled alpha between slices.
    for (var i = 0; i <= AlbumSpineSurface.segments; i++) {
      final u = AlbumSpineSurface.flatStart * i / AlbumSpineSurface.segments;
      final x = size.width * AlbumSpineSurface.projectedX(u);
      final inset = size.width * AlbumSpineSurface.edgeInset(u);
      points.addAll([Offset(x, inset), Offset(x, size.height - inset)]);
      texture.addAll([
        Offset(source.left + source.width * u, source.top),
        Offset(source.left + source.width * u, source.bottom),
      ]);
    }
    // The flat front shares the final mesh edge: fractional scaling cannot
    // expose a light seam between separately clipped image draws.
    points.addAll([Offset(size.width, 0), Offset(size.width, size.height)]);
    texture.addAll([source.topRight, source.bottomRight]);
    _meshSize = size;
    return _mesh = ui.Vertices(
      ui.VertexMode.triangleStrip,
      points,
      textureCoordinates: texture,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final source = sourceRectFor(size);
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..invertColors = invertColors;
    canvas.save();
    canvas.clipRect(rect);
    // Isolate replacement blending so a transparent photo remains transparent.
    // The front uses Flutter's image sampling, including its minification filter.
    canvas.saveLayer(rect, Paint());
    // Crop and zoom are applied to UVs, so the binding itself never scales up.
    final shader = ui.ImageShader(
      image,
      ui.TileMode.clamp,
      ui.TileMode.clamp,
      Matrix4.identity().storage,
      filterQuality: FilterQuality.medium,
    );
    canvas.drawVertices(
      _vertices(size, source),
      BlendMode.srcOver,
      paint..shader = shader,
    );
    shader.dispose();
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        size.width * AlbumSpineSurface.flatStart,
        0,
        size.width,
        size.height,
      ),
    );
    canvas.drawImageRect(
      image,
      source,
      rect,
      paint
        ..shader = null
        ..blendMode = BlendMode.src,
    );
    canvas.restore();
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AlbumSpineImagePainter oldDelegate) =>
      image != oldDelegate.image ||
      imageScale != oldDelegate.imageScale ||
      alignment != oldDelegate.alignment ||
      zoom != oldDelegate.zoom ||
      invertColors != oldDelegate.invertColors;
}
