import '../../data/dto/request/create_album_request.dart';
import '../entities/album.dart';

/// 앨범 도메인 레포지토리 인터페이스
/// 구현체는 data 레이어(AlbumRepositoryImpl)에 위치
abstract class AlbumRepository {
  /// 앨범 생성
  Future<Album> createAlbum(CreateAlbumRequest request);

  /// 앨범 수정
  Future<Album> updateAlbum(int albumId, CreateAlbumRequest request);

  /// 단일 앨범 조회
  Future<Album> fetchAlbum(String albumId);

  /// 내 앨범 목록 조회
  Future<List<Album>> fetchMyAlbums();

  /// 앨범 삭제
  Future<void> deleteAlbum(int albumId);
}
