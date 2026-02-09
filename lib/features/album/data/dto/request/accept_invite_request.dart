import 'package:freezed_annotation/freezed_annotation.dart';

part 'accept_invite_request.freezed.dart';
part 'accept_invite_request.g.dart';

@freezed
sealed class AcceptInviteRequest with _$AcceptInviteRequest {
  const factory AcceptInviteRequest({
    required String userId,
  }) = _AcceptInviteRequest;

  factory AcceptInviteRequest.fromJson(Map<String, dynamic> json) =>
      _$AcceptInviteRequestFromJson(json);
}
