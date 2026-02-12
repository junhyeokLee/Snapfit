// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_album_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CreateAlbumRequest _$CreateAlbumRequestFromJson(Map<String, dynamic> json) =>
    _CreateAlbumRequest(
      userId: json['userId'] as String? ?? '',
      ratio: json['ratio'] as String,
      title: json['title'] as String? ?? '',
      targetPages: (json['targetPages'] as num?)?.toInt() ?? 0,
      coverLayersJson: json['coverLayersJson'] as String,
      coverImageUrl: json['coverImageUrl'] as String,
      coverThumbnailUrl: json['coverThumbnailUrl'] as String,
      coverOriginalUrl: json['coverOriginalUrl'] as String?,
      coverPreviewUrl: json['coverPreviewUrl'] as String?,
      coverTheme: json['coverTheme'] as String? ?? '',
    );

Map<String, dynamic> _$CreateAlbumRequestToJson(_CreateAlbumRequest instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'ratio': instance.ratio,
      'title': instance.title,
      'targetPages': instance.targetPages,
      'coverLayersJson': instance.coverLayersJson,
      'coverImageUrl': instance.coverImageUrl,
      'coverThumbnailUrl': instance.coverThumbnailUrl,
      'coverOriginalUrl': instance.coverOriginalUrl,
      'coverPreviewUrl': instance.coverPreviewUrl,
      'coverTheme': instance.coverTheme,
    };
