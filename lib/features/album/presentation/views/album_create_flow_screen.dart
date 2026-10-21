import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:uuid/uuid.dart';
import '../../../../config/env.dart';
import '../../../../core/constants/cover_size.dart';
import '../../../../core/constants/album_page_policy.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/web/web_design.dart';
import '../../../../shared/widgets/album_bottom_sheet.dart';
import '../../../../shared/widgets/album_stage_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../../../core/navigation/web_unsaved_work_guard.dart';
import '../../../../core/navigation/web_app_location.dart';
import '../../../billing/data/billing_provider.dart';
import '../../../billing/data/billing_repository.dart';
import '../../../profile/presentation/views/billing_management_screen.dart';
import '../../../profile/domain/order_visibility_owner.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/layer.dart';
import '../../domain/entities/album_creation_template.dart';
import '../../../store/domain/entities/premium_template.dart';
import '../../../store/data/api/template_provider.dart';
import '../../../store/presentation/views/template_detail_screen.dart';
import '../../ai_album/domain/ai_album_draft_generation_service.dart';
import '../../ai_album/domain/ai_album_draft_template_builder.dart';
import '../../ai_album/domain/ai_album_models.dart';
import '../../ai_album/domain/ai_template_job.dart';
import '../../ai_album/domain/ai_template_paper_tone.dart';
import '../../ai_album/data/ai_template_device_store.dart';
import '../../data/api/album_provider.dart';
import '../../data/gallery/browser_photo_asset.dart';
import '../../data/album_creation_catalog_provider.dart';
import '../../data/album_creation_draft_store.dart';
import '../../domain/entities/album_creation_draft.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../widgets/create_flow/album_creation_review_sheet.dart';
import '../widgets/web/web_album_workspace.dart';
import '../widgets/create_flow/creation_workspace.dart';
import '../widgets/create_flow/album_create_step1.dart';
import '../widgets/create_flow/album_create_step2.dart';
import '../widgets/create_flow/ai_album_draft_failure_step.dart';
import '../widgets/create_flow/ai_album_photo_range_step.dart';
import '../widgets/create_flow/ai_album_point_confirmation_step.dart';
import '../widgets/create_flow/ai_album_recommendation_review_step.dart';
import '../widgets/create_flow/ai_album_start_step.dart';
import '../widgets/create_flow/ai_template_brief_step.dart';
import '../widgets/create_flow/ai_template_generating_step.dart';
import '../widgets/create_flow/ai_template_design_review.dart';
import '../widgets/create_flow/template_photo_fill_step.dart';
import '../viewmodels/album_editor_view_model.dart';
import 'add_cover_screen.dart';
import 'page_editor_screen.dart';

