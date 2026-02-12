import 'package:freezed_annotation/freezed_annotation.dart';

part 'album.freezed.dart';
part 'album.g.dart';

@freezed
sealed class Album with _$Album {
  const factory Album({
    /// 백엔드의 albumId(int)와 매핑
    /// 생성 API 응답에 albumId가 없을 수도 있어 기본값 허용
    @JsonKey(name: 'albumId') @Default(0) int id,
    /// 커버 레이어 전체 상태(JSON) - 있을 경우 홈에서도 에디터와 동일하게 렌더링
    @Default('') String coverLayersJson,
    /// 서버에서 null 이 와도 안전하게 처리하기 위해 기본값 사용
    @Default('') String ratio,
    /// 앨범 제목
    @Default('') String title,
    String? coverImageUrl,
    String? coverThumbnailUrl,
    /// 운영급: 커버 원본/미리보기 URL (없으면 coverImageUrl을 preview로 간주)
    String? coverOriginalUrl,
    String? coverPreviewUrl,
    /// 커버 테마 (예: classic, nature1) - 서버에서 저장/반환 시 편집 화면에서 복원
    String? coverTheme,
    @Default(0) int totalPages,
    /// 목표 페이지 수 (완성 기준)
    @Default(0) int targetPages,
    /// 사용자 지정 순서 (낮을수록 상단)
    @Default(0) int orders,
    @Default('') String createdAt,
    @Default('') String updatedAt,
  }) = _Album;

  factory Album.fromJson(Map<String, dynamic> json) => _$AlbumFromJson(json);
}