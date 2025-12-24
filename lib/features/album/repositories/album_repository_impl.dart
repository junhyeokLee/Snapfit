import '../data/api/album_api.dart';
import '../data/dto/request/create_album_request.dart';
import '../data/models/album.dart';
import 'album_repository.dart';

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