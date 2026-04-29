import '../../domain/repositories/album_repository.dart';
import '../api/album_api.dart';
import '../dto/request/create_album_request.dart';
import '../../domain/entities/album.dart';

import '../../../../core/interceptors/token_storage.dart';

class AlbumRepositoryImpl implements AlbumRepository {
  final AlbumApi api;
  final TokenStorage tokenStorage;

  AlbumRepositoryImpl(this.api, {required this.tokenStorage});

  Future<String> _getUserId() async {
    final id = await tokenStorage.getResolvedUserId();
    if (id == null || id.trim().isEmpty) {
      throw Exception('로그인이 만료되었습니다. 다시 로그인 후 시도해주세요.');
    }
    return id.trim();
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
