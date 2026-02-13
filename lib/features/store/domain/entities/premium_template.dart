class PremiumTemplate {
  final String id;
  final String title;
  final String subTitle;
  final String dateRange;
  final String coverImageUrl;
  final List<String> previewImages;
  final int pageCount;
  final int userCount;
  final bool isBest;
  final bool isPremium;
  final String description; // For detail screen

  const PremiumTemplate({
    required this.id,
    required this.title,
    required this.subTitle,
    required this.dateRange,
    required this.coverImageUrl,
    required this.previewImages,
    required this.pageCount,
    required this.userCount,
    required this.description,
    this.isBest = false,
    this.isPremium = true,
  });
}
