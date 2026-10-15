import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/edit_cover.dart';

import '../../../../core/constants/cover_size.dart';
import '../../../../core/constants/album_page_policy.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../data/api/album_provider.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/layer.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../viewmodels/cover_view_model.dart';
import '../widgets/editor/editor_bottom_menu.dart';
import '../widgets/editor/decorate_panel.dart';
import '../widgets/editor/layer_manager_panel.dart';
import '../widgets/editor/template_selection_panel.dart';
import '../widgets/editor/design_template_panel.dart';
import '../widgets/editor/layer_action_panel.dart';
import '../widgets/editor/text_style_picker_sheet.dart';
import '../controllers/layer_interaction_manager.dart';
import '../controllers/toolbar_action_handler.dart';
import '../controllers/text_editor_manager.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/web/web_design.dart';
import '../controllers/photo_frame_editor.dart';
import '../controllers/photo_crop_editor.dart';
import '../controllers/layer_builder.dart';

@visibleForTesting
double coverLayerActionPanelBaseBottom({required bool isCreateFlow}) =>
    isCreateFlow ? 204 : 100;

@visibleForTesting
double coverLayerActionPanelBottom({
  required bool isCreateFlow,
  required double Function(double value) scaleBaseOffset,
  double safeAreaBottom = 0,
}) {
  final base = coverLayerActionPanelBaseBottom(isCreateFlow: isCreateFlow);
  final scaledBase = scaleBaseOffset(base);
  return (isCreateFlow ? scaledBase.clamp(base, double.infinity) : scaledBase) +
      safeAreaBottom;
}

/// 커버 편집 화면 (앨범 생성/편집 공통)
/// - editAlbum == null && albumId == null: 앨범 생성 모드 (새 커버 만들기)
/// - editAlbum != null: 앨범 편집 모드 (기존 커버 수정, 이미 prepareAlbumForEdit 호출됨)
/// - albumId != null: 앨범 ID로 앨범을 로드하여 편집 모드로 진입
///
/// 참고: 앨범 내부 페이지 편집은 AlbumSpreadScreen 사용
class AddCoverScreen extends ConsumerStatefulWidget {
  /// 편집 모드: 홈에서 앨범 선택 후 이 화면으로 올 때 전달 (이미 prepareAlbumForEdit 호출됨)
  final Album? editAlbum;

  /// 앨범 ID로 앨범을 로드하여 편집 모드로 진입 (앨범 생성 플로우에서 사용)
  final int? albumId;

  /// 앨범 생성 플로우에서 사용되는지 여부 (생성 후 페이지 편집 화면으로 이동)
  final bool isFromCreateFlow;

  /// 앨범 생성 플로우에서 선택된 커버 사이즈
  final CoverSize? initialCoverSize;

  /// 앨범 제목 (생성 플로우에서 사용)
  final String? albumTitle;

  /// 목표 페이지 수 (생성 플로우에서 사용)
  final int? targetPages;

  /// 템플릿 유입 시 Step2에서 보여줄 예시 커버 레이어
  final List<LayerModel>? initialTemplateCoverLayers;
  final Size? initialTemplateCanvasSize;

  /// 앨범 생성 완료 콜백 (플로우에서 사용)
  final Function(int albumId)? onAlbumCreated;

  /// 테스트에서 실제 레이어 선택 상태를 안정적으로 재현하기 위한 초기 선택 ID.
  @visibleForTesting
  final String? debugInitialSelectedLayerId;

  /// 플로우 AppBar의 '완료' 버튼이 눌렸을 때 호출할 액션 등록 (플로우에서만 사용)
  final void Function(Future<void> Function())? onRegisterCompleteAction;
  final VoidCallback? onReviewBeforeCreate;

  const AddCoverScreen({
    super.key,
    this.editAlbum,
    this.albumId,
    this.isFromCreateFlow = false,
    this.initialCoverSize,
    this.albumTitle,
    this.targetPages,
    this.initialTemplateCoverLayers,
    this.initialTemplateCanvasSize,
    this.onAlbumCreated,
    this.debugInitialSelectedLayerId,
    this.onRegisterCompleteAction,
    this.onReviewBeforeCreate,
  });

  @override
  ConsumerState<AddCoverScreen> createState() => _AddCoverScreenState();
}

