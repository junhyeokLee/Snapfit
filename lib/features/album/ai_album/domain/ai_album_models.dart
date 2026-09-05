import 'package:photo_manager/photo_manager.dart';

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

enum AiPhotoRange {
  recent30Days,
  dateRange,
  album,
  manualSelection,
  limitedLibrary,
}

enum AiCurationReasonType {
  highResolution,
  themeOrientation,
  dateFlow,
  timeClusterRepresentative,
  coverCandidate,
  endingCandidate,
  screenshotExcluded,
  lowResolutionExcluded,
  duplicateTimeExcluded,
  dailyLimitExcluded,
  totalLimitExcluded,
  weakThemeFitExcluded,
}

class AiCurationReason {
  const AiCurationReason({required this.type, required this.message});

  final AiCurationReasonType type;
  final String message;
}

class PhotoCandidate {
  const PhotoCandidate({
    required this.assetId,
    required this.createdAt,
    required this.width,
    required this.height,
    required this.orientation,
    this.albumName,
    this.isScreenshot = false,
    this.asset,
  });

  final String assetId;
  final DateTime createdAt;
  final int width;
  final int height;
  final PhotoOrientation orientation;
  final String? albumName;
  final bool isScreenshot;
  final AssetEntity? asset;

  String get dayKey =>
      '${createdAt.year.toString().padLeft(4, '0')}-'
      '${createdAt.month.toString().padLeft(2, '0')}-'
      '${createdAt.day.toString().padLeft(2, '0')}';

  bool get isHighResolution => width >= 1200 && height >= 1200;
  bool get isLowResolution => width < 900 || height < 900;
}

class RecommendedPhoto {
  const RecommendedPhoto({
    required this.candidate,
    required this.score,
    required this.reasons,
  });

  final PhotoCandidate candidate;
  final double score;
  final List<AiCurationReason> reasons;

  String get assetId => candidate.assetId;
}

class ExcludedPhoto {
  const ExcludedPhoto({required this.candidate, required this.reasons});

  final PhotoCandidate candidate;
  final List<AiCurationReason> reasons;

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
    this.draftId = '',
    required this.theme,
    required this.title,
    required this.pageCount,
    required this.templateTone,
    required this.recommendedPhotos,
    required this.excludedPhotos,
    required this.storySections,
    required this.summary,
    this.curationNotes = const [],
    this.requiresUserReview = true,
    this.alreadyCreatedAlbum = false,
    this.reviewCtaLabel = '이 구성으로 시작하기',
  });

  final String draftId;
  final AlbumTheme theme;
  final String title;
  final int pageCount;
  final String templateTone;
  final List<RecommendedPhoto> recommendedPhotos;
  final List<ExcludedPhoto> excludedPhotos;
  final List<StorySection> storySections;
  final String summary;
  final List<String> curationNotes;
  final bool requiresUserReview;
  final bool alreadyCreatedAlbum;
  final String reviewCtaLabel;

  AlbumRecommendationDraft copyWith({
    String? draftId,
    AlbumTheme? theme,
    String? title,
    int? pageCount,
    String? templateTone,
    List<RecommendedPhoto>? recommendedPhotos,
    List<ExcludedPhoto>? excludedPhotos,
    List<StorySection>? storySections,
    String? summary,
    List<String>? curationNotes,
    bool? requiresUserReview,
    bool? alreadyCreatedAlbum,
    String? reviewCtaLabel,
  }) {
    return AlbumRecommendationDraft(
      draftId: draftId ?? this.draftId,
      theme: theme ?? this.theme,
      title: title ?? this.title,
      pageCount: pageCount ?? this.pageCount,
      templateTone: templateTone ?? this.templateTone,
      recommendedPhotos: recommendedPhotos ?? this.recommendedPhotos,
      excludedPhotos: excludedPhotos ?? this.excludedPhotos,
      storySections: storySections ?? this.storySections,
      summary: summary ?? this.summary,
      curationNotes: curationNotes ?? this.curationNotes,
      requiresUserReview: requiresUserReview ?? this.requiresUserReview,
      alreadyCreatedAlbum: alreadyCreatedAlbum ?? this.alreadyCreatedAlbum,
      reviewCtaLabel: reviewCtaLabel ?? this.reviewCtaLabel,
    );
  }
}
