import 'dart:math' as math;
import 'dart:ui';

enum ResizeHandlePosition { topLeft, topRight, bottomLeft, bottomRight }

/// Matches the editor's centre-aligned scale/rotation render transforms.
/// [position] remains the unscaled base rectangle's top-left corner.
class LayerTransformGeometry {
  const LayerTransformGeometry({
    required this.position,
    required this.baseSize,
    required this.scale,
    required this.rotation,
  });

  final Offset position;
  final Size baseSize;
  final double scale;
  final double rotation; // radians

  Offset get center =>
      position + Offset(baseSize.width / 2, baseSize.height / 2);
  Size get visibleSize => Size(baseSize.width * scale, baseSize.height * scale);

  Rect get bounds {
    final corners = ResizeHandlePosition.values.map(corner).toList();
    return Rect.fromLTRB(
      corners.map((point) => point.dx).reduce(math.min),
      corners.map((point) => point.dy).reduce(math.min),
      corners.map((point) => point.dx).reduce(math.max),
      corners.map((point) => point.dy).reduce(math.max),
    );
  }

  static Offset rotate(Offset value, double radians) => Offset(
    value.dx * math.cos(radians) - value.dy * math.sin(radians),
    value.dx * math.sin(radians) + value.dy * math.cos(radians),
  );

  static Offset cornerDirection(ResizeHandlePosition corner) =>
      switch (corner) {
        ResizeHandlePosition.topLeft => const Offset(-1, -1),
        ResizeHandlePosition.topRight => const Offset(1, -1),
        ResizeHandlePosition.bottomLeft => const Offset(-1, 1),
        ResizeHandlePosition.bottomRight => const Offset(1, 1),
      };

  Offset corner(ResizeHandlePosition handle) {
    final direction = cornerDirection(handle);
    return center +
        rotate(
          Offset(
            direction.dx * baseSize.width * scale / 2,
            direction.dy * baseSize.height * scale / 2,
          ),
          rotation,
        );
  }

  /// Uses displacement since pointer-down, expressed in logical canvas axes.
  /// Projecting onto the rotated diagonal keeps aspect ratio and the opposite
  /// corner fixed, including when a pointer crosses the minimum-size limit.
  LayerTransformGeometry resize({
    required ResizeHandlePosition handle,
    required Offset displacement,
    double minScale = .3,
    double maxScale = 3,
  }) {
    if (!displacement.dx.isFinite ||
        !displacement.dy.isFinite ||
        !baseSize.width.isFinite ||
        !baseSize.height.isFinite ||
        baseSize.width <= 0 ||
        baseSize.height <= 0)
      return this;
    final direction = cornerDirection(handle);
    final diagonal = Offset(
      direction.dx * baseSize.width,
      direction.dy * baseSize.height,
    );
    final localDelta = rotate(displacement, -rotation);
    final scaleDelta =
        (localDelta.dx * diagonal.dx + localDelta.dy * diagonal.dy) /
        diagonal.distanceSquared;
    final nextScale = (scale + scaleDelta).clamp(minScale, maxScale).toDouble();
    final opposite = center - rotate(diagonal * (scale / 2), rotation);
    final nextCenter = opposite + rotate(diagonal * (nextScale / 2), rotation);
    return LayerTransformGeometry(
      position: nextCenter - Offset(baseSize.width / 2, baseSize.height / 2),
      baseSize: baseSize,
      scale: nextScale,
      rotation: rotation,
    );
  }

  double rotationAt({
    required Offset initialPointer,
    required Offset pointer,
    bool snap = false,
  }) {
    final initial = initialPointer - center;
    final current = pointer - center;
    if (initial.distanceSquared < .000001 || current.distanceSquared < .000001)
      return rotation;
    final delta = math.atan2(
      initial.dx * current.dy - initial.dy * current.dx,
      initial.dx * current.dx + initial.dy * current.dy,
    );
    final next = rotation + delta;
    final step = math.pi / 12;
    return snap ? (next / step).round() * step : next;
  }
}
