import 'ai_album_curation_engine.dart';
import 'ai_album_models.dart';

typedef AiPhotoCandidateLoader =
    Future<List<PhotoCandidate>> Function(AiPhotoRange range);

enum AiAlbumDraftGenerationStatus { success, insufficientPhotos, failed }

class AiAlbumDraftGenerationResult {
  const AiAlbumDraftGenerationResult._({
    required this.status,
    required this.shouldChargePoints,
    this.draft,
    this.failureMessage,
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
  }) {
    return AiAlbumDraftGenerationResult._(
      status: AiAlbumDraftGenerationStatus.insufficientPhotos,
      shouldChargePoints: false,
      failureMessage:
          'AI 초안을 만들려면 사진이 조금 더 필요해요. 최소 $minimumPhotoCount장 이상 허용해 주세요. 현재 후보는 $actualPhotoCount장이에요.',
    );
  }

  factory AiAlbumDraftGenerationResult.failed() {
    return const AiAlbumDraftGenerationResult._(
      status: AiAlbumDraftGenerationStatus.failed,
      shouldChargePoints: false,
      failureMessage: 'AI 초안을 준비하지 못했어요. 포인트는 차감되지 않았어요.',
    );
  }

  final AiAlbumDraftGenerationStatus status;
  final bool shouldChargePoints;
  final AlbumRecommendationDraft? draft;
  final String? failureMessage;
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
        );
      }

      final draft = _engine.curate(theme: theme, candidates: candidates);
      if (draft.recommendedPhotos.isEmpty) {
        return AiAlbumDraftGenerationResult.insufficientPhotos(
          minimumPhotoCount: _minimumPhotoCount,
          actualPhotoCount: candidates.length,
        );
      }

      return AiAlbumDraftGenerationResult.success(draft);
    } catch (_) {
      return AiAlbumDraftGenerationResult.failed();
    }
  }
}
