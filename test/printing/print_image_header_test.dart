import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as bitmap;
import 'package:snap_fit/features/album/printing/print_image_header.dart';

void main() {
  test(
    'web metadata reports PNG original dimensions without decoding pixels',
    () {
      final png = bitmap.encodePng(bitmap.Image(width: 31, height: 19));
      expect(printEncodedImageSize(png), const Size(31, 19));
    },
  );
  test(
    'web metadata applies JPEG EXIF rotation before PPI and decode planning',
    () {
      final original = bitmap.Image(width: 31, height: 19);
      final jpeg = bitmap.encodeJpg(original);
      expect(printEncodedImageSize(jpeg), const Size(31, 19));
      final exif = bitmap.ExifData()..imageIfd.orientation = 6;
      final rotated = bitmap.injectJpgExif(jpeg, exif)!;
      expect(printEncodedImageSize(rotated), const Size(19, 31));
    },
  );
  test(
    'unknown image headers fail instead of inventing original resolution',
    () {
      expect(() => printEncodedImageSize(Uint8List(32)), throwsFormatException);
    },
  );
}
