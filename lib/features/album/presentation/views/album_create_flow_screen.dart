import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../../config/env.dart';
import '../../../../core/constants/cover_size.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/platform_ui.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../../billing/data/billing_provider.dart';
import '../../../billing/data/billing_repository.dart';
import '../../../profile/presentation/views/billing_management_screen.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/layer.dart';
import '../../domain/entities/album_creation_template.dart';
import '../../../store/domain/entities/premium_template.dart';
import '../../../store/data/api/template_provider.dart';
import '../../../store/presentation/views/template_detail_screen.dart';
import '../../ai_album/domain/ai_album_draft_generation_service.dart';
import '../../ai_album/domain/ai_album_draft_template_builder.dart';
import '../../ai_album/domain/ai_album_models.dart';
import '../../data/api/album_provider.dart';
import '../../data/album_creation_catalog_provider.dart';
import '../widgets/create_flow/album_create_step1.dart';
import '../widgets/create_flow/album_create_step2.dart';
import '../widgets/create_flow/ai_album_draft_failure_step.dart';
import '../widgets/create_flow/ai_album_photo_range_step.dart';
import '../widgets/create_flow/ai_album_point_confirmation_step.dart';
import '../widgets/create_flow/ai_album_recommendation_review_step.dart';
import '../widgets/create_flow/ai_album_start_step.dart';
import '../widgets/create_flow/ai_template_brief_step.dart';
import '../widgets/create_flow/template_photo_fill_step.dart';
import '../viewmodels/album_editor_view_model.dart';
import 'add_cover_screen.dart';
import 'page_editor_screen.dart';

/// 앨범 생성 플로우 화면 (스텝1~3)
class AlbumCreateFlowScreen extends ConsumerStatefulWidget {
  final AlbumCreationTemplate? initialCreationTemplate;
  final List<List<LayerModel>>? initialTemplatePages;
  final Map<String, List<List<LayerModel>>>? initialTemplatePagesByAspect;
  final String? initialAlbumTitle;
  final List<String>? initialTemplatePreviewImages;
  final CoverSize? initialCoverSize;
  final bool usesServerDraftProvider;
  final bool usesAdvancedServerAnalysis;

