import 'package:freezed_annotation/freezed_annotation.dart';

part 'invite_accept_response.freezed.dart';
part 'invite_accept_response.g.dart';

@freezed
sealed class InviteAcceptResponse with _$InviteAcceptResponse {
  const factory InviteAcceptResponse({
    required int albumId,
    required String role,
    required bool success,
  }) = _InviteAcceptResponse;

  factory InviteAcceptResponse.fromJson(Map<String, dynamic> json) =>
      _$InviteAcceptResponseFromJson(json);
}
