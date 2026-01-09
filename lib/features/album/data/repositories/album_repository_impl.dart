import '../../domain/repositories/album_repository.dart';
import '../api/album_api.dart';
import '../dto/request/create_album_request.dart';
import '../../domain/entities/album.dart';

class AlbumRepositoryImpl implements AlbumRepository {
  final AlbumApi api;

  AlbumRepositoryImpl(this.api);

  @override
  Future<Album> createAlbum(CreateAlbumRequest request) {
    return api.createAlbum(request);
  }

  @override
  Future<Album> fetchAlbum(String albumId) {
    return api.fetchAlbum(albumId);
  }
}