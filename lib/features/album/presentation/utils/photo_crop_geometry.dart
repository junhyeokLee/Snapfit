import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Local geometry only: no pixels, metadata or photos leave the device.
abstract final class PhotoCropGeometry {
  static bool _valid(Size size) =>
      size.width.isFinite &&
      size.height.isFinite &&
      size.width > 0 &&
      size.height > 0;

  static Size coveredSize(Size photo, Size viewport, {double zoom = 1}) {
    if (!_valid(photo) || !_valid(viewport)) return viewport;
    final scale =
        math.max(viewport.width / photo.width, viewport.height / photo.height) *
        zoom.clamp(1.0, 4.0);
    return photo * scale;
  }

  /// Fraction of the source still visible when a slot is filled edge to edge.
  static double visibleFraction(Size photo, Size viewport) {
    if (!_valid(photo) || !_valid(viewport)) return 1;
    final covered = coveredSize(photo, viewport);
    return (viewport.width * viewport.height / (covered.width * covered.height))
        .clamp(0.0, 1.0);
  }

  static bool needsReview(Size photo, Size viewport) =>
      visibleFraction(photo, viewport) < .6;

  /// Match the drag to the actual cropped overflow, including zoom. Keeping
  /// the focal source point stable also prevents a pinch from jumping sideways.
  static Alignment move({
    required Size photo,
    required Size viewport,
    required Alignment alignment,
    required double previousZoom,
    required double zoom,
    required Offset focalPoint,
    required Offset delta,
  }) {
    if (!_valid(photo) || !_valid(viewport)) return alignment;
    final before = coveredSize(photo, viewport, zoom: previousZoom);
    final after = coveredSize(photo, viewport, zoom: zoom);

    double axis(
      double value,
      double extent,
      double oldExtent,
      double newExtent,
      double focal,
      double movement,
    ) {
      final overflow = newExtent - extent;
      if (overflow < .01) return value;
      final anchor = (value + 1) * .5;
      final oldOrigin = -(oldExtent - extent) * anchor;
      final sourcePosition = (focal - movement - oldOrigin) / oldExtent;
      final newOrigin = focal - sourcePosition * newExtent;
      return (-2 * newOrigin / overflow - 1).clamp(-1.0, 1.0);
    }

    return Alignment(
      axis(
        alignment.x,
        viewport.width,
        before.width,
        after.width,
        focalPoint.dx,
        delta.dx,
      ),
      axis(
        alignment.y,
        viewport.height,
        before.height,
        after.height,
        focalPoint.dy,
        delta.dy,
      ),
    );
  }
}
