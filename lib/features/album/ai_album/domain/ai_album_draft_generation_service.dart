import 'ai_album_curation_engine.dart';
import 'ai_album_models.dart';
import 'ai_template_text_preflight.dart';
import 'ai_template_job.dart';

typedef AiPhotoCandidateLoader =
    Future<List<PhotoCandidate>> Function(AiPhotoRange range);
typedef AdvancedAiAlbumPreviewPreparer =
    Future<List<PhotoCandidate>> Function(List<PhotoCandidate> candidates);

abstract interface class AiAlbumDraftFailureCode {
  String get code;
}

abstract class AiAlbumDraftProvider {
  const AiAlbumDraftProvider();

  Future<AlbumRecommendationDraft> createTemplate(AiTemplateBrief brief) {
    throw UnsupportedError('template_provider_not_configured');
  }

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
        : (selectedOnly
              ? '선택한 사진이 조금 더 필요해요.'
              : 'AI 템플릿을 만들려면 기준 사진이 조금 더 필요해요.');
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
          '스크린샷이나 작은 이미지는 템플릿 슬롯에서 잠시 제외했어요. 여행·일상 사진이 더 보이는 범위로 다시 골라 주세요. 포인트는 차감되지 않았어요.',
      primaryCtaLabel: '사진 범위 다시 고르기',
      primaryRecoveryAction: AiAlbumDraftRecoveryAction.retryPhotoRange,
    );
  }

  factory AiAlbumDraftGenerationResult.themeMismatch({
    required AlbumTheme theme,
    required AiPhotoRange range,
  }) {
    final label = _themeLabel(theme);
    final selectedOnly = range == AiPhotoRange.limitedLibrary;
    return AiAlbumDraftGenerationResult._(
      status: AiAlbumDraftGenerationStatus.insufficientPhotos,
      shouldChargePoints: false,
      failureTitle: '$label에 맞는 사진을 찾지 못했어요',
      failureMessage: selectedOnly
          ? '허용한 사진 안에서 $label 주제와 맞는 사진을 찾지 못했어요. 더 알맞은 사진을 허용하거나 최근 30일로 다시 살펴봐 주세요. 포인트는 차감되지 않았어요.'
          : '선택한 범위에서 $label 주제와 맞는 사진을 찾지 못했어요. 기간이나 사진 범위를 다시 골라 주세요. 포인트는 차감되지 않았어요.',
      primaryCtaLabel: '사진 범위 다시 고르기',
      primaryRecoveryAction: AiAlbumDraftRecoveryAction.retryPhotoRange,
    );
  }

  factory AiAlbumDraftGenerationResult.permissionDenied() {
    return const AiAlbumDraftGenerationResult._(
      status: AiAlbumDraftGenerationStatus.permissionDenied,
      shouldChargePoints: false,
      failureTitle: '사진을 볼 수 없어 AI 템플릿을 만들지 못했어요',
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
      failureTitle: 'AI 템플릿을 만들지 못했어요',
      failureMessage: 'AI 템플릿을 준비하지 못했어요. 포인트는 차감되지 않았어요.',
      primaryCtaLabel: '사진 범위 다시 고르기',
      primaryRecoveryAction: AiAlbumDraftRecoveryAction.retryPhotoRange,
    );
  }

  factory AiAlbumDraftGenerationResult.templateFailed({
    bool qualityFailure = false,
    String? code,
  }) {
    final explanation = switch (code) {
      'ai_generation_auth_required' => '로그인 상태를 확인한 뒤 다시 시도해 주세요.',
      'ai_generation_insufficient_points' =>
        '포인트가 부족해 생성을 시작하지 않았어요. 포인트를 확인해 주세요.',
      'ai_generation_in_progress' => '이미 템플릿을 생성하고 있어요. 잠시 후 결과를 확인해 주세요.',
      'ai_generation_rate_limited' ||
      'ai_generation_capacity_limited' ||
      'template_provider_rate_limited' ||
      'template_provider_capacity_unavailable' =>
        'AI 사용 한도에 도달했어요. 사용량이 초기화된 뒤 다시 시도해 주세요.',
      'template_provider_not_configured' ||
      'template_provider_model_unavailable' ||
      'template_provider_model_not_supported' ||
      'template_provider_free_only' ||
      'template_provider_invalid_config' ||
      'template_provider_unsupported' => 'AI 연결을 준비 중이에요. 요청 내용은 그대로 남겨두었어요.',
      'ai_generation_privacy_review_required' =>
        'AI의 개인정보 처리 설정을 검토 중이에요. 요청 내용은 AI에 보내지 않았어요.',
      'template_generation_timeout' =>
        '디자인 생성이 오래 걸려 처리 결과를 받지 못했어요. 요청 내용은 그대로 남겨두었어요. 잠시 후 다시 확인해 주세요.',
      'ai_generation_v3_not_validated' =>
        '새 AI 디자인 엔진을 검수 중이에요. 요청 내용은 그대로 남겨두었어요.',
      'ai_generation_price_changed' ||
      'ai_generation_price_confirmation_required' =>
        '무료 혜택이나 사용 포인트를 다시 확인한 뒤 시도해 주세요. 생성을 시작하지 않았어요.',
      _ => null,
    };
    return AiAlbumDraftGenerationResult._(
      status: AiAlbumDraftGenerationStatus.failed,
      shouldChargePoints: false,
      failureTitle: qualityFailure ? '디자인을 조금 더 다듬어야 해요' : 'AI 템플릿을 만들지 못했어요',
      failureMessage: explanation != null
          ? '$explanation 포인트는 차감되지 않았어요.'
          : qualityFailure
          ? '페이지 배치나 가독성이 기준에 맞지 않아 전달하지 않았어요. 요청을 다듬어 다시 시도해 주세요. 포인트는 차감되지 않았어요.'
          : '지금 디자인을 생성하지 못했어요. 요청 내용은 그대로 남겨두었어요. 잠시 후 다시 시도해 주세요. 포인트는 차감되지 않았어요.',
      primaryCtaLabel: '디자인 요청 다시 보기',
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
    AiAlbumDraftProvider? templateProvider,
    AdvancedAiAlbumPreviewPreparer? prepareAdvancedPreviews,
    AiAlbumCurationEngine engine = const AiAlbumCurationEngine(),
    int minimumPhotoCount = 3,
  }) : _collectCandidates = collectCandidates,
       _draftProvider =
           draftProvider ?? MetadataFirstAiAlbumDraftProvider(engine: engine),
       _templateProvider = templateProvider ?? draftProvider,
       _prepareAdvancedPreviews = prepareAdvancedPreviews,
       _minimumPhotoCount = minimumPhotoCount;

  final AiPhotoCandidateLoader _collectCandidates;
  final AiAlbumDraftProvider _draftProvider;
  final AiAlbumDraftProvider? _templateProvider;
  final AdvancedAiAlbumPreviewPreparer? _prepareAdvancedPreviews;
  final int _minimumPhotoCount;

  AiTemplateJobProvider? get jobs => _templateProvider is AiTemplateJobProvider
      ? _templateProvider as AiTemplateJobProvider
      : null;

  Future<AiAlbumDraftGenerationResult> resume(
    AiTemplateJob job, {
    AiTemplatePollingToken? token,
    void Function(AiTemplateJob)? onProgress,
  }) async {
    final provider = jobs;
    if (provider == null) return AiAlbumDraftGenerationResult.failed();
    try {
      final draft = await provider.resumeTemplateJob(
        job,
        token: token,
        onProgress: onProgress,
      );
      return _validateTemplate(job.brief.publicBrief, draft);
    } catch (error) {
      return AiAlbumDraftGenerationResult.templateFailed(
        code: error is AiAlbumDraftFailureCode ? error.code : null,
      );
    }
  }

  AiAlbumDraftGenerationResult _validateTemplate(
    AiTemplateBrief brief,
    AlbumRecommendationDraft draft,
  ) {
    if (draft.design == null ||
        (brief.designVersion == 3 && draft.design!.version != 3) ||
        draft.pageCount != brief.pageCount ||
        draft.design!.aspect != brief.aspect) {
      return AiAlbumDraftGenerationResult.templateFailed(qualityFailure: true);
    }
    if (draft.design!.version == 3) {
      draft.design!.compositionPlan!.validateRequest(
        brief.publicBrief,
        copy: draft.design!.pages
            .expand((page) => page.elements)
            .where((element) => element.kind == 'text')
            .map((element) => element.text!),
      );
      if (draft.design!.printProduct?['id'] != brief.printProductId) {
        return AiAlbumDraftGenerationResult.templateFailed(
          qualityFailure: true,
        );
      }
    }
    validateAiTemplateText(draft.design!);
    return AiAlbumDraftGenerationResult.success(draft);
  }

  Future<AiAlbumDraftGenerationResult> generate({
    required AlbumTheme theme,
    required AiPhotoRange range,
    AiTemplateBrief? designBrief,
    String? generationRequestId,
    AiTemplatePollingToken? token,
    void Function(AiTemplateJob)? onProgress,
  }) async {
    try {
      if (designBrief != null) {
        final provider = _templateProvider ?? _draftProvider;
        final draft =
            provider is AiTemplateJobProvider && generationRequestId != null
            ? await (provider as AiTemplateJobProvider).createTemplateJob(
                designBrief.publicBrief,
                requestId: generationRequestId,
                token: token,
                onProgress: onProgress,
              )
            : await provider.createTemplate(designBrief.publicBrief);
        return _validateTemplate(designBrief.publicBrief, draft);
      }
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
      final excludedForQuality = draft.excludedPhotos.where((photo) {
        return photo.reasons.any(
          (reason) =>
              reason.type == AiCurationReasonType.screenshotExcluded ||
              reason.type == AiCurationReasonType.lowResolutionExcluded,
        );
      }).length;
      if (draft.recommendedPhotos.isEmpty &&
          excludedForQuality >= _minimumPhotoCount) {
        return AiAlbumDraftGenerationResult.lowQualityPhotos();
      }
      if (draft.recommendedPhotos.isEmpty && draft.templateSlots.isEmpty) {
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
    } catch (error) {
      if (designBrief != null) {
        return AiAlbumDraftGenerationResult.templateFailed(
          code: error is AiAlbumDraftFailureCode ? error.code : null,
          qualityFailure:
              error is FormatException ||
              error.toString().contains('template_quality_failed'),
        );
      }
      if (error.toString().contains('themed_candidates_not_found')) {
        return AiAlbumDraftGenerationResult.themeMismatch(
          theme: theme,
          range: range,
        );
      }
      return AiAlbumDraftGenerationResult.failed();
    }
  }
}

String _themeLabel(AlbumTheme theme) {
  return switch (theme) {
    AlbumTheme.travel => '여행',
    AlbumTheme.couple => '커플',
    AlbumTheme.family => '가족',
    AlbumTheme.baby => '성장',
    AlbumTheme.birthday => '기념일',
    AlbumTheme.friends => '친구',
    AlbumTheme.daily => '일상',
    AlbumTheme.custom => '선택한 주제',
  };
}
