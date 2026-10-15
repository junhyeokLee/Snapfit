import 'dart:typed_data';
import 'dart:io' show File;
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as bitmap;
import 'package:photo_manager/photo_manager.dart';
import 'package:uuid/uuid.dart';

import '../../printing/print_image_header.dart';

const browserPhotoMaxFileBytes = 50000000;
const browserPhotoMaxTotalBytes = 250000000;
const browserPhotoMaxCount = 100;

class BrowserPhotoException implements Exception {
  const BrowserPhotoException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Existing editor models retain AssetEntity, while browser photos never call
/// a mobile photo-library plugin or turn a preview into a print original.
class BrowserPhotoAsset extends AssetEntity {
  BrowserPhotoAsset._({
    required super.id,
    required super.width,
    required super.height,
    required super.title,
    required super.mimeType,
    required super.createDateSecond,
    required this.ownerId,
    required this.originalBytes,
    required this.previewBytes,
    required this.extension,
    required this.contentSha256,
  }) : super(typeInt: 1, orientation: 0);

  final String ownerId;
  final Uint8List originalBytes;
  final Uint8List previewBytes;
  final String extension;
  final String contentSha256;
  int get byteLength => originalBytes.length;

  /// Restore the exact browser original and its stable layer reference.
  /// Draft previews are never promoted to print originals during restoration.
  factory BrowserPhotoAsset.fromStored({
    required String ownerId,
    required String id,
    required String name,
    required int width,
    required int height,
    required int createdAtSecond,
    required Uint8List originalBytes,
    required Uint8List previewBytes,
    required String contentSha256,
  }) {
    if (ownerId.trim().isEmpty ||
        !id.startsWith('browser_') ||
        originalBytes.isEmpty ||
        originalBytes.length > browserPhotoMaxFileBytes ||
        previewBytes.isEmpty ||
        sha256.convert(originalBytes).toString() != contentSha256) {
      throw const BrowserPhotoException('임시 저장한 사진 원본을 확인하지 못했어요.');
    }
    final (mime, extension) = browserPhotoFormat(originalBytes);
    final size = printEncodedImageSize(originalBytes);
    if (width != size.width.toInt() ||
        height != size.height.toInt() ||
        width <= 0 || height <= 0 || width > 20000 || height > 20000 ||
        width * height > 80000000) {
      throw const BrowserPhotoException('임시 저장한 사진 크기를 확인하지 못했어요.');
    }
    return BrowserPhotoAsset._(
      id: id,
      width: width,
      height: height,
      title: name,
      mimeType: mime,
      createDateSecond: createdAtSecond,
      ownerId: ownerId,
      originalBytes: originalBytes,
      previewBytes: previewBytes,
      extension: extension,
      contentSha256: contentSha256,
    );
  }

  static Future<BrowserPhotoAsset> fromBytes({
    required String ownerId,
    required String name,
    required Uint8List bytes,
    DateTime? modifiedAt,
  }) async {
    if (ownerId.trim().isEmpty) {
      throw const BrowserPhotoException('로그인한 뒤 사진을 선택해주세요.');
    }
    if (bytes.isEmpty || bytes.length > browserPhotoMaxFileBytes) {
      throw const BrowserPhotoException('사진 한 장은 50MB 이하로 선택해주세요.');
    }
    final (mime, extension) = browserPhotoFormat(bytes);
    ui.Size size;
    try {
      size = printEncodedImageSize(bytes);
    } catch (_) {
      throw const BrowserPhotoException(
        '읽을 수 없는 사진이에요. 다른 JPG·PNG·WebP 파일을 선택해주세요.',
      );
    }
    if (size.width > 20000 ||
        size.height > 20000 ||
        size.width * size.height > 80000000) {
      throw const BrowserPhotoException(
        '사진은 8천만 화소 이하로 선택해주세요. 원본을 자동 축소하지 않습니다.',
      );
    }
    final preview = await browserPhotoJpegPreview(bytes, maxDimension: 1600);
    return BrowserPhotoAsset._(
      id: 'browser_${const Uuid().v4()}',
      width: size.width.toInt(),
      height: size.height.toInt(),
      title: name,
      mimeType: mime,
      createDateSecond:
          (modifiedAt ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000,
      ownerId: ownerId,
      originalBytes: bytes,
      previewBytes: preview,
      extension: extension,
      contentSha256: sha256.convert(bytes).toString(),
    );
  }

  @override
  Future<Uint8List?> get originBytes async => originalBytes;

  /// Browsers expose selected bytes, never a native filesystem path.
  @override
  Future<File?> get file async => null;

  @override
  Future<Uint8List?> get thumbnailData async => previewBytes;

  @override
  Future<Uint8List?> thumbnailDataWithSize(
    ThumbnailSize size, {
    ThumbnailFormat format = ThumbnailFormat.jpeg,
    int quality = 100,
    PMProgressHandler? progressHandler,
    PMCancelToken? cancelToken,
    int frame = 0,
  }) async => browserPhotoJpegPreview(
    previewBytes,
    maxDimension: size.width > size.height ? size.width : size.height,
    quality: quality.clamp(60, 90).toInt(),
  );
}

(String mime, String extension) browserPhotoFormat(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return ('image/jpeg', 'jpg');
  }
  if (bytes.length >= 8 &&
      bytes[0] == 137 &&
      bytes[1] == 80 &&
      bytes[2] == 78 &&
      bytes[3] == 71 &&
      bytes[4] == 13 &&
      bytes[5] == 10 &&
      bytes[6] == 26 &&
      bytes[7] == 10) {
    return ('image/png', 'png');
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return ('image/webp', 'webp');
  }
  throw const BrowserPhotoException(
    'JPG·PNG·WebP 사진만 선택할 수 있어요. HEIC는 JPG로 내보낸 뒤 선택해주세요.',
  );
}

Future<Uint8List> browserPhotoJpegPreview(
  Uint8List bytes, {
  required int maxDimension,
  int quality = 85,
}) async {
  ui.Codec? codec;
  ui.Image? image;
  try {
    final size = printEncodedImageSize(bytes);
    final scale =
        (maxDimension / (size.width > size.height ? size.width : size.height))
            .clamp(0.0, 1.0);
    codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: (size.width * scale).round().clamp(1, maxDimension).toInt(),
      targetHeight: (size.height * scale)
          .round()
          .clamp(1, maxDimension)
          .toInt(),
      allowUpscaling: false,
    );
    image = (await codec.getNextFrame()).image;
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final decoded = png == null
        ? null
        : bitmap.decodePng(png.buffer.asUint8List());
    if (decoded == null) throw const FormatException('preview_decode_failed');
    return Uint8List.fromList(bitmap.encodeJpg(decoded, quality: quality));
  } catch (_) {
    throw const BrowserPhotoException('사진 미리보기를 만들지 못했어요. 파일을 다시 선택해주세요.');
  } finally {
    image?.dispose();
    codec?.dispose();
  }
}
