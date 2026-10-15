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
import '../../../../core/utils/platform_ui.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../../../core/navigation/web_unsaved_work_guard.dart';
import '../../../../core/navigation/web_app_location.dart';
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
import '../../data/gallery/browser_photo_asset.dart';
import '../../data/album_creation_catalog_provider.dart';
import '../../data/album_creation_draft_store.dart';
import '../../domain/entities/album_creation_draft.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../widgets/create_flow/album_creation_review_sheet.dart';
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
        _draftWriteSession = (store as AlbumCreationDraftWriteSession).beginDraftWriteSession(
          _draftOwner!, _draftId, restoring: widget.initialDraft,
        ).then<void>((_) {}, onError: (Object error, StackTrace _) {
          // Keep asynchronous preparation failures handled until Save can show
          // the message without discarding the document being edited.
          _draftWriteSessionError = error;
        });
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
    }
    ScreenLogger.enter(
      'AlbumCreateFlowScreen',
      '앨범 생성 플로우 Step 1~4 (정보 입력 → 커버 편집 → 친구 초대 → 페이지 편집)',
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(kIsWeb
            ? '이 브라우저에 사진 원본과 함께 임시 저장했어요.'
            : '이 기기에 임시 저장했어요.')));
      return true;
    } catch (error) {
      if (mounted && notify)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(kIsWeb && error is BrowserPhotoException
              ? error.message
              : kIsWeb
              ? '임시 저장하지 못했어요. 브라우저 저장 공간을 확인한 뒤 다시 시도해주세요. 작업은 유지됩니다.'
              : '임시 저장하지 못했어요. 작업을 유지한 채 다시 시도해주세요.')),
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
    return WebUnsavedWorkGuard(
      hasUnsavedChanges: _hasUnsavedBrowserPhotoWork,
      child: WillPopScope(
        onWillPop: () async {
          final handled = await _handleBack();
          return !handled; // handled == true 이면 pop 막기
        },
        child: kIsWeb ? _buildWebCreation() : Scaffold(
          backgroundColor: SnapFitColors.backgroundOf(context),
          appBar: AppBar(
            toolbarHeight:
                MediaQuery.orientationOf(context) == Orientation.landscape
                ? 48
                : 60,
            backgroundColor: SnapFitColors.backgroundOf(context),
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            elevation: 0,
            leading: IconButton(
              tooltip: '뒤로가기',
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
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: ExperienceFormStyle.ink(context),
                letterSpacing: 0,
              ),
            ),
            actions: [
              if (!_isAiCreationMode && !_isGeneratingAiDraft) ...[
                IconButton(
                  key: const ValueKey('creation-save-draft'),
                  tooltip: '임시 저장',
                  onPressed: _savingDraft || _startingAlbum ? null : _saveDraft,
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
              if (_currentStep == 1 && !_showPhotoFill)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: TextButton(
                      onPressed:
                          _onCompletePressed == null ||
                              _savingDraft ||
                              _startingAlbum
                          ? null
                          : _reviewBeforeCreate,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: const Size(64, 44),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        '전체 확인',
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
              if (_hasSelectedCreationMode &&
                  !(MediaQuery.orientationOf(context) ==
                          Orientation.landscape &&
                      creationKeyboardIsOpen(context)))
                _buildCreationProgress(),
              Expanded(child: _buildStepContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebCreation() {
    final compactHeader = MediaQuery.sizeOf(context).width < 700;
    final hasPhotos = _resolvedTemplatePages != null || _isAiCreationMode;
    final labels = hasPhotos
        ? ['디자인 선택', '앨범 설정', '사진 채우기', '표지 편집', _currentStep == 2 ? '공유 설정' : '편집 시작']
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
      section: WebSection.create,
      workspace: true,
      showNavigation: false,
      sidebar: SingleChildScrollView(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('제작 순서', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: WebPalette.of(context).muted)),
            const SizedBox(height: 20),
            for (var i = 0; i < labels.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  selected: i == selected,
                  label: '${i + 1}단계 ${labels[i]}${i < selected ? ', 이전 단계' : ''}',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: i == selected ? WebPalette.of(context).softBrand : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Icon(i < selected ? Icons.check_circle_outline : Icons.radio_button_unchecked, size: 18, color: i <= selected ? WebPalette.of(context).brandInk : WebPalette.of(context).muted),
                      const SizedBox(width: 10),
                      Expanded(child: Text(labels[i], style: TextStyle(fontSize: 14, fontWeight: i == selected ? FontWeight.w700 : FontWeight.w400, color: i == selected ? WebPalette.of(context).ink : WebPalette.of(context).muted))),
                    ]),
                  ),
                ),
              ),
            const SizedBox(height: 28),
            Divider(color: WebPalette.of(context).line),
            const SizedBox(height: 16),
            Text('사진을 추가한 뒤에는 앨범 저장을 마치고 창을 닫아주세요.', style: TextStyle(fontSize: 12, height: 1.7, color: WebPalette.of(context).muted)),
          ],
        ),
      )),
      actions: [
        if (compactHeader)
          IconButton(onPressed: _savingDraft || _startingAlbum || _reviewing ? null : _handleBack, tooltip: '이전 단계', icon: const Icon(Icons.arrow_back, size: 20))
        else TextButton.icon(
          onPressed: _savingDraft || _startingAlbum || _reviewing ? null : _handleBack,
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('이전'),
        ),
        if (!_isAiCreationMode && !_isGeneratingAiDraft) ...[
          if (compactHeader)
            IconButton(
              key: const ValueKey('creation-save-draft'),
              onPressed: _savingDraft || _startingAlbum ? null : _saveDraft,
              tooltip: _savingDraft ? '저장 중' : '임시 저장',
              icon: const Icon(Icons.save_outlined, size: 20),
            )
          else TextButton.icon(
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
      child: LayoutBuilder(builder: (context, bounds) {
        final compact = bounds.maxWidth < 760;
        return Padding(
          padding: EdgeInsets.fromLTRB(compact ? 20 : 32, 24, compact ? 20 : 32, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (MediaQuery.sizeOf(context).width < 1000) ...[
                Text('앨범 만들기  /  ${selected + 1}단계 · $title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: WebPalette.of(context).brandInk)),
                const SizedBox(height: 14),
              ],
              WebPageHeading(
                eyebrow: 'ALBUM MAKER · ${selected + 1} / ${labels.length}',
                title: title,
                description: description,
                trailing: _currentStep == 1 && !_showPhotoFill
                    ? FilledButton.icon(
                        onPressed: _onCompletePressed == null || _savingDraft || _startingAlbum ? null : _reviewBeforeCreate,
                        icon: const Icon(Icons.fact_check_outlined, size: 18),
                        label: const Text('전체 확인'),
                      )
                    : null,
              ),
              const SizedBox(height: 18),
              if (_selectedCover != null && _hasSelectedCreationMode && !_isAiCreationMode) ...[
                Wrap(spacing: 20, runSpacing: 6, children: [
                  Text(_albumTitle.trim().isEmpty ? '제목 입력 전' : _albumTitle, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: WebPalette.of(context).ink)),
                  Text('${_selectedCover!.displayName} · ${_selectedCover!.coverType.label} · 내지 $_selectedPageCount쪽', style: TextStyle(fontSize: 13, color: WebPalette.of(context).muted)),
                  Text(_sourceLabel, style: TextStyle(fontSize: 13, color: WebPalette.of(context).muted)),
                ]),
                const SizedBox(height: 18),
              ],
              Expanded(child: WebSurface(padding: EdgeInsets.zero, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _buildStepContent()))),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildAiDraftGenerating() {
    return AiTemplateGeneratingStep(
      cover: _designBrief?.coverSize ?? _selectedCover,
      innerPageCount: _designBrief?.pageCount,
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
        _selectedPageCount = _normalizePageCount(draft.pageCount);
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
    if (_createdAlbumId != null)
      return const Center(child: CircularProgressIndicator());
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
