import '../../data/dto/request/create_album_request.dart';
import '../entities/album.dart';

/// 앨범 도메인 레포지토리 인터페이스
/// 구현체는 data 레이어(SupabaseAlbumRepository)에 위치
abstract class AlbumRepository {
  /// Create only with a durably persisted immutable command. Replays retain
  /// both identifiers and the exact original request; no unkeyed INSERT.
  Future<Album> createAlbum(
    CreateAlbumRequest request, {
    String? requestId,
    String? expectedUserId,
  });

  /// Atomically replace the document loaded at [expectedUpdatedAt]. A retry of
  /// the same immutable save must retain [requestId] and [expectedUserId].
  Future<Album> updateAlbum(
    int albumId,
    CreateAlbumRequest request, {
    String? expectedUpdatedAt,
    String? requestId,
    String? expectedUserId,
  });

  /// 단일 앨범 조회
  Future<Album> fetchAlbum(String albumId);

  /// 내 앨범 목록 조회
  Future<List<Album>> fetchMyAlbums();

  /// 앨범 삭제
  Future<void> deleteAlbum(int albumId);

  /// 앨범 순서 변경
  Future<void> reorderAlbums(List<int> albumIds);

  /// 앨범 편집 잠금 (진입 시)
  /// 실패 시 예외 발생 (409 Conflict 등)
  Future<void> lockAlbum(int albumId);

  /// 앨범 편집 잠금 해제 (이탈 시)
  Future<void> unlockAlbum(int albumId);
}
