import 'package:flutter/material.dart';
import '../../features/album/domain/entities/layer.dart';

/// Crop only the photograph; the frame and its page geometry stay unchanged.
class PhotoCropViewport extends StatelessWidget {
  const PhotoCropViewport({
    super.key,
    required this.layer,
    required this.child,
  });

  final LayerModel layer;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (layer.type != LayerType.image || layer.imageZoom <= 1) return child;
    return ClipRect(
      child: Transform.scale(
        scale: layer.imageZoom.clamp(1, 4),
        alignment: layer.imageAlignment,
        child: child,
      ),
    );
  }
}
