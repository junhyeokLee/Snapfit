import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/edit_cover.dart';

import '../../../../core/constants/cover_size.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../../../shared/widgets/snapfit_gradient_background.dart';
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
import '../viewmodels/gallery_notifier.dart';
import '../../../../shared/widgets/album_bottom_sheet.dart';
import '../../../../shared/widgets/image_frame_style_picker.dart';

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

  /// 앨범 생성 완료 콜백 (플로우에서 사용)
  final Function(int albumId)? onAlbumCreated;

  /// 플로우 AppBar의 '완료' 버튼이 눌렸을 때 호출할 액션 등록 (플로우에서만 사용)
  final void Function(VoidCallback)? onRegisterCompleteAction;

  const AddCoverScreen({
    super.key,
    this.editAlbum,
    this.albumId,
    this.isFromCreateFlow = false,
    this.initialCoverSize,
    this.albumTitle,
    this.targetPages,
    this.initialTemplateCoverLayers,
    this.onAlbumCreated,
    this.onRegisterCompleteAction,
  });

  @override
  ConsumerState<AddCoverScreen> createState() => _AddCoverScreenState();
}

class _AddCoverScreenState extends ConsumerState<AddCoverScreen> {
  final GlobalKey<EditCoverState> _coverEditorKey = GlobalKey<EditCoverState>();
  final GlobalKey _canvasKey = GlobalKey();
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
          targetPages: widget.targetPages ?? 1,
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
                targetPages: widget.targetPages ?? 1,
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
    vm.applyTemplateCoverPreview(coverLayers);
    _templateCoverApplied = true;

    // 일부 초기화 루틴에서 레이어가 덮어써지는 경우를 대비해 한 프레임 뒤 재적용
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      vm.applyTemplateCoverPreview(coverLayers);
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        if (mode == EditorMode.decorate) {
          return DecoratePanel(onClose: () => Navigator.pop(ctx));
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
            .applyTemplateCoverPreview(widget.initialTemplateCoverLayers!);
        _templateApplyQueued = false;
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: SnapFitColors.backgroundOf(context), // Match theme
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: EditCover(
                      key: _coverEditorKey,
                      editAlbum: widget.editAlbum,
                      isFromCreateFlow: widget.isFromCreateFlow,
                      albumTitle: widget.albumTitle,
                      targetPages: widget.targetPages,
                      fallbackTemplateCoverLayers:
                          widget.initialTemplateCoverLayers,
                      onAlbumCreated: widget.onAlbumCreated,
                      onRegisterCompleteAction: widget.onRegisterCompleteAction,
                      initialCoverSize: _selectedCover,
                      showBottomToolbar: false, // Use shared menu
                      interaction: _interaction,
                      canvasKey: _canvasKey,
                      onSizeChanged: (size) {
                        // Synced size for menu actions
                      },
                    ),
                  ),
                  // Bottom Menu
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
                  bottom: 100, // Bottom Menu 위에 겹치도록
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

  Future<void> _openGalleryForSelected(LayerModel layer) async {
    final gallery = ref.read(galleryProvider);
    if (gallery.albums.isEmpty) {
      await ref.read(galleryProvider.notifier).fetchInitialData();
    }

    final asset = await showPhotoSelectionSheet(context, ref);
    if (asset != null) {
      ref
          .read(albumEditorViewModelProvider.notifier)
          .updateLayer(
            layer.copyWith(
              asset: asset,
              imageUrl: null,
              originalUrl: null,
              previewUrl: null,
            ),
          );
      if (mounted) setState(() {});
    }
  }

  void _openDecorateSheetForLayer(LayerModel layer) {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    if (layer.type == LayerType.image) {
      final currentKey =
          vm.findLayerById(layer.id)?.imageBackground ??
          layer.imageBackground ??
          '';
      ImageFrameStylePicker.show(context, currentKey: currentKey).then((key) {
        if (key != null && mounted) {
          vm.updateImageFrame(layer.id, key);
          setState(() {});
        }
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