  const AlbumCreateFlowScreen({
    super.key,
    this.initialCreationTemplate,
    this.initialTemplatePages,
    this.initialTemplatePagesByAspect,
    this.initialAlbumTitle,
    this.initialTemplatePreviewImages,
    this.initialCoverSize,
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

class _AlbumCreateFlowScreenState extends ConsumerState<AlbumCreateFlowScreen> {
  static const int _maxPageCount = 50;
  int _currentStep = 0;
  String _albumTitle = '';
  static const int _aiDraftPointCost = Env.aiAlbumDraftPointCost;
  static const AiAlbumDraftTemplateBuilder _aiDraftTemplateBuilder =
      AiAlbumDraftTemplateBuilder();
  bool _hasSelectedCreationMode = false;
  bool _isAiCreationMode = false;
  bool _hasConfirmedAiPointCost = false;
  bool _isGeneratingAiDraft = false;
  int _aiDraftRequestId = 0;
  AlbumTheme? _selectedAiTheme;
  AiTemplateBrief? _designBrief;
  AiPhotoRange? _selectedAiRange;
  AlbumRecommendationDraft? _pendingAiDraft;
  String? _aiDraftFailureTitle;
  String? _aiDraftFailureMessage;
  String? _aiDraftPrimaryCtaLabel;
  AiAlbumDraftRecoveryAction? _aiDraftPrimaryRecoveryAction;

  CoverSize? _selectedCover;
  PrintCoverType? _preferredCoverType;
  int _selectedPageCount = 10;
  int _templateMinPageCount = 10;
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
  VoidCallback? _onCompletePressed;

  void _resetDesign() {
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
    _templateMinPageCount = 10;
    _selectedPageCount = _selectedPageCount.clamp(10, _maxPageCount);
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
    _templateMinPageCount = (selection.pages.length - 1).clamp(
      1,
      _maxPageCount,
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
        _applyTemplateByCoverIfNeeded(cover);
        _hasFilledPhotos =
            _resolvedTemplatePages
                ?.expand((p) => p)
                .any((l) => l.asset != null) ??
            false;
      }
    });
  }

  Widget _buildCreationProgress() {
    final labels = _resolvedTemplatePages == null
        ? ['설정', '표지', '편집']
        : ['설정', '사진', '표지', '편집'];
    final selected = _currentStep == 0
        ? 0
        : _showPhotoFill
        ? 1
        : labels.length - 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: SnapFitColors.textMutedOf(context),
                ),
              ),
            Text(
              labels[i],
              style: TextStyle(
                fontSize: 12,
                fontWeight: i == selected ? FontWeight.w700 : FontWeight.w400,
                color: i == selected
                    ? SnapFitColors.textPrimaryOf(context)
                    : SnapFitColors.textMutedOf(context),
              ),
            ),
          ],
        ],
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
    _templateMinPageCount = (_resolvedTemplatePages!.length - 1).clamp(
      1,
      _maxPageCount,
    );
    _selectedPageCount = _selectedPageCount.clamp(
      _templateMinPageCount,
      _maxPageCount,
    );
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
    if (widget.initialCreationTemplate != null) {
      _useTemplate(widget.initialCreationTemplate!);
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
          toolbarHeight: 52,
          backgroundColor: SnapFitColors.backgroundOf(context),
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              platformBackIcon(),
              color: SnapFitColors.textPrimaryOf(context),
              size: 22,
            ),
            onPressed: _handleBack,
          ),
          title: Text(
            _currentStep == 0
                ? '앨범 만들기'
                : _currentStep == 1
                ? (_showPhotoFill ? '앨범 만들기' : '표지')
                : '초대',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: SnapFitColors.textPrimaryOf(context),
              letterSpacing: 0,
            ),
          ),
          actions: [
            if (_currentStep == 1 && !_showPhotoFill)
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
                        fontSize: 15,
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
            if (_hasSelectedCreationMode && !_isAiCreationMode)
              _buildCreationProgress(),
            Expanded(child: _buildStepContent()),
          ],
        ),
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
              'AI 템플릿을 잡고 있어요',
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
    final requestId = ++_aiDraftRequestId;

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
        .generate(theme: theme, range: range, designBrief: _designBrief);
    if (!mounted || requestId != _aiDraftRequestId) return;

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
      _aiDraftFailureTitle = result.failureTitle ?? 'AI 템플릿을 만들지 못했어요';
      _aiDraftFailureMessage =
          result.failureMessage ?? 'AI 템플릿을 준비하지 못했어요. 포인트는 차감되지 않았어요.';
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
      ref.invalidate(myPointBalanceProvider);
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
      _usesPhysicalTemplateCanvas = true;
      _preserveTemplateTypography = acceptedDraft.design?.artDirection != null;
      _isAiCreationMode = false;
      _hasFilledPhotos = false;
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
        ? 'AI 템플릿은 준비됐지만, 이 구성을 열기엔 포인트가 부족해요. 현재 포인트를 다시 확인하거나 직접 구성할 수 있어요. 아직 포인트는 차감되지 않았어요.'
        : '템플릿은 만들었지만 사용 처리 기준을 확인하지 못해 바로 열지 않았어요. 포인트는 차감되지 않았어요.';
    _aiDraftPrimaryCtaLabel = isInsufficient ? '포인트 충전하기' : '사진 범위 다시 고르기';
    _aiDraftPrimaryRecoveryAction = isInsufficient
        ? AiAlbumDraftRecoveryAction.reviewPointCost
        : AiAlbumDraftRecoveryAction.retryPhotoRange;
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
            templates: ref.watch(albumCreationCatalogProvider),
            onRetry: () {
              ref.invalidate(templateListProvider);
              ref.invalidate(albumCreationCatalogProvider);
            },
            onTemplateSelected: _selectTemplate,
            aiPointCost: _aiDraftPointCost,
            freeDraftLabel: '사진은 직접 고르고 바꿀 수 있어요',
            isFirstAiDraftFree: true,
            onAiStart: () => setState(() {
              _resetDesign();
              _isAiCreationMode = true;
              _hasSelectedCreationMode = true;
            }),
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
          return AiTemplateBriefStep(
            initialBrief: _designBrief,
            initialCoverSize: _selectedCover,
            onContinue: (brief) => setState(() {
              _designBrief = brief;
              _selectedCover = brief.coverSize;
              _preferredCoverType = brief.coverSize.coverType;
              _selectedAiTheme = AlbumTheme.custom;
              _selectedAiRange = AiPhotoRange.manualSelection;
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
            usesServerDraftProvider:
                _designBrief == null && widget.usesServerDraftProvider,
            usesAdvancedServerAnalysis:
                _designBrief == null && widget.usesAdvancedServerAnalysis,
            title: aiDraftFailureTitle ?? 'AI 템플릿을 만들지 못했어요',
            message: aiDraftFailureMessage,
            primaryActionLabel:
                _designBrief != null &&
                    aiDraftPrimaryRecoveryAction !=
                        AiAlbumDraftRecoveryAction.reviewPointCost
                ? '디자인 요청 다시 보기'
                : aiDraftPrimaryCtaLabel ?? '사진 범위 다시 고르기',
            isTemplateDesign: _designBrief != null,
            onRetryRange: () {
              if (_designBrief != null &&
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
          final pointBalance = ref
              .watch(myPointBalanceProvider)
              .maybeWhen(data: (value) => value, orElse: () => 0);
          return AiAlbumPointConfirmationStep(
            designBrief: _designBrief,
            theme: selectedAiTheme,
            range: selectedAiRange,
            pointCost: _aiDraftPointCost,
            balance: pointBalance,
            isFirstAiDraftFree: true,
            usesServerDraftProvider: widget.usesServerDraftProvider,
            usesAdvancedServerAnalysis: widget.usesAdvancedServerAnalysis,
            onConfirm: _generateAiDraftFromSelection,
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
          );
        }
        if (_isAiCreationMode &&
            selectedAiTheme != null &&
            selectedAiRange != null &&
            pendingDraft != null) {
          return AiAlbumRecommendationReviewStep(
            draft: pendingDraft,
            targetCover: _designBrief?.coverSize,
            onAcceptDraft: _acceptAiDraft,
            onBack: () => setState(() {
              if (_designBrief != null) _selectedAiTheme = null;
              _selectedAiRange = null;
              _hasConfirmedAiPointCost = false;
              _isGeneratingAiDraft = false;
              _pendingAiDraft = null;
            }),
          );
        }
        return AlbumCreateStep1(
          albumTitle: _albumTitle,
          templateTitle: _templateTitle,
          templatePreviewImageUrl: _templatePreviewUrl,
          sourceLabel: _sourceLabel,
          coverLayers: _resolvedTemplatePages?.firstOrNull,
          availableCovers: coverSizes,
          onChangeDesign: _changeDesign,
          selectedCover: _selectedCover,
          selectedPageCount: _selectedPageCount,
          minPageCount: _templateMinPageCount,
          // 제목 변경은 부모의 setState를 매 키 입력마다 호출하지 않고,
          // 값만 보관해서 한글 IME 조합이 끊기지 않도록 한다.
          onTitleChanged: (title) => _albumTitle = title,
          onCoverSelected: _selectCover,
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
              _hasFilledPhotos = true;
            }),
            onContinue: () => setState(() => _showPhotoFill = false),
          );
        }
        // Step 2: 앨범 생성 페이지 (커버 편집 화면)
        if (_selectedCover == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return AddCoverScreen(
          isFromCreateFlow: true,
          initialCoverSize: _selectedCover,
          initialTemplateCanvasSize: _usesPhysicalTemplateCanvas
              ? coverCanvasBaseSize(_selectedCover!)
              : null,
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
      // Keep the cover just edited; only the inner pages come from the template.
      final cover = _editedCoverLayers();
      final pages = <List<LayerModel>>[
        cover,
        ..._resolvedTemplatePages!.skip(1),
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
            : null,
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

  List<LayerModel> _editedCoverLayers() {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    if (vm.pages.isEmpty) return _resolvedTemplatePages!.first;
    final page = vm.pages.first;
    if (!_usesPhysicalTemplateCanvas) return [...page.layers];
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
      ...page.layers,
    ];
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
  bool _handleBack() {
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
      final vm = ref.read(albumEditorViewModelProvider.notifier);
      setState(() {
        if (vm.pages.isNotEmpty) {
          _resolvedTemplatePages = [
            _editedCoverLayers(),
            ..._resolvedTemplatePages!.skip(1),
          ];
        }
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
