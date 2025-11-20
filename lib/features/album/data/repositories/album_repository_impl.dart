// lib/features/album/data/repositories/album_repository_impl.dart
import '../models/album.dart';
import 'album_repository.dart';
import '../api/album_api.dart';
import '../models/album_dto.dart';

/// AlbumRepository의 실제 구현체
class AlbumRepositoryImpl implements AlbumRepository {
  final AlbumApi _api;

  AlbumRepositoryImpl(this._api);

  @override
  Future<Album> fetchAlbum(String albumId) async {
    final dto = await _api.fetchAlbum(albumId);
    return dto.toEntity();
  }

  @override
  Future<void> saveAlbum(Album album) async {
    final dto = AlbumDto.fromEntity(album);
    await _api.saveAlbum(dto);
  }
}