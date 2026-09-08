import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as bitmap;

/// Web ImageDescriptor does not expose encoded width/height. Read metadata
/// without allocating a full-resolution pixel buffer, preserving EXIF rotation.
Size printEncodedImageSize(Uint8List bytes) {
  final decoder = bitmap.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null || info.width <= 0 || info.height <= 0) {
    throw const FormatException('print_image_header_unsupported');
  }
  var width = info.width, height = info.height;
  if (decoder is bitmap.JpegDecoder) {
    final orientation = bitmap.decodeJpgExif(bytes)?.imageIfd.orientation;
    if (orientation != null && orientation >= 5 && orientation <= 8) {
      final previousWidth = width;
      width = height;
      height = previousWidth;
    }
  }
  return Size(width.toDouble(), height.toDouble());
}
