// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'premium_template.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PremiumTemplate _$PremiumTemplateFromJson(Map<String, dynamic> json) =>
    PremiumTemplate(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      subTitle: json['subTitle'] as String?,
      description: json['description'] as String?,
      coverImageUrl: json['coverImageUrl'] as String,
      previewImages: (json['previewImages'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      pageCount: (json['pageCount'] as num).toInt(),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      userCount: (json['userCount'] as num).toInt(),
      isBest: json['isBest'] as bool? ?? false,
      isPremium: json['isPremium'] as bool? ?? true,
      isLiked: json['isLiked'] as bool? ?? false,
      templateJson: json['templateJson'] as String?,
    );

Map<String, dynamic> _$PremiumTemplateToJson(PremiumTemplate instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'subTitle': instance.subTitle,
      'description': instance.description,
      'coverImageUrl': instance.coverImageUrl,
      'previewImages': instance.previewImages,
      'pageCount': instance.pageCount,
      'likeCount': instance.likeCount,
      'userCount': instance.userCount,
      'isBest': instance.isBest,
      'isPremium': instance.isPremium,
      'isLiked': instance.isLiked,
      'templateJson': instance.templateJson,
    };
