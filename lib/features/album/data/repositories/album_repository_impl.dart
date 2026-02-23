import '../../domain/repositories/album_repository.dart';
import '../api/album_api.dart';
import '../dto/request/create_album_request.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/album.dart';

import '../../../../core/interceptors/token_storage.dart';

class AlbumRepositoryImpl implements AlbumRepository {
  final AlbumApi api;
  final TokenStorage tokenStorage;

  AlbumRepositoryImpl(
    this.api, {
    required this.tokenStorage,
  });

  Future<String> _getUserId() async {
    final id = await tokenStorage.getUserId();
    if (id == null || id.isEmpty) {
      // 로그인이 안 된 상태라면 빈 문자열 반환 (API에서 처리하거나 401 유도)
      // 혹은 예외를 던져서 진입을 막을 수도 있음
      return '';
    }
    return id;
  }

  @override
  Future<Album> createAlbum(CreateAlbumRequest request) async {
    final userId = await _getUserId();
    return api.createAlbum(request.copyWith(userId: userId));
  }

  @override
  Future<Album> updateAlbum(int albumId, CreateAlbumRequest request) async {
    final userId = await _getUserId();
    return api.updateAlbum(albumId, request, userId);
  }

  @override
  Future<Album> fetchAlbum(String albumId) async {
    final userId = await _getUserId();
    return api.fetchAlbum(albumId, userId);
  }

  @override
  Future<List<Album>> fetchMyAlbums() async {
    final userId = await _getUserId();
    return api.fetchMyAlbums(userId);
  }

  @override
  Future<void> deleteAlbum(int albumId) async {
    final userId = await _getUserId();
    await api.deleteAlbum(albumId, userId);
  }

  @override
  Future<void> reorderAlbums(List<int> albumIds) async {
    final userId = await _getUserId();
    await api.reorderAlbums({'albumIds': albumIds}, userId);
  }

  @override
  Future<void> lockAlbum(int albumId) async {
    final userId = await _getUserId();
    await api.lockAlbum(albumId, userId);
  }

  @override
  Future<void> unlockAlbum(int albumId) async {
    final userId = await _getUserId();
    await api.unlockAlbum(albumId, userId);
  }
}