/// 앨범 생성 플로우 화면 (스텝1~3)
class _CreationStepReveal extends StatelessWidget {
  const _CreationStepReveal({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    // Only the incoming step is mounted; editor canvases must not coexist.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: .65 + .35 * value,
        child: Transform.translate(
          offset: Offset(0, 4 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

class AlbumCreateFlowScreen extends ConsumerStatefulWidget {
  final AlbumCreationTemplate? initialCreationTemplate;
  final List<List<LayerModel>>? initialTemplatePages;
  final Map<String, List<List<LayerModel>>>? initialTemplatePagesByAspect;
  final String? initialAlbumTitle;
  final List<String>? initialTemplatePreviewImages;
  final CoverSize? initialCoverSize;
  final bool usesServerDraftProvider;
  final bool usesAdvancedServerAnalysis;
  final AlbumCreationDraft? initialDraft;
  final bool initialAiMode;

  const AlbumCreateFlowScreen({
    super.key,
    this.initialCreationTemplate,
    this.initialTemplatePages,
    this.initialTemplatePagesByAspect,
    this.initialAlbumTitle,
    this.initialTemplatePreviewImages,
    this.initialCoverSize,
    this.initialDraft,
    this.initialAiMode = false,
    bool? usesServerDraftProvider,
    bool? usesAdvancedServerAnalysis,
  }) : usesServerDraftProvider =
           usesServerDraftProvider ?? Env.useServerAiAlbumDraft,
       usesAdvancedServerAnalysis =
           usesAdvancedServerAnalysis ?? Env.useAdvancedServerAiAlbumAnalysis;

  @override
  ConsumerState<AlbumCreateFlowScreen> createState() =>
      _AlbumCreateFlowScreenState();
}

class _AlbumCreateFlowScreenState extends ConsumerState<AlbumCreateFlowScreen>
    with WidgetsBindingObserver {
  final _photoSession = TemplatePhotoFillSession();
  late String _draftId;
  String? _draftOwner;
  bool _savingDraft = false;
  Future<bool>? _draftSaveFuture;
  Future<void>? _draftWriteSession;
  Object? _draftWriteSessionError;
  bool _leaving = false;
  bool _reviewing = false;
  bool _startingAlbum = false;
  List<LayerModel>? _draftCoverLayers;
  Size? _draftCoverCanvasSize;
  int _currentStep = 0;
  String _albumTitle = '';
  static int _costForPages(int pageCount) => 300 + pageCount * 10;
  int get _aiDraftPointCost => _costForPages(_selectedPageCount);
  static const AiAlbumDraftTemplateBuilder _aiDraftTemplateBuilder =
      AiAlbumDraftTemplateBuilder();
  bool _hasSelectedCreationMode = false;
  bool _isAiCreationMode = false;
  bool _hasConfirmedAiPointCost = false;
  bool _isGeneratingAiDraft = false;
  int _aiDraftRequestId = 0;
  DateTime? _aiDraftRequestStartedAt;
  bool _isAcceptingAiDraft = false;
  bool _aiPointUsageUnconfirmed = false;
  Future<AiAlbumDraftPointUsageResult>? _aiPointUsageFuture;
  String? _aiPointUsageDraftId;
  String? _aiRequestOwner;
  bool _aiAccountChanged = false;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _aiWaitNotice;

  void _dismissAiWaitNotice() {
    final notice = _aiWaitNotice;
    _aiWaitNotice = null;
    notice?.close();
  }

  bool get _ownsAiRequest {
    final owner = _aiRequestOwner;
    return owner != null &&
        owner.isNotEmpty &&
        ref.read(visibleOrderOwnerProvider) == owner;
  }

  void _discardAiAccountWork() {
    _stopAiObservation();
    _aiCurrentJob = null;
    _aiResumeCandidate = null;
    _aiDeviceCheckpoint = null;
    _aiUnappliedLocalEdits = null;
    _aiGenerationUuid = null;
    _aiInputDirty = false;
    _aiLoadingLatest = false;
    _aiDeviceMessage = null;
    _dismissAiWaitNotice();
    _aiDraftRequestId += 1;
    _aiRequestOwner = null;
    _aiAccountChanged = true;
    _clearAiResultHistory();
    _isGeneratingAiDraft = false;
    _isAcceptingAiDraft = false;
    _aiPointUsageUnconfirmed = false;
    _aiPointUsageFuture = null;
    _aiPointUsageDraftId = null;
    _pendingAiDraft = null;
    _designBrief = null;
    _selectedAiTheme = null;
    _selectedAiRange = null;
    _aiDraftFailureTitle = null;
    _aiDraftFailureMessage = null;
    _aiDraftPrimaryCtaLabel = null;
    _aiDraftPrimaryRecoveryAction = null;
    _hasConfirmedAiPointCost = false;
    _albumTitle = '';
    _selectedCover = null;
    _preferredCoverType = null;
    _selectedPageCount = AlbumPagePolicy.minInnerPages;
    _hasSelectedCreationMode = false;
    _draftOwner = ref.read(visibleOrderOwnerProvider);
    _draftId = const Uuid().v4();
  }

  AlbumTheme? _selectedAiTheme;
  AiTemplateBrief? _designBrief;
  AiPhotoRange? _selectedAiRange;
  AlbumRecommendationDraft? _pendingAiDraft;
  AiTemplatePollingToken? _aiPolling;
  AiTemplateJob? _aiCurrentJob;
  AiTemplateJob? _aiResumeCandidate;
  Map<String, dynamic>? _aiDeviceCheckpoint;
  Map? _aiUnappliedLocalEdits;
  String? _aiGenerationUuid;
  String? _aiDeviceMessage;
  Timer? _aiMemoTimer;
  bool _aiLoadingLatest = false;
  bool _aiInputDirty = false;
  bool _aiWasPolling = false;
  int _aiPrefsRevision = 0;
  AiTemplateDesign? _aiPaperOriginalDesign;
  AlbumRecommendationDraft? _comparisonAiDraft;
  bool _previewAiComparison = false;
  ({
    AlbumRecommendationDraft draft,
    AiTemplateDesign? originalDesign,
    AiTemplateBrief? brief,
    AlbumTheme? theme,
    AiPhotoRange? range,
    CoverSize? cover,
    PrintCoverType? coverType,
    int pageCount,
  })?
  _aiRequestEdit;
  String? _aiDraftFailureTitle;
  String? _aiDraftFailureMessage;
  String? _aiDraftPrimaryCtaLabel;
  AiAlbumDraftRecoveryAction? _aiDraftPrimaryRecoveryAction;

  void _stopAiObservation() {
    _aiPolling?.cancel();
    _aiPolling = null;
    _aiMemoTimer?.cancel();
    _aiMemoTimer = null;
  }

  Future<void> _saveAiDevice() async {
    final owner = _aiRequestOwner;
    final generationId = _aiGenerationUuid;
    final brief = _designBrief;
    if (owner == null ||
        brief == null ||
        !_ownsAiRequest ||
        ref.read(aiAlbumDraftGenerationServiceProvider).jobs == null)
      return;
    try {
      final cachedEdits = _aiDeviceCheckpoint?['requestId'] == generationId
          ? (_aiDeviceCheckpoint?['edits'])
          : null;
      final value = <String, Object?>{
        'safeDesign': brief.toSafeDesignJson(),
        'memo': brief.prompt,
        'requestId': _aiGenerationUuid,
        if (_aiCurrentJob != null) 'envelope': _aiCurrentJob!.envelope,
        if (_pendingAiDraft?.design != null && _aiPaperOriginalDesign != null)
          'edits':
              _aiUnappliedLocalEdits ??
              aiTemplateLocalEdits(
                _aiPaperOriginalDesign!,
                _pendingAiDraft!.design!,
              ),
        if (_pendingAiDraft?.design == null && cachedEdits is Map)
          'edits': cachedEdits,
      };
      await ref.read(aiTemplateDeviceStoreProvider).save(owner, value);
      if (mounted &&
          _ownsAiRequest &&
          _aiGenerationUuid == generationId &&
          _aiRequestOwner == owner)
        _aiDeviceCheckpoint = Map<String, dynamic>.from(value);
    } catch (_) {
      if (mounted && _ownsAiRequest)
        setState(
          () => _aiDeviceMessage =
              '이 기기에 메모를 저장하지 못했어요. 저장 공간을 확인해 주세요. 서버 요청은 이전 작업에서 다시 확인할 수 있어요.',
        );
    }
  }

  void _rememberAiBrief(AiTemplateBrief brief) {
    _designBrief = brief;
    _aiInputDirty = true;
    _aiMemoTimer?.cancel();
    _aiMemoTimer = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(_saveAiDevice()),
    );
  }

  Future<void> _loadAiSession({bool continuePolling = false}) async {
    final jobs = ref.read(aiAlbumDraftGenerationServiceProvider).jobs;
    final owner = _aiRequestOwner;
    final requestId = _aiDraftRequestId;
    if (jobs == null ||
        owner == null ||
        !_ownsAiRequest ||
        _aiLoadingLatest ||
        _isAcceptingAiDraft ||
        _aiPointUsageUnconfirmed)
      return;
    setState(() => _aiLoadingLatest = true);
    bool current() =>
        mounted &&
        _isAiCreationMode &&
        _aiRequestOwner == owner &&
        _ownsAiRequest &&
        requestId == _aiDraftRequestId;
    try {
      try {
        final saved = await ref.read(aiTemplateDeviceStoreProvider).load(owner);
        if (!current()) return;
        _aiDeviceCheckpoint = saved;
        if (!_aiInputDirty && saved?['safeDesign'] is Map) {
          final restored = AiTemplateBrief.fromSafeDesign(
            saved!['safeDesign'] as Map,
            localMemo: saved['memo'] as String? ?? '',
          );
          setState(() {
            _designBrief = restored;
            _selectedCover = restored.coverSize;
            _preferredCoverType = restored.coverSize.coverType;
            _selectedPageCount = restored.pageCount;
            _aiPrefsRevision++;
          });
        }
      } catch (_) {
        if (current())
          setState(
            () => _aiDeviceMessage =
                '기기에 저장한 메모를 읽지 못했어요. 서버에 보관한 디자인 요청은 계속 확인할 수 있어요.',
          );
      }
      final latest = await jobs.latestTemplateJob();
      if (!current()) return;
      setState(
        () => _aiResumeCandidate =
            latest != null && (latest.pending || latest.usable) ? latest : null,
      );
      if (latest?.state == AiTemplateJobState.consumed &&
          latest?.usable == false) {
        setState(
          () => _aiDeviceMessage =
              '사용했던 디자인의 임시 보관 기간이 끝났어요. 이미 만든 앨범은 앨범 목록에서 확인해 주세요.',
        );
      }
      if (continuePolling && _aiResumeCandidate != null) {
        unawaited(_resumeAiJob(_aiResumeCandidate!));
      } else if (continuePolling) {
        setState(() {
          _isGeneratingAiDraft = false;
          _selectedAiTheme = null;
          _selectedAiRange = null;
        });
      }
    } catch (_) {
      if (current()) {
        setState(() {
          _aiDeviceMessage = '이전 작업을 확인하지 못했어요. 다시 확인해 주세요.';
          if (continuePolling) {
            _isGeneratingAiDraft = false;
            _selectedAiTheme = null;
            _selectedAiRange = null;
          }
        });
      }
    } finally {
      if (mounted && _aiRequestOwner == owner)
        setState(() => _aiLoadingLatest = false);
    }
  }

  void _onAiJobProgress(AiTemplateJob job, int requestId) {
    if (!mounted ||
        !_ownsAiRequest ||
        requestId != _aiDraftRequestId ||
        _aiPolling?.canceled == true)
      return;
    final changed =
        _aiCurrentJob?.state != job.state ||
        _aiCurrentJob?.stage != job.stage ||
        _aiCurrentJob?.completedStages != job.completedStages ||
        _aiCurrentJob?.nextAttemptAt != job.nextAttemptAt;
    setState(() => _aiCurrentJob = job);
    if (changed) unawaited(_saveAiDevice());
  }

  Future<void> _resumeAiJob(AiTemplateJob job) async {
    if (!_ownsAiRequest ||
        _isAcceptingAiDraft ||
        _aiPointUsageUnconfirmed ||
        (_isGeneratingAiDraft && _aiPolling?.canceled != true))
      return;
    final owner = _aiRequestOwner;
    final previousRequestId = _aiDraftRequestId;
    if (job.usable) {
      try {
        job = await ref
            .read(aiAlbumDraftGenerationServiceProvider)
            .jobs!
            .templateJobStatus(job.id);
      } catch (_) {
        if (mounted && _aiRequestOwner == owner && _ownsAiRequest)
          setState(
            () => _aiDeviceMessage = '디자인의 보관 상태를 확인하지 못했어요. 다시 확인해 주세요.',
          );
        return;
      }
      if (!mounted ||
          _aiRequestOwner != owner ||
          !_ownsAiRequest ||
          previousRequestId != _aiDraftRequestId)
        return;
    }
    if (!job.pending && !job.usable) {
      setState(() {
        _aiResumeCandidate = null;
        _isGeneratingAiDraft = false;
        _selectedAiTheme = null;
        _selectedAiRange = null;
        _aiDeviceMessage = job.state == AiTemplateJobState.consumed
            ? '사용했던 디자인의 임시 보관 기간이 끝났어요. 이미 만든 앨범은 앨범 목록에서 확인해 주세요.'
            : '이 요청의 보관 기간이 끝났거나 취소됐어요. 새 디자인을 선택할 수 있어요.';
      });
      return;
    }
    final saved = _aiDeviceCheckpoint;
    final memo = saved?['requestId'] == job.id
        ? ((saved?['memo'] as String?) ?? '')
        : '';
    _aiPolling?.cancel();
    final polling = _aiPolling = AiTemplatePollingToken();
    final requestId = ++_aiDraftRequestId;
    setState(() {
      _designBrief = AiTemplateBrief.fromSafeDesign(
        job.brief.toSafeDesignJson(),
        localMemo: memo,
      );
      _selectedCover = job.brief.coverSize;
      _selectedPageCount = job.brief.pageCount;
      _preferredCoverType = job.brief.coverSize.coverType;
      _selectedAiTheme = AlbumTheme.custom;
      _selectedAiRange = AiPhotoRange.manualSelection;
      _aiGenerationUuid = job.id;
      _aiCurrentJob = job;
      _aiResumeCandidate = null;
      _isGeneratingAiDraft = true;
      _hasConfirmedAiPointCost = true;
      _pendingAiDraft = null;
      _aiDraftFailureMessage = null;
      _aiDraftRequestStartedAt = DateTime.now();
    });
    final result = await ref
        .read(aiAlbumDraftGenerationServiceProvider)
        .resume(
          job,
          token: polling,
          onProgress: (progress) => _onAiJobProgress(progress, requestId),
        );
    if (polling.canceled) return;
    _applyAiGenerationResult(result, requestId, restoring: saved);
  }

  Future<void> _refreshAiJob() async {
    final job = _aiCurrentJob;
    final jobs = ref.read(aiAlbumDraftGenerationServiceProvider).jobs;
    final requestId = _aiDraftRequestId;
    if (job == null ||
        jobs == null ||
        !_ownsAiRequest ||
        _isAcceptingAiDraft ||
        _aiPointUsageUnconfirmed)
      return;
    _aiPolling?.cancel();
    try {
      final updated = await jobs.templateJobStatus(job.id);
      if (!mounted ||
          !_ownsAiRequest ||
          requestId != _aiDraftRequestId ||
          _aiGenerationUuid != job.id)
        return;
      await _resumeAiJob(updated);
    } catch (_) {
      if (!mounted || !_ownsAiRequest || requestId != _aiDraftRequestId) return;
      await _pauseAiJob();
      if (mounted && _ownsAiRequest)
        setState(
          () => _aiDeviceMessage = '진행 상황을 확인하지 못했어요. 이전 작업을 다시 확인해 주세요.',
        );
    }
  }

  Future<void> _pauseAiJob() async {
    if (!_ownsAiRequest || _isAcceptingAiDraft || _aiPointUsageUnconfirmed)
      return;
    await _saveAiDevice();
    if (!mounted || !_ownsAiRequest) return;
    _aiPolling?.cancel();
    setState(() {
      _aiResumeCandidate = _aiCurrentJob;
      _aiDeviceMessage = '요청은 서버에서 계속 진행돼요. 이 화면을 나가도 다음에 이어서 확인할 수 있어요.';
      _isGeneratingAiDraft = false;
      _selectedAiTheme = null;
      _selectedAiRange = null;
      _aiPrefsRevision++;
    });
  }

  Widget _aiSessionBanner(Widget child) {
    if (_aiRequestEdit != null) return child;
    final job = _pendingAiDraft == null ? _aiResumeCandidate : null;
    if (job == null && !_aiLoadingLatest && _aiDeviceMessage == null)
      return child;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_aiDeviceMessage != null) Text(_aiDeviceMessage!),
              if (job != null)
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      job.alreadyAccepted
                          ? '포인트 사용을 확인한 디자인이 있어요. 추가 차감 없이 이어서 편집할 수 있어요.'
                          : job.usable
                          ? '확인할 AI 디자인이 있어요.'
                          : '만들던 AI 디자인을 이어서 확인할 수 있어요.',
                    ),
                    TextButton(
                      onPressed: () => _resumeAiJob(job),
                      child: Text(job.alreadyAccepted ? '이어서 편집' : '이어서 확인'),
                    ),
                    if (job.pending)
                      TextButton(
                        onPressed: () async {
                          final owner = _aiRequestOwner;
                          try {
                            await ref
                                .read(aiAlbumDraftGenerationServiceProvider)
                                .jobs!
                                .cancelTemplateJob(job.id);
                            if (mounted &&
                                _aiRequestOwner == owner &&
                                _ownsAiRequest)
                              setState(() => _aiResumeCandidate = null);
                          } catch (_) {
                            if (mounted && _ownsAiRequest)
                              setState(
                                () => _aiDeviceMessage =
                                    '취소 결과를 확인하지 못했어요. 다시 확인해 주세요.',
                              );
                          }
                        },
                        child: const Text('이전 요청 취소'),
                      ),
                  ],
                ),
              if (_aiLoadingLatest) const Text('이전 작업 확인 중'),
              if (_aiDeviceMessage != null && !_aiLoadingLatest)
                TextButton(
                  onPressed: _loadAiSession,
                  child: const Text('이전 작업 다시 확인'),
                ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  void _clearAiResultHistory() {
    _aiPaperOriginalDesign = null;
    _comparisonAiDraft = null;
    _aiRequestEdit = null;
    _previewAiComparison = false;
  }

  void _editAiRequest() {
    final draft = _pendingAiDraft;
    if (draft == null ||
        _isGeneratingAiDraft ||
        _isAcceptingAiDraft ||
        _aiPointUsageUnconfirmed ||
        !_ownsAiRequest)
      return;
    setState(() {
      _aiRequestEdit = (
        draft: draft,
        originalDesign: _aiPaperOriginalDesign,
        brief: _designBrief,
        theme: _selectedAiTheme,
        range: _selectedAiRange,
        cover: _selectedCover,
        coverType: _preferredCoverType,
        pageCount: _selectedPageCount,
      );
      if (_designBrief != null) _selectedAiTheme = null;
      _selectedAiRange = null;
      _hasConfirmedAiPointCost = false;
    });
  }

  bool _returnToAiResult() {
    final saved = _aiRequestEdit;
    if (saved == null ||
        _isGeneratingAiDraft ||
        _isAcceptingAiDraft ||
        _aiPointUsageUnconfirmed ||
        !_ownsAiRequest)
      return false;
    setState(() {
      _pendingAiDraft = saved.draft;
      _aiPaperOriginalDesign = saved.originalDesign;
      _designBrief = saved.brief;
      _selectedAiTheme = saved.theme;
      _selectedAiRange = saved.range;
      _selectedCover = saved.cover;
      _preferredCoverType = saved.coverType;
      _selectedPageCount = saved.pageCount;
      _hasConfirmedAiPointCost = true;
      _aiDraftFailureTitle = null;
      _aiDraftFailureMessage = null;
      _aiDraftPrimaryCtaLabel = null;
      _aiDraftPrimaryRecoveryAction = null;
      _aiRequestEdit = null;
    });
    unawaited(_saveAiDevice());
    return true;
  }

  Widget _withAiResultRecovery(Widget child) {
    child = _aiSessionBanner(child);
    if (_aiPointUsageUnconfirmed ||
        _isAcceptingAiDraft ||
        _isGeneratingAiDraft) {
      return child;
    }
    final canReturn = _aiRequestEdit != null;
    final canCompare = _comparisonAiDraft?.design != null;
    if (!canReturn && !canCompare) return child;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (canReturn)
                TextButton.icon(
                  key: const ValueKey('ai-return-to-result'),
                  onPressed: _returnToAiResult,
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: const Text('기존 결과로 돌아가기'),
                )
              else if (canCompare)
                TextButton.icon(
                  key: const ValueKey('ai-open-previous-result'),
                  onPressed: () => setState(() => _previewAiComparison = true),
                  icon: const Icon(Icons.compare_arrows_rounded, size: 18),
                  label: const Text('이전 결과 비교'),
                ),
              Text(
                canReturn ? '새 생성을 시작하면 이전 결과는 비교용으로 남아요.' : '이전 결과는 비교만 가능해요.',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  CoverSize? _selectedCover;
  PrintCoverType? _preferredCoverType;
  int _selectedPageCount = AlbumPagePolicy.minInnerPages;
  int _templateMinPageCount = AlbumPagePolicy.minInnerPages;
  bool _allowEditing = true;
  List<String> _invitedEmails = [];
  int? _createdAlbumId;
  List<List<LayerModel>>? _resolvedTemplatePages;
  List<List<LayerModel>>? _baseTemplatePages;
  Map<String, List<List<LayerModel>>>? _templatePagesByAspect;
  Map<String, Size> _templateCanvasSizes = {};
  Size? _baseTemplateCanvasSize;
  String? _templateTitle;
  String? _templatePreviewUrl;
  String _sourceLabel = '직접 만들기';
  bool _showPhotoFill = false;
  bool _hasFilledPhotos = false;
  bool _returnToSetupFromHub = false;
  bool _usesPhysicalTemplateCanvas = false;
  bool _preserveTemplateTypography = false;

  /// 커버 편집 단계(step 1)에서 AppBar 완료 버튼이 호출할 콜백
  Future<void> Function()? _onCompletePressed;

  int _normalizePageCount(int count) {
    // Oversized templates stay intact and are blocked in setup.
    if (_templateMinPageCount > AlbumPagePolicy.maxInnerPages) {
      return _templateMinPageCount;
    }
    final normalized = AlbumPagePolicy.normalize(count);
    return normalized < _templateMinPageCount
        ? _templateMinPageCount
        : normalized;
  }

  void _resetDesign() {
    _stopAiObservation();
    _aiCurrentJob = null;
    _aiResumeCandidate = null;
    _aiUnappliedLocalEdits = null;
    _aiGenerationUuid = null;
    _aiInputDirty = false;
    _aiDeviceMessage = null;
    _clearAiResultHistory();
    _aiRequestOwner = null;
    _photoSession.reset();
    _draftCoverLayers = null;
    _draftCoverCanvasSize = null;
    _usesPhysicalTemplateCanvas = false;
    _preserveTemplateTypography = false;
    _returnToSetupFromHub = false;
    _resolvedTemplatePages = null;
    _baseTemplatePages = null;
    _templatePagesByAspect = null;
    _templateCanvasSizes = {};
    _baseTemplateCanvasSize = null;
    _templateTitle = null;
    _templatePreviewUrl = null;
    _templateMinPageCount = AlbumPagePolicy.minInnerPages;
    _selectedPageCount = AlbumPagePolicy.normalize(_selectedPageCount);
    _sourceLabel = '직접 만들기';
    _hasFilledPhotos = false;
    _showPhotoFill = false;
    _pendingAiDraft = null;
    _selectedAiTheme = null;
    _selectedAiRange = null;
    _hasConfirmedAiPointCost = false;
    _aiDraftFailureMessage = null;
  }

  void _useTemplate(AlbumCreationTemplate selection) {
    _resetDesign();
    _preserveTemplateTypography = selection.preserveTypography;
    _usesPhysicalTemplateCanvas = true;
    _selectedCover = newAlbumCoverSize(
      selection.cover,
    ).withCoverType(_preferredCoverType ?? selection.cover.coverType);
    _preferredCoverType = _selectedCover!.coverType;
    final sourceKey = AlbumCreationTemplate.variantKey(selection.cover);
    _templatePagesByAspect = {
      ...selection.variants,
      sourceKey: selection.pages,
    };
    _baseTemplateCanvasSize =
        selection.pagesCanvasSize ?? coverCanvasBaseSize(selection.cover);
    _templateCanvasSizes = {
      ...selection.variantCanvasSizes,
      sourceKey: _baseTemplateCanvasSize!,
    };
    _baseTemplatePages = selection.pages;
    _applyTemplateByCoverIfNeeded(_selectedCover!);
    _templateTitle = selection.title;
    _templatePreviewUrl = selection.previewUrl;
    _sourceLabel = '선택한 템플릿';
    _templateMinPageCount = AlbumPagePolicy.minimumForContent(
      (_resolvedTemplatePages ?? selection.pages).length - 1,
    );
    _selectedPageCount = _templateMinPageCount;
    if (_albumTitle.trim().isEmpty) _albumTitle = selection.title;
    _isAiCreationMode = false;
    _hasSelectedCreationMode = true;
  }

  Future<void> _selectTemplate(PremiumTemplate template) async {
    final selection = await Navigator.push<AlbumCreationTemplate>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TemplateDetailScreen(template: template, selectForCreation: true),
      ),
    );
    if (!mounted || selection == null) return;
    setState(() => _useTemplate(selection));
  }

  Future<bool> _confirmDesignChange() async {
    if (!_hasFilledPhotos) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('디자인을 변경할까요?'),
            content: const Text('현재 넣은 사진은 다시 배치해야 해요. 앨범 제목은 유지돼요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('유지하기'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('변경하기'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _changeDesign() async {
    if (!await _confirmDesignChange() || !mounted) return;
    setState(() {
      _returnToSetupFromHub = true;
      _hasSelectedCreationMode = false;
      _isAiCreationMode = false;
    });
  }

  Future<void> _selectCover(CoverSize cover) async {
    if (cover.productId == _selectedCover?.productId) return;
    final sameSize = cover.sizeProductId == _selectedCover?.sizeProductId;
    if (!sameSize &&
        _resolvedTemplatePages != null &&
        !await _confirmDesignChange())
      return;
    if (!mounted) return;
    setState(() {
      _selectedCover = cover;
      _preferredCoverType = cover.coverType;
      if (!sameSize) {
        _photoSession.reset();
        _applyTemplateByCoverIfNeeded(cover);
        _hasFilledPhotos =
            _resolvedTemplatePages
                ?.expand((p) => p)
                .any((l) => l.type == LayerType.image && l.hasImageSource) ??
            false;
      }
    });
  }

  Widget _buildCreationProgress() {
    final hasPhotos = _resolvedTemplatePages != null || _isAiCreationMode;
    final labels = hasPhotos
        ? ['디자인', '설정', '사진', '표지', '편집']
        : ['디자인', '설정', '표지', '편집'];
    final selected = _isAiCreationMode
        ? 0
        : _currentStep == 0
        ? 1
        : _currentStep == 2
        ? labels.length - 1
        : _showPhotoFill
        ? 2
        : labels.length - 2;
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: LayoutBuilder(
          builder: (context, box) {
            final compact =
                box.maxWidth < 520 ||
                MediaQuery.viewInsetsOf(context).bottom > 0;
            return Semantics(
              label:
                  '${selected + 1} / ${labels.length}단계, ${labels[selected]}',
              child: compact
                  ? Row(
                      children: [
                        Text(
                          '${selected + 1} / ${labels.length}',
                          style: ExperienceFormStyle.text(
                            context,
                            12,
                            secondary: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          labels[selected],
                          style: ExperienceFormStyle.text(
                            context,
                            13,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: (selected + 1) / labels.length,
                            minHeight: 2,
                            color: SnapFitColors.accent,
                            backgroundColor: ExperienceFormStyle.line(context),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        for (var i = 0; i < labels.length; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    width: 2,
                                    color: i <= selected
                                        ? SnapFitColors.accent
                                        : ExperienceFormStyle.line(context),
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '${i + 1}  ${labels[i]}',
                                  style: ExperienceFormStyle.text(
                                    context,
                                    12,
                                    weight: i == selected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    secondary: i != selected,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  List<List<LayerModel>> _hydrateTemplatePages(List<List<LayerModel>> pages) {
    final images = widget.initialTemplatePreviewImages ?? const <String>[];
    if (images.isEmpty) return pages;

    var imageCursor = 0;
    return pages
        .map((page) {
          return page
              .map((layer) {
                if (layer.type != LayerType.image) return layer;
                final hasUrl =
                    (layer.previewUrl != null &&
                        layer.previewUrl!.isNotEmpty) ||
                    (layer.imageUrl != null && layer.imageUrl!.isNotEmpty) ||
                    (layer.originalUrl != null &&
                        layer.originalUrl!.isNotEmpty);
                if (hasUrl) return layer;
                final url = images[imageCursor % images.length];
                imageCursor++;
                return layer.copyWith(
                  previewUrl: url,
                  imageUrl: url,
                  originalUrl: url,
                );
              })
              .toList(growable: false);
        })
        .toList(growable: false);
  }

  String _aspectKeyFromCover(CoverSize cover) {
    final ratio = cover.ratio;
    if (ratio >= 1.05) return 'landscape';
    if (ratio <= 0.95) return 'portrait';
    return 'square';
  }

  CoverSize _resolveInitialCover() {
    if (widget.initialCoverSize != null) {
      return newAlbumCoverSize(widget.initialCoverSize);
    }
    final variants = _templatePagesByAspect;
    if (variants != null &&
        variants.isNotEmpty &&
        !variants.containsKey(defaultCoverSize.productId) &&
        !variants.containsKey('square') &&
        variants.containsKey('landscape')) {
      return newAlbumCoverSize(legacyCoverSizes.last);
    }
    return defaultCoverSize;
  }

  void _applyTemplateByCoverIfNeeded(CoverSize cover) {
    final variants = _templatePagesByAspect;
    final productKey = AlbumCreationTemplate.variantKey(cover);
    final sizeKey = cover.sizeProductId;
    final aspectKey = _aspectKeyFromCover(cover);
    final key = variants?.containsKey(productKey) == true
        ? productKey
        : variants?.containsKey(sizeKey) == true
        ? sizeKey
        : variants?.containsKey(aspectKey) == true
        ? aspectKey
        : null;
    var selected = key == null ? _baseTemplatePages : variants?[key];
    var source = key == null
        ? _baseTemplateCanvasSize
        : _templateCanvasSizes[key];
    if (selected == null || selected.isEmpty) {
      if (variants == null || variants.isEmpty) return;
      final fallback = variants.entries.first;
      selected = fallback.value;
      source =
          _templateCanvasSizes[fallback.key] ??
          _legacyVariantCanvas(fallback.key);
    }
    if ((_baseTemplatePages?.length ?? 0) > 1 && selected.length <= 1) {
      selected = _baseTemplatePages!;
      source = _baseTemplateCanvasSize;
    }
    _resolvedTemplatePages = AlbumCreationTemplate.preparePages(
      _hydrateTemplatePages(selected),
      sourceCanvas: source ?? _legacyVariantCanvas(key ?? aspectKey),
      cover: cover,
      clearSamplePhotos: false,
    );
    _usesPhysicalTemplateCanvas = true;
    _templateMinPageCount = AlbumPagePolicy.minimumForContent(
      _resolvedTemplatePages!.length - 1,
    );
    _selectedPageCount = _normalizePageCount(_selectedPageCount);
  }

  Size _legacyVariantCanvas(String key) {
    final product = coverSizeForProduct(key);
    if (product != null) return coverCanvasBaseSize(product);
    final ratio = key == 'portrait'
        ? 3 / 4
        : key == 'landscape'
        ? 4 / 3
        : 1.0;
    return Size(kCoverReferenceWidth, kCoverReferenceWidth / ratio);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _draftId = widget.initialDraft?.id ?? const Uuid().v4();
    _draftOwner = ref.read(authViewModelProvider).asData?.value?.id;
    if (kIsWeb && _draftOwner?.isNotEmpty == true) {
      final store = ref.read(albumCreationDraftStoreProvider);
      if (store is AlbumCreationDraftWriteSession) {
        _draftWriteSession = (store as AlbumCreationDraftWriteSession)
            .beginDraftWriteSession(
              _draftOwner!,
              _draftId,
              restoring: widget.initialDraft,
            )
            .then<void>(
              (_) {},
              onError: (Object error, StackTrace _) {
                // Keep asynchronous preparation failures handled until Save can show
                // the message without discarding the document being edited.
                _draftWriteSessionError = error;
              },
            );
      }
    }
    _hasSelectedCreationMode =
        (widget.initialTemplatePages != null &&
            widget.initialTemplatePages!.isNotEmpty) ||
        (widget.initialTemplatePagesByAspect != null &&
            widget.initialTemplatePagesByAspect!.isNotEmpty) ||
        (widget.initialAlbumTitle != null &&
            widget.initialAlbumTitle!.trim().isNotEmpty);

    if (widget.initialTemplatePagesByAspect != null &&
        widget.initialTemplatePagesByAspect!.isNotEmpty) {
      _templatePagesByAspect = widget.initialTemplatePagesByAspect!.map((k, v) {
        final key = coverSizeForProduct(k)?.productId ?? k.toLowerCase();
        _templateCanvasSizes[key] = _legacyVariantCanvas(key);
        return MapEntry(key, v);
      });
    }
    if (widget.initialTemplatePages != null &&
        widget.initialTemplatePages!.isNotEmpty) {
      _baseTemplatePages = _hydrateTemplatePages(widget.initialTemplatePages!);
      final sourceCover = widget.initialCoverSize ?? defaultCoverSize;
      _baseTemplateCanvasSize = Size(
        kCoverReferenceWidth,
        kCoverReferenceWidth / sourceCover.ratio,
      );
      _resolvedTemplatePages = _baseTemplatePages;
      (_templatePagesByAspect ??=
              <String, List<List<LayerModel>>>{})[_aspectKeyFromCover(
            widget.initialCoverSize ?? defaultCoverSize,
          )] =
          _baseTemplatePages!;
    }
    if (widget.initialAlbumTitle != null &&
        widget.initialAlbumTitle!.trim().isNotEmpty) {
      _albumTitle = widget.initialAlbumTitle!.trim();
      _templateTitle = _resolvedTemplatePages == null ? null : _albumTitle;
      _templatePreviewUrl = widget.initialTemplatePreviewImages?.firstOrNull;
      _sourceLabel = _templateTitle == null ? '직접 만들기' : '선택한 템플릿';
    }
    _selectedCover = _resolveInitialCover();
    if (widget.initialCoverSize != null)
      _preferredCoverType = _selectedCover!.coverType;
    if (_resolvedTemplatePages != null && _resolvedTemplatePages!.isNotEmpty) {
      // cover 제외 내지 페이지 수
      _templateMinPageCount = AlbumPagePolicy.minimumForContent(
        _resolvedTemplatePages!.length - 1,
      );
      _selectedPageCount = _templateMinPageCount;
    }
    // 초기 진입 시에도 현재 선택 커버 비율(기본: 정사각형)에 맞는 variant를 즉시 적용한다.
    // 그래야 사용자가 정사각형을 한 번 더 탭하지 않아도 페이지/이미지 크기가 맞게 보인다.
    if (_selectedCover != null) {
      _applyTemplateByCoverIfNeeded(_selectedCover!);
    }
    if (widget.initialCreationTemplate != null) {
      _useTemplate(widget.initialCreationTemplate!);
    }
    final draft = widget.initialDraft;
    if (draft != null) {
      _createdAlbumId = draft.createdAlbumId;
      _albumTitle = draft.title;
      _selectedCover = draft.cover;
      _preferredCoverType = draft.cover.coverType;
      _selectedPageCount = draft.pageCount;
      _currentStep = draft.step;
      _showPhotoFill = draft.showPhotoFill;
      _hasSelectedCreationMode = draft.hasSelectedMode;
      _resolvedTemplatePages = draft.pages;
      _baseTemplatePages = draft.basePages;
      _templatePagesByAspect = draft.variants;
      _templateCanvasSizes = draft.canvasSizes;
      _baseTemplateCanvasSize = draft.baseCanvasSize;
      _templateTitle = draft.templateTitle;
      _templatePreviewUrl = draft.previewUrl;
      _sourceLabel = draft.sourceLabel;
      _usesPhysicalTemplateCanvas = draft.usesPhysicalCanvas;
      _preserveTemplateTypography = draft.preserveTypography;
      _draftCoverLayers = draft.editedCover;
      _draftCoverCanvasSize = draft.editedCoverCanvasSize;
      _templateMinPageCount = AlbumPagePolicy.minimumForContent(
        (draft.pages?.length ?? 1) - 1,
      );
      _hasFilledPhotos =
          draft.pages
              ?.expand((page) => page)
              .any(
                (layer) =>
                    layer.type == LayerType.image && layer.hasImageSource,
              ) ??
          false;
      _photoSession.page = draft.currentPage;
      _photoSession.pendingPhotos.addAll(draft.pendingPhotos);
      _photoSession.selectedPhoto = draft.pendingPhotos
          .where((photo) => photo.id == draft.selectedPhotoId)
          .firstOrNull;
      _photoSession.selectedSlot = draft.selectedSlot;
      if (draft.createdAlbumId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted)
            _handleAlbumCreated(draft.createdAlbumId!, restoring: true);
        });
      }
    }
    if (kIsWeb &&
        widget.initialAiMode &&
        widget.initialDraft == null &&
        widget.initialCreationTemplate == null &&
        widget.initialTemplatePages == null &&
        widget.initialTemplatePagesByAspect == null &&
        !_hasSelectedCreationMode) {
      // Direct web entry only opens the existing request form. Generation and
      // point usage still require the same explicit confirmation callbacks.
      _isAiCreationMode = true;
      _hasSelectedCreationMode = true;
      _aiRequestOwner = ref.read(visibleOrderOwnerProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadAiSession());
      });
    }
    ScreenLogger.enter(
      'AlbumCreateFlowScreen',
      '앨범 생성 플로우 Step 1~4 (정보 입력 → 커버 편집 → 친구 초대 → 페이지 편집)',
    );
  }

  @override
  void dispose() {
    _stopAiObservation();
    WidgetsBinding.instance.removeObserver(this);
    _aiDraftRequestId += 1;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isAiCreationMode) {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive ||
          state == AppLifecycleState.hidden) {
        unawaited(_saveAiDevice());
        _aiWasPolling = _isGeneratingAiDraft;
        _aiPolling?.cancel();
      } else if (state == AppLifecycleState.resumed && _ownsAiRequest) {
        final resume = _aiWasPolling;
        _aiWasPolling = false;
        unawaited(_loadAiSession(continuePolling: resume));
      }
      return;
    }
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive) &&
        _hasSelectedCreationMode &&
        !_isGeneratingAiDraft &&
        !_isAiCreationMode &&
        !_savingDraft &&
        !_leaving &&
        _createdAlbumId == null) {
      unawaited(_saveDraft(notify: false));
    }
  }

  void _keepEditedCover() {
    if (_currentStep != 1 || _showPhotoFill) return;
    final cover = _editedCoverLayers();
    _draftCoverLayers = cover;
    _draftCoverCanvasSize = _usesPhysicalTemplateCanvas
        ? coverCanvasBaseSize(_selectedCover!)
        : ref.read(albumEditorViewModelProvider).asData?.value.coverCanvasSize;
    if (_resolvedTemplatePages?.isNotEmpty == true) {
      _resolvedTemplatePages = [cover, ..._resolvedTemplatePages!.skip(1)];
      _photoSession.updateCover(cover);
      final key = AlbumCreationTemplate.variantKey(_selectedCover!);
      _templatePagesByAspect?[key] = _resolvedTemplatePages!;
    }
  }

  Future<bool> _saveDraft({bool notify = true, bool afterCreation = false}) {
    if (_savingDraft) {
      if (afterCreation && _draftSaveFuture != null) {
        return _draftSaveFuture!.then(
          (_) =>
              mounted ? _saveDraft(notify: notify, afterCreation: true) : false,
        );
      }
      return Future.value(false);
    }
    return _draftSaveFuture = _writeDraft(
      notify: notify,
      afterCreation: afterCreation,
    );
  }

  List<List<LayerModel>>? _copyDraftPages(List<List<LayerModel>>? pages) =>
      pages?.map((page) => [...page]).toList();

  Future<bool> _writeDraft({
    required bool notify,
    required bool afterCreation,
  }) async {
    if (_savingDraft ||
        (!afterCreation && (_createdAlbumId != null || _startingAlbum)))
      return false;
    final owner = ref.read(authViewModelProvider).asData?.value?.id;
    if (owner == null ||
        owner.isEmpty ||
        (_draftOwner != null && owner != _draftOwner)) {
      if (notify)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 상태를 확인한 뒤 다시 저장해주세요.')),
        );
      return false;
    }
    _draftOwner ??= owner;
    _keepEditedCover();
    final draft = AlbumCreationDraft(
      id: _draftId,
      createdAlbumId: _createdAlbumId,
      updatedAt: DateTime.now(),
      title: _albumTitle,
      cover: _selectedCover ?? defaultCoverSize,
      pageCount: _selectedPageCount,
      step: _currentStep.clamp(0, 1),
      showPhotoFill: _showPhotoFill,
      hasSelectedMode: _hasSelectedCreationMode,
      sourceLabel: _sourceLabel,
      usesPhysicalCanvas: _usesPhysicalTemplateCanvas,
      preserveTypography: _preserveTemplateTypography,
      pages: _copyDraftPages(_resolvedTemplatePages),
      basePages: _copyDraftPages(_baseTemplatePages),
      variants: _templatePagesByAspect?.map(
        (key, value) => MapEntry(key, _copyDraftPages(value)!),
      ),
      canvasSizes: Map.of(_templateCanvasSizes),
      baseCanvasSize: _baseTemplateCanvasSize,
      templateTitle: _templateTitle,
      previewUrl: _templatePreviewUrl,
      currentPage: _photoSession.page,
      pendingPhotos: [..._photoSession.pendingPhotos],
      selectedPhotoId: _photoSession.selectedPhoto?.id,
      selectedSlot: _photoSession.selectedSlot,
      editedCover: _draftCoverLayers == null ? null : [..._draftCoverLayers!],
      editedCoverCanvasSize: _draftCoverCanvasSize,
    );
    setState(() => _savingDraft = true);
    try {
      if (kIsWeb) {
        await _draftWriteSession;
        if (_draftWriteSessionError case final error?) throw error;
      }
      await ref.read(albumCreationDraftStoreProvider).save(owner, draft);
      if (!mounted) return true;
      ref.invalidate(albumCreationDraftProvider);
      if (notify)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kIsWeb ? '이 브라우저에 사진 원본과 함께 임시 저장했어요.' : '이 기기에 임시 저장했어요.',
            ),
          ),
        );
      return true;
    } catch (error) {
      if (mounted && notify)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kIsWeb && error is BrowserPhotoException
                  ? error.message
                  : kIsWeb
                  ? '임시 저장하지 못했어요. 브라우저 저장 공간을 확인한 뒤 다시 시도해주세요. 작업은 유지됩니다.'
                  : '임시 저장하지 못했어요. 작업을 유지한 채 다시 시도해주세요.',
            ),
          ),
        );
      return false;
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  Future<void> _leaveCreation() async {
    if (_leaving || _savingDraft || _startingAlbum) return;
    _leaving = true;
    try {
      final hasWork =
          _hasSelectedCreationMode ||
          _albumTitle.trim().isNotEmpty ||
          _photoSession.pendingPhotos.isNotEmpty;
      final choice = !hasWork
          ? 'leave'
          : await showDialog<String>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('앨범 만들기를 나갈까요?'),
                content: const Text('임시 저장하면 이 기기에서 이어서 만들 수 있어요.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('계속 만들기'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'discard'),
                    child: const Text('저장 안 함'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, 'save'),
                    child: const Text('임시 저장 후 나가기'),
                  ),
                ],
              ),
            );
      if (!mounted || choice == null) return;
      if (choice == 'save' && !await _saveDraft()) return;
      if (choice == 'discard' && _draftOwner != null) {
        try {
          await ref
              .read(albumCreationDraftStoreProvider)
              .remove(_draftOwner!, _draftId);
          if (mounted) ref.invalidate(albumCreationDraftProvider);
        } catch (_) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('임시 저장을 지우지 못했어요. 다시 시도해주세요.')),
            );
          return;
        }
      }
      if (mounted) Navigator.pop(context);
    } finally {
      _leaving = false;
    }
  }

  Future<void> _reviewBeforeCreate() async {
    final complete = _onCompletePressed;
    if (_reviewing || _savingDraft || _startingAlbum || complete == null)
      return;
    _reviewing = true;
    _keepEditedCover();
    try {
      final pages =
          _resolvedTemplatePages ?? [_draftCoverLayers ?? <LayerModel>[]];
      final result = await showAlbumCreationReview(
        context,
        pages: pages,
        innerPageCount: _selectedPageCount,
        canvasSize:
            _draftCoverCanvasSize ?? coverCanvasBaseSize(_selectedCover!),
      );
      if (!mounted || result == null) return;
      if (result == -1) {
        setState(() => _startingAlbum = true);
        await complete();
      } else if (result > 0 && _resolvedTemplatePages != null) {
        setState(() {
          _photoSession.page = result;
          _photoSession.selectedSlot = null;
          _showPhotoFill = true;
          _onCompletePressed = null;
        });
      }
    } finally {
      _reviewing = false;
      if (mounted && _startingAlbum) setState(() => _startingAlbum = false);
    }
  }

  bool _hasUnsavedBrowserPhotoWork() {
    if (!kIsWeb) return false;
    if (_isGeneratingAiDraft ||
        _isAcceptingAiDraft ||
        _aiPointUsageUnconfirmed ||
        (_isAiCreationMode && _pendingAiDraft != null)) {
      return true;
    }
    bool containsPhoto(Iterable<LayerModel>? layers) =>
        layers?.any((layer) => layer.asset is BrowserPhotoAsset) ?? false;
    if (_photoSession.selectedPhoto is BrowserPhotoAsset ||
        _photoSession.pendingPhotos.any(
          (photo) => photo is BrowserPhotoAsset,
        ) ||
        containsPhoto(_draftCoverLayers))
      return true;
    for (final pages in <List<List<LayerModel>>?>[
      _resolvedTemplatePages,
      _baseTemplatePages,
      ...?_templatePagesByAspect?.values,
    ]) {
      if (pages != null && containsPhoto(pages.expand((page) => page)))
        return true;
    }
    if (_pendingAiDraft?.recommendedPhotos.any(
          (photo) => photo.candidate.asset is BrowserPhotoAsset,
        ) ??
        false)
      return true;
    return _currentStep == 1 &&
        !_showPhotoFill &&
        containsPhoto(
          ref.read(albumEditorViewModelProvider).asData?.value.layers,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(visibleOrderOwnerProvider, (_, next) {
      final owner = _aiRequestOwner;
      if (owner != null && next != owner) {
        setState(_discardAiAccountWork);
      }
    });
    return WebUnsavedWorkGuard(
      hasUnsavedChanges: _hasUnsavedBrowserPhotoWork,
      child: WillPopScope(
        onWillPop: () async {
          final handled = await _handleBack();
          return !handled; // handled == true 이면 pop 막기
        },
        child: kIsWeb
            ? _buildWebCreation()
            : Scaffold(
                backgroundColor: AlbumStageStyle.top(context),
                appBar: AppBar(
                  toolbarHeight:
                      MediaQuery.orientationOf(context) == Orientation.landscape
                      ? 48
                      : 52,
                  backgroundColor: AlbumStageStyle.top(context),
                  systemOverlayStyle: AlbumStageStyle.overlay(context).copyWith(
                    systemNavigationBarColor: AlbumStageStyle.bottom(context),
                  ),
                  surfaceTintColor: Colors.transparent,
                  scrolledUnderElevation: 0,
                  elevation: 0,
                  leading: IconButton(
                    tooltip: '뒤로가기',
                    icon: const ExperienceIcon('ArrowLeft', size: 22),
                    onPressed: _handleBack,
                  ),
                  title: Text(
                    _currentStep == 0
                        ? '앨범 만들기'
                        : _currentStep == 1
                        ? (_showPhotoFill ? '앨범 만들기' : '표지')
                        : '초대',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ExperienceFormStyle.text(
                      context,
                      15,
                      weight: FontWeight.w600,
                    ),
                  ),
                  actions: [
                    if (!_isAiCreationMode && !_isGeneratingAiDraft) ...[
                      IconButton(
                        key: const ValueKey('creation-save-draft'),
                        tooltip: '임시 저장',
                        onPressed: _savingDraft || _startingAlbum
                            ? null
                            : _saveDraft,
                        icon: const Icon(Icons.save_outlined, size: 21),
                      ),
                      IconButton(
                        key: const ValueKey('creation-exit'),
                        tooltip: '앨범 만들기 나가기',
                        onPressed: _savingDraft || _startingAlbum
                            ? null
                            : _leaveCreation,
                        icon: const Icon(Icons.close_rounded, size: 21),
                      ),
                    ],
                  ],
                ),
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_hasSelectedCreationMode &&
                        !(MediaQuery.orientationOf(context) ==
                                Orientation.landscape &&
                            creationKeyboardIsOpen(context)))
                      _buildCreationProgress(),
                    if (_isAiCreationMode &&
                        _currentStep == 0 &&
                        !(MediaQuery.orientationOf(context) ==
                                Orientation.landscape &&
                            creationKeyboardIsOpen(context)))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Text(
                          _aiCreationProgress,
                          key: const ValueKey('creation-ai-subprogress'),
                          style: ExperienceFormStyle.text(
                            context,
                            12,
                            secondary: true,
                          ),
                        ),
                      ),
                    Expanded(
                      child: _CreationStepReveal(
                        key: ValueKey(_creationScene),
                        child: _buildStepContent(),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  String get _creationScene {
    if (_createdAlbumId != null) return 'opening';
    if (!_hasSelectedCreationMode) return 'choose';
    if (_currentStep > 0) return _showPhotoFill ? 'photos' : 'cover';
    if (!_isAiCreationMode) return 'settings';
    if (_selectedAiTheme == null || _selectedAiRange == null) return 'brief';
    if (_aiDraftFailureMessage != null) return 'ai-recovery';
    if (_isGeneratingAiDraft) return 'ai-generating';
    if (_pendingAiDraft != null) return 'ai-review';
    return 'ai-confirm';
  }

  String get _aiCreationProgress => switch (_creationScene) {
    'brief' => 'AI 디자인 1/4 · 요청 작성',
    'ai-confirm' => 'AI 디자인 2/4 · 이용 조건 확인',
    'ai-generating' => 'AI 디자인 3/4 · 디자인 생성 중',
    'ai-review' => 'AI 디자인 4/4 · 결과 검토',
    'ai-recovery' => 'AI 디자인 · 요청을 확인하고 다시 시도해요',
    _ => 'AI 디자인',
  };

  Widget _buildWebCreation() {
    final compactHeader = MediaQuery.sizeOf(context).width < 700;
    final hasPhotos = _resolvedTemplatePages != null || _isAiCreationMode;
    final labels = hasPhotos
        ? [
            '디자인 선택',
            '앨범 설정',
            '사진 채우기',
            '표지 편집',
            _currentStep == 2 ? '공유 설정' : '편집 시작',
          ]
        : ['디자인 선택', '앨범 설정', '표지 편집', _currentStep == 2 ? '공유 설정' : '편집 시작'];
    final selected = !_hasSelectedCreationMode || _isAiCreationMode
        ? 0
        : _currentStep == 0
        ? 1
        : _currentStep == 2
        ? labels.length - 1
        : _showPhotoFill
        ? 2
        : labels.length - 2;
    final title = labels[selected];
    final description = !_hasSelectedCreationMode
        ? '템플릿으로 시작하거나, 빈 앨범에서 원하는 디자인을 만들어보세요.'
        : _isAiCreationMode
        ? '원하는 분위기와 사진을 고르고, 생성 전에 이용 조건을 확인하세요.'
        : _currentStep == 0
        ? '제목과 실물 책 규격을 정하세요. 앨범 내용은 편집 화면에서 계속 바꿀 수 있습니다.'
        : _currentStep == 2
        ? '함께 편집할 사람과 공유 설정을 확인하세요. 혼자 편집을 시작할 수도 있습니다.'
        : _showPhotoFill
        ? '컴퓨터의 사진을 골라 페이지에 채우고, 사진마다 배치를 확인하세요.'
        : '표지를 편집하고 전체 구성을 확인한 뒤 내지 편집으로 이어가세요.';
    return SnapFitWebShell(
      title: '앨범 만들기',
      compactBrand: true,
      denseHeader: true,
      headerTitle: WebAlbumDocumentTitle(
        key: const ValueKey('web-creation-document-header'),
        title: '앨범 만들기 · $title',
        subtitle: '${selected + 1} / ${labels.length}단계 · $description',
        onBack: _handleBack,
        backLabel: '이전 단계',
        busy:
            _savingDraft || _startingAlbum || _reviewing || _isAcceptingAiDraft,
      ),
      section: WebSection.create,
      workspace: true,
      showNavigation: false,
      sidebar: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '제작 순서',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: WebPalette.of(context).muted,
                ),
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < labels.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Semantics(
                    selected: i == selected,
                    label:
                        '${i + 1}단계 ${labels[i]}${i < selected ? ', 이전 단계' : ''}',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: i == selected
                            ? WebPalette.of(context).softBrand
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            i < selected
                                ? Icons.check_circle_outline
                                : Icons.radio_button_unchecked,
                            size: 18,
                            color: i <= selected
                                ? WebPalette.of(context).brandInk
                                : WebPalette.of(context).muted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              labels[i],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: i == selected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: i == selected
                                    ? WebPalette.of(context).ink
                                    : WebPalette.of(context).muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.7,
                  color: WebPalette.of(context).muted,
                ),
              ),
              const SizedBox(height: 20),
              Divider(color: WebPalette.of(context).line),
              const SizedBox(height: 16),
              Text(
                '사진을 추가한 뒤에는 앨범 저장을 마치고 창을 닫아주세요.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.7,
                  color: WebPalette.of(context).muted,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (!_isAiCreationMode && !_isGeneratingAiDraft) ...[
          if (compactHeader)
            IconButton(
              key: const ValueKey('creation-save-draft'),
              onPressed: _savingDraft || _startingAlbum ? null : _saveDraft,
              tooltip: _savingDraft ? '저장 중' : '임시 저장',
              icon: const Icon(Icons.save_outlined, size: 20),
            )
          else
            TextButton.icon(
              key: const ValueKey('creation-save-draft'),
              onPressed: _savingDraft || _startingAlbum ? null : _saveDraft,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(_savingDraft ? '저장 중' : '임시 저장'),
            ),
          IconButton(
            key: const ValueKey('creation-exit'),
            tooltip: '앨범 만들기 나가기',
            onPressed: _savingDraft || _startingAlbum ? null : _leaveCreation,
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
      ],
      child: LayoutBuilder(
        builder: (context, bounds) {
          final compact = bounds.maxWidth < 760;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 24,
              16,
              compact ? 12 : 24,
              16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (MediaQuery.sizeOf(context).width < 1000) ...[
                  SizedBox(
                    key: const ValueKey('web-creation-compact-stages'),
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: labels.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) => Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: selected == index
                              ? WebPalette.of(context).softBrand
                              : WebPalette.of(context).surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected == index
                                ? WebPalette.of(context).brandInk
                                : WebPalette.of(context).line,
                          ),
                        ),
                        child: Text(
                          '${index + 1} ${labels[index]}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected == index
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: selected == index
                                ? WebPalette.of(context).brandInk
                                : WebPalette.of(context).muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_selectedCover != null &&
                    _hasSelectedCreationMode &&
                    !_isAiCreationMode) ...[
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      Text(
                        '${_selectedCover!.displayName} · ${_selectedCover!.coverType.label} · 내지 $_selectedPageCount쪽',
                        style: TextStyle(
                          fontSize: 12,
                          color: WebPalette.of(context).ink,
                        ),
                      ),
                      Text(
                        _sourceLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: WebPalette.of(context).muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: WebSurface(
                    padding: EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildStepContent(),
                    ),
                  ),
                ),
                if (_currentStep == 1 && !_showPhotoFill) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      key: const ValueKey('web-creation-review'),
                      onPressed:
                          _onCompletePressed == null ||
                              _savingDraft ||
                              _startingAlbum
                          ? null
                          : _reviewBeforeCreate,
                      icon: const Icon(Icons.fact_check_outlined, size: 18),
                      label: const Text('전체 확인'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAiDraftGenerating() {
    return AiTemplateGeneratingStep(
      cover: _designBrief?.coverSize ?? _selectedCover,
      innerPageCount: _designBrief?.pageCount,
      requestStartedAt: _aiDraftRequestStartedAt,
      job: _aiCurrentJob,
      onRefresh: _aiCurrentJob?.pending == true
          ? () => unawaited(_refreshAiJob())
          : null,
      onPause: _aiCurrentJob?.pending == true
          ? () => unawaited(_pauseAiJob())
          : null,
    );
  }

  Future<void> _generateAiDraftFromSelection() async {
    final theme = _selectedAiTheme;
    final range = _selectedAiRange;
    if (theme == null ||
        range == null ||
        _isGeneratingAiDraft ||
        _isAcceptingAiDraft ||
        _aiPointUsageUnconfirmed)
      return;
    final owner = ref.read(visibleOrderOwnerProvider);
    if (owner == null || owner.isEmpty) {
      setState(_discardAiAccountWork);
      return;
    }
    _aiRequestOwner = owner;
    final requestId = ++_aiDraftRequestId;
    _aiPolling?.cancel();
    final polling = _aiPolling = AiTemplatePollingToken();
    _aiGenerationUuid = const Uuid().v4();
    _aiUnappliedLocalEdits = null;
    _aiCurrentJob = null;
    _aiResumeCandidate = null;

    setState(() {
      // A newly admitted server generation expires the old READY intent.
      // Preserve its artwork for comparison, never as a usable billing draft.
      _comparisonAiDraft =
          _aiRequestEdit?.draft ?? _pendingAiDraft ?? _comparisonAiDraft;
      _aiRequestEdit = null;
      _previewAiComparison = false;
      _aiPaperOriginalDesign = null;
      _isGeneratingAiDraft = true;
      _aiDraftRequestStartedAt = DateTime.now();
      _aiPointUsageFuture = null;
      _aiPointUsageDraftId = null;
      _hasConfirmedAiPointCost = false;
      _pendingAiDraft = null;
      _aiDraftFailureTitle = null;
      _aiDraftFailureMessage = null;
      _aiDraftPrimaryCtaLabel = null;
      _aiDraftPrimaryRecoveryAction = null;
    });

    await _saveAiDevice();
    if (!mounted ||
        !_ownsAiRequest ||
        requestId != _aiDraftRequestId ||
        polling.canceled)
      return;
    final result = await ref
        .read(aiAlbumDraftGenerationServiceProvider)
        .generate(
          theme: theme,
          range: range,
          designBrief: _designBrief,
          generationRequestId: _aiGenerationUuid,
          token: polling,
          onProgress: (job) => _onAiJobProgress(job, requestId),
        );
    if (polling.canceled) return;
    _applyAiGenerationResult(result, requestId);
  }

  void _applyAiGenerationResult(
    AiAlbumDraftGenerationResult result,
    int requestId, {
    Map<String, dynamic>? restoring,
  }) {
    if (!mounted || requestId != _aiDraftRequestId) return;
    _dismissAiWaitNotice();
    if (!_ownsAiRequest) {
      setState(_discardAiAccountWork);
      return;
    }

    var draft = result.draft;
    final originalDesign = draft?.design;
    if (draft != null &&
        originalDesign != null &&
        restoring?['requestId'] == _aiGenerationUuid &&
        restoring?['edits'] is Map) {
      try {
        draft = withAiTemplateDesign(
          draft,
          restoreAiTemplateLocalEdits(
            originalDesign,
            restoring!['edits'] as Map,
          ),
        );
      } catch (_) {
        _aiUnappliedLocalEdits = restoring!['edits'] as Map;
        _aiDeviceMessage =
            '이전에 수정한 문구를 자동으로 적용하지 못했어요. 저장한 메모와 원본 디자인을 확인해 주세요.';
      }
    }
    final accepted = draft;
    if (result.shouldChargePoints && accepted != null) {
      setState(() {
        _isGeneratingAiDraft = false;
        _hasConfirmedAiPointCost = true;
        _pendingAiDraft = accepted;
        _aiPaperOriginalDesign = originalDesign;
        _aiDraftFailureTitle = null;
        _aiDraftFailureMessage = null;
        _aiDraftPrimaryCtaLabel = null;
        _aiDraftPrimaryRecoveryAction = null;
        if (_albumTitle.trim().isEmpty) {
          _albumTitle = accepted.title;
        }
        _selectedPageCount = _normalizePageCount(accepted.pageCount);
      });
      unawaited(_saveAiDevice());
      return;
    }

    setState(() {
      _isGeneratingAiDraft = false;
      _hasConfirmedAiPointCost = false;
      _pendingAiDraft = null;
      _aiDraftFailureTitle = result.failureTitle ?? 'AI 템플릿을 만들지 못했어요';
      _aiDraftFailureMessage =
          result.failureMessage ?? 'AI 템플릿을 준비하지 못했어요. 포인트는 차감되지 않았어요.';
      _aiDraftPrimaryCtaLabel = result.primaryCtaLabel ?? '사진 범위 다시 고르기';
      _aiDraftPrimaryRecoveryAction =
          result.primaryRecoveryAction ??
          AiAlbumDraftRecoveryAction.retryPhotoRange;
      if (_aiCurrentJob?.pending == true) _aiResumeCandidate = _aiCurrentJob;
    });
    // A response can be lost after the server admitted the request. A read-only
    // lookup recovers its identity instead of encouraging a second generation.
    unawaited(_loadAiSession());
  }

  Future<void> _acceptAiDraft(AlbumRecommendationDraft acceptedDraft) async {
    if (_isAcceptingAiDraft || _isGeneratingAiDraft) return;
    if (_pendingAiDraft?.draftId != acceptedDraft.draftId) return;
    final requestId = _aiDraftRequestId;
    final requestOwner = _aiRequestOwner;
    bool currentRequest() =>
        mounted &&
        requestId == _aiDraftRequestId &&
        requestOwner == _aiRequestOwner &&
        _pendingAiDraft?.draftId == acceptedDraft.draftId &&
        _ownsAiRequest;
    if (!_ownsAiRequest) {
      setState(_discardAiAccountWork);
      return;
    }
    final editorReadiness = _aiDraftTemplateBuilder.validateEditorReady(
      acceptedDraft,
    );
    if (!editorReadiness.isReady) {
      setState(() => _setAiDraftEditorHandoffFailure(editorReadiness.reason));
      return;
    }

    setState(() => _isAcceptingAiDraft = true);
    try {
      // A local timeout cannot cancel a server write. Keep its Future and draft
      // identity so checking again observes the same operation, including a late
      // success. Only a completed error permits another call with the same id.
      if (_aiPointUsageFuture == null ||
          _aiPointUsageDraftId != acceptedDraft.draftId) {
        _aiPointUsageDraftId = acceptedDraft.draftId;
        _aiPointUsageFuture = ref
            .read(billingRepositoryProvider)
            .recordAiAlbumDraftSuccess(
              draftId: acceptedDraft.draftId,
              pointCost: _aiDraftPointCost,
            );
      }
      await _aiPointUsageFuture!.timeout(const Duration(seconds: 8));
      if (!currentRequest()) return;
      _dismissAiWaitNotice();
      ref.invalidate(myPointBalanceProvider);
      ref.invalidate(isFirstAiDraftFreeProvider);
    } on AiAlbumDraftPointUsageException catch (error) {
      if (!currentRequest()) return;
      _aiPointUsageFuture = null;
      setState(() => _setAiDraftPointUsageFailure(error.failure));
      return;
    } catch (error) {
      if (!currentRequest()) return;
      if (error is! TimeoutException) _aiPointUsageFuture = null;
      setState(
        () => _setAiDraftPointUsageFailure(
          AiAlbumDraftPointUsageFailure.unavailable,
        ),
      );
      return;
    }

    if (!currentRequest()) return;
    setState(() {
      _isAcceptingAiDraft = false;
      _aiRequestOwner = null;
      _aiPointUsageUnconfirmed = false;
      _aiPointUsageFuture = null;
      _aiPointUsageDraftId = null;
      final proposedCover =
          _designBrief?.coverSize ??
          newAlbumCoverSize(acceptedDraft.design?.coverSize ?? _selectedCover);
      _selectedCover = proposedCover.withCoverType(
        _designBrief?.coverSize.coverType ??
            _preferredCoverType ??
            proposedCover.coverType,
      );
      _preferredCoverType = _selectedCover!.coverType;
      final aiPages =
          acceptedDraft.design?.buildLayers(
            targetSize: coverCanvasBaseSize(_selectedCover!),
          ) ??
          AlbumCreationTemplate.preparePages(
            _aiDraftTemplateBuilder.build(acceptedDraft),
            sourceCanvas: AiAlbumDraftTemplateBuilder.canvasSize,
            cover: _selectedCover!,
            clearSamplePhotos: false,
          );
      _resolvedTemplatePages = aiPages;
      _baseTemplatePages = aiPages;
      final productKey = AlbumCreationTemplate.variantKey(_selectedCover!);
      _baseTemplateCanvasSize = coverCanvasBaseSize(_selectedCover!);
      _templatePagesByAspect = {productKey: aiPages};
      _templateCanvasSizes = {productKey: _baseTemplateCanvasSize!};
      _templateTitle = acceptedDraft.title;
      _templatePreviewUrl = null;
      _sourceLabel = 'AI 템플릿';
      _clearAiResultHistory();
      _usesPhysicalTemplateCanvas = true;
      _preserveTemplateTypography = acceptedDraft.design?.artDirection != null;
      _isAiCreationMode = false;
      _hasFilledPhotos = false;
      _templateMinPageCount = AlbumPagePolicy.minimumForContent(
        aiPages.length - 1,
      );
      _pendingAiDraft = null;
      _aiDraftFailureTitle = null;
      _aiDraftFailureMessage = null;
      _aiDraftPrimaryCtaLabel = null;
      _aiDraftPrimaryRecoveryAction = null;
      if (_albumTitle.trim().isEmpty) {
        _albumTitle = acceptedDraft.title;
      }
      _selectedPageCount = _normalizePageCount(acceptedDraft.pageCount);
    });
  }

  void _setAiDraftPointUsageFailure(AiAlbumDraftPointUsageFailure failure) {
    _dismissAiWaitNotice();
    final isInsufficient =
        failure == AiAlbumDraftPointUsageFailure.insufficientPoints;
    // The generated draft remains available; recovery never creates a new one.
    _hasConfirmedAiPointCost = false;
    _isGeneratingAiDraft = false;
    _isAcceptingAiDraft = false;
    _aiPointUsageUnconfirmed = !isInsufficient;
    _aiDraftFailureTitle = isInsufficient
        ? '포인트가 조금 부족해요'
        : '포인트 처리 결과를 확인하지 못했어요';
    _aiDraftFailureMessage = isInsufficient
        ? 'AI 디자인은 그대로 유지했어요. 포인트를 충전한 뒤 같은 디자인으로 다시 확인하거나 직접 구성할 수 있어요. 아직 포인트는 차감되지 않았어요.'
        : '디자인은 그대로 유지했어요. 포인트 사용 처리의 완료 여부를 확인하지 못했어요. 새로 생성하지 않고 같은 디자인으로 다시 확인해 주세요.';
    _aiDraftPrimaryCtaLabel = isInsufficient ? '포인트 충전하기' : '같은 디자인으로 다시 확인';
    _aiDraftPrimaryRecoveryAction = isInsufficient
        ? AiAlbumDraftRecoveryAction.reviewPointCost
        : null;
  }

  void _setAiDraftEditorHandoffFailure(
    AiAlbumDraftEditorReadinessReason reason,
  ) {
    final title = switch (reason) {
      AiAlbumDraftEditorReadinessReason.emptyRecommendedPhotos =>
        '템플릿에 넣을 사진 슬롯을 만들지 못했어요',
      AiAlbumDraftEditorReadinessReason.pageCountMismatch => '앨범 쪽수를 다시 맞춰야 해요',
      AiAlbumDraftEditorReadinessReason.missingLocalImageAsset ||
      AiAlbumDraftEditorReadinessReason.ready => 'AI 템플릿을 안전하게 열지 않았어요',
    };
    final message = switch (reason) {
      AiAlbumDraftEditorReadinessReason.emptyRecommendedPhotos =>
        '선택한 범위에서 앨범에 넣을 사진을 찾지 못했어요. 사진 범위를 다시 고르거나 직접 구성해 주세요. 포인트는 차감되지 않았어요.',
      AiAlbumDraftEditorReadinessReason.pageCountMismatch =>
        'AI가 만든 쪽수와 실제 편집 쪽수가 달라 바로 열지 않았어요. 새 템플릿으로 다시 맞춰볼게요. 포인트는 차감되지 않았어요.',
      AiAlbumDraftEditorReadinessReason.missingLocalImageAsset ||
      AiAlbumDraftEditorReadinessReason.ready =>
        '구성은 만들었지만 편집기에 넣을 사진 슬롯을 확인하지 못했어요. 새 AI 템플릿으로 다시 만들면 안전해요. 포인트는 차감되지 않았어요.',
    };

    _pendingAiDraft = null;
    _hasConfirmedAiPointCost = false;
    _isGeneratingAiDraft = false;
    _aiDraftFailureTitle = title;
    _aiDraftFailureMessage = message;
    _aiDraftPrimaryCtaLabel = '사진 범위 다시 고르기';
    _aiDraftPrimaryRecoveryAction = AiAlbumDraftRecoveryAction.retryPhotoRange;
  }

  Future<void> _handleAiDraftPrimaryRecovery(
    AiAlbumDraftRecoveryAction? action,
  ) async {
    if (_isAcceptingAiDraft || _isGeneratingAiDraft) return;
    if (!_ownsAiRequest) {
      setState(_discardAiAccountWork);
      return;
    }
    final retainedDraft = _pendingAiDraft;
    if (_aiPointUsageUnconfirmed && retainedDraft != null) {
      await _acceptAiDraft(retainedDraft);
      return;
    }
    if (kIsWeb &&
        (action == AiAlbumDraftRecoveryAction.openPhotoSettings ||
            action == AiAlbumDraftRecoveryAction.openLimitedPhotoPicker)) {
      // A browser can only revisit explicitly selected files; it has no
      // native system photo-permission or limited-library settings screen.
      await showPhotosSelectionSheet(context, ref);
      if (!mounted) return;
      setState(() {
        _hasConfirmedAiPointCost = false;
        _isGeneratingAiDraft = false;
        _pendingAiDraft = null;
        _aiDraftFailureTitle = null;
        _aiDraftFailureMessage = null;
        _aiDraftPrimaryCtaLabel = null;
        _aiDraftPrimaryRecoveryAction = null;
      });
      return;
    }
    switch (action ?? AiAlbumDraftRecoveryAction.retryPhotoRange) {
      case AiAlbumDraftRecoveryAction.openPhotoSettings:
        openAppSettings();
      case AiAlbumDraftRecoveryAction.openLimitedPhotoPicker:
        await PhotoManager.presentLimited(type: RequestType.image);
        if (!mounted) return;
        setState(() {
          _hasConfirmedAiPointCost = false;
          _isGeneratingAiDraft = false;
          _pendingAiDraft = null;
          _aiDraftFailureTitle = null;
          _aiDraftFailureMessage = null;
          _aiDraftPrimaryCtaLabel = null;
          _aiDraftPrimaryRecoveryAction = null;
        });
      case AiAlbumDraftRecoveryAction.reviewPointCost:
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const BillingManagementScreen(returnToAiDraftFlow: true),
          ),
        );
        if (!mounted) return;
        ref.invalidate(myPointBalanceProvider);
        setState(() {
          _hasConfirmedAiPointCost = _pendingAiDraft != null;
          _isGeneratingAiDraft = false;
          _aiDraftFailureTitle = null;
          _aiDraftFailureMessage = null;
          _aiDraftPrimaryCtaLabel = null;
          _aiDraftPrimaryRecoveryAction = null;
        });
      case AiAlbumDraftRecoveryAction.retryPhotoRange:
        setState(() {
          _selectedAiRange = null;
          _hasConfirmedAiPointCost = false;
          _isGeneratingAiDraft = false;
          _pendingAiDraft = null;
          _aiDraftFailureTitle = null;
          _aiDraftFailureMessage = null;
          _aiDraftPrimaryCtaLabel = null;
          _aiDraftPrimaryRecoveryAction = null;
        });
    }
  }

  Widget _buildStepContent() {
    if (_createdAlbumId != null)
      return const Center(child: CircularProgressIndicator());
    switch (_currentStep) {
      case 0:
        if (_aiAccountChanged) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('로그인 상태가 바뀌었어요.'),
                  const SizedBox(height: 12),
                  const Text('이전 요청과 결과를 닫았어요. 현재 계정으로 새로 시작해 주세요.'),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => setState(() {
                      _aiAccountChanged = false;
                      _isAiCreationMode = false;
                    }),
                    child: const Text('처음으로'),
                  ),
                ],
              ),
            ),
          );
        }
        if (_previewAiComparison && _comparisonAiDraft?.design != null) {
          return AiTemplateDesignReview(
            design: _comparisonAiDraft!.design!,
            onBack: () => setState(() => _previewAiComparison = false),
            onAccept: () {},
            isAccepting: false,
            readOnly: true,
          );
        }
        if (!_hasSelectedCreationMode) {
          return AiAlbumStartStep(
            templates: ref.watch(albumCreationCatalogProvider),
            onRetry: () {
              ref.invalidate(templateListProvider);
              ref.invalidate(albumCreationCatalogProvider);
            },
            onTemplateSelected: _selectTemplate,
            aiPointCost: _aiDraftPointCost,
            freeDraftLabel: '사진은 직접 고르고 바꿀 수 있어요',
            isFirstAiDraftFree:
                ref.watch(isFirstAiDraftFreeProvider).asData?.value ?? false,
            onAiStart: () {
              setState(() {
                _resetDesign();
                _aiRequestOwner = ref.read(visibleOrderOwnerProvider);
                _isAiCreationMode = true;
                _hasSelectedCreationMode = true;
              });
              unawaited(_loadAiSession());
            },
            onManualStart: () => setState(() {
              _resetDesign();
              _selectedAiTheme = null;
              _selectedAiRange = null;
              _pendingAiDraft = null;
              _aiDraftFailureTitle = null;
              _aiDraftFailureMessage = null;
              _aiDraftPrimaryCtaLabel = null;
              _aiDraftPrimaryRecoveryAction = null;
              _isAiCreationMode = false;
              _hasConfirmedAiPointCost = false;
              _isGeneratingAiDraft = false;
              _hasSelectedCreationMode = true;
            }),
          );
        }
        if (_isAiCreationMode &&
            (_selectedAiTheme == null ||
                (_designBrief != null && _selectedAiRange == null))) {
          return _withAiResultRecovery(
            AiTemplateBriefStep(
              key: ValueKey('ai-brief-$_aiPrefsRevision'),
              initialBrief: _designBrief,
              initialCoverSize: _selectedCover,
              onChanged: _rememberAiBrief,
              onContinue: (brief) => setState(() {
                _designBrief = brief;
                unawaited(_saveAiDevice());
                _selectedCover = brief.coverSize;
                _selectedPageCount = brief.pageCount;
                _preferredCoverType = brief.coverSize.coverType;
                _selectedAiTheme = AlbumTheme.custom;
                _selectedAiRange = AiPhotoRange.manualSelection;
              }),
              onBack: () {
                if (_returnToAiResult()) return;
                setState(() {
                  _selectedAiTheme = null;
                  _selectedAiRange = null;
                  _pendingAiDraft = null;
                  _aiDraftFailureTitle = null;
                  _aiDraftFailureMessage = null;
                  _aiDraftPrimaryCtaLabel = null;
                  _aiDraftPrimaryRecoveryAction = null;
                  _isAiCreationMode = false;
                  _hasConfirmedAiPointCost = false;
                  _isGeneratingAiDraft = false;
                  _hasSelectedCreationMode = false;
                  _clearAiResultHistory();
                });
              },
            ),
          );
        }
        final selectedAiTheme = _selectedAiTheme;
        if (_isAiCreationMode &&
            selectedAiTheme != null &&
            _selectedAiRange == null) {
          return _withAiResultRecovery(
            AiAlbumPhotoRangeStep(
              theme: selectedAiTheme,
              usesServerDraftProvider: widget.usesServerDraftProvider,
              usesAdvancedServerAnalysis: widget.usesAdvancedServerAnalysis,
              onRangeSelected: (range) {
                setState(() {
                  _selectedAiRange = range;
                  _hasConfirmedAiPointCost = false;
                  _isGeneratingAiDraft = false;
                  _pendingAiDraft = null;
                  _aiDraftFailureTitle = null;
                  _aiDraftFailureMessage = null;
                  _aiDraftPrimaryCtaLabel = null;
                  _aiDraftPrimaryRecoveryAction = null;
                });
              },
              onBack: () => setState(() {
                _selectedAiTheme = null;
                _selectedAiRange = null;
                _pendingAiDraft = null;
                _aiDraftFailureTitle = null;
                _aiDraftFailureMessage = null;
                _aiDraftPrimaryCtaLabel = null;
                _aiDraftPrimaryRecoveryAction = null;
                _hasConfirmedAiPointCost = false;
                _isGeneratingAiDraft = false;
              }),
            ),
          );
        }
        final pendingDraft = _pendingAiDraft;
        final selectedAiRange = _selectedAiRange;
        final aiDraftFailureTitle = _aiDraftFailureTitle;
        final aiDraftFailureMessage = _aiDraftFailureMessage;
        final aiDraftPrimaryCtaLabel = _aiDraftPrimaryCtaLabel;
        final aiDraftPrimaryRecoveryAction = _aiDraftPrimaryRecoveryAction;
        if (_isAiCreationMode &&
            selectedAiTheme != null &&
            selectedAiRange != null &&
            aiDraftFailureMessage != null) {
          return _withAiResultRecovery(
            AiAlbumDraftFailureStep(
              usesServerDraftProvider:
                  _designBrief == null && widget.usesServerDraftProvider,
              usesAdvancedServerAnalysis:
                  _designBrief == null && widget.usesAdvancedServerAnalysis,
              title: aiDraftFailureTitle ?? 'AI 템플릿을 만들지 못했어요',
              message: aiDraftFailureMessage,
              primaryActionLabel: _aiPointUsageUnconfirmed
                  ? '같은 디자인으로 다시 확인'
                  : _designBrief != null &&
                        aiDraftPrimaryRecoveryAction !=
                            AiAlbumDraftRecoveryAction.reviewPointCost
                  ? '디자인 요청 다시 보기'
                  : aiDraftPrimaryCtaLabel ?? '사진 범위 다시 고르기',
              isTemplateDesign: _designBrief != null,
              requestSummary: _designBrief == null
                  ? null
                  : '${_designBrief!.safeOptions.summary}\n${_designBrief!.coverSize.displayName} · ${_designBrief!.coverSize.coverType.label} · 내지 ${_designBrief!.pageCount}쪽',
              pointUsageUnconfirmed: _aiPointUsageUnconfirmed,
              isBusy: _isAcceptingAiDraft,
              showManualStart: !_aiPointUsageUnconfirmed,
              onRetryRange: () {
                if (_aiPointUsageUnconfirmed) {
                  unawaited(_handleAiDraftPrimaryRecovery(null));
                } else if (_designBrief != null &&
                    aiDraftPrimaryRecoveryAction !=
                        AiAlbumDraftRecoveryAction.reviewPointCost) {
                  setState(() {
                    _selectedAiTheme = null;
                    _selectedAiRange = null;
                    _hasConfirmedAiPointCost = false;
                    _aiDraftFailureMessage = null;
                  });
                } else {
                  _handleAiDraftPrimaryRecovery(aiDraftPrimaryRecoveryAction);
                }
              },
              onManualStart: () => setState(() {
                _clearAiResultHistory();
                _aiRequestOwner = null;
                _selectedAiTheme = null;
                _selectedAiRange = null;
                _isAiCreationMode = false;
                _hasConfirmedAiPointCost = false;
                _isGeneratingAiDraft = false;
                _pendingAiDraft = null;
                _aiDraftFailureTitle = null;
                _aiDraftFailureMessage = null;
                _aiDraftPrimaryCtaLabel = null;
                _aiDraftPrimaryRecoveryAction = null;
              }),
            ),
          );
        }
        if (_isAiCreationMode &&
            selectedAiTheme != null &&
            selectedAiRange != null &&
            _isGeneratingAiDraft) {
          return _buildAiDraftGenerating();
        }
        if (_isAiCreationMode &&
            selectedAiTheme != null &&
            selectedAiRange != null &&
            !_hasConfirmedAiPointCost) {
          final pointBalance = ref
              .watch(myPointBalanceProvider)
              .maybeWhen(data: (value) => value, orElse: () => 0);
          final firstFree =
              ref.watch(isFirstAiDraftFreeProvider).asData?.value ?? false;
          return _withAiResultRecovery(
            AiAlbumPointConfirmationStep(
              designBrief: _designBrief,
              theme: selectedAiTheme,
              range: selectedAiRange,
              pointCost: _aiDraftPointCost,
              balance: pointBalance,
              isFirstAiDraftFree: firstFree,
              usesServerDraftProvider: widget.usesServerDraftProvider,
              usesAdvancedServerAnalysis: widget.usesAdvancedServerAnalysis,
              onConfirm: () {
                _designBrief = _designBrief?.withExpectedPointCost(
                  firstFree ? 0 : _aiDraftPointCost,
                );
                _generateAiDraftFromSelection();
              },
              onBack: () => setState(() {
                if (_designBrief != null) _selectedAiTheme = null;
                _selectedAiRange = null;
                _hasConfirmedAiPointCost = false;
                _isGeneratingAiDraft = false;
                _pendingAiDraft = null;
                _aiDraftFailureTitle = null;
                _aiDraftFailureMessage = null;
                _aiDraftPrimaryCtaLabel = null;
                _aiDraftPrimaryRecoveryAction = null;
              }),
            ),
          );
        }
        if (_isAiCreationMode &&
            selectedAiTheme != null &&
            selectedAiRange != null &&
            pendingDraft != null) {
          return _aiSessionBanner(
            AiAlbumRecommendationReviewStep(
              draft: pendingDraft,
              targetCover: _designBrief?.coverSize,
              onAcceptDraft: _acceptAiDraft,
              originalDesign: _aiPaperOriginalDesign,
              previousDesign: _comparisonAiDraft?.design,
              alreadyAccepted: _aiCurrentJob?.alreadyAccepted ?? false,
              onDraftChanged: (draft) {
                if (!_ownsAiRequest ||
                    _isAcceptingAiDraft ||
                    _aiPointUsageUnconfirmed ||
                    _pendingAiDraft?.draftId != draft.draftId)
                  return;
                setState(() {
                  _pendingAiDraft = draft;
                  _aiUnappliedLocalEdits = null;
                });
                unawaited(_saveAiDevice());
              },
              onBack: _editAiRequest,
            ),
          );
        }
        return AlbumCreateStep1(
          albumTitle: _albumTitle,
          templateTitle: _templateTitle,
          templatePreviewImageUrl: _templatePreviewUrl,
          sourceLabel: _sourceLabel,
          coverLayers: _resolvedTemplatePages?.firstOrNull,
          documentPages: _resolvedTemplatePages,
          preserveTypography: _preserveTemplateTypography,
          availableCovers: coverSizes,
          onChangeDesign: _changeDesign,
          selectedCover: _selectedCover,
          selectedPageCount: _selectedPageCount,
          minPageCount: _templateMinPageCount,
          templatePageCount: (_resolvedTemplatePages?.length ?? 1) - 1,
          // 제목 변경은 부모의 setState를 매 키 입력마다 호출하지 않고,
          // 값만 보관해서 한글 IME 조합이 끊기지 않도록 한다.
          onTitleChanged: (title) => _albumTitle = title,
          onCoverSelected: _selectCover,
          onPageCountChanged: (count) =>
              setState(() => _selectedPageCount = _normalizePageCount(count)),
          onNext: () {
            final title = _albumTitle.trim();
            if (title.isNotEmpty &&
                _selectedCover != null &&
                AlbumPagePolicy.isValid(_selectedPageCount)) {
              _albumTitle = title;
              setState(() {
                _showPhotoFill = _resolvedTemplatePages != null;
                _currentStep = 1;
              });
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('앨범 제목과 책 크기를 확인해주세요.')),
            );
          },
        );
      case 1:
        if (_showPhotoFill &&
            _resolvedTemplatePages != null &&
            _selectedCover != null) {
          return TemplatePhotoFillStep(
            session: _photoSession,
            pages: _resolvedTemplatePages!,
            preserveTypography: _preserveTemplateTypography,
            cover: _selectedCover!,
            onChanged: (pages) => setState(() {
              _resolvedTemplatePages = pages;
              final productKey = AlbumCreationTemplate.variantKey(
                _selectedCover!,
              );
              _templatePagesByAspect?[productKey] = pages;
              _templateCanvasSizes[productKey] = coverCanvasBaseSize(
                _selectedCover!,
              );
              _hasFilledPhotos = pages
                  .expand((page) => page)
                  .any(
                    (layer) =>
                        layer.type == LayerType.image && layer.hasImageSource,
                  );
            }),
            onContinue: () => setState(() => _showPhotoFill = false),
          );
        }
        // Step 2: 앨범 생성 페이지 (커버 편집 화면)
        if (_selectedCover == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return AddCoverScreen(
          onReviewBeforeCreate: _reviewBeforeCreate,
          isFromCreateFlow: true,
          initialCoverSize: _selectedCover,
          initialTemplateCanvasSize: _usesPhysicalTemplateCanvas
              ? coverCanvasBaseSize(_selectedCover!)
              : _draftCoverCanvasSize,
          albumTitle: _albumTitle, // 앨범 제목 전달
          targetPages: _selectedPageCount, // 목표 페이지 수 전달
          initialTemplateCoverLayers:
              (_resolvedTemplatePages != null &&
                  _resolvedTemplatePages!.isNotEmpty)
              ? _resolvedTemplatePages!.first
              : _draftCoverLayers,
          onRegisterCompleteAction: (callback) {
            setState(() {
              _onCompletePressed = callback;
            });
          },
          onAlbumCreated: (albumId) {
            _handleAlbumCreated(albumId);
          },
        );
      case 2:
        // Step 3: 친구 초대 (마지막 단계)
        if (_createdAlbumId == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return AlbumCreateStep2(
          albumTitle: _albumTitle,
          documentPages:
              _resolvedTemplatePages ??
              (_draftCoverLayers == null ? null : [_draftCoverLayers!]),
          documentCanvas:
              _draftCoverCanvasSize ?? coverCanvasBaseSize(_selectedCover!),
          selectedCover: _selectedCover!,
          selectedPageCount: _selectedPageCount,
          allowEditing: _allowEditing,
          albumId: _createdAlbumId,
          onAllowEditingChanged: (value) =>
              setState(() => _allowEditing = value),
          onNext: () {
            // 마지막 단계 완료 -> 편집 화면(Reader)으로 이동
            if (_createdAlbumId != null) {
              // 앨범이 아직 생성 중일 수 있으므로 ID만으로 더미 Album 생성
              final dummyAlbum = Album(
                id: _createdAlbumId!,
                ratio: _selectedCover!.ratio.toString(),
                targetPages: _selectedPageCount,
              );

              final vm = ref.read(albumEditorViewModelProvider.notifier);
              if (_resolvedTemplatePages != null &&
                  _resolvedTemplatePages!.isNotEmpty) {
                // 템플릿 페이지는 이미 메모리에 완성되어 있으므로 업로드 폴링을 기다리지 않는다.
                // 업로드/대표이미지 보정은 백그라운드에서 진행하되 편집 화면은 즉시 열린다.
                vm.beginCreatedTemplateAlbumForEdit(
                  albumId: dummyAlbum.id,
                  albumTitle: _albumTitle,
                  pages: _resolvedTemplatePages!,
                  initialCover: _selectedCover,
                );
              } else {
                // 일반 생성도 이미 로컬에 빈 커버/내지 페이지가 준비되어 있으므로
                // 서버 대표이미지/업로드 폴링을 기다리지 않고 즉시 편집으로 연다.
                vm.beginCreatedAlbumForEdit(
                  albumId: dummyAlbum.id,
                  albumTitle: _albumTitle,
                );
              }

              // 즉시 편집 화면으로 이동
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  settings: const WebAppRouteSettings(WebAppLocation.create),
                  builder: (_) => const PageEditorScreen(initialPageIndex: 1),
                ),
              );
            }
          },
          onBack: () => setState(() => _currentStep = 1),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _handleAlbumCreated(
    int albumId, {
    bool restoring = false,
  }) async {
    _createdAlbumId = albumId;
    // Inner pages have not reached the backend yet. Keep a linked draft until
    // the page editor saves the entire album, and never create it twice on resume.
    if (!restoring) await _saveDraft(notify: false, afterCreation: true);
    if (!mounted) return;
    await ref.read(albumEditorViewModelProvider.future);
    if (!mounted) return;
    final dummyAlbum = Album(
      id: albumId,
      ratio: _selectedCover!.ratio.toString(),
      targetPages: _selectedPageCount,
    );

    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final editorCheckpoint = restoring
        ? widget.initialDraft?.editorCheckpoint
        : null;
    if (editorCheckpoint != null) {
      vm.restoreCreatedEditorDraft(
        albumId: albumId,
        albumTitle: _albumTitle,
        cover: _selectedCover!,
        checkpoint: editorCheckpoint,
      );
    } else if ((_resolvedTemplatePages != null &&
            _resolvedTemplatePages!.isNotEmpty) ||
        (restoring && _draftCoverLayers != null)) {
      // Keep the cover just edited; only the inner pages come from the template.
      final cover = restoring
          ? _draftCoverLayers ?? _resolvedTemplatePages!.first
          : _editedCoverLayers();
      final pages = <List<LayerModel>>[
        cover,
        ...?_resolvedTemplatePages?.skip(1),
      ];
      while (pages.length <= _selectedPageCount) {
        pages.add(<LayerModel>[]);
      }
      vm.beginCreatedTemplateAlbumForEdit(
        albumId: dummyAlbum.id,
        albumTitle: _albumTitle,
        pages: pages,
        initialCover: _selectedCover,
        templateCanvasSize: _usesPhysicalTemplateCanvas
            ? coverCanvasBaseSize(_selectedCover!)
            : _draftCoverCanvasSize,
      );
    } else {
      vm.beginCreatedAlbumForEdit(
        albumId: dummyAlbum.id,
        albumTitle: _albumTitle,
      );
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        settings: const WebAppRouteSettings(WebAppLocation.create),
        builder: (_) => PageEditorScreen(
          initialPageIndex: editorCheckpoint?.pageIndex ?? 1,
          creationDraftId: _draftId,
          creationDraftOwner: _draftOwner,
        ),
      ),
    );
  }

  List<LayerModel> _editedCoverLayers() {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    if (vm.pages.isEmpty)
      return _resolvedTemplatePages?.firstOrNull ?? _draftCoverLayers ?? [];
    final page = vm.pages.first;
    final source =
        ref.read(albumEditorViewModelProvider).value?.coverCanvasSize ??
        Size(
          kCoverReferenceWidth,
          kCoverReferenceWidth / _selectedCover!.ratio,
        );
    final layers = <LayerModel>[
      if (page.backgroundColor != null)
        LayerModel(
          id: 'creation-edited-background',
          type: LayerType.decoration,
          position: Offset.zero,
          width: source.width,
          height: source.height,
          imageBackground: 'free',
          decorationFillColor:
              '#${page.backgroundColor!.toRadixString(16).padLeft(8, '0')}',
          zIndex: -100,
        ),
      ...page.layers.where(
        (layer) =>
            page.backgroundColor == null ||
            layer.id != 'creation-edited-background',
      ),
    ];
    if (!_usesPhysicalTemplateCanvas) return layers;
    return AlbumCreationTemplate.preparePages(
      [layers],
      sourceCanvas: source,
      cover: _selectedCover!,
      clearSamplePhotos: false,
    ).first;
  }

  /// 뒤로가기 처리
  /// - Step 0: 플로우 종료 (Navigator.pop)
  /// - Step 1,2,3: 이전 스텝으로 이동
  /// return true 이면 이벤트를 소모했음을 의미 (WillPopScope에서 pop 방지)
  Future<bool> _handleBack() async {
    if (_savingDraft || _leaving || _reviewing) return true;
    if (_isGeneratingAiDraft ||
        _isAcceptingAiDraft ||
        _aiPointUsageUnconfirmed) {
      _dismissAiWaitNotice();
      final notice = ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _aiPointUsageUnconfirmed
                ? '포인트 처리 결과를 먼저 확인해 주세요. 같은 디자인을 유지하고 있어요.'
                : '현재 요청의 결과를 기다리고 있어요. 중복 요청을 보내지 않도록 잠시 기다려 주세요.',
          ),
        ),
      );
      _aiWaitNotice = notice;
      unawaited(
        notice.closed.then((_) {
          if (identical(_aiWaitNotice, notice)) _aiWaitNotice = null;
        }),
      );
      return true;
    }
    if (_previewAiComparison) {
      setState(() => _previewAiComparison = false);
      return true;
    }
    if (_returnToAiResult()) return true;
    if (_currentStep == 0 &&
        _isAiCreationMode &&
        _pendingAiDraft != null &&
        _aiDraftFailureMessage == null) {
      _editAiRequest();
      return true;
    }
    if (_currentStep == 0 &&
        !_hasSelectedCreationMode &&
        _returnToSetupFromHub) {
      setState(() {
        _returnToSetupFromHub = false;
        _hasSelectedCreationMode = true;
      });
      return true;
    }
    if (_currentStep == 0 &&
        _hasSelectedCreationMode &&
        _hasFilledPhotos &&
        !_isAiCreationMode) {
      _changeDesign();
      return true;
    }
    if (_currentStep == 1 &&
        !_showPhotoFill &&
        _resolvedTemplatePages != null) {
      _keepEditedCover();
      setState(() {
        _showPhotoFill = true;
        _onCompletePressed = null;
      });
      return true;
    }
    if (_currentStep == 0 &&
        _hasSelectedCreationMode &&
        widget.initialTemplatePages == null &&
        widget.initialTemplatePagesByAspect == null &&
        widget.initialAlbumTitle == null) {
      setState(() {
        _aiDraftRequestId += 1;
        _clearAiResultHistory();
        _aiRequestOwner = null;
        _isGeneratingAiDraft = false;
        _selectedAiTheme = null;
        _selectedAiRange = null;
        _pendingAiDraft = null;
        _isAiCreationMode = false;
        _hasConfirmedAiPointCost = false;
        _hasSelectedCreationMode = false;
      });
      return true;
    }
    if (_currentStep > 0) {
      _keepEditedCover();
      setState(() {
        _currentStep -= 1;
      });
      return true;
    } else {
      await _leaveCreation();
      return true;
    }
  }
}
