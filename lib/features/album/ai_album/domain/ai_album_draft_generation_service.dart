import 'ai_album_curation_engine.dart';
import 'ai_album_models.dart';

typedef AiPhotoCandidateLoader =
    Future<List<PhotoCandidate>> Function(AiPhotoRange range);

enum AiAlbumDraftGenerationStatus {
  success,
  insufficientPhotos,
  permissionDenied,
  failed,
}

enum AiAlbumDraftRecoveryAction { retryPhotoRange, openPhotoSettings }

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
      draft: draft,
    );
  }

  factory AiAlbumDraftGenerationResult.insufficientPhotos({
    required int minimumPhotoCount,
    required int actualPhotoCount,
    AiPhotoRange? range,
  }) {
    final selectedOnly = range == AiPhotoRange.limitedLibrary;
    final lead = selectedOnly
        ? '선택한 사진이 조금 더 필요해요.'
        : 'AI 초안을 만들려면 사진이 조금 더 필요해요.';
    final rangeHint = selectedOnly
        ? '사진 접근을 조금 더 허용하거나 범위를 다시 골라 주세요.'
        : '최소 $minimumPhotoCount장 이상 허용해 주세요.';
    return AiAlbumDraftGenerationResult._(
      status: AiAlbumDraftGenerationStatus.insufficientPhotos,
      shouldChargePoints: false,
      failureTitle: selectedOnly ? '선택한 사진 안에서만 살펴봤어요' : '초안을 만들기엔 사진이 조금 적어요',
      failureMessage:
          '$lead $rangeHint 현재 후보는 $actualPhotoCount장이에요. 기기 안에서만 확인하고 포인트는 차감되지 않았어요.',
      primaryCtaLabel: selectedOnly ? '사진 더 선택하기' : '사진 범위 다시 고르기',
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
  const AiAlbumDraftGenerationService({
    required AiPhotoCandidateLoader collectCandidates,
    AiAlbumCurationEngine engine = const AiAlbumCurationEngine(),
    int minimumPhotoCount = 3,
  }) : _collectCandidates = collectCandidates,
       _engine = engine,
       _minimumPhotoCount = minimumPhotoCount;

  final AiPhotoCandidateLoader _collectCandidates;
  final AiAlbumCurationEngine _engine;
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

      final draft = _engine.curate(theme: theme, candidates: candidates);
      if (draft.recommendedPhotos.isEmpty) {
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
