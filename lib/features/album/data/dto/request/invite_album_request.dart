import 'package:freezed_annotation/freezed_annotation.dart';

part 'invite_album_request.freezed.dart';
part 'invite_album_request.g.dart';

@freezed
sealed class InviteAlbumRequest with _$InviteAlbumRequest {
  const factory InviteAlbumRequest({
    @Default('EDITOR') String role,
  }) = _InviteAlbumRequest;

  factory InviteAlbumRequest.fromJson(Map<String, dynamic> json) =>
      _$InviteAlbumRequestFromJson(json);
}
