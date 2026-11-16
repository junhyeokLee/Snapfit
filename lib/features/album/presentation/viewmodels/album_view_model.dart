// lib/features/album/presentation/viewmodels/album_view_model.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/api/album_provider.dart';
import '../../data/dto/request/create_album_request.dart';
import '../../domain/entities/album.dart';
import '../providers/album_edit_session_provider.dart';

part 'album_view_model.g.dart';

@Riverpod(keepAlive: true)
class AlbumViewModel extends _$AlbumViewModel {
  int _operation = 0;
  bool _disposed = false;
  late AlbumEditorOwnerReader _readOwner;
  String? _owner;

  bool _current(int operation, String? owner) =>
      !_disposed && operation == _operation && _readOwner() == owner;

  @override
  FutureOr<Album?> build() {
    _disposed = false;
    _readOwner = ref.read(albumEditorOwnerReaderProvider);
    _owner = _readOwner();
    ref.onDispose(() {
      _disposed = true;
      _operation++;
    });
    ref.listen(albumEditorOwnerChangesProvider, (_, value) {
      if (!value.hasValue || value.value == _owner) return;
      _owner = value.value;
      _operation++;
      state = const AsyncData(null);
    });
    return null;
  }

  Future<void> createAlbum({
    required String coverLayersJson,
    required String ratio,
    String title = '', // 앨범 제목
    int targetPages = 0, // 목표 페이지 수
    required String coverImageUrl,
    required String coverThumbnailUrl,
    String? coverOriginalUrl,
    String? coverPreviewUrl,
    String coverTheme = '',
    String? requestId,
    String? expectedUserId,
  }) async {
    final operation = ++_operation;
    final owner = _readOwner();
    state = const AsyncLoading();

    try {
      final repository = ref.read(albumRepositoryProvider);
      final album = await repository.createAlbum(
        CreateAlbumRequest(
          ratio: ratio,
          title: title, // 앨범 제목 전달
          targetPages: targetPages, // 목표 페이지 수 전달
          coverLayersJson: coverLayersJson,
          coverImageUrl: coverImageUrl,
          coverThumbnailUrl: coverThumbnailUrl,
          coverOriginalUrl: coverOriginalUrl,
          coverPreviewUrl: coverPreviewUrl,
          coverTheme: coverTheme,
        ),
        requestId: requestId,
        expectedUserId: expectedUserId,
      );
      if (_current(operation, owner)) state = AsyncData(album);
    } catch (e, st) {
      if (_current(operation, owner)) state = AsyncError(e, st);
    }
  }

  Future<void> updateAlbum({
    required int albumId,
    String? expectedUpdatedAt,
    String? requestId,
    String? expectedUserId,
    required String coverLayersJson,
    required String ratio,
    String title = '', // 앨범 제목
    int targetPages = 0, // 목표 페이지 수
    required String coverImageUrl,
    required String coverThumbnailUrl,
    String? coverOriginalUrl,
    String? coverPreviewUrl,
    String coverTheme = '',
  }) async {
    final operation = ++_operation;
    final owner = _readOwner();
    state = const AsyncLoading();

    try {
      final repository = ref.read(albumRepositoryProvider);
      final album = await repository.updateAlbum(
        albumId,
        CreateAlbumRequest(
          ratio: ratio,
          title: title, // 앨범 제목 전달
          targetPages: targetPages, // 목표 페이지 수 전달
          coverLayersJson: coverLayersJson,
          coverImageUrl: coverImageUrl,
          coverThumbnailUrl: coverThumbnailUrl,
          coverOriginalUrl: coverOriginalUrl,
          coverPreviewUrl: coverPreviewUrl,
          coverTheme: coverTheme,
        ),
        expectedUpdatedAt: expectedUpdatedAt,
        requestId: requestId,
        expectedUserId: expectedUserId,
      );
      if (_current(operation, owner)) state = AsyncData(album);
    } on DioException catch (e, st) {
      if (!_current(operation, owner)) return;
      final statusCode = e.response?.statusCode;
      if (statusCode == 405) {
        state = AsyncError(
          Exception('서버에서 앨범 수정을 지원하지 않습니다. (PUT /api/albums/{id} 필요)'),
          st,
        );
      } else if (statusCode == 500) {
        state = AsyncError(Exception('서버 오류가 발생했습니다. 백엔드 로그를 확인해주세요.'), st);
      } else {
        state = AsyncError(e, st);
      }
    } catch (e, st) {
      if (_current(operation, owner)) state = AsyncError(e, st);
    }
  }

  void acceptSavedAlbum(Album album) => state = AsyncData(album);
}
