import 'dart:io';
import 'dart:typed_data';
import 'dart:typed_data' as ui;
import 'dart:ui' as ui;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_image_compress/flutter_image_compress.dart';

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

  /// 프로필 사진 업로드 — 리사이즈(512px, 품질 85) 후 Firebase 업로드 → 다운로드 URL 반환
  Future<String?> uploadProfileImage(File file, String userId) async {
    try {
      final bytes = await file.readAsBytes();
      final resized = await _resizeImageBytesToJpeg(
        bytes,
        maxDimension: 512,
        quality: 85,
      );
      final ts = DateTime.now().microsecondsSinceEpoch;
      final ref = _storage.ref().child('profiles/${userId}_$ts.jpg');
      await ref.putData(
        resized,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await ref.getDownloadURL();
    } catch (e) {
      // ignore: avoid_print
      print('Profile upload error: $e');
      return null;
    }
  }

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

      // 병렬 처리를 위한 Future 정의
      Future<void> uploadOriginal() async {
        final originalRef = _storage.ref().child('albums/images/$originalName');
        final originalSnap = await originalRef.putFile(file);
        originalUrl = await originalSnap.ref.getDownloadURL();
        originalGsPath =
            'gs://${originalSnap.ref.bucket}/${originalSnap.ref.fullPath}';
      }

      Future<void> uploadPreview() async {
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
      }

      // 두 업로드를 동시에 시작하고 기다림
      await Future.wait([uploadOriginal(), uploadPreview()]);

    } catch (e) {
      // ignore: avoid_print
      print('Upload Error: $e');
      // 에러 발생 시 부분 성공한 URL이라도 반환할지, 아니면 실패 처리할지는 정책에 따라 결정
      // 여기서는 일단 있는 정보라도 반환
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
      // [OPTIMIZATION] PNG(10MB+) 대신 고화질 JPEG(2MB) 사용
      // 인쇄 품질(95%)을 유지하면서 업로드 속도를 획기적으로 개선
      final originalName = '${ts}_orig.jpg';
      final previewName = '${ts}_preview.jpg';

      Future<void> uploadOriginal() async {
        final sw = Stopwatch()..start();
        print('[PERF] Original Input Size: ${(pngBytes.length / 1024).toStringAsFixed(2)} KB');
        
        // Native Compressor를 사용하여 빠르고 효율적으로 변환
        final originalBytes = await FlutterImageCompress.compressWithList(
          pngBytes,
          quality: 85, // 95 -> 85 (인쇄 품질 유지하되 용량 대폭 감소)
          format: CompressFormat.jpeg,
        );
        print('[PERF] Native Compress(Original): ${sw.elapsedMilliseconds}ms, Size: ${(originalBytes.length / 1024).toStringAsFixed(2)} KB');

        final originalRef = _storage.ref().child('albums/covers/$originalName');
        final originalSnap = await originalRef.putData(
          originalBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        print('[PERF] Upload(Original): ${sw.elapsedMilliseconds}ms');
        originalUrl = await originalSnap.ref.getDownloadURL();
        originalGsPath =
            'gs://${originalSnap.ref.bucket}/${originalSnap.ref.fullPath}';
      }

      Future<void> uploadPreview() async {
        final sw = Stopwatch()..start();
        // 앱용 미리보기: 리사이징 + 적정 화질
        final previewBytes = await FlutterImageCompress.compressWithList(
          pngBytes,
          minWidth: previewMaxDimension,
          minHeight: previewMaxDimension,
          quality: 80,
          format: CompressFormat.jpeg,
        );
        print('[PERF] Native Compress(Preview): ${sw.elapsedMilliseconds}ms, Size: ${(previewBytes.length / 1024).toStringAsFixed(2)} KB');
        
        final previewRef = _storage.ref().child('albums/covers/$previewName');
        final previewSnap = await previewRef.putData(
          previewBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        print('[PERF] Upload(Preview): ${sw.elapsedMilliseconds}ms');
        previewUrl = await previewSnap.ref.getDownloadURL();
        previewGsPath =
            'gs://${previewSnap.ref.bucket}/${previewSnap.ref.fullPath}';
      }

      await Future.wait([uploadOriginal(), uploadPreview()]);

    } catch (e) {
      // ignore: avoid_print
      print('Upload Cover Error: $e');
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

  /// 바이트를 다운스케일하여 JPEG로 반환 (native compressor 사용)
  Future<Uint8List> _resizeImageBytesToJpeg(
    Uint8List bytes, {
    required int maxDimension,
    int quality = 80,
  }) async {
    try {
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: maxDimension,
        minHeight: maxDimension,
        quality: quality,
      );
      return compressed;
    } catch (e) {
      // fallback: 에러 시 원본 반환 (혹은 image 패키지 사용)
      print("Native compress error: $e");
      return bytes;
    }
  }
}