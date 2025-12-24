import 'package:freezed_annotation/freezed_annotation.dart';

part 'create_album_request.freezed.dart';
part 'create_album_request.g.dart';

@freezed
sealed class CreateAlbumRequest with _$CreateAlbumRequest {
  const factory CreateAlbumRequest({
    required String coverLayersJson,
    required double coverRatio,
  }) = _CreateAlbumRequest;

  factory CreateAlbumRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateAlbumRequestFromJson(json);
}