import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../../core/constants/cover_size.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/platform_ui.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../../billing/data/billing_provider.dart';
import '../../../billing/data/billing_repository.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/layer.dart';
import '../../ai_album/domain/ai_album_draft_generation_service.dart';
import '../../ai_album/domain/ai_album_draft_template_builder.dart';
import '../../ai_album/domain/ai_album_models.dart';
import '../../data/api/album_provider.dart';
import '../widgets/create_flow/album_create_step1.dart';
import '../widgets/create_flow/album_create_step2.dart';
import '../widgets/create_flow/ai_album_draft_failure_step.dart';
import '../widgets/create_flow/ai_album_photo_range_step.dart';
import '../widgets/create_flow/ai_album_point_confirmation_step.dart';
import '../widgets/create_flow/ai_album_recommendation_review_step.dart';
import '../widgets/create_flow/ai_album_start_step.dart';
import '../widgets/create_flow/ai_album_theme_step.dart';
import '../viewmodels/album_editor_view_model.dart';
import 'add_cover_screen.dart';
import 'page_editor_screen.dart';

/// 앨범 생성 플로우 화면 (스텝1~3)
class AlbumCreateFlowScreen extends ConsumerStatefulWidget {
  final List<List<LayerModel>>? initialTemplatePages;
  final Map<String, List<List<LayerModel>>>? initialTemplatePagesByAspect;
  final String? initialAlbumTitle;
  final List<String>? initialTemplatePreviewImages;
  final CoverSize? initialCoverSize;

  const AlbumCreateFlowScreen({
    super.key,
    this.initialTemplatePages,
    this.initialTemplatePagesByAspect,
    this.initialAlbumTitle,
    this.initialTemplatePreviewImages,
    this.initialCoverSize,
  });

  @override
  ConsumerState<AlbumCreateFlowScreen> createState() =>
      _AlbumCreateFlowScreenState();
}

class _AlbumCreateFlowScreenState extends ConsumerState<AlbumCreateFlowScreen> {
  static const int _maxPageCount = 50;
  int _currentStep = 0;
  String _albumTitle = '';
  static const int _aiDraftPointCost = 300;
  static const int _previewPointBalance = 1200;
  static const AiAlbumDraftTemplateBuilder _aiDraftTemplateBuilder =
      AiAlbumDraftTemplateBuilder();
  bool _hasSelectedCreationMode = false;
  bool _isAiCreationMode = false;
  bool _hasConfirmedAiPointCost = false;
  bool _isGeneratingAiDraft = false;
  AlbumTheme? _selectedAiTheme;
  AiPhotoRange? _selectedAiRange;
  AlbumRecommendationDraft? _pendingAiDraft;
  String? _aiDraftFailureTitle;
  String? _aiDraftFailureMessage;
  String? _aiDraftPrimaryCtaLabel;
  AiAlbumDraftRecoveryAction? _aiDraftPrimaryRecoveryAction;

  CoverSize? _selectedCover;
  int _selectedPageCount = 10;
  int _templateMinPageCount = 10;
  bool _allowEditing = true;
  List<String> _invitedEmails = [];
  int? _createdAlbumId;
  List<List<LayerModel>>? _resolvedTemplatePages;
  List<List<LayerModel>>? _baseTemplatePages;
  Map<String, List<List<LayerModel>>>? _templatePagesByAspect;

  /// 커버 편집 단계(step 1)에서 AppBar 완료 버튼이 호출할 콜백
  VoidCallback? _onCompletePressed;

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

  CoverSize _coverForAspectKey(String key) {
    final normalized = key.toLowerCase();
    if (normalized == 'portrait') {
      return coverSizes.firstWhere(
        (s) => s.name == '세로형',
        orElse: () => coverSizes.first,
      );
    }
    if (normalized == 'landscape') {
      return coverSizes.firstWhere(
        (s) => s.name == '가로형',
        orElse: () => coverSizes.last,
      );
    }
    return coverSizes.firstWhere(
      (s) => s.name == '정사각형',
      orElse: () => coverSizes.first,
    );
  }

  CoverSize _resolveInitialCover() {
    if (widget.initialCoverSize != null) {
      return widget.initialCoverSize!;
    }
    final variants = _templatePagesByAspect;
    if (variants != null && variants.isNotEmpty) {
      if (variants['portrait']?.isNotEmpty ?? false) {
        return _coverForAspectKey('portrait');
      }
      if (variants['square']?.isNotEmpty ?? false) {
        return _coverForAspectKey('square');
      }
      if (variants['landscape']?.isNotEmpty ?? false) {
        return _coverForAspectKey('landscape');
      }
    }
    return coverSizes.firstWhere(
      (s) => s.name == '정사각형',
      orElse: () => coverSizes.first,
    );
  }

