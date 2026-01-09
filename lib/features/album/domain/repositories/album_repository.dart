import '../../data/dto/request/create_album_request.dart';
import '../entities/album.dart';

abstract class AlbumRepository {
  Future<Album> createAlbum(CreateAlbumRequest request);
  Future<Album> fetchAlbum(String albumId);
}