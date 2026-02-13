import '../../domain/repositories/album_repository.dart';
import '../api/album_api.dart';
import '../dto/request/create_album_request.dart';
import '../../domain/entities/album.dart';
import '../../../../core/user/user_id_service.dart';

class AlbumRepositoryImpl implements AlbumRepository {
  final AlbumApi api;
  final UserIdService userIdService;

  AlbumRepositoryImpl(
    this.api, {
    required this.userIdService,
  });

  @override
  Future<Album> createAlbum(CreateAlbumRequest request) async {
    final userId = await userIdService.getOrCreate();
    return api.createAlbum(request.copyWith(userId: userId));
  }

  @override
  Future<Album> updateAlbum(int albumId, CreateAlbumRequest request) async {
    final userId = await userIdService.getOrCreate();
    return api.updateAlbum(albumId, request, userId);
  }

  @override
  Future<Album> fetchAlbum(String albumId) async {
    final userId = await userIdService.getOrCreate();
    return api.fetchAlbum(albumId, userId);
  }

  @override
  Future<List<Album>> fetchMyAlbums() async {
    final userId = await userIdService.getOrCreate();
    return api.fetchMyAlbums(userId);
  }

  @override
  Future<void> deleteAlbum(int albumId) async {
    final userId = await userIdService.getOrCreate();
    await api.deleteAlbum(albumId, userId);
  }

  @override
  Future<void> reorderAlbums(List<int> albumIds) async {
    final userId = await userIdService.getOrCreate();
    await api.reorderAlbums({'albumIds': albumIds}, userId);
  }

  @override
  Future<void> lockAlbum(int albumId) async {
    final userId = await userIdService.getOrCreate();
    await api.lockAlbum(albumId, userId);
  }

  @override
  Future<void> unlockAlbum(int albumId) async {
    final userId = await userIdService.getOrCreate();
    await api.unlockAlbum(albumId, userId);
  }
}