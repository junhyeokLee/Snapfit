import 'ai_album_curation_engine.dart';
import 'ai_album_models.dart';

typedef AiPhotoCandidateLoader =
    Future<List<PhotoCandidate>> Function(AiPhotoRange range);
typedef AdvancedAiAlbumPreviewPreparer =
    Future<List<PhotoCandidate>> Function(List<PhotoCandidate> candidates);

abstract class AiAlbumDraftProvider {
  const AiAlbumDraftProvider();

  Future<AlbumRecommendationDraft> createDraft({
    required AlbumTheme theme,
    required AiPhotoRange range,
    required List<PhotoCandidate> candidates,
  });
}

class MetadataFirstAiAlbumDraftProvider extends AiAlbumDraftProvider {
  const MetadataFirstAiAlbumDraftProvider({
    AiAlbumCurationEngine engine = const AiAlbumCurationEngine(),
  }) : _engine = engine;

  final AiAlbumCurationEngine _engine;

  @override
  Future<AlbumRecommendationDraft> createDraft({
    required AlbumTheme theme,
    required AiPhotoRange range,
    required List<PhotoCandidate> candidates,
  }) async {
    return _engine.curate(theme: theme, candidates: candidates);
  }
}

enum AiAlbumDraftGenerationStatus {
  success,
  insufficientPhotos,
  lowQualityPhotos,
  permissionDenied,
  failed,
}

enum AiAlbumDraftRecoveryAction {
  retryPhotoRange,
  openPhotoSettings,
  openLimitedPhotoPicker,
  reviewPointCost,
}

enum AiPhotoCandidateCollectionFailure { permissionDenied }

class AiPhotoCandidateCollectionException implements Exception {
  const AiPhotoCandidateCollectionException(this.failure);

  final AiPhotoCandidateCollectionFailure failure;
}

class AiAlbumDraftGenerationResult {
  const AiAlbumDraftGenerationResult._({
    required this.status,
    required this.shouldChargePoints,
    this.draft,
    this.failureTitle,
    this.failureMessage,
    this.primaryCtaLabel,
    this.primaryRecoveryAction,
  });

  factory AiAlbumDraftGenerationResult.success(AlbumRecommendationDraft draft) {
    return AiAlbumDraftGenerationResult._(
      status: AiAlbumDraftGenerationStatus.success,
      shouldChargePoints: true,
      draft: _withDraftId(draft),
    );
  }

  static AlbumRecommendationDraft _withDraftId(AlbumRecommendationDraft draft) {
    if (draft.draftId.trim().isNotEmpty) return draft;
    return draft.copyWith(
      draftId: 'ai-draft-${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  factory AiAlbumDraftGenerationResult.insufficientPhotos({
    required int minimumPhotoCount,
    required int actualPhotoCount,
    AiPhotoRange? range,
  }) {
    final selectedOnly = range == AiPhotoRange.limitedLibrary;
    final noCandidates = actualPhotoCount == 0;
    final title = noCandidates
        ? (selectedOnly ? '선택한 사진을 찾지 못했어요' : '사진 후보를 찾지 못했어요')
        : (selectedOnly ? '선택한 사진 안에서만 살펴봤어요' : '초안을 만들기엔 사진이 조금 적어요');
    final lead = noCandidates
        ? (selectedOnly
              ? '허용한 사진 안에서 후보를 찾지 못했어요.'
              : '선택한 범위에서 앨범 후보 사진을 찾지 못했어요.')
        : (selectedOnly ? '선택한 사진이 조금 더 필요해요.' : 'AI 초안을 만들려면 사진이 조금 더 필요해요.');
    final rangeHint = selectedOnly
        ? '사진 접근을 조금 더 허용하거나 범위를 다시 골라 주세요.'
        : '최소 $minimumPhotoCount장 이상 허용해 주세요.';
    return AiAlbumDraftGenerationResult._(
      status: AiAlbumDraftGenerationStatus.insufficientPhotos,
      shouldChargePoints: false,
      failureTitle: title,
      failureMessage:
          '$lead $rangeHint 현재 후보는 $actualPhotoCount장이에요. 기기 안에서만 확인하고 포인트는 차감되지 않았어요.',
      primaryCtaLabel: selectedOnly ? '사진 더 선택하기' : '사진 범위 다시 고르기',
      primaryRecoveryAction: selectedOnly
          ? AiAlbumDraftRecoveryAction.openLimitedPhotoPicker
          : AiAlbumDraftRecoveryAction.retryPhotoRange,
    );
  }

