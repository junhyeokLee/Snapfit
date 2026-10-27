import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

const socialProfilePhotoMaxBytes = 3 * 1024 * 1024;
const socialProfilePhotoInputMaxBytes = 20 * 1024 * 1024;

/// Publish a bounded first frame with a fresh PNG encoding, not camera metadata.
Future<Uint8List> prepareSocialProfilePhoto(Uint8List input) async {
  if (input.isEmpty || input.length > socialProfilePhotoInputMaxBytes) {
    throw const FormatException('20MB 이하의 사진을 선택해 주세요.');
  }
  ui.Codec? codec;
  ui.Image? image;
  try {
    // Common photo headers can be checked before allocating decoded pixels.
    // ImageDescriptor's encoded width/height getters are unsupported on web.
    final info = img.findDecoderForData(input)?.startDecode(input);
    if (info != null && info.width * info.height > 40000000) {
      throw const FormatException('사진 크기가 너무 커요. 더 작은 사진을 선택해 주세요.');
    }
    // This API owns and disposes its input buffer on both native and web.
    codec = await ui.instantiateImageCodecWithSize(
      await ui.ImmutableBuffer.fromUint8List(input),
      getTargetSize: (width, height) {
        if (width * height > 40000000) {
          throw const FormatException('사진 크기가 너무 커요. 더 작은 사진을 선택해 주세요.');
        }
        final edge = width > height ? width : height;
        final scale = edge > 1024 ? 1024 / edge : 1.0;
        return ui.TargetImageSize(
          width: (width * scale).round().clamp(1, 1024),
          height: (height * scale).round().clamp(1, 1024),
        );
      },
    );
    image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null || data.lengthInBytes > socialProfilePhotoMaxBytes) {
      throw const FormatException('사진 용량이 커요. 더 작은 사진을 선택해 주세요.');
    }
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('사진을 읽지 못했어요. 다른 사진을 선택해 주세요.');
  } finally {
    image?.dispose();
    codec?.dispose();
  }
}
