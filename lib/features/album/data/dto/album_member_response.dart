import 'package:freezed_annotation/freezed_annotation.dart';

part 'album_member_response.freezed.dart';
part 'album_member_response.g.dart';

@freezed
sealed class AlbumMemberResponse with _$AlbumMemberResponse {
  const factory AlbumMemberResponse({
    required int id,
    required int userId,
    String? userName,
    String? userEmail,
    String? profileImageUrl,
    required String role,
    required String status,
  }) = _AlbumMemberResponse;

  factory AlbumMemberResponse.fromJson(Map<String, dynamic> json) =>
      _$AlbumMemberResponseFromJson(json);
}
