
import '../data/dto/request/create_album_request.dart';
import '../data/models/album.dart';

abstract class AlbumRepository {
  Future<Album> createAlbum(CreateAlbumRequest request);
  Future<Album> fetchAlbum(String albumId);
}