import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/entities/layer.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/album_bottom_sheet.dart';
import '../../../../shared/widgets/image_frame_style_picker.dart';
import '../controllers/text_editor_manager.dart';
import '../controllers/layer_interaction_manager.dart';
import '../controllers/layer_builder.dart';
import '../widgets/editor/edit_toolbar.dart';
import '../widgets/editor/page_template_picker.dart';
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
                    child: _buildLargePageCanvas(context, ref, state, vm, canvasW, canvasH, layers),
                  ),
                ),
                if (panelVisible && selectedLayer != null)
                  Positioned(
                    left: 24.w,
                    right: 24.w,
                    bottom: 100.h,
                    child: _buildStylePanel(context, ref, vm, selectedLayer, layers),
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

  Widget _buildStylePanel(
    BuildContext context,
    WidgetRef ref,
    AlbumEditorViewModel vm,
    LayerModel selected,
    List<LayerModel> layers,
  ) {
    final isText = selected.type == LayerType.text;
    return Material(
      color: SnapFitColors.surfaceOf(context).withOpacity(0.92),
      borderRadius: BorderRadius.circular(16.r),
      elevation: 4,
      child: Container(
        height: _panelHeight,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (isText) ...[
              _textStyleButton(context, ref, vm, selected, "라벨", "tag"),
              _textStyleButton(context, ref, vm, selected, "말풍선", "bubble"),
              _textStyleButton(context, ref, vm, selected, "노트", "note"),
              _textStyleButton(context, ref, vm, selected, "캘리", "calligraphy"),
              _textStyleButton(context, ref, vm, selected, "스티커", "sticker"),
              _textStyleButton(context, ref, vm, selected, "테이프", "tape"),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: () async {
                  final textEditor = TextEditorManager(context, vm);
                  await textEditor.openForExisting(selected);
                  if (mounted) setState(() {});
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text("편집", style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
            if (!isText) ...[
              if (selected.asset != null || (selected.previewUrl ?? selected.imageUrl ?? selected.originalUrl) != null)
                GestureDetector(
                  onTap: () async {
                    final currentKey = selected.imageBackground ?? '';
                    final result = await ImageFrameStylePicker.show(context, currentKey: currentKey);
                    if (result != null && mounted) {
                      vm.updateImageFrame(selected.id, result);
                      setState(() {});
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    margin: EdgeInsets.only(right: 8.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          SnapFitColors.overlayMediumOf(context),
                          SnapFitColors.overlayLightOf(context),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.photo_size_select_large,
                          size: 20.sp,
                          color: SnapFitColors.textPrimaryOf(context),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          "프레임",
                          style: TextStyle(
                            color: SnapFitColors.textPrimaryOf(context),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: () async {
                    await _pickPhotoForSlot(context, ref, vm, selected);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    margin: EdgeInsets.only(right: 8.w),
                    decoration: BoxDecoration(
                      color: SnapFitColors.overlayMediumOf(context),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_a_photo,
                          size: 20.sp,
                          color: SnapFitColors.textPrimaryOf(context),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          "사진 추가",
                          style: TextStyle(
                            color: SnapFitColors.textPrimaryOf(context),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            GestureDetector(
              onTap: () {
                _interaction.deleteSelected();
                setState(() {});
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.delete, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textStyleButton(
    BuildContext context,
    WidgetRef ref,
    AlbumEditorViewModel vm,
    LayerModel selected,
    String label,
    String styleKey,
  ) {
    final isSelected = (selected.textBackground ?? '') == styleKey;
    return Padding(
      padding: EdgeInsets.only(right: 6.w),
      child: GestureDetector(
        onTap: () {
          vm.updateTextStyle(selected.id, styleKey);
          setState(() {});
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: isSelected
                ? SnapFitColors.overlayStrongOf(context)
                : SnapFitColors.overlayLightOf(context),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: SnapFitColors.textPrimaryOf(context),
              fontSize: 11.sp,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLargePageCanvas(
    BuildContext context,
    WidgetRef ref,
    AlbumEditorState? state,
    AlbumEditorViewModel vm,
    double canvasW,
    double canvasH,
    List<LayerModel> layers,
  ) {
    return Container(
      key: _canvasKey,
      width: canvasW,
      height: canvasH,
      decoration: BoxDecoration(
        color: SnapFitColors.pureWhite,
        borderRadius: BorderRadius.circular(8.r),
        boxShadow: [
          BoxShadow(
            color: SnapFitColors.isDark(context)
                ? SnapFitColors.accentLight.withOpacity(0.2)
                : Colors.black45,
            blurRadius: 20,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 0 && constraints.maxHeight > 0) {
              _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
            }
            if (layers.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.dashboard_customize_outlined,
                      size: 48.sp,
                      color: SnapFitColors.deepCharcoal.withOpacity(0.35),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      "템플릿을 선택하거나\n사진/텍스트를 추가하세요",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: SnapFitColors.deepCharcoal.withOpacity(0.6),
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
              );
            }
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Container(color: SnapFitColors.pureWhite),
                ..._interaction.sortByZ(layers).map((layer) {
                  if (layer.type == LayerType.image) {
                    return _layerBuilder.buildImage(layer);
                  }
                  return _layerBuilder.buildText(layer);
                }),
              ],
            );
          },
        ),
      ),
    );
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