class _AddCoverScreenState extends ConsumerState<AddCoverScreen> {
  final GlobalKey<EditCoverState> _coverEditorKey = GlobalKey<EditCoverState>();
  final GlobalKey _canvasKey = GlobalKey();
  final GlobalKey _creationDockKey = GlobalKey();
  double _creationDockHeight = 0;
  late final LayerInteractionManager _interaction;
  late final ToolbarActionHandler _toolbarActionHandler;
  EditorMode _currentMode = EditorMode.none;

  late final ScrollController _gridController;
  bool _initialized = false;
  bool _templateCoverApplied = false;
  bool _templateApplyQueued = false;
  late CoverSize _selectedCover;

  @override
  void initState() {
    super.initState();
    final mode = widget.editAlbum != null
        ? '기존 앨범 커버 편집'
        : widget.isFromCreateFlow
        ? '앨범 생성 플로우 · 커버 편집 (Step 2)'
        : '신규 앨범 커버 생성';
    ScreenLogger.enter('AddCoverScreen', mode);

    _interaction = LayerInteractionManager(
      ref: ref,
      coverKey: _canvasKey,
      setState: setState,
      getCoverSize: () =>
          coverCanvasBaseSize(_selectedCover), // Approximate size
      onEditText: (layer) {
        final vm = ref.read(albumEditorViewModelProvider.notifier);
        TextEditorManager(context, vm).openForExisting(layer);
      },
    );
    _toolbarActionHandler = ToolbarActionHandler(context, ref);

    _gridController = ScrollController();

    // 플로우에서 넘어온 경우, 이미 선택된 커버 사이즈가 있을 수 있으므로 우선 사용
    _selectedCover =
        widget.initialCoverSize ??
        coverSizes.firstWhere(
          (s) => s.name == '정사각형',
          orElse: () => coverSizes.first,
        );

    // Provider 수정은 build 사이클 이후에 일어나야 하므로 항상 비동기로 처리한다.
    Future.microtask(() async {
      if (_initialized) return;

      if (widget.editAlbum == null && widget.albumId == null) {
        // 생성 플로우(신규 생성): 선택된 커버로 바로 초기화
        final vm = ref.read(albumEditorViewModelProvider.notifier);
        vm.resetForCreate(
          initialCover: _selectedCover,
          targetPages: widget.targetPages ?? AlbumPagePolicy.minInnerPages,
        );
        _applyTemplateCoverIfNeeded();
      } else if (widget.editAlbum != null) {
        // 편집 모드: 에디터에 이미 로드됨 → 커버 VM만 동기화
        final editorSt = ref.read(albumEditorViewModelProvider).asData?.value;
        if (editorSt != null) {
          ref
              .read(coverViewModelProvider.notifier)
              .selectCover(editorSt.selectedCover);
          ref
              .read(coverViewModelProvider.notifier)
              .updateTheme(editorSt.selectedTheme);
        }
      } else if (widget.albumId != null) {
        // 앨범 ID로 앨범을 로드하여 편집 모드로 진입
        try {
          final albumRepository = ref.read(albumRepositoryProvider);
          final album = await albumRepository.fetchAlbum(
            widget.albumId.toString(),
          );
          await ref
              .read(albumEditorViewModelProvider.notifier)
              .prepareAlbumForEdit(album);

          // 커버 VM 동기화
          final editorSt = ref.read(albumEditorViewModelProvider).asData?.value;
          if (editorSt != null) {
            ref
                .read(coverViewModelProvider.notifier)
                .selectCover(editorSt.selectedCover);
            ref
                .read(coverViewModelProvider.notifier)
                .updateTheme(editorSt.selectedTheme);
          }
        } catch (e) {
          // 앨범 로드 실패 시 빈 커버로 시작
          ref
              .read(albumEditorViewModelProvider.notifier)
              .resetForCreate(
                initialCover: _selectedCover,
                targetPages:
                    widget.targetPages ?? AlbumPagePolicy.minInnerPages,
              );
        }
      }

      _initialized = true;
    });
  }

