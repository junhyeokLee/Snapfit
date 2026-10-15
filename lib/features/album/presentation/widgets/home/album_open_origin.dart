import 'package:flutter/material.dart';

/// The front face's actual size and transform, including the live float pose.
class AlbumOpenOrigin {
  AlbumOpenOrigin({required this.size, required Matrix4 transform})
    : transform = Matrix4.copy(transform);

  final Size size;
  final Matrix4 transform;

  static AlbumOpenOrigin? capture(GlobalKey key) {
    final object = key.currentContext?.findRenderObject();
    if (object is! RenderBox ||
        !object.attached ||
        !object.hasSize ||
        object.size.isEmpty)
      return null;
    return AlbumOpenOrigin(
      size: object.size,
      transform: object.getTransformTo(null),
    );
  }

  static AlbumOpenOrigin interpolate(
    AlbumOpenOrigin start,
    AlbumOpenOrigin end,
    double progress,
  ) {
    // Keep perspective terms: decomposing into scale/rotation drops them.
    final matrix = Matrix4.zero();
    for (var i = 0; i < 16; i++) {
      matrix.storage[i] =
          start.transform.storage[i] +
          (end.transform.storage[i] - start.transform.storage[i]) * progress;
    }
    return AlbumOpenOrigin(
      size: Size.lerp(start.size, end.size, progress)!,
      transform: matrix,
    );
  }
}
