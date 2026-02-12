import 'package:freezed_annotation/freezed_annotation.dart';

part 'create_album_request.freezed.dart';
part 'create_album_request.g.dart';

@freezed
sealed class CreateAlbumRequest with _$CreateAlbumRequest {
  const factory CreateAlbumRequest({
    /// 서버 식별자 (로그인 없이도 설치 단위로 고정)
    /// - Repository에서 자동 주입하므로 호출부에서는 비워둬도 됨
    // ignore: invalid_annotation_target
    @JsonKey(name: 'userId') @Default('') String userId,
    required String ratio,
    /// 앨범 제목
    @Default('') String title,
    /// 목표 페이지 수 (완성 기준)
    @Default(0) int targetPages,
    required String coverLayersJson,
    required String coverImageUrl,
    required String coverThumbnailUrl,
    /// 운영급: 커버 원본/미리보기 URL (하위 호환: 없으면 coverImageUrl을 preview로 간주)
    String? coverOriginalUrl,
    String? coverPreviewUrl,
    @Default('') String coverTheme,
  }) = _CreateAlbumRequest;

  factory CreateAlbumRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateAlbumRequestFromJson(json);
}