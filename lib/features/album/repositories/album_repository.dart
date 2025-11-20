// lib/features/album/domain/repositories/album_repository.dart
import '../data/models/album.dart';

/// Domain 레이어에서 사용하는 추상 저장소 인터페이스
abstract class AlbumRepository {
  /// 앨범 하나 가져오기
  Future<Album> fetchAlbum(String albumId);

  /// 앨범 저장/업데이트
  Future<void> saveAlbum(Album album);
}