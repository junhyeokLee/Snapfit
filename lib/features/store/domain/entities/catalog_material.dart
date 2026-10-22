class CatalogMaterial {
  const CatalogMaterial({
    required this.productKey,
    required this.label,
    required this.type,
    this.collection,
    this.isActive = true,
    this.isPremium = false,
    this.isNew = false,
    this.isBest = false,
    this.weeklyScore = 0,
    this.likeCount = 0,
    this.userCount = 0,
    this.isLiked = false,
  });

  final String productKey, label, type;
  final String? collection;
  final bool isActive, isPremium, isNew, isBest, isLiked;
  final int weeklyScore, likeCount, userCount;

  CatalogMaterial copyWith({
    String? productKey,
    String? label,
    String? type,
    String? collection,
    bool? isActive,
    bool? isPremium,
    bool? isNew,
    bool? isBest,
    int? weeklyScore,
    int? likeCount,
    int? userCount,
    bool? isLiked,
  }) => CatalogMaterial(
    productKey: productKey ?? this.productKey,
    label: label ?? this.label,
    type: type ?? this.type,
    collection: collection ?? this.collection,
    isActive: isActive ?? this.isActive,
    isPremium: isPremium ?? this.isPremium,
    isNew: isNew ?? this.isNew,
    isBest: isBest ?? this.isBest,
    weeklyScore: weeklyScore ?? this.weeklyScore,
    likeCount: likeCount ?? this.likeCount,
    userCount: userCount ?? this.userCount,
    isLiked: isLiked ?? this.isLiked,
  );
}
