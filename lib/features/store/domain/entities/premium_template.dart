import 'package:json_annotation/json_annotation.dart';

part 'premium_template.g.dart';

@JsonSerializable()
class PremiumTemplate {
  final int id;
  final String title;
  final String? subTitle;
  final String? description;
  final String coverImageUrl;
  final List<String> previewImages;
  final int pageCount;
  final int likeCount;
  final int userCount;
  final bool isBest;
  final bool isPremium;
  final bool isLiked;
  final String? templateJson;

  const PremiumTemplate({
    required this.id,
    required this.title,
    this.subTitle,
    this.description,
    required this.coverImageUrl,
    required this.previewImages,
    required this.pageCount,
    this.likeCount = 0,
    required this.userCount,
    this.isBest = false,
    this.isPremium = true,
    this.isLiked = false,
    this.templateJson,
  });

  factory PremiumTemplate.fromJson(Map<String, dynamic> json) => _$PremiumTemplateFromJson(json);
  Map<String, dynamic> toJson() => _$PremiumTemplateToJson(this);

  PremiumTemplate copyWith({
    int? id,
    String? title,
    String? subTitle,
    String? description,
    String? coverImageUrl,
    List<String>? previewImages,
    int? pageCount,
    int? likeCount,
    int? userCount,
    bool? isBest,
    bool? isPremium,
    bool? isLiked,
    String? templateJson,
  }) {
    return PremiumTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      subTitle: subTitle ?? this.subTitle,
      description: description ?? this.description,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      previewImages: previewImages ?? this.previewImages,
      pageCount: pageCount ?? this.pageCount,
      likeCount: likeCount ?? this.likeCount,
      userCount: userCount ?? this.userCount,
      isBest: isBest ?? this.isBest,
      isPremium: isPremium ?? this.isPremium,
      isLiked: isLiked ?? this.isLiked,
      templateJson: templateJson ?? this.templateJson,
    );
  }
}

