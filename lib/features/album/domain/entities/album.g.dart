// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'album.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Album _$AlbumFromJson(Map<String, dynamic> json) => _Album(
  id: (json['albumId'] as num?)?.toInt() ?? 0,
  coverLayersJson: json['coverLayersJson'] as String? ?? '',
  ratio: json['ratio'] as String? ?? '',
  title: json['title'] as String? ?? '',
  coverImageUrl: json['coverImageUrl'] as String?,
  coverThumbnailUrl: json['coverThumbnailUrl'] as String?,
  coverOriginalUrl: json['coverOriginalUrl'] as String?,
  coverPreviewUrl: json['coverPreviewUrl'] as String?,
  coverTheme: json['coverTheme'] as String?,
  totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
  targetPages: (json['targetPages'] as num?)?.toInt() ?? 0,
  orders: (json['orders'] as num?)?.toInt() ?? 0,
  createdAt: json['createdAt'] as String? ?? '',
  updatedAt: json['updatedAt'] as String? ?? '',
);

Map<String, dynamic> _$AlbumToJson(_Album instance) => <String, dynamic>{
  'albumId': instance.id,
  'coverLayersJson': instance.coverLayersJson,
  'ratio': instance.ratio,
  'title': instance.title,
  'coverImageUrl': instance.coverImageUrl,
  'coverThumbnailUrl': instance.coverThumbnailUrl,
  'coverOriginalUrl': instance.coverOriginalUrl,
  'coverPreviewUrl': instance.coverPreviewUrl,
  'coverTheme': instance.coverTheme,
  'totalPages': instance.totalPages,
  'targetPages': instance.targetPages,
  'orders': instance.orders,
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
};
