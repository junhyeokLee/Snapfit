import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Fits the same image crop to glyph bounds in both the editor and previews.
ImageShader textImageCoverShader(Image image, Rect bounds) {
  final scale = math.max(
    bounds.width / image.width,
    bounds.height / image.height,
  );
  final dx = bounds.left + (bounds.width - image.width * scale) / 2;
  final dy = bounds.top + (bounds.height - image.height * scale) / 2;
  return ImageShader(
    image,
    TileMode.clamp,
    TileMode.clamp,
    Float64List.fromList([
      scale,
      0,
      0,
      0,
      0,
      scale,
      0,
      0,
      0,
      0,
      1,
      0,
      dx,
      dy,
      0,
      1,
    ]),
  );
}
