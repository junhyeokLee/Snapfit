// lib/features/album/domain/usecases/save_album_usecase.dart
import '../../data/models/album.dart';
import '../../data/repositories/album_repository.dart';

/// 앨범 저장 유스케이스
class SaveAlbumUseCase {
  final AlbumRepository _repository;

  SaveAlbumUseCase(this._repository);

  Future<void> call(Album album) {
    // 추후 검증/트랜잭션 처리 등 가능
    return _repository.saveAlbum(album);
  }
}