  void _applyTemplateCoverIfNeeded() {
    if (_templateCoverApplied) return;
    final coverLayers = widget.initialTemplateCoverLayers;
    if (coverLayers == null || coverLayers.isEmpty) return;

    final vm = ref.read(albumEditorViewModelProvider.notifier);
    vm.applyTemplateCoverPreview(
      coverLayers,
      templateCanvasSize: widget.initialTemplateCanvasSize,
    );
    _templateCoverApplied = true;

    // 일부 초기화 루틴에서 레이어가 덮어써지는 경우를 대비해 한 프레임 뒤 재적용
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      vm.applyTemplateCoverPreview(
        coverLayers,
        templateCanvasSize: widget.initialTemplateCanvasSize,
      );
    });
  }

  @override
  void dispose() {
    _gridController.dispose();
    super.dispose();
  }

  void _handleModeChange(EditorMode mode, List<LayerModel> layers) {
    if (mode == EditorMode.none) {
      setState(() => _currentMode = mode);
      return;
    }

    if (mode == EditorMode.text) {
      _currentMode = EditorMode.none;
      final vm = ref.read(albumEditorViewModelProvider.notifier);
      final effectiveSize = coverCanvasBaseSize(_selectedCover);
      TextEditorManager(context, vm).openAndCreateNew(
        Size(effectiveSize.width * 0.92, effectiveSize.height * 0.18),
      );
      return;
    }

    setState(() => _currentMode = mode);

    if (kIsWeb) {
      showWebAwareDialog<void>(
        context: context,
        maxWidth: 1000,
        maxHeight: 760,
        builder: (_) => _webModePanel(mode, layers),
      ).then((_) {
        if (mounted) setState(() => _currentMode = EditorMode.none);
      });
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        if (mode == EditorMode.sticker) {
          return const DecoratePanel(mode: DecorateSheetMode.sticker);
        } else if (mode == EditorMode.backgroundColor) {
          return const DecoratePanel(mode: DecorateSheetMode.backgroundColor);
        } else if (mode == EditorMode.layer) {
          return LayerManagerPanel(layers: layers, interaction: _interaction);
        } else if (mode == EditorMode.layout) {
          return const TemplateSelectionPanel(title: '레이아웃');
        } else if (mode == EditorMode.template) {
          return const DesignTemplatePanel();
        }
        return const SizedBox.shrink();
      },
    ).then((_) {
      if (mounted) setState(() => _currentMode = EditorMode.none);
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(albumEditorViewModelProvider);
    final layers = asyncState.value?.layers ?? [];
    final canUndo = asyncState.value?.canUndo ?? false;
    final canRedo = asyncState.value?.canRedo ?? false;

    final debugSelectedId = widget.debugInitialSelectedLayerId;
    if (debugSelectedId != null &&
        layers.any((layer) => layer.id == debugSelectedId) &&
        _interaction.selectedLayerId != debugSelectedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _interaction.setSelectedLayer(debugSelectedId);
      });
    }

    if (!_templateApplyQueued &&
        widget.isFromCreateFlow &&
        layers.isEmpty &&
        widget.initialTemplateCoverLayers != null &&
        widget.initialTemplateCoverLayers!.isNotEmpty) {
      _templateApplyQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(albumEditorViewModelProvider.notifier)
            .applyTemplateCoverPreview(
              widget.initialTemplateCoverLayers!,
              templateCanvasSize: widget.initialTemplateCanvasSize,
            );
        _templateApplyQueued = false;
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCreateFlow = widget.isFromCreateFlow;
        if (kIsWeb && isCreateFlow) {
          return _webCoverWorkspace(layers, canUndo: canUndo, canRedo: canRedo);
        }
        if (isCreateFlow) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final size = _creationDockKey.currentContext?.size;
            if (size != null &&
                (_creationDockHeight - size.height).abs() > .5) {
              setState(() => _creationDockHeight = size.height);
            }
          });
        }
        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: SnapFitColors.backgroundOf(context),
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: _CoverFocusReveal(
                      enabled: isCreateFlow,
                      child: EditCover(
                        key: _coverEditorKey,
                        editAlbum: widget.editAlbum,
                        isFromCreateFlow: widget.isFromCreateFlow,
                        albumTitle: widget.albumTitle,
                        targetPages: widget.targetPages,
                        fallbackTemplateCoverLayers:
                            widget.initialTemplateCoverLayers,
                        fallbackTemplateCanvasSize:
                            widget.initialTemplateCanvasSize,
                        onAlbumCreated: widget.onAlbumCreated,
                        onRegisterCompleteAction:
                            widget.onRegisterCompleteAction,
                        initialCoverSize: _selectedCover,
                        showBottomToolbar: false, // Use shared menu
                        interaction: _interaction,
                        canvasKey: _canvasKey,
                        onSizeChanged: (size) {
                          // Synced size for menu actions
                        },
                      ),
                    ),
                  ),
                  if (isCreateFlow)
                    _CoverAtelierActionBar(
                      key: _creationDockKey,
                      currentMode: _currentMode,
                      onModeChanged: (mode) => _handleModeChange(mode, layers),
                      onAddPhoto: () => _toolbarActionHandler.addPhoto(
                        coverCanvasBaseSize(_selectedCover),
                      ),
                      onStartEditing:
                          widget.onReviewBeforeCreate ??
                          () => _coverEditorKey.currentState?.submitCover(),
                      primaryLabel: widget.onReviewBeforeCreate == null
                          ? '편집 시작'
                          : '전체 확인',
                      canUndo: canUndo,
                      canRedo: canRedo,
                      onUndo: () {
                        ref.read(albumEditorViewModelProvider.notifier).undo();
                        _interaction.clearSelection();
                        setState(() {});
                      },
                      onRedo: () {
                        ref.read(albumEditorViewModelProvider.notifier).redo();
                        _interaction.clearSelection();
                        setState(() {});
                      },
                    )
                  else
                    EditorBottomMenu(
                      currentMode: _currentMode,
                      isCover: true,
                      showCoverMenuItem: false,
                      onModeChanged: (mode) => _handleModeChange(mode, layers),
                      onAddPhoto: () => _toolbarActionHandler.addPhoto(
                        coverCanvasBaseSize(_selectedCover),
                      ),
                      onCover: () => _toolbarActionHandler.openCoverTheme(),
                    ),
                ],
              ),

              // 커버 레이어 선택 시 하단 액션 패널 (스텝2에서도 스냅핏 만들기 화면과 동일하게)
              if (_interaction.selectedLayerId != null)
                Positioned(
                  bottom: isCreateFlow && _creationDockHeight > 0
                      ? _creationDockHeight + 8
                      : coverLayerActionPanelBottom(
                          isCreateFlow: isCreateFlow,
                          scaleBaseOffset: (value) => value.h,
                          safeAreaBottom: MediaQuery.paddingOf(context).bottom,
                        ),
                  left: 20,
                  right: 20,
                  child: LayerActionPanel(
                    layers: layers,
                    interaction: _interaction,
                    textEditor: TextEditorManager(
                      context,
                      ref.read(albumEditorViewModelProvider.notifier),
                    ),
                    onRefresh: () => setState(() {}),
                    onOpenGallery: (layer) => _openGalleryForSelected(layer),
                    onOpenPhotoCrop: (layer) => editPhotoCrop(
                      context,
                      ref,
                      layer,
                      layerBuilder: LayerBuilder(
                        _interaction,
                        () => coverCanvasBaseSize(_selectedCover),
                      ),
                    ),
                    onOpenDecorateSheet: (layer) =>
                        _openDecorateSheetForLayer(layer),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _webModePanel(EditorMode mode, List<LayerModel> layers) {
    return switch (mode) {
      EditorMode.sticker => const DecoratePanel(mode: DecorateSheetMode.sticker),
      EditorMode.backgroundColor => const DecoratePanel(mode: DecorateSheetMode.backgroundColor),
      EditorMode.layer => LayerManagerPanel(layers: layers, interaction: _interaction),
      EditorMode.layout => const TemplateSelectionPanel(title: '레이아웃'),
      EditorMode.template => const DesignTemplatePanel(),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _webCoverWorkspace(List<LayerModel> layers, {required bool canUndo, required bool canRedo}) {
    Widget tool(String label, IconData icon, EditorMode mode) => TextButton.icon(
      onPressed: () => _handleModeChange(mode, layers),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
    final canvas = ColoredBox(
      color: WebPalette.of(context).canvas,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: EditCover(
          key: _coverEditorKey,
          editAlbum: widget.editAlbum,
          isFromCreateFlow: widget.isFromCreateFlow,
          albumTitle: widget.albumTitle,
          targetPages: widget.targetPages,
          fallbackTemplateCoverLayers: widget.initialTemplateCoverLayers,
          fallbackTemplateCanvasSize: widget.initialTemplateCanvasSize,
          onAlbumCreated: widget.onAlbumCreated,
          onRegisterCompleteAction: widget.onRegisterCompleteAction,
          initialCoverSize: _selectedCover,
          showAppBar: false,
          showBottomToolbar: false,
          flatPresentation: true,
          interaction: _interaction,
          canvasKey: _canvasKey,
        ),
      ),
    );
    final inspector = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('표지 구성', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: WebPalette.of(context).ink)),
        const SizedBox(height: 12),
        Text('${_selectedCover.displayName} · ${_selectedCover.coverType.label}', style: TextStyle(fontSize: 13, height: 1.6, color: WebPalette.of(context).muted)),
        const SizedBox(height: 24),
        Divider(color: WebPalette.of(context).line),
        const SizedBox(height: 20),
        if (_interaction.selectedLayerId == null)
          Text('사진이나 글을 클릭하면 해당 요소의 편집 도구를 사용할 수 있습니다. 배치와 여백을 확인한 뒤 상단의 전체 확인을 눌러주세요.', style: TextStyle(fontSize: 13, height: 1.8, color: WebPalette.of(context).muted))
        else ...[
          const Text('선택한 요소', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          LayerActionPanel(
            layers: layers,
            interaction: _interaction,
            textEditor: TextEditorManager(context, ref.read(albumEditorViewModelProvider.notifier)),
            onRefresh: () => setState(() {}),
            onOpenGallery: (layer) => _openGalleryForSelected(layer),
            onOpenPhotoCrop: (layer) => editPhotoCrop(context, ref, layer, layerBuilder: LayerBuilder(_interaction, () => coverCanvasBaseSize(_selectedCover))),
            onOpenDecorateSheet: _openDecorateSheetForLayer,
          ),
        ],
      ]),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: WebPalette.of(context).surface, border: Border(bottom: BorderSide(color: WebPalette.of(context).line))),
        child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, runSpacing: 4, children: [
          TextButton.icon(onPressed: () => _toolbarActionHandler.addPhoto(coverCanvasBaseSize(_selectedCover)), icon: const Icon(Icons.add_photo_alternate_outlined, size: 18), label: const Text('사진 추가')),
          tool('글', Icons.text_fields, EditorMode.text),
          TextButton.icon(onPressed: () => _toolbarActionHandler.openCoverTheme(), icon: const Icon(Icons.style_outlined, size: 18), label: const Text('표지 테마')),
          tool('레이아웃', Icons.dashboard_customize_outlined, EditorMode.layout),
          tool('템플릿', Icons.auto_awesome_mosaic_outlined, EditorMode.template),
          tool('꾸미기', Icons.emoji_emotions_outlined, EditorMode.sticker),
          tool('배경', Icons.palette_outlined, EditorMode.backgroundColor),
          tool('레이어', Icons.layers_outlined, EditorMode.layer),
          IconButton(tooltip: '실행 취소', onPressed: canUndo ? () {
            ref.read(albumEditorViewModelProvider.notifier).undo();
            _interaction.clearSelection();
            setState(() {});
          } : null, icon: const Icon(Icons.undo, size: 19)),
          IconButton(tooltip: '다시 실행', onPressed: canRedo ? () {
            ref.read(albumEditorViewModelProvider.notifier).redo();
            _interaction.clearSelection();
            setState(() {});
          } : null, icon: const Icon(Icons.redo, size: 19)),
        ]),
      ),
      Expanded(child: LayoutBuilder(builder: (context, bounds) {
        if (bounds.maxWidth < 900) return Column(children: [
          Expanded(child: canvas),
          if (_interaction.selectedLayerId != null) SizedBox(height: 150, child: inspector),
        ]);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: canvas),
          VerticalDivider(width: 1, color: WebPalette.of(context).line),
          SizedBox(width: 280, child: inspector),
        ]);
      })),
    ]);
  }

  Future<void> _openGalleryForSelected(LayerModel layer) async {
    final changed = await replacePhotoInSlot(
      context,
      ref,
      layer,
      layerBuilder: LayerBuilder(
        _interaction,
        () => coverCanvasBaseSize(_selectedCover),
      ),
    );
    if (changed && mounted) setState(() {});
  }

  void _openDecorateSheetForLayer(LayerModel layer) {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    if (layer.type == LayerType.image) {
      editPhotoFrame(
        context,
        ref,
        layer,
        layerBuilder: LayerBuilder(
          _interaction,
          () => coverCanvasBaseSize(_selectedCover),
        ),
      ).then((changed) {
        if (changed && mounted) setState(() {});
      });
    } else {
      final currentKey =
          vm.findLayerById(layer.id)?.textBackground ??
          layer.textBackground ??
          '';
      TextStylePickerSheet.show(context, currentKey: currentKey).then((key) {
        if (key != null && mounted) {
          vm.updateTextStyle(layer.id, key);
          setState(() {});
        }
      });
    }
  }
}

