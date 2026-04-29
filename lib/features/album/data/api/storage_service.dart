import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../../billing/data/billing_repository.dart';
import '../../../../core/utils/app_logger.dart';

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

class StorageQuotaExceededException implements Exception {
  final int hardLimitBytes;
  final int usedBytes;
  final int incomingBytes;
  final int projectedBytes;
  final String reason;

  const StorageQuotaExceededException({
    required this.hardLimitBytes,
    required this.usedBytes,
    required this.incomingBytes,
    required this.projectedBytes,
    required this.reason,
  });

  @override
  String toString() =>
      'StorageQuotaExceededException(reason: $reason, used: $usedBytes, incoming: $incomingBytes, limit: $hardLimitBytes)';
}

class StorageService {
  StorageService({BillingRepository? billingRepository})
    : _billingRepository = billingRepository;

  final _storage = FirebaseStorage.instance;
  final BillingRepository? _billingRepository;

  /// 프로필 사진 업로드 — 리사이즈(512px, 품질 85) 후 Firebase 업로드 → 다운로드 URL 반환
  Future<String?> uploadProfileImage(File file, String userId) async {
    return uploadFile(
      file,
      'profiles/${userId}_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
  }

  /// Generic file upload method
  Future<String?> uploadFile(File file, String path) async {
    try {
      final bytes = await file.readAsBytes();
      final resized = await _resizeImageBytesToJpeg(
        bytes,
        maxDimension: 1600,
        quality: 85,
      );
      final ref = _storage.ref().child(path);
      await ref.putData(resized, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      AppLogger.warn('Upload error ($path): $e');
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
      final originalBytesSize = await file.length();
      final bytes = await file.readAsBytes();
      final resizedPreviewBytes = await _resizeImageBytesToJpeg(
        bytes,
        maxDimension: previewMaxDimension,
      );
      final incomingBytes = originalBytesSize + resizedPreviewBytes.length;
      await _ensureStorageQuota(incomingBytes);

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
        final previewRef = _storage.ref().child('albums/images/$previewName');
        final previewSnap = await previewRef.putData(
          resizedPreviewBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        previewUrl = await previewSnap.ref.getDownloadURL();
        previewGsPath =
            'gs://${previewSnap.ref.bucket}/${previewSnap.ref.fullPath}';
      }

      // 두 업로드를 동시에 시작하고 기다림
      await Future.wait([uploadOriginal(), uploadPreview()]);
    } on StorageQuotaExceededException {
      rethrow;
    } catch (e) {
      AppLogger.warn('Upload error: $e');
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
      final originalBytes = await FlutterImageCompress.compressWithList(
        pngBytes,
        quality: 85,
        format: CompressFormat.jpeg,
      );
      final previewBytes = await FlutterImageCompress.compressWithList(
        pngBytes,
        minWidth: previewMaxDimension,
        minHeight: previewMaxDimension,
        quality: 80,
        format: CompressFormat.jpeg,
      );
      await _ensureStorageQuota(originalBytes.length + previewBytes.length);

      Future<void> uploadOriginal() async {
        final sw = Stopwatch()..start();
        AppLogger.perf(
          '[PERF] Original Input Size: ${(pngBytes.length / 1024).toStringAsFixed(2)} KB',
        );
        AppLogger.perf(
          '[PERF] Native Compress(Original): ${sw.elapsedMilliseconds}ms, Size: ${(originalBytes.length / 1024).toStringAsFixed(2)} KB',
        );

        final originalRef = _storage.ref().child('albums/covers/$originalName');
        final originalSnap = await originalRef.putData(
          originalBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        AppLogger.perf('[PERF] Upload(Original): ${sw.elapsedMilliseconds}ms');
        originalUrl = await originalSnap.ref.getDownloadURL();
        originalGsPath =
            'gs://${originalSnap.ref.bucket}/${originalSnap.ref.fullPath}';
      }

      Future<void> uploadPreview() async {
        final sw = Stopwatch()..start();
        AppLogger.perf(
          '[PERF] Native Compress(Preview): ${sw.elapsedMilliseconds}ms, Size: ${(previewBytes.length / 1024).toStringAsFixed(2)} KB',
        );

        final previewRef = _storage.ref().child('albums/covers/$previewName');
        final previewSnap = await previewRef.putData(
          previewBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        AppLogger.perf('[PERF] Upload(Preview): ${sw.elapsedMilliseconds}ms');
        previewUrl = await previewSnap.ref.getDownloadURL();
        previewGsPath =
            'gs://${previewSnap.ref.bucket}/${previewSnap.ref.fullPath}';
      }

      await Future.wait([uploadOriginal(), uploadPreview()]);
    } on StorageQuotaExceededException {
      rethrow;
    } catch (e) {
      AppLogger.warn('Upload cover error: $e');
    }
    return UploadedUrls(
      originalUrl: originalUrl,
      previewUrl: previewUrl,
      originalGsPath: originalGsPath,
      previewGsPath: previewGsPath,
    );
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
      AppLogger.warn('Native compress error: $e');
      return bytes;
    }
  }

  Future<void> _ensureStorageQuota(int incomingBytes) async {
    if (_billingRepository == null) return;
    if (incomingBytes <= 0) return;

    final result = await _billingRepository.preflightStorage(
      incomingBytes: incomingBytes,
    );
    if (result.allowed) return;

    throw StorageQuotaExceededException(
      hardLimitBytes: result.hardLimitBytes,
      usedBytes: result.usedBytes,
      incomingBytes: result.incomingBytes,
      projectedBytes: result.projectedBytes,
      reason: result.reason,
    );
  }
}
