enum AlbumTheme {
  couple,
  travel,
  family,
  baby,
  birthday,
  friends,
  daily,
  custom,
}

enum PhotoOrientation { portrait, landscape, square }

class PhotoCandidate {
  const PhotoCandidate({
    required this.assetId,
    required this.createdAt,
    required this.width,
    required this.height,
    required this.orientation,
    this.albumName,
    this.isScreenshot = false,
  });

  final String assetId;
  final DateTime createdAt;
  final int width;
  final int height;
  final PhotoOrientation orientation;
  final String? albumName;
  final bool isScreenshot;

  String get dayKey =>
      '${createdAt.year.toString().padLeft(4, '0')}-'
      '${createdAt.month.toString().padLeft(2, '0')}-'
      '${createdAt.day.toString().padLeft(2, '0')}';

  bool get isHighResolution => width >= 1200 && height >= 1200;
}

class RecommendedPhoto {
  const RecommendedPhoto({
    required this.candidate,
    required this.score,
    required this.reasons,
  });

  final PhotoCandidate candidate;
  final double score;
  final List<String> reasons;

  String get assetId => candidate.assetId;
}

class StorySection {
  const StorySection({
    required this.title,
    required this.description,
    required this.photoAssetIds,
  });

  final String title;
  final String description;
  final List<String> photoAssetIds;
}

class AlbumRecommendationDraft {
  const AlbumRecommendationDraft({
    required this.theme,
    required this.title,
    required this.pageCount,
    required this.templateTone,
    required this.recommendedPhotos,
    required this.excludedPhotos,
    required this.storySections,
    required this.summary,
    this.requiresUserReview = true,
    this.alreadyCreatedAlbum = false,
    this.reviewCtaLabel = '이 구성으로 시작하기',
  });

  final AlbumTheme theme;
  final String title;
  final int pageCount;
  final String templateTone;
  final List<RecommendedPhoto> recommendedPhotos;
  final List<PhotoCandidate> excludedPhotos;
  final List<StorySection> storySections;
  final String summary;
  final bool requiresUserReview;
  final bool alreadyCreatedAlbum;
  final String reviewCtaLabel;
}
