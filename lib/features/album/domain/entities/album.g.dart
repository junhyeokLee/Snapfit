// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'album.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Album _$AlbumFromJson(Map<String, dynamic> json) => _Album(
  id: json['id'] as String,
  coverLayersJson: json['coverLayersJson'] as String,
  coverRatio: json['coverRatio'] as String,
  createdAt: json['createdAt'] as String,
  updatedAt: json['updatedAt'] as String,
);

Map<String, dynamic> _$AlbumToJson(_Album instance) => <String, dynamic>{
  'id': instance.id,
  'coverLayersJson': instance.coverLayersJson,
  'coverRatio': instance.coverRatio,
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
};