class _CoverFocusReveal extends StatefulWidget {
  final bool enabled;
  final Widget child;

  const _CoverFocusReveal({required this.enabled, required this.child});

  @override
  State<_CoverFocusReveal> createState() => _CoverFocusRevealState();
}

class _CoverFocusRevealState extends State<_CoverFocusReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
      value: widget.enabled ? 0 : 1,
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.78, curve: Curves.easeOutCubic),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(curve);
    _scale = Tween<double>(begin: 0.965, end: 1).animate(curve);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.035),
      end: Offset.zero,
    ).animate(curve);
    if (widget.enabled) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _CoverFocusReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      _controller.forward(from: 0);
    } else if (!widget.enabled && oldWidget.enabled) {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return SlideTransition(
      key: const Key('coverFocusRevealSlide'),
      position: _slide,
      child: FadeTransition(
        key: const Key('coverFocusRevealFade'),
        opacity: _fade,
        child: ScaleTransition(
          key: const Key('coverFocusRevealScale'),
          scale: _scale,
          child: widget.child,
        ),
      ),
    );
  }
}

class _CoverAtelierActionBar extends StatefulWidget {
  final EditorMode currentMode;
  final ValueChanged<EditorMode> onModeChanged;
  final VoidCallback onAddPhoto;
  final VoidCallback onStartEditing;
  final String primaryLabel;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;

