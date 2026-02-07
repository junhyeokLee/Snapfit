import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/cover_size.dart';
import '../../../../shared/widgets/album_bottom_sheet.dart';
import '../../domain/entities/layer.dart';
import '../controllers/layer_builder.dart';
import '../controllers/layer_interaction_manager.dart';
import '../controllers/text_editor_manager.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../viewmodels/home_view_model.dart';
import '../widgets/editor/edit_toolbar.dart';
import '../widgets/editor/layer_style_panel.dart';
import '../widgets/editor/page_editor_canvas.dart';
import '../widgets/editor/page_template_picker.dart';

class PageEditorScreen extends ConsumerStatefulWidget {
  /// 편집할 내지 페이지 인덱스 (1 이상). null이면 현재 선택된 페이지 유지.
  /// 0(커버)은 페이지 편집에서 사용하지 않음.
  final int? initialPageIndex;
  const PageEditorScreen({
    super.key,
    this.initialPageIndex,
  });

  @override
  ConsumerState<PageEditorScreen> createState() => _PageEditorScreenState();
}

class _PageEditorScreenState extends ConsumerState<PageEditorScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  Size _canvasSize = Size.zero;
  bool _isSaving = false;

  late final LayerInteractionManager _interaction;
  late final LayerBuilder _layerBuilder;

  @override
  void initState() {
    super.initState();
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

    // 내지 페이지만 편집: initialPageIndex가 있으면 해당 페이지로 이동 (커버 0 제외)
    final idx = widget.initialPageIndex;
    if (idx != null && idx >= 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final vm = ref.read(albumEditorViewModelProvider.notifier);
        final maxIdx = vm.pages.length - 1;
        vm.goToPage(idx.clamp(1, maxIdx > 0 ? maxIdx : 1));
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

    final baseCanvasSize = state != null ? coverCanvasBaseSize(state.selectedCover) : const Size(300, 400);
    final pageRatio = baseCanvasSize.width / baseCanvasSize.height;
    final layers = state?.layers ?? [];

    final selectedId = _interaction.selectedLayerId;
    LayerModel? selectedLayer;
    if (selectedId != null) {
      try {
        selectedLayer = layers.firstWhere((l) => l.id == selectedId);
      } catch (_) {}
    }
    final panelVisible = selectedLayer != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, false);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF7d7a97),
        appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: Text("페이지 편집", style: TextStyle(color: Colors.white, fontSize: 16.sp)),
        actions: [
          TextButton(
            onPressed: _isSaving
                ? null
                : () async {
                    setState(() => _isSaving = true);
                    try {
                      await vm.saveFullAlbum();
                      if (!mounted) return;
                      await ref.read(homeViewModelProvider.notifier).refresh();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("앨범이 저장되었습니다.")),
                      );
                      Navigator.pop(context, true);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("저장 실패: ${e.toString().replaceFirst('Exception: ', '')}")),
                      );
                    } finally {
                      if (mounted) setState(() => _isSaving = false);
                    }
                  },
            child: Text(
              _isSaving ? "저장 중..." : "저장",
              style: TextStyle(
                color: _isSaving ? Colors.white54 : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (state == null) return const SizedBox();
                _canvasSize = baseCanvasSize;
                final pageSize = calculatePagePreviewSize(
                  screen: MediaQuery.sizeOf(context),
                  constraints: constraints,
                  pageRatio: pageRatio,
                  maxHeightFactor: kPageEditorPreviewMaxHeightFactor,
                );
                return Stack(
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
                          targetW: pageSize.width,
                          targetH: pageSize.height,
                          baseCanvasSize: baseCanvasSize,
                          layers: layers,
                          interaction: _interaction,
                          layerBuilder: _layerBuilder,
                        ),
                      ),
                    ),
                    if (panelVisible && selectedLayer != null)
                      Positioned(
                        left: 24.w,
                        right: 24.w,
                        bottom: 100.h,
                        child: LayerStylePanel(
                          selected: selectedLayer,
                          vm: vm,
                          interaction: _interaction,
                          onChanged: () => setState(() {}),
                          onPickPhotoForSlot: (LayerModel layer) => _pickPhotoForSlot(context, ref, vm, layer),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          EditToolbar(
            vm: vm,
            selected: selectedLayer,
            coverLabel: '템플릿',
            onAddText: () => _openAddText(context, ref, vm, baseCanvasSize),
            onAddPhoto: () {
              // TODO: 갤러리 열기 후 사진 추가
            },
            onOpenCoverSelector: () {
              PageTemplatePicker.show(context, onSelect: (template) {
                vm.applyTemplateToCurrentPage(template, baseCanvasSize);
                _interaction.clearSelection();
                setState(() {});
              });
            },
          ),
        ],
      ),
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