  factory AiAlbumDraftGenerationResult.lowQualityPhotos() {
    return const AiAlbumDraftGenerationResult._(
      status: AiAlbumDraftGenerationStatus.lowQualityPhotos,
      shouldChargePoints: false,
      failureTitle: '앨범에 어울리는 사진이 조금 부족해요',
      failureMessage:
          '스크린샷이나 작은 이미지는 초안에서 잠시 제외했어요. 여행·일상 사진이 더 보이는 범위로 다시 골라 주세요. 포인트는 차감되지 않았어요.',
      primaryCtaLabel: '사진 범위 다시 고르기',
      primaryRecoveryAction: AiAlbumDraftRecoveryAction.retryPhotoRange,
    );
  }

  factory AiAlbumDraftGenerationResult.permissionDenied() {
    return const AiAlbumDraftGenerationResult._(
      status: AiAlbumDraftGenerationStatus.permissionDenied,
      shouldChargePoints: false,
      failureTitle: '사진을 볼 수 없어 초안을 만들지 못했어요',
      failureMessage:
          '사진 접근 권한이 필요해요. 설정에서 사진을 몇 장 더 허용한 뒤 다시 시도해 주세요. 포인트는 차감되지 않았어요.',
      primaryCtaLabel: '사진 권한 열기',
      primaryRecoveryAction: AiAlbumDraftRecoveryAction.openPhotoSettings,
    );
  }

  factory AiAlbumDraftGenerationResult.failed() {
    return const AiAlbumDraftGenerationResult._(
      status: AiAlbumDraftGenerationStatus.failed,
      shouldChargePoints: false,
      failureTitle: '초안을 만들지 못했어요',
      failureMessage: 'AI 초안을 준비하지 못했어요. 포인트는 차감되지 않았어요.',
      primaryCtaLabel: '사진 범위 다시 고르기',
      primaryRecoveryAction: AiAlbumDraftRecoveryAction.retryPhotoRange,
    );
  }

  final AiAlbumDraftGenerationStatus status;
  final bool shouldChargePoints;
  final AlbumRecommendationDraft? draft;
  final String? failureTitle;
  final String? failureMessage;
  final String? primaryCtaLabel;
  final AiAlbumDraftRecoveryAction? primaryRecoveryAction;
}

class AiAlbumDraftGenerationService {
  AiAlbumDraftGenerationService({
    required AiPhotoCandidateLoader collectCandidates,
    AiAlbumDraftProvider? draftProvider,
    AdvancedAiAlbumPreviewPreparer? prepareAdvancedPreviews,
    AiAlbumCurationEngine engine = const AiAlbumCurationEngine(),
    int minimumPhotoCount = 3,
  }) : _collectCandidates = collectCandidates,
       _draftProvider =
           draftProvider ?? MetadataFirstAiAlbumDraftProvider(engine: engine),
       _prepareAdvancedPreviews = prepareAdvancedPreviews,
       _minimumPhotoCount = minimumPhotoCount;

  final AiPhotoCandidateLoader _collectCandidates;
  final AiAlbumDraftProvider _draftProvider;
  final AdvancedAiAlbumPreviewPreparer? _prepareAdvancedPreviews;
  final int _minimumPhotoCount;

  Future<AiAlbumDraftGenerationResult> generate({
    required AlbumTheme theme,
    required AiPhotoRange range,
  }) async {
    try {
      final candidates = await _collectCandidates(range);
      if (candidates.length < _minimumPhotoCount) {
        return AiAlbumDraftGenerationResult.insufficientPhotos(
          minimumPhotoCount: _minimumPhotoCount,
          actualPhotoCount: candidates.length,
          range: range,
        );
      }

      final preparedCandidates = _prepareAdvancedPreviews == null
          ? candidates
          : await _prepareAdvancedPreviews(candidates);
      final draft = await _draftProvider.createDraft(
        theme: theme,
        range: range,
        candidates: preparedCandidates,
      );
      if (draft.recommendedPhotos.isEmpty) {
        final excludedForQuality = draft.excludedPhotos.where((photo) {
          return photo.reasons.any(
            (reason) =>
                reason.type == AiCurationReasonType.screenshotExcluded ||
                reason.type == AiCurationReasonType.lowResolutionExcluded,
          );
        }).length;
        if (excludedForQuality >= _minimumPhotoCount) {
          return AiAlbumDraftGenerationResult.lowQualityPhotos();
        }
        return AiAlbumDraftGenerationResult.insufficientPhotos(
          minimumPhotoCount: _minimumPhotoCount,
          actualPhotoCount: candidates.length,
          range: range,
        );
      }

      return AiAlbumDraftGenerationResult.success(draft);
    } on AiPhotoCandidateCollectionException catch (error) {
      return switch (error.failure) {
        AiPhotoCandidateCollectionFailure.permissionDenied =>
          AiAlbumDraftGenerationResult.permissionDenied(),
      };
    } catch (_) {
      return AiAlbumDraftGenerationResult.failed();
    }
  }
}