  const _CoverAtelierActionBar({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    required this.onAddPhoto,
    required this.onStartEditing,
    this.primaryLabel = '편집 시작',
    this.canUndo = false,
    this.canRedo = false,
    this.onUndo,
    this.onRedo,
  });

  @override
  State<_CoverAtelierActionBar> createState() => _CoverAtelierActionBarState();
}

class _CoverAtelierActionBarState extends State<_CoverAtelierActionBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    final curve = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(curve);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(curve);
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menu = EditorBottomMenu(
      currentMode: widget.currentMode,
      isCover: true,
      showCoverMenuItem: false,
      useCreationStyle: true,
      onModeChanged: widget.onModeChanged,
      onAddPhoto: widget.onAddPhoto,
    );
    final history = [
      IconButton(
        tooltip: '실행 취소',
        onPressed: widget.canUndo ? widget.onUndo : null,
        icon: const Icon(Icons.undo_rounded, size: 20),
      ),
      IconButton(
        tooltip: '다시 실행',
        onPressed: widget.canRedo ? widget.onRedo : null,
        icon: const Icon(Icons.redo_rounded, size: 20),
      ),
    ];
    final primary = _CoverAtelierPressScale(
      scaleKey: const Key('coverAtelierPrimaryPressScale'),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: widget.onStartEditing,
          style: ExperienceFormStyle.primary(context),
          child: Text(widget.primaryLabel),
        ),
      ),
    );
    return SlideTransition(
      key: const Key('coverAtelierEntrySlide'),
      position: _slide,
      child: FadeTransition(
        key: const Key('coverAtelierEntryFade'),
        opacity: _fade,
        child: SafeArea(
          top: false,
          child: Container(
            key: const Key('coverAtelierActionBar'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: BoxDecoration(
              color: SnapFitColors.backgroundOf(context),
              border: Border(
                top: BorderSide(color: ExperienceFormStyle.line(context)),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth >= 640
                  ? Row(
                      children: [
                        ...history,
                        const SizedBox(width: 8),
                        Expanded(child: menu),
                        const SizedBox(width: 16),
                        SizedBox(width: 148, child: primary),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '표지 도구',
                                style: ExperienceFormStyle.text(
                                  context,
                                  12,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ...history,
                          ],
                        ),
                        const SizedBox(height: 4),
                        menu,
                        const SizedBox(height: 12),
                        primary,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverAtelierPressScale extends StatefulWidget {
  final Widget child;
  final Key? scaleKey;

  const _CoverAtelierPressScale({required this.child, this.scaleKey});

  @override
  State<_CoverAtelierPressScale> createState() =>
      _CoverAtelierPressScaleState();
}

class _CoverAtelierPressScaleState extends State<_CoverAtelierPressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        key: widget.scaleKey,
        scale: _pressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
