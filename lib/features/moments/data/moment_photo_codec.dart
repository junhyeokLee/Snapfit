import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import '../domain/moment_record.dart';

class PreparedMomentPhoto {
  const PreparedMomentPhoto(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width, height;
}

/// Decode one frame and re-encode it without location/camera metadata. Both
/// Flutter web and native use the same bounded photo representation.
Future<PreparedMomentPhoto> prepareMomentPhoto(Uint8List input) async {
  if (input.isEmpty || input.length > 20 * 1024 * 1024) {
    throw const MomentException('20MB 이하의 사진을 선택해 주세요.');
  }
  ui.Codec? codec;
  ui.Image? image;
  try {
    final info = img.findDecoderForData(input)?.startDecode(input);
    if (info != null && info.width * info.height > 40000000) {
      throw const MomentException('사진 크기가 너무 커요. 더 작은 사진을 선택해 주세요.');
    }
    codec = await ui.instantiateImageCodecWithSize(
      await ui.ImmutableBuffer.fromUint8List(input),
      getTargetSize: (width, height) {
        if (width * height > 40000000) {
          throw const MomentException('사진 크기가 너무 커요. 더 작은 사진을 선택해 주세요.');
        }
        final edge = width > height ? width : height;
        final scale = edge > 2560 ? 2560 / edge : 1.0;
        return ui.TargetImageSize(
          width: (width * scale).round().clamp(1, 2560),
          height: (height * scale).round().clamp(1, 2560),
        );
      },
    );
    image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null || data.lengthInBytes > 12 * 1024 * 1024) {
      throw const MomentException('사진 용량이 커요. 더 작은 사진을 선택해 주세요.');
    }
    return PreparedMomentPhoto(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      image.width,
      image.height,
    );
  } on MomentException {
    rethrow;
  } catch (_) {
    throw const MomentException('사진을 읽지 못했어요. 다른 사진을 선택해 주세요.');
  } finally {
    image?.dispose();
    codec?.dispose();
  }
}
