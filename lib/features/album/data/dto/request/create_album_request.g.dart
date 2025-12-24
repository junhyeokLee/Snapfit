// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_album_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CreateAlbumRequest _$CreateAlbumRequestFromJson(Map<String, dynamic> json) =>
    _CreateAlbumRequest(
      coverLayersJson: json['coverLayersJson'] as String,
      coverRatio: (json['coverRatio'] as num).toDouble(),
    );

Map<String, dynamic> _$CreateAlbumRequestToJson(_CreateAlbumRequest instance) =>
    <String, dynamic>{
      'coverLayersJson': instance.coverLayersJson,
      'coverRatio': instance.coverRatio,
    };
