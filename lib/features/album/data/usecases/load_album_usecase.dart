// lib/features/album/domain/usecases/load_album_usecase.dart
import '../../data/models/album.dart';
import '../../repositories/album_repository.dart';

/// 앨범 불러오기 유스케이스
class LoadAlbumUseCase {
  final AlbumRepository _repository;

  LoadAlbumUseCase(this._repository);

  Future<Album> call(String albumId) {
    // 추후 권한 체크, 로깅 등 추가 가능
    return _repository.fetchAlbum(albumId);
  }
}