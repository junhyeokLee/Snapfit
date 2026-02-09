import 'package:freezed_annotation/freezed_annotation.dart';

part 'invite_info_response.freezed.dart';
part 'invite_info_response.g.dart';

@freezed
sealed class InviteInfoResponse with _$InviteInfoResponse {
  const factory InviteInfoResponse({
    required int albumId,
    required String albumTitle,
    required String inviterName,
    required String role,
  }) = _InviteInfoResponse;

  factory InviteInfoResponse.fromJson(Map<String, dynamic> json) =>
      _$InviteInfoResponseFromJson(json);
}
