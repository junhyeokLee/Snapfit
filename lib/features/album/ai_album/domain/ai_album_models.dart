import 'package:photo_manager/photo_manager.dart';
import 'ai_template_design.dart';

export 'ai_template_design.dart';

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
    this.previewStorageUri,
  });

  final String assetId;
  final DateTime createdAt;
  final int width;
  final int height;
  final PhotoOrientation orientation;
  final String? albumName;
  final bool isScreenshot;
  final AssetEntity? asset;
  final String? previewStorageUri;

  String get dayKey =>
      '${createdAt.year.toString().padLeft(4, '0')}-'
      '${createdAt.month.toString().padLeft(2, '0')}-'
      '${createdAt.day.toString().padLeft(2, '0')}';

  bool get isHighResolution => width >= 1200 && height >= 1200;
  bool get isLowResolution => width < 900 || height < 900;

  PhotoCandidate copyWith({
    String? assetId,
    DateTime? createdAt,
    int? width,
    int? height,
    PhotoOrientation? orientation,
    String? albumName,
    bool? isScreenshot,
    AssetEntity? asset,
    String? previewStorageUri,
  }) {
    return PhotoCandidate(
      assetId: assetId ?? this.assetId,
      createdAt: createdAt ?? this.createdAt,
      width: width ?? this.width,
      height: height ?? this.height,
      orientation: orientation ?? this.orientation,
      albumName: albumName ?? this.albumName,
      isScreenshot: isScreenshot ?? this.isScreenshot,
      asset: asset ?? this.asset,
      previewStorageUri: previewStorageUri ?? this.previewStorageUri,
    );
  }
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

class AiTemplateSlot {
  const AiTemplateSlot({
    required this.slotId,
    required this.pageIndex,
    required this.role,
    required this.hint,
    this.assetId,
    this.left,
    this.top,
    this.width,
    this.height,
    this.rotation = 0,
    this.imageTemplate,
    this.imageBackground,
    this.caption,
    this.emphasis = 1,
  });

  final String slotId;
  final int pageIndex;
  final String role;
  final String hint;
  final String? assetId;
  final double? left;
  final double? top;
  final double? width;
  final double? height;
  final double rotation;
  final String? imageTemplate;
  final String? imageBackground;
  final String? caption;
  final double emphasis;

  bool get hasCustomFrame =>
      left != null && top != null && width != null && height != null;
}

class AlbumRecommendationDraft {
  const AlbumRecommendationDraft({
    this.design,
    this.draftId = '',
    required this.theme,
    required this.title,
    required this.pageCount,
    required this.templateTone,
    required this.recommendedPhotos,
    required this.excludedPhotos,
    required this.storySections,
    required this.summary,
    this.templateSlots = const [],
    this.curationNotes = const [],
    this.requiresUserReview = true,
    this.alreadyCreatedAlbum = false,
    this.reviewCtaLabel = '이 구성으로 시작하기',
  });

  final String draftId;
  final AiTemplateDesign? design;
  final AlbumTheme theme;
  final String title;
  final int pageCount;
  final String templateTone;
  final List<RecommendedPhoto> recommendedPhotos;
  final List<ExcludedPhoto> excludedPhotos;
  final List<StorySection> storySections;
  final String summary;
  final List<AiTemplateSlot> templateSlots;
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
    List<AiTemplateSlot>? templateSlots,
    List<String>? curationNotes,
    bool? requiresUserReview,
    bool? alreadyCreatedAlbum,
    String? reviewCtaLabel,
  }) {
    return AlbumRecommendationDraft(
      design: design,
      draftId: draftId ?? this.draftId,
      theme: theme ?? this.theme,
      title: title ?? this.title,
      pageCount: pageCount ?? this.pageCount,
      templateTone: templateTone ?? this.templateTone,
      recommendedPhotos: recommendedPhotos ?? this.recommendedPhotos,
      excludedPhotos: excludedPhotos ?? this.excludedPhotos,
      storySections: storySections ?? this.storySections,
      summary: summary ?? this.summary,
      templateSlots: templateSlots ?? this.templateSlots,
      curationNotes: curationNotes ?? this.curationNotes,
      requiresUserReview: requiresUserReview ?? this.requiresUserReview,
      alreadyCreatedAlbum: alreadyCreatedAlbum ?? this.alreadyCreatedAlbum,
      reviewCtaLabel: reviewCtaLabel ?? this.reviewCtaLabel,
    );
  }
}