  void _applyTemplateByCoverIfNeeded(CoverSize cover) {
    final key = _aspectKeyFromCover(cover);
    final variants = _templatePagesByAspect;
    final selected = key == 'portrait'
        ? _baseTemplatePages
        : variants == null
        ? null
        : variants[key];
    if (selected == null || selected.isEmpty) return;
    // 기존에 충분한 페이지가 이미 해석된 상태라면,
    // 페이지 수가 부족한 variant로 덮어쓰지 않도록 방어한다.
    final currentResolvedCount = _resolvedTemplatePages?.length ?? 0;
    if (currentResolvedCount > 1 && selected.length <= 1) return;
    _resolvedTemplatePages = _hydrateTemplatePages(selected);
    _templateMinPageCount = (_resolvedTemplatePages!.length - 1).clamp(
      1,
      _maxPageCount,
    );
    _selectedPageCount = _selectedPageCount.clamp(
      _templateMinPageCount,
      _maxPageCount,
    );
  }

  @override
  void initState() {
    super.initState();
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
        return MapEntry(k.toLowerCase(), v);
      });
    }
    if (widget.initialTemplatePages != null &&
        widget.initialTemplatePages!.isNotEmpty) {
      _baseTemplatePages = _hydrateTemplatePages(widget.initialTemplatePages!);
      _resolvedTemplatePages = _baseTemplatePages;
      (_templatePagesByAspect ??=
              <String, List<List<LayerModel>>>{})['portrait'] =
          _baseTemplatePages!;
    }
    if (widget.initialAlbumTitle != null &&
        widget.initialAlbumTitle!.trim().isNotEmpty) {
      _albumTitle = widget.initialAlbumTitle!.trim();
    }
    _selectedCover = _resolveInitialCover();
    if (_resolvedTemplatePages != null && _resolvedTemplatePages!.isNotEmpty) {
      // cover 제외 내지 페이지 수
      _templateMinPageCount = (_resolvedTemplatePages!.length - 1).clamp(
        1,
        _maxPageCount,
      );
      _selectedPageCount = _templateMinPageCount;
    }
    // 초기 진입 시에도 현재 선택 커버 비율(기본: 정사각형)에 맞는 variant를 즉시 적용한다.
    // 그래야 사용자가 정사각형을 한 번 더 탭하지 않아도 페이지/이미지 크기가 맞게 보인다.
    if (_selectedCover != null) {
      _applyTemplateByCoverIfNeeded(_selectedCover!);
    }
    ScreenLogger.enter(
      'AlbumCreateFlowScreen',
      '앨범 생성 플로우 Step 1~4 (정보 입력 → 커버 편집 → 친구 초대 → 페이지 편집)',
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final handled = _handleBack();
        return !handled; // handled == true 이면 pop 막기
      },
      child: Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        appBar: AppBar(
          toolbarHeight: 52.h,
          backgroundColor: SnapFitColors.backgroundOf(context),
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              platformBackIcon(),
              color: SnapFitColors.textPrimaryOf(context),
              size: 18.sp,
            ),
            onPressed: _handleBack,
          ),
          title: Text(
            _currentStep == 0
                ? '새 앨범'
                : _currentStep == 1
                ? '표지'
                : '초대',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w900,
              color: SnapFitColors.textPrimaryOf(context),
              letterSpacing: -0.25,
            ),
          ),
          actions: [
            if (_currentStep == 1)
              Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: Center(
                  child: TextButton(
                    onPressed: _onCompletePressed,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      minimumSize: Size(64.w, 36.h),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      '다음',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: SnapFitColors.textPrimaryOf(context),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_currentStep > 0) _buildFlowProgress(),
            Expanded(child: _buildStepContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowProgress() {
    final totalSteps = 2;
    final visibleStep = _currentStep.clamp(1, totalSteps);
    final label = _currentStep == 1 ? '표지에 집중하기' : '초대 설정';
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$visibleStep / $totalSteps',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: SnapFitColors.textMutedOf(context),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999.r),
                  child: LinearProgressIndicator(
                    minHeight: 3.h,
                    value: visibleStep / totalSteps,
                    backgroundColor: SnapFitColors.overlayLightOf(context),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      SnapFitColors.textPrimaryOf(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5.sp,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: SnapFitColors.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiDraftGenerating() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 34.w,
              height: 34.w,
              child: const CircularProgressIndicator(strokeWidth: 2.8),
            ),
            SizedBox(height: 18.h),
            Text(
              'AI 초안을 정리하고 있어요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18.sp,
                height: 1.25,
                fontWeight: FontWeight.w900,
                color: SnapFitColors.textPrimaryOf(context),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '성공 시만 처리. 실패 시 차감 없음.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: SnapFitColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAiDraftFromSelection() async {
    final theme = _selectedAiTheme;
    final range = _selectedAiRange;
    if (theme == null || range == null || _isGeneratingAiDraft) return;

    setState(() {
      _isGeneratingAiDraft = true;
      _hasConfirmedAiPointCost = false;
      _pendingAiDraft = null;
      _aiDraftFailureTitle = null;
      _aiDraftFailureMessage = null;
      _aiDraftPrimaryCtaLabel = null;
      _aiDraftPrimaryRecoveryAction = null;
    });

    final result = await ref
        .read(aiAlbumDraftGenerationServiceProvider)
        .generate(theme: theme, range: range);
    if (!mounted) return;

    final draft = result.draft;
    if (result.shouldChargePoints && draft != null) {
      setState(() {
        _isGeneratingAiDraft = false;
        _hasConfirmedAiPointCost = true;
        _pendingAiDraft = draft;
        _aiDraftFailureTitle = null;
        _aiDraftFailureMessage = null;
        _aiDraftPrimaryCtaLabel = null;
        _aiDraftPrimaryRecoveryAction = null;
        if (_albumTitle.trim().isEmpty) {
          _albumTitle = draft.title;
        }
        _selectedPageCount = draft.pageCount.clamp(
          _templateMinPageCount,
          _maxPageCount,
        );
      });
      return;
    }

    setState(() {
      _isGeneratingAiDraft = false;
      _hasConfirmedAiPointCost = false;
      _pendingAiDraft = null;
      _aiDraftFailureTitle = result.failureTitle ?? '초안을 만들지 못했어요';
      _aiDraftFailureMessage =
          result.failureMessage ?? 'AI 초안을 준비하지 못했어요. 포인트는 차감되지 않았어요.';
      _aiDraftPrimaryCtaLabel = result.primaryCtaLabel ?? '사진 범위 다시 고르기';
      _aiDraftPrimaryRecoveryAction =
          result.primaryRecoveryAction ??
          AiAlbumDraftRecoveryAction.retryPhotoRange;
    });
  }

  Future<void> _acceptAiDraft(AlbumRecommendationDraft acceptedDraft) async {
    final editorReadiness = _aiDraftTemplateBuilder.validateEditorReady(
      acceptedDraft,
    );
    if (!editorReadiness.isReady) {
      setState(() => _setAiDraftEditorHandoffFailure(editorReadiness.reason));
      return;
    }

    try {
      await ref
          .read(billingRepositoryProvider)
          .recordAiAlbumDraftSuccess(
            draftId: acceptedDraft.draftId,
            pointCost: _aiDraftPointCost,
          )
          .timeout(const Duration(seconds: 8));
    } on AiAlbumDraftPointUsageException catch (error) {
      if (!mounted) return;
      setState(() => _setAiDraftPointUsageFailure(error.failure));
      return;
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _setAiDraftPointUsageFailure(
          AiAlbumDraftPointUsageFailure.unavailable,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      final aiPages = _aiDraftTemplateBuilder.build(acceptedDraft);
      _resolvedTemplatePages = aiPages;
      _baseTemplatePages = aiPages;
      (_templatePagesByAspect ??=
              <String, List<List<LayerModel>>>{})[_selectedCover == null
              ? 'square'
              : _aspectKeyFromCover(_selectedCover!)] =
          aiPages;
      _templateMinPageCount = (aiPages.length - 1).clamp(1, _maxPageCount);
      _pendingAiDraft = null;
      _aiDraftFailureTitle = null;
      _aiDraftFailureMessage = null;
      _aiDraftPrimaryCtaLabel = null;
      _aiDraftPrimaryRecoveryAction = null;
      if (_albumTitle.trim().isEmpty) {
        _albumTitle = acceptedDraft.title;
      }
      _selectedPageCount = acceptedDraft.pageCount.clamp(
        _templateMinPageCount,
        _maxPageCount,
      );
    });
  }

  void _setAiDraftPointUsageFailure(AiAlbumDraftPointUsageFailure failure) {
    final isInsufficient =
        failure == AiAlbumDraftPointUsageFailure.insufficientPoints;
    _pendingAiDraft = null;
    _hasConfirmedAiPointCost = false;
    _isGeneratingAiDraft = false;
    _aiDraftFailureTitle = isInsufficient
        ? '포인트가 조금 부족해요'
        : '포인트 상태를 확인하지 못했어요';
    _aiDraftFailureMessage = isInsufficient
        ? 'AI 초안은 준비됐지만, 이 구성을 열기엔 포인트가 부족해요. 현재 포인트를 다시 확인하거나 직접 구성할 수 있어요. 아직 포인트는 차감되지 않았어요.'
        : '초안은 만들었지만 사용 처리 기준을 확인하지 못해 바로 열지 않았어요. 포인트는 차감되지 않았어요.';
    _aiDraftPrimaryCtaLabel = isInsufficient ? '포인트 확인하기' : '사진 범위 다시 고르기';
    _aiDraftPrimaryRecoveryAction = isInsufficient
        ? AiAlbumDraftRecoveryAction.reviewPointCost
        : AiAlbumDraftRecoveryAction.retryPhotoRange;
  }

  void _setAiDraftEditorHandoffFailure(
    AiAlbumDraftEditorReadinessReason reason,
  ) {
    final title = switch (reason) {
      AiAlbumDraftEditorReadinessReason.emptyRecommendedPhotos =>
        '초안에 넣을 사진이 없어요',
      AiAlbumDraftEditorReadinessReason.pageCountMismatch => '앨범 쪽수를 다시 맞춰야 해요',
      AiAlbumDraftEditorReadinessReason.missingLocalImageAsset ||
      AiAlbumDraftEditorReadinessReason.ready => '앨범 초안을 안전하게 열지 않았어요',
    };
    final message = switch (reason) {
      AiAlbumDraftEditorReadinessReason.emptyRecommendedPhotos =>
        '선택한 범위에서 앨범에 넣을 사진을 찾지 못했어요. 사진 범위를 다시 고르거나 직접 구성해 주세요. 포인트는 차감되지 않았어요.',
      AiAlbumDraftEditorReadinessReason.pageCountMismatch =>
        'AI가 고른 쪽수와 실제 편집 쪽수가 달라 바로 열지 않았어요. 새 초안으로 다시 맞춰볼게요. 포인트는 차감되지 않았어요.',
      AiAlbumDraftEditorReadinessReason.missingLocalImageAsset ||
      AiAlbumDraftEditorReadinessReason.ready =>
        '구성은 만들었지만 편집기에 넣을 사진 레이어를 확인하지 못했어요. 사진을 다시 골라 새 초안을 만들면 안전해요. 포인트는 차감되지 않았어요.',
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
        setState(() {
          _hasConfirmedAiPointCost = false;
          _isGeneratingAiDraft = false;
          _pendingAiDraft = null;
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
    switch (_currentStep) {
      case 0:
        if (!_hasSelectedCreationMode) {
          return AiAlbumStartStep(
            aiPointCost: _aiDraftPointCost,
            freeDraftLabel: '첫 생성은 무료예요',
            isFirstAiDraftFree: true,
            onAiStart: () => setState(() {
              _isAiCreationMode = true;
              _hasSelectedCreationMode = true;
            }),
            onManualStart: () => setState(() {
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
        if (_isAiCreationMode && _selectedAiTheme == null) {
          return AiAlbumThemeStep(
            onThemeSelected: (theme) => setState(() {
              _selectedAiTheme = theme;
            }),
            onBack: () => setState(() {
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
            }),
          );
        }
        final selectedAiTheme = _selectedAiTheme;
        if (_isAiCreationMode &&
            selectedAiTheme != null &&
            _selectedAiRange == null) {
          return AiAlbumPhotoRangeStep(
            theme: selectedAiTheme,
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
          return AiAlbumDraftFailureStep(
            title: aiDraftFailureTitle ?? '초안을 만들지 못했어요',
            message: aiDraftFailureMessage,
            primaryActionLabel: aiDraftPrimaryCtaLabel ?? '사진 범위 다시 고르기',
            onRetryRange: () =>
                _handleAiDraftPrimaryRecovery(aiDraftPrimaryRecoveryAction),
            onManualStart: () => setState(() {
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
          return AiAlbumPointConfirmationStep(
            theme: selectedAiTheme,
            range: selectedAiRange,
            pointCost: _aiDraftPointCost,
            balance: _previewPointBalance,
            isFirstAiDraftFree: true,
            onConfirm: _generateAiDraftFromSelection,
            onBack: () => setState(() {
              _selectedAiRange = null;
              _hasConfirmedAiPointCost = false;
              _isGeneratingAiDraft = false;
              _pendingAiDraft = null;
              _aiDraftFailureTitle = null;
              _aiDraftFailureMessage = null;
              _aiDraftPrimaryCtaLabel = null;
              _aiDraftPrimaryRecoveryAction = null;
            }),
          );
        }
        if (_isAiCreationMode &&
            selectedAiTheme != null &&
            selectedAiRange != null &&
            pendingDraft != null) {
          return AiAlbumRecommendationReviewStep(
            draft: pendingDraft,
            onAcceptDraft: _acceptAiDraft,
            onBack: () => setState(() {
              _selectedAiRange = null;
              _hasConfirmedAiPointCost = false;
              _isGeneratingAiDraft = false;
              _pendingAiDraft = null;
            }),
          );
        }
        return AlbumCreateStep1(
          albumTitle: _albumTitle,
          templateTitle: widget.initialAlbumTitle,
          templatePreviewImageUrl:
              widget.initialTemplatePreviewImages != null &&
                  widget.initialTemplatePreviewImages!.isNotEmpty
              ? widget.initialTemplatePreviewImages!.first
              : null,
          selectedCover: _selectedCover,
          selectedPageCount: _selectedPageCount,
          minPageCount: _templateMinPageCount,
          // 제목 변경은 부모의 setState를 매 키 입력마다 호출하지 않고,
          // 값만 보관해서 한글 IME 조합이 끊기지 않도록 한다.
          onTitleChanged: (title) => _albumTitle = title,
          onCoverSelected: (cover) => setState(() {
            _selectedCover = cover;
            _applyTemplateByCoverIfNeeded(cover);
          }),
          onPageCountChanged: (count) => setState(
            () => _selectedPageCount = count.clamp(
              _templateMinPageCount,
              _maxPageCount,
            ),
          ),
          onNext: () {
            final title = _albumTitle.trim();
            if (title.isNotEmpty && _selectedCover != null) {
              _albumTitle = title;
              setState(() => _currentStep = 1);
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('앨범 제목과 커버 비율을 확인해주세요.')),
            );
          },
        );
      case 1:
        // Step 2: 앨범 생성 페이지 (커버 편집 화면)
        if (_selectedCover == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return AddCoverScreen(
          isFromCreateFlow: true,
          initialCoverSize: _selectedCover,
          albumTitle: _albumTitle, // 앨범 제목 전달
          targetPages: _selectedPageCount, // 목표 페이지 수 전달
          initialTemplateCoverLayers:
              (_resolvedTemplatePages != null &&
                  _resolvedTemplatePages!.isNotEmpty)
              ? _resolvedTemplatePages!.first
              : null,
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

  Future<void> _handleAlbumCreated(int albumId) async {
    _createdAlbumId = albumId;
    final dummyAlbum = Album(
      id: albumId,
      ratio: _selectedCover!.ratio.toString(),
      targetPages: _selectedPageCount,
    );

    final vm = ref.read(albumEditorViewModelProvider.notifier);
    if (_resolvedTemplatePages != null && _resolvedTemplatePages!.isNotEmpty) {
      vm.beginCreatedTemplateAlbumForEdit(
        albumId: dummyAlbum.id,
        albumTitle: _albumTitle,
        pages: _resolvedTemplatePages!,
        initialCover: _selectedCover,
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
        builder: (_) => const PageEditorScreen(initialPageIndex: 1),
      ),
    );
  }

  /// 뒤로가기 처리
  /// - Step 0: 플로우 종료 (Navigator.pop)
  /// - Step 1,2,3: 이전 스텝으로 이동
  /// return true 이면 이벤트를 소모했음을 의미 (WillPopScope에서 pop 방지)
  bool _handleBack() {
    if (_currentStep == 0 &&
        _hasSelectedCreationMode &&
        widget.initialTemplatePages == null &&
        widget.initialTemplatePagesByAspect == null &&
        widget.initialAlbumTitle == null) {
      setState(() {
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
      setState(() {
        _currentStep -= 1;
      });
      return true;
    } else {
      Navigator.pop(context);
      return true;
    }
  }
}
