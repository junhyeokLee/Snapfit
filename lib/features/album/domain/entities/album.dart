import 'package:freezed_annotation/freezed_annotation.dart';

part 'album.freezed.dart';
part 'album.g.dart';

@freezed
sealed class Album with _$Album {
  const factory Album({
    required String id,
    required String coverLayersJson,
    required String coverRatio,
    required String createdAt,
    required String updatedAt,
  }) = _Album;

  factory Album.fromJson(Map<String, dynamic> json) => _$AlbumFromJson(json);
}