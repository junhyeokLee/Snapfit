import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/api/storage_service.dart';
import 'package:snap_fit/features/album/data/dto/request/create_album_request.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/album_edit_failure.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';

import 'mock_repositories.dart' show MockAlbumRepository;
import '../unit/album_editor_view_model_test.dart'
    show FakeAlbumPersistenceService, FakeStorageService;

/// Records the real create boundary while keeping all test work off the server.
class RecordingCreationAlbums extends MockAlbumRepository {
  RecordingCreationAlbums({required this.owner, this.albumId = 71});
  final String owner;
  final int albumId;
  static const revision = '2026-11-11T00:00:00.123456Z';
  int creates = 0, updates = 0, reads = 0;
  Completer<void>? creating;
  Album? created;
  final requests = <CreateAlbumRequest>[];
  final requestIds = <String?>[];
  final requestedOwners = <String?>[];

  @override
  Future<Album> createAlbum(
    CreateAlbumRequest request, {
    String? requestId,
    String? expectedUserId,
  }) async {
    creates++;
    requests.add(request);
    requestIds.add(requestId);
    requestedOwners.add(expectedUserId);
    if (expectedUserId != owner) throw StateError('Unexpected creation owner');
    if (creating != null) await creating!.future;
    return created = _album(request);
  }

  Album _album(CreateAlbumRequest request) => Album(
    id: albumId,
    userId: owner,
    memberRole: 'OWNER',
    title: request.title,
    ratio: request.ratio,
    targetPages: request.targetPages,
    updatedAt: revision,
    coverLayersJson: request.coverLayersJson,
  );

  @override
  Future<Album> updateAlbum(
    int id,
    CreateAlbumRequest request, {
    String? expectedUpdatedAt,
    String? requestId,
    String? expectedUserId,
  }) async {
    updates++;
    if (id != albumId || expectedUserId != owner) {
      throw StateError('Unexpected update target');
    }
    return created = _album(request);
  }

  @override
  Future<Album> fetchAlbum(String id) async {
    reads++;
    return created ?? Album(
      id: int.parse(id),
      userId: owner,
      memberRole: 'OWNER',
      ratio: '1.0',
      updatedAt: revision,
    );
  }

  @override
  Future<List<Album>> fetchMyAlbums() async => [];
}

/// Reuses the upload fake but retains the owner, role and revision of create.
class OwnerPreservingCreationPersistence extends FakeAlbumPersistenceService {
  OwnerPreservingCreationPersistence(this.albums);
  final RecordingCreationAlbums albums;
  int calls = 0;

  @override
  Future<Album> performBackgroundUpload({
    required int albumId,
    required String expectedUpdatedAt,
    required String expectedUserId,
    required String requestId,
    bool Function()? canContinue,
    void Function(CreateAlbumRequest)? onPrepared,
    void Function(LayerModel before, LayerModel after)? onLayerUploaded,
    void Function(UploadedUrls)? onUploaded,
    required Size canvasSize,
    required List<LayerModel> currentLayers,
    required Uint8List? coverImageBytes,
    required String themeLabel,
    required String title,
    required double coverRatio,
    required int targetPages,
    Map<String, dynamic>? printProduct,
    String? sourceTemplateProductKey,
    bool swallowErrors = true,
    void Function(int completed, int total)? onProgress,
  }) async {
    calls++;
    if (canContinue?.call() == false || expectedUserId != albums.owner) {
      throw const AlbumEditSessionChanged();
    }
    final created = albums.created;
    if (created == null || created.id != albumId) {
      throw StateError('An upload fake requires the confirmed create response');
    }
    return created.copyWith(updatedAt: expectedUpdatedAt);
  }
}

List<Override> unifiedCreationBackendOverrides({
  required RecordingCreationAlbums albums,
}) => [
  albumRepositoryProvider.overrideWithValue(albums),
  albumEditorServiceProvider.overrideWithValue(const AlbumEditorService()),
  albumPersistenceServiceProvider.overrideWithValue(
    OwnerPreservingCreationPersistence(albums),
  ),
  storageServiceProvider.overrideWithValue(FakeStorageService()),
];
