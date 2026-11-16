import 'package:flutter/material.dart';

/// Clips a positioned layer in its parent page, outside the layer transform.
/// Keeping the artboard separate from its content preserves free editing.
Widget clipPositionedLayerToCanvas(Widget child, Rect? clip) {
  if (clip == null) return child;
  if (!clip.left.isFinite ||
      !clip.top.isFinite ||
      !clip.width.isFinite ||
      !clip.height.isFinite ||
      clip.isEmpty) {
    return const SizedBox.shrink();
  }
  return Positioned.fill(
    child: ClipRect(
      clipper: _LayerCanvasClipper(clip),
      child: Stack(clipBehavior: Clip.none, children: [child]),
    ),
  );
}

class _LayerCanvasClipper extends CustomClipper<Rect> {
  const _LayerCanvasClipper(this.rect);
  final Rect rect;

  @override
  Rect getClip(Size size) => rect.intersect(Offset.zero & size);

  @override
  bool shouldReclip(_LayerCanvasClipper oldClipper) => rect != oldClipper.rect;
}
