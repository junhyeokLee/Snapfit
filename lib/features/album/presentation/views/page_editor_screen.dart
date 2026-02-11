import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/entities/layer.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../../../shared/widgets/album_bottom_sheet.dart';
import '../../../../shared/widgets/image_frame_style_picker.dart';
import '../controllers/text_editor_manager.dart';
import '../controllers/layer_interaction_manager.dart';
import '../controllers/layer_builder.dart';
import '../widgets/editor/edit_toolbar.dart';
import '../widgets/editor/page_template_picker.dart';
import '../widgets/editor/page_editor_style_panel.dart';
import '../widgets/editor/page_editor_canvas.dart';
import '../viewmodels/album_editor_view_model.dart';

class PageEditorScreen extends ConsumerStatefulWidget {
  /// 편집할 내지 페이지 인덱스 (1 이상). null이면 현재 선택된 페이지 유지.
  /// 0(커버)은 페이지 편집에서 사용하지 않음.
  final int? initialPageIndex;

  const PageEditorScreen({super.key, this.initialPageIndex});

  @override
  ConsumerState<PageEditorScreen> createState() => _PageEditorScreenState();
}

class _PageEditorScreenState extends ConsumerState<PageEditorScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  Size _canvasSize = Size.zero;
  static const double _panelHeight = 56;

  late final LayerInteractionManager _interaction;
  late final LayerBuilder _layerBuilder;

  @override
  void initState() {
    super.initState();
    ScreenLogger.enter(
      'PageEditorScreen',
      widget.initialPageIndex != null
          ? '내지 페이지 편집 (페이지 ${widget.initialPageIndex})'
          : '내지 페이지 편집 · 템플릿/레이어/스타일',
    );
    _interaction = LayerInteractionManager(
      ref: ref,
      coverKey: _canvasKey,
      setState: setState,
      getCoverSize: () => _canvasSize,
      onEditText: (layer) {
        final vm = ref.read(albumEditorViewModelProvider.notifier);
        TextEditorManager(context, vm).openForExisting(layer);
      },
      onTapPlaceholder: (layer) => _openGalleryForPlaceholder(layer),
    );
    _layerBuilder = LayerBuilder(_interaction, () => _canvasSize);

    // 내지 페이지만 편집: initialPageIndex가 있으면 즉시 해당 페이지로 이동 (스타일이 적용된 레이어 표시)
    final idx = widget.initialPageIndex;
    if (idx != null && idx >= 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final vm = ref.read(albumEditorViewModelProvider.notifier);
        final maxIdx = vm.pages.length - 1;
        final pageIndex = idx.clamp(1, maxIdx > 0 ? maxIdx : 1);
        vm.goToPage(pageIndex);
        setState(() {});
      });
    }
  }

  Future<void> _openGalleryForPlaceholder(LayerModel layer) async {
    if (!mounted) return;
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    await vm.ensureGalleryLoaded();
    if (!mounted) return;
    final asset = await showPhotoSelectionSheet(context, ref);
    if (asset == null || !mounted) return;
    await vm.updateSlotImage(layer.id, asset);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(albumEditorViewModelProvider);
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final state = asyncState.value;

    final canvasW = 300.w;
    final canvasH = 400.h;
    final canvasSize = Size(canvasW, canvasH);
    // initialPageIndex가 있으면 해당 페이지 레이어 직접 사용 (로드 후 스타일이 적용된 레이어 표시)
    final pageIndex = widget.initialPageIndex ?? vm.currentPageIndex;
    final List<LayerModel> layers = (widget.initialPageIndex != null &&
            widget.initialPageIndex! >= 0 &&
            widget.initialPageIndex! < vm.pages.length)
        ? vm.pages[widget.initialPageIndex!].layers
        : (state?.layers ?? []);

    final selectedId = _interaction.selectedLayerId;
    LayerModel? selectedLayer;
    if (selectedId != null) {
      try {
        selectedLayer = layers.firstWhere((l) => l.id == selectedId);
      } catch (_) {}
    }
    final panelVisible = selectedLayer != null;

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: SnapFitColors.textPrimaryOf(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "페이지 편집",
          style: TextStyle(color: SnapFitColors.textPrimaryOf(context), fontSize: 16.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "저장",
              style: TextStyle(
                color: SnapFitColors.textPrimaryOf(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Center(
                  child: GestureDetector(
                    onTap: () {
                      if (_interaction.selectedLayerId != null) _interaction.clearSelection();
                      setState(() {});
                    },
                    behavior: HitTestBehavior.translucent,
                    child: PageEditorCanvas(
                      canvasKey: _canvasKey,
                      canvasW: canvasW,
                      canvasH: canvasH,
                      layers: layers,
                      interaction: _interaction,
                      layerBuilder: _layerBuilder,
                      onCanvasSizeChanged: (size) {
                        _canvasSize = size;
                      },
                    ),
                  ),
                ),
                if (panelVisible && selectedLayer != null)
                  Positioned(
                    left: 24.w,
                    right: 24.w,
                    bottom: 100.h,
                    child: PageEditorStylePanel(
                      vm: vm,
                      selected: selectedLayer,
                      layers: layers,
                      onDelete: () {
                        _interaction.deleteSelected();
                        setState(() {});
                      },
                      onPickPhotoForSlot: (layer) => _pickPhotoForSlot(context, ref, vm, layer),
                      onStateChanged: () {
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
              ],
            ),
          ),
          EditToolbar(
            vm: vm,
            selected: selectedLayer,
            coverLabel: '템플릿',
            onAddText: () => _openAddText(context, ref, vm, canvasSize),
            onAddPhoto: () {
              // TODO: 갤러리 열기 후 사진 추가
            },
            onOpenCoverSelector: () {
              PageTemplatePicker.show(context, onSelect: (template) {
                vm.applyTemplateToCurrentPage(template, canvasSize);
                _interaction.clearSelection();
                setState(() {});
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openAddText(
    BuildContext context,
    WidgetRef ref,
    AlbumEditorViewModel vm,
    Size canvasSize,
  ) async {
    final textEditor = TextEditorManager(context, vm);
    await textEditor.openAndCreateNew(canvasSize);
    if (mounted) setState(() {});
  }


  Future<void> _pickPhotoForSlot(
    BuildContext context,
    WidgetRef ref,
    AlbumEditorViewModel vm,
    LayerModel layer,
  ) async {
    await vm.ensureGalleryLoaded();
    if (!context.mounted) return;
    final asset = await showPhotoSelectionSheet(context, ref);
    if (asset == null || !context.mounted) return;
    await vm.updateSlotImage(layer.id, asset);
    if (mounted) setState(() {});
  }
}
