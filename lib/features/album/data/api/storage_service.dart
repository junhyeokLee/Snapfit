import 'dart:io';
import 'dart:typed_data';
import 'dart:typed_data' as ui;
import 'dart:ui' as ui;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:image/image.dart' as img;

class UploadedUrls {
  final String? originalUrl;
  final String? previewUrl;
  final String? thumbnailUrl;
  /// Firebase Storage gs:// 경로 (원본/미리보기)
  final String? originalGsPath;
  final String? previewGsPath;

  const UploadedUrls({
    this.originalUrl,
    this.previewUrl,
    this.thumbnailUrl,
    this.originalGsPath,
    this.previewGsPath,
  });
}

class StorageService {
  final _storage = FirebaseStorage.instance;

  /// 운영급: 원본(프린트용) + 미리보기(앱용) URL 업로드
  /// - 하위 호환을 위해 호출부가 previewUrl을 imageUrl로 미러링해도 됨
  Future<UploadedUrls> uploadImageVariants(
    AssetEntity asset, {
    int previewMaxDimension = 1600,
  }) async {
    String? originalUrl;
    String? previewUrl;
    String? originalGsPath;
    String? previewGsPath;
    try {
      final File? file = await asset.file;
      if (file == null) return const UploadedUrls();

      // 파일명 중복 방지 (고유 ID 생성)
      final ts = DateTime.now().microsecondsSinceEpoch;
      final originalName = '${ts}_orig.jpg';
      final previewName = '${ts}_preview.jpg';

      // 1) 원본 업로드
      final originalRef = _storage.ref().child('albums/images/$originalName');
      final originalSnap = await originalRef.putFile(file);
      originalUrl = await originalSnap.ref.getDownloadURL();
      originalGsPath =
          'gs://${originalSnap.ref.bucket}/${originalSnap.ref.fullPath}';

      // 2) 미리보기(다운스케일) 생성 후 업로드 (JPEG로 인코딩하여 용량 절감)
      final bytes = await file.readAsBytes();
      final resized = await _resizeImageBytesToJpeg(
        bytes,
        maxDimension: previewMaxDimension,
      );
      final previewRef = _storage.ref().child('albums/images/$previewName');
      final previewSnap = await previewRef.putData(
        resized,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      previewUrl = await previewSnap.ref.getDownloadURL();
      previewGsPath =
          'gs://${previewSnap.ref.bucket}/${previewSnap.ref.fullPath}';
    } catch (e) {
      // ignore: avoid_print
      print('Upload Error: $e');
      return UploadedUrls(
        originalUrl: originalUrl,
        previewUrl: previewUrl,
        originalGsPath: originalGsPath,
        previewGsPath: previewGsPath,
      );
    }
    return UploadedUrls(
      originalUrl: originalUrl,
      previewUrl: previewUrl,
      originalGsPath: originalGsPath,
      previewGsPath: previewGsPath,
    );
  }

  /// 커버 전체를 캡처한 PNG 바이트를 업로드해서 대표 이미지로 사용
  /// 운영급: 커버 원본/미리보기 업로드
  Future<UploadedUrls> uploadCoverVariants(
    Uint8List pngBytes, {
    int originalMaxDimension = 4096,
    int previewMaxDimension = 1024,
  }) async {
    String? originalUrl;
    String? previewUrl;
    String? originalGsPath;
    String? previewGsPath;
    try {
      final ts = DateTime.now().microsecondsSinceEpoch;
      final originalName = '${ts}_orig.png';
      final previewName = '${ts}_preview.jpg';

      final originalBytes = await _resizeImageBytesToPng(
        pngBytes,
        maxDimension: originalMaxDimension,
      );
      // 커버 미리보기는 JPEG로 인코딩
      final previewBytes = await _resizeImageBytesToJpeg(
        pngBytes,
        maxDimension: previewMaxDimension,
      );

      final originalRef = _storage.ref().child('albums/covers/$originalName');
      final originalSnap = await originalRef.putData(
        originalBytes,
        SettableMetadata(contentType: 'image/png'),
      );
      originalUrl = await originalSnap.ref.getDownloadURL();
      originalGsPath =
          'gs://${originalSnap.ref.bucket}/${originalSnap.ref.fullPath}';

      final previewRef = _storage.ref().child('albums/covers/$previewName');
      final previewSnap = await previewRef.putData(
        previewBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      previewUrl = await previewSnap.ref.getDownloadURL();
      previewGsPath =
          'gs://${previewSnap.ref.bucket}/${previewSnap.ref.fullPath}';
    } catch (e) {
      // ignore: avoid_print
      print('Upload Cover Error: $e');
      return UploadedUrls(
        originalUrl: originalUrl,
        previewUrl: previewUrl,
        originalGsPath: originalGsPath,
        previewGsPath: previewGsPath,
      );
    }
    return UploadedUrls(
      originalUrl: originalUrl,
      previewUrl: previewUrl,
      originalGsPath: originalGsPath,
      previewGsPath: previewGsPath,
    );
  }

  /// 바이트를 다운스케일하여 PNG로 반환 (패키지 없이 `ui.instantiateImageCodec` 사용)
  Future<Uint8List> _resizeImageBytesToPng(
    Uint8List bytes, {
    required int maxDimension,
  }) async {
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image src = frame.image;

    final int w = src.width;
    final int h = src.height;
    final int longest = w > h ? w : h;
    if (longest <= maxDimension) {
      // 입력이 이미 PNG가 아닐 수도 있지만, 그대로 업로드하면 용량이 커질 수 있어
      // 여기서는 "리사이즈 불필요"인 경우만 그대로 반환한다.
      return bytes;
    }

    final double scale = maxDimension / longest;
    final int targetW = (w * scale).round().clamp(1, maxDimension);
    final int targetH = (h * scale).round().clamp(1, maxDimension);

    final ui.Codec resizedCodec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetW,
      targetHeight: targetH,
    );
    final ui.FrameInfo resizedFrame = await resizedCodec.getNextFrame();
    final ui.ByteData? out =
        await resizedFrame.image.toByteData(format: ui.ImageByteFormat.png);
    return out?.buffer.asUint8List() ?? bytes;
  }

  /// 바이트를 다운스케일하여 JPEG로 반환 (image 패키지 사용)
  Future<Uint8List> _resizeImageBytesToJpeg(
    Uint8List bytes, {
    required int maxDimension,
    int quality = 80,
  }) async {
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    final int w = decoded.width;
    final int h = decoded.height;
    final int longest = w > h ? w : h;
    if (longest <= maxDimension) {
      return Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
    }

    final double scale = maxDimension / longest;
    final int targetW = (w * scale).round().clamp(1, maxDimension);
    final int targetH = (h * scale).round().clamp(1, maxDimension);

    final img.Image resized = img.copyResize(
      decoded,
      width: targetW,
      height: targetH,
      interpolation: img.Interpolation.average,
    );
    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  }
}