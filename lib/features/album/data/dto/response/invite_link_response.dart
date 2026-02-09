import 'package:freezed_annotation/freezed_annotation.dart';

part 'invite_link_response.freezed.dart';
part 'invite_link_response.g.dart';

@freezed
sealed class InviteLinkResponse with _$InviteLinkResponse {
  const factory InviteLinkResponse({
    required int albumId,
    required String token,
    required String link,
  }) = _InviteLinkResponse;

  factory InviteLinkResponse.fromJson(Map<String, dynamic> json) =>
      _$InviteLinkResponseFromJson(json);
}
