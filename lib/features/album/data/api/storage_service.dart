import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';
import '../../../billing/data/billing_repository.dart';
import '../../../../core/utils/app_logger.dart';
import '../gallery/browser_photo_asset.dart';

class UploadedUrls {
  final String? originalUrl;
  final String? previewUrl;
  final String? thumbnailUrl;

  /// Storage object path marker. New uploads use supabase://album-assets/...
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

class AiAlbumPreviewUpload {
  const AiAlbumPreviewUpload({
    required this.assetId,
    required this.path,
    required this.storageUri,
  });

  final String assetId;
  final String path;
  final String storageUri;
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
  StorageService({
    BillingRepository? billingRepository,
    SupabaseClient? supabase,
  }) : _billingRepository = billingRepository,
       _supabase = supabase;

  final SupabaseClient? _supabase;
  final BillingRepository? _billingRepository;

  static String userScopedAlbumAssetPath({
    required String userId,
    required String relativePath,
    int? albumId,
  }) {
    final cleanUserId = userId.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(cleanUserId)) {
      throw StateError('Authenticated user is required for album uploads.');
    }
    var cleanPath = relativePath.startsWith('/')
        ? relativePath.substring(1)
        : relativePath;
    if (cleanPath.startsWith('$cleanUserId/')) {
      cleanPath = cleanPath.substring(cleanUserId.length + 1);
    }
    if (cleanPath.contains('\\') ||
        cleanPath
            .split('/')
            .any((part) => part.isEmpty || part == '.' || part == '..')) {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'Invalid storage path.',
      );
    }
    if (albumId != null) {
      if (albumId <= 0 || !cleanPath.startsWith('albums/')) {
        throw ArgumentError.value(
          albumId,
          'albumId',
          'A saved album is required.',
        );
      }
      cleanPath = 'albums/$albumId/${cleanPath.substring('albums/'.length)}';
    }
    return '$cleanUserId/$cleanPath';
  }

  static String albumAssetStorageUri(String path) =>
      'supabase://album-assets/$path';

  static String userScopedAiAlbumPreviewPath({
    required String userId,
    required String draftId,
    required String assetId,
  }) {
    final cleanUserId = _storageSegment(userId);
    if (cleanUserId.isEmpty) {
      throw StateError('Authenticated user is required for AI album previews.');
    }
    final cleanDraftId = _storageSegment(draftId);
    if (cleanDraftId.isEmpty) {
      throw ArgumentError.value(draftId, 'draftId', 'Draft id is required.');
    }
    final cleanAssetId = _storageSegment(assetId);
    if (cleanAssetId.isEmpty) {
      throw ArgumentError.value(assetId, 'assetId', 'Asset id is required.');
    }
    return '$cleanUserId/$cleanDraftId/$cleanAssetId.jpg';
  }

  static String aiAlbumPreviewStorageUri(String path) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return 'supabase://ai-album-previews/$cleanPath';
  }

  static String _storageSegment(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
        .replaceAll('..', '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^[-.]+|[-.]+$'), '');
  }

  /// 프로필 사진 업로드 — 리사이즈 후 Supabase Storage URL 반환
  Future<String?> uploadProfileImage(File file, String userId) async {
    return uploadFile(
      file,
      'profiles/${userId}_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
  }

  /// Generic file upload method
  Future<String?> uploadFile(File file, String path) async {
    final client = _requireSupabase();
    final owner = _uploadOwner(client);
    try {
      final bytes = await file.readAsBytes();
      _checkUploadOwner(client, owner);
      final resized = await _resizeImageBytesToJpeg(
        bytes,
        maxDimension: 1600,
        quality: 85,
      );
      _checkUploadOwner(client, owner);
      final normalizedPath = _albumAssetPath(client, path, owner: owner);
      AppLogger.debug(
        '[StorageUpload] bucket=album-assets path=$normalizedPath',
      );
      await client.storage
          .from('album-assets')
          .uploadBinary(
            normalizedPath,
            resized,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
      _checkUploadOwner(client, owner);
      return albumAssetStorageUri(normalizedPath);
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
    int? albumId,
  }) async {
    if (asset is BrowserPhotoAsset) {
      return _uploadBrowserPhotoVariants(asset, albumId: albumId);
    }
    final client = _requireSupabase();
    final owner = _uploadOwner(client);
    final stamp = const Uuid().v4();
    final originalPath = _albumAssetPath(
      client,
      'albums/images/${stamp}_orig.jpg',
      owner: owner,
      albumId: albumId,
    );
    final previewPath = _albumAssetPath(
      client,
      'albums/images/${stamp}_preview.jpg',
      owner: owner,
      albumId: albumId,
    );
    final uploaded = <String>[];
    try {
      final File? file = await asset.file;
      _checkUploadOwner(client, owner);
      if (file == null) throw StateError('album_photo_unavailable');
      final bytes = await file.readAsBytes();
      _checkUploadOwner(client, owner);
      final resizedPreviewBytes = await _resizeImageBytesToJpeg(
        bytes,
        maxDimension: previewMaxDimension,
      );
      _checkUploadOwner(client, owner);
      final incomingBytes = bytes.length + resizedPreviewBytes.length;
      await _ensureStorageQuota(incomingBytes);
      _checkUploadOwner(client, owner);
      await client.storage
          .from('album-assets')
          .uploadBinary(
            originalPath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
      uploaded.add(originalPath);
      _checkUploadOwner(client, owner);
      await client.storage
          .from('album-assets')
          .uploadBinary(
            previewPath,
            resizedPreviewBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
      uploaded.add(previewPath);
      _checkUploadOwner(client, owner);
      return _uploadedPair(originalPath, previewPath);
    } catch (_) {
      await _removePartialUpload(client, owner, uploaded);
      rethrow;
    }
  }

  Future<UploadedUrls> _uploadBrowserPhotoVariants(
    BrowserPhotoAsset asset, {
    int? albumId,
  }) async {
    final client = _requireSupabase();
    final owner = client.auth.currentUser?.id;
    void sameOwner() {
      if (owner == null ||
          owner != asset.ownerId ||
          client.auth.currentUser?.id != owner) {
        throw StateError('browser_photo_owner_changed');
      }
    }

    sameOwner();
    await _ensureStorageQuota(
      asset.originalBytes.length + asset.previewBytes.length,
    );
    sameOwner();
    final stamp = const Uuid().v4();
    final originalPath = userScopedAlbumAssetPath(
      userId: owner!,
      relativePath:
          'albums/images/${stamp}_${asset.id}_orig.${asset.extension}',
      albumId: albumId,
    );
    final previewPath = userScopedAlbumAssetPath(
      userId: owner,
      relativePath: 'albums/images/${stamp}_${asset.id}_preview.jpg',
      albumId: albumId,
    );
    final uploaded = <String>[];
    try {
      await client.storage
          .from('album-assets')
          .uploadBinary(
            originalPath,
            asset.originalBytes,
            fileOptions: FileOptions(
              contentType: asset.mimeType,
              upsert: false,
            ),
          );
      uploaded.add(originalPath);
      sameOwner();
      await client.storage
          .from('album-assets')
          .uploadBinary(
            previewPath,
            asset.previewBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
      uploaded.add(previewPath);
      sameOwner();
      return _uploadedPair(originalPath, previewPath);
    } catch (_) {
      // A partial pair must not be attached to an album as a successful save.
      await _removePartialUpload(client, owner, uploaded);
      rethrow;
    }
  }

  Future<List<AiAlbumPreviewUpload>> uploadAiAlbumPreviews({
    required String draftId,
    required List<AssetEntity> assets,
    int maxDimension = 512,
  }) async {
    if (assets.isEmpty) return const [];
    final supabase = _requireSupabase();
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) {
      throw StateError('Authenticated user is required for AI album previews.');
    }

    final uploads = <AiAlbumPreviewUpload>[];
    for (final asset in assets) {
      if (asset is BrowserPhotoAsset && asset.ownerId != userId) {
        throw StateError('browser_photo_owner_changed');
      }
      final bytes = await asset.thumbnailDataWithSize(
        ThumbnailSize.square(maxDimension),
        format: ThumbnailFormat.jpeg,
        quality: 72,
      );
      if (bytes == null || bytes.isEmpty) continue;
      if (supabase.auth.currentUser?.id != userId)
        throw StateError('browser_photo_owner_changed');
      final path = userScopedAiAlbumPreviewPath(
        userId: userId,
        draftId: draftId,
        assetId: asset.id,
      );
      AppLogger.debug('[StorageUpload] bucket=ai-album-previews path=$path');
      await supabase.storage
          .from('ai-album-previews')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
      if (supabase.auth.currentUser?.id != userId)
        throw StateError('browser_photo_owner_changed');
      uploads.add(
        AiAlbumPreviewUpload(
          assetId: asset.id,
          path: path,
          storageUri: aiAlbumPreviewStorageUri(path),
        ),
      );
    }
    return uploads;
  }

  Future<void> deleteAiAlbumPreviews(Iterable<String> paths) async {
    final normalized = paths
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
    if (normalized.isEmpty) return;
    await _requireSupabase().storage
        .from('ai-album-previews')
        .remove(normalized);
  }

  /// 커버 전체를 캡처한 PNG 바이트를 업로드해서 대표 이미지로 사용
  /// 운영급: 커버 원본/미리보기 업로드
  Future<UploadedUrls> uploadCoverVariants(
    Uint8List pngBytes, {
    int originalMaxDimension = 4096,
    int previewMaxDimension = 1024,
    int? albumId,
  }) async {
    final client = _requireSupabase();
    final owner = _uploadOwner(client);
    final stamp = const Uuid().v4();
    final originalPath = _albumAssetPath(
      client,
      'albums/covers/${stamp}_orig.jpg',
      owner: owner,
      albumId: albumId,
    );
    final previewPath = _albumAssetPath(
      client,
      'albums/covers/${stamp}_preview.jpg',
      owner: owner,
      albumId: albumId,
    );
    final uploaded = <String>[];
    try {
      final originalBytes = kIsWeb
          ? await browserPhotoJpegPreview(
              pngBytes,
              maxDimension: originalMaxDimension,
              quality: 95,
            )
          : await FlutterImageCompress.compressWithList(
              pngBytes,
              quality: 85,
              format: CompressFormat.jpeg,
            );
      _checkUploadOwner(client, owner);
      final previewBytes = kIsWeb
          ? await browserPhotoJpegPreview(
              pngBytes,
              maxDimension: previewMaxDimension,
              quality: 80,
            )
          : await FlutterImageCompress.compressWithList(
              pngBytes,
              minWidth: previewMaxDimension,
              minHeight: previewMaxDimension,
              quality: 80,
              format: CompressFormat.jpeg,
            );
      _checkUploadOwner(client, owner);
      await _ensureStorageQuota(originalBytes.length + previewBytes.length);
      _checkUploadOwner(client, owner);
      await client.storage
          .from('album-assets')
          .uploadBinary(
            originalPath,
            originalBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
      uploaded.add(originalPath);
      _checkUploadOwner(client, owner);
      await client.storage
          .from('album-assets')
          .uploadBinary(
            previewPath,
            previewBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
      uploaded.add(previewPath);
      _checkUploadOwner(client, owner);
      return _uploadedPair(originalPath, previewPath);
    } catch (_) {
      await _removePartialUpload(client, owner, uploaded);
      rethrow;
    }
  }

  UploadedUrls _uploadedPair(String originalPath, String previewPath) =>
      UploadedUrls(
        originalUrl: albumAssetStorageUri(originalPath),
        previewUrl: albumAssetStorageUri(previewPath),
        originalGsPath: albumAssetStorageUri(originalPath),
        previewGsPath: albumAssetStorageUri(previewPath),
      );

  String _uploadOwner(SupabaseClient client) {
    final owner = client.auth.currentUser?.id;
    if (owner == null || owner.trim().isEmpty) {
      throw StateError('Authenticated user is required for album uploads.');
    }
    return owner;
  }

  void _checkUploadOwner(SupabaseClient client, String owner) {
    if (client.auth.currentUser?.id != owner) {
      throw StateError('album_photo_owner_changed');
    }
  }

  Future<void> _removePartialUpload(
    SupabaseClient client,
    String? owner,
    List<String> paths,
  ) async {
    // Never perform cleanup using another account's credentials. A late orphan
    // is private and can be cleaned by its uploader's later retry/retention.
    if (owner == null || client.auth.currentUser?.id != owner || paths.isEmpty)
      return;
    try {
      await client.storage.from('album-assets').remove(paths);
    } catch (_) {
      // Cleanup cannot turn a failed pair into a successful album save.
    }
  }

  /// Server policies keep any object already referenced by a committed album.
  /// A lost save response must never turn this cleanup into photo deletion.
  Future<void> removeUnreferencedAlbumUploads(
    Iterable<String> references, {
    required String expectedOwner,
  }) async {
    final client = _requireSupabase();
    if (client.auth.currentUser?.id != expectedOwner) return;
    final paths = <String>{};
    for (final reference in references) {
      final prefix = 'supabase://album-assets/$expectedOwner/';
      if (reference.startsWith(prefix)) {
        paths.add(reference.substring('supabase://album-assets/'.length));
      }
    }
    for (final path in paths) {
      if (client.auth.currentUser?.id != expectedOwner) return;
      try {
        await client.storage.from('album-assets').remove([path]);
      } catch (_) {
        // Referenced objects and uncertain cleanup stay private and intact.
      }
    }
  }

  /// 바이트를 다운스케일하여 JPEG로 반환 (native compressor 사용)
  Future<Uint8List> _resizeImageBytesToJpeg(
    Uint8List bytes, {
    required int maxDimension,
    int quality = 80,
  }) async {
    if (kIsWeb)
      return browserPhotoJpegPreview(
        bytes,
        maxDimension: maxDimension,
        quality: quality,
      );
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

  SupabaseClient _requireSupabase() {
    final supabase = _supabase;
    if (supabase == null) {
      throw StateError(
        'Supabase Storage client is required for album uploads.',
      );
    }
    return supabase;
  }

  String _albumAssetPath(
    SupabaseClient supabase,
    String relativePath, {
    String? owner,
    int? albumId,
  }) {
    final userId = supabase.auth.currentUser?.id;
    if (owner != null) _checkUploadOwner(supabase, owner);
    if (userId == null || userId.trim().isEmpty) {
      throw StateError('Authenticated user is required for album uploads.');
    }
    return userScopedAlbumAssetPath(
      userId: userId,
      relativePath: relativePath,
      albumId: albumId,
    );
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
