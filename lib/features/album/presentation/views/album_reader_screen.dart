import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/cover_size.dart';
import '../../../../core/constants/cover_theme.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../domain/entities/album_page.dart';
import '../../domain/entities/layer.dart';
import '../controllers/cover_size_controller.dart';
import '../controllers/layer_builder.dart';
import '../controllers/layer_interaction_manager.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../widgets/reader/album_reader_empty_state.dart';
import '../widgets/reader/album_reader_footer.dart';
import '../widgets/reader/album_reader_page_card.dart';
import '../widgets/reader/album_reader_peek_card.dart';
import '../widgets/reader/album_reader_thumbnail_strip.dart';
import '../widgets/reader/layer_order_list.dart';
import '../controllers/text_editor_manager.dart';
import '../widgets/reader/slow_page_physics.dart';
import '../widgets/reader/album_reader_cover_editor.dart';
import '../widgets/reader/album_reader_inner_page_view.dart';
import '../widgets/reader/album_reader_toolbar.dart';

class AlbumReaderScreen extends ConsumerStatefulWidget {
  const AlbumReaderScreen({super.key});

  @override
  ConsumerState<AlbumReaderScreen> createState() => _AlbumReaderScreenState();
}

class _AlbumReaderScreenState extends ConsumerState<AlbumReaderScreen> {
  late final PageController _pageController;
  late final GlobalKey _coverKey;
  late final LayerInteractionManager _interaction;
  late final LayerBuilder _layerBuilder;
  Size _baseCanvasSize = const Size(300, 400);
  Size _coverSize = Size.zero;
  bool _hasLoadedLayers = false;
  bool _showLayerOrderList = false;
  final CoverSizeController _layout = CoverSizeController();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _coverKey = GlobalKey();
    _interaction = LayerInteractionManager(
      ref: ref,
      coverKey: _coverKey,
      setState: setState,
      getCoverSize: () => _coverSize,
      onEditText: (layer) {
        final vm = ref.read(albumEditorViewModelProvider.notifier);
        TextEditorManager(context, vm).openForExisting(layer);
      },
    );
    _layerBuilder = LayerBuilder(_interaction, () => _baseCanvasSize);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(albumEditorViewModelProvider);
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final state = asyncState.value;

    if (state == null) {
      return Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        body: Center(
          child: CircularProgressIndicator(
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
      );
    }

    // coverCanvasSize는 CoverLayout의 onCoverSizeChanged에서 실제 렌더링 크기로 설정됨
    final coverCanvas = state.coverCanvasSize;
    if (coverCanvas != null && coverCanvas != Size.zero) {
      _baseCanvasSize = coverCanvas;
    }

    // 커버 페이지가 항상 존재하도록 보장
    vm.ensureCoverPage();
    
    final allPages = vm.pages;
    // 커버 페이지 찾기
    AlbumPage? coverPage;
    if (allPages.isNotEmpty) {
      try {
        coverPage = allPages.firstWhere((p) => p.isCover);
      } catch (_) {
        coverPage = allPages.first;
      }
    }
    final pages = allPages.where((p) => !p.isCover).toList(growable: false);
    final hasInnerPages = pages.isNotEmpty;
    
    // 현재 편집 중인 페이지 결정 (내지가 있으면 첫 번째 내지, 없으면 커버)
    final currentPage = hasInnerPages && _pageController.hasClients
        ? pages[_pageController.page?.round().clamp(0, pages.length - 1) ?? 0]
        : coverPage;
    
    final layers = currentPage?.layers ?? [];
    final selectedLayerId = _interaction.selectedLayerId;
    LayerModel? selectedLayer;
    if (selectedLayerId != null) {
      try {
        selectedLayer = layers.firstWhere((l) => l.id == selectedLayerId);
      } catch (_) {}
    }
    
    final selectedCover = state.selectedCover;
    final coverTheme = state.selectedTheme;
    final aspect = selectedCover.ratio;
    final coverSide = _layout.getCoverSidePadding(selectedCover);

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: SnapFitColors.textPrimaryOf(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "스냅핏 레이어 편집",
          style: TextStyle(
            color: SnapFitColors.textPrimaryOf(context),
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          // 프로필 아이콘들 (임시)
          Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28.w,
                  height: 28.w,
                  decoration: BoxDecoration(
                    color: SnapFitColors.overlayLightOf(context),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 4.w),
                Container(
                  width: 28.w,
                  height: 28.w,
                  decoration: BoxDecoration(
                    color: SnapFitColors.overlayLightOf(context),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 4.w),
                Container(
                  width: 28.w,
                  height: 28.w,
                  decoration: BoxDecoration(
                    color: SnapFitColors.accent.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '+2',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: SnapFitColors.accent,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              // 저장 후 닫기
              Navigator.pop(context, true);
            },
            child: Text(
              "완료",
              style: TextStyle(
                color: SnapFitColors.textPrimaryOf(context),
                fontWeight: FontWeight.w700,
                fontSize: 16.sp,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 중앙 캔버스 영역
          Expanded(
            child: hasInnerPages
                ? AlbumReaderInnerPageView(
                    pages: pages,
                    selectedCover: selectedCover,
                    coverTheme: coverTheme,
                    pageController: _pageController,
                    interaction: _interaction,
                    layerBuilder: _layerBuilder,
                    canvasKey: _coverKey,
                    onCanvasSizeChanged: (size) {
                      _baseCanvasSize = size;
                    },
                    onPageChanged: (index) {
                      final vm = ref.read(albumEditorViewModelProvider.notifier);
                      vm.goToPage(index + 1); // 내지 페이지는 1부터 시작
                    },
                    onStateChanged: () {
                      if (mounted) setState(() {});
                    },
                  )
                : (coverPage != null
                    ? AlbumReaderCoverEditor(
                        coverPage: coverPage,
                        selectedCover: selectedCover,
                        coverTheme: coverTheme,
                        coverSide: coverSide,
                        interaction: _interaction,
                        layerBuilder: _layerBuilder,
                        coverKey: _coverKey,
                        onCoverSizeChanged: (size) {
                          _coverSize = size;
                        },
                        onBaseCanvasSizeChanged: (size) {
                          _baseCanvasSize = size;
                        },
                      )
                    : (asyncState.isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: SnapFitColors.textSecondaryOf(context),
                            ),
                          )
                        : const AlbumReaderEmptyState(
                            isLoading: false,
                            baseCanvasSize: Size(300, 400),
                          ))),
          ),
          // 편집 툴바
          AlbumReaderToolbar(
            vm: vm,
            selectedLayer: selectedLayer,
            layers: layers,
            interaction: _interaction,
            baseCanvasSize: _baseCanvasSize,
            showLayerOrderList: _showLayerOrderList,
            onLayerOrderListToggled: (show) {
              setState(() {
                _showLayerOrderList = show;
              });
            },
            onStateChanged: () {
              if (mounted) setState(() {});
            },
          ),
          // 레이어 순서 리스트 (토글 가능)
          if (_showLayerOrderList)
            Container(
              height: MediaQuery.of(context).size.height * 0.35,
              child: LayerOrderList(
                layers: _interaction.sortByZ(layers),
                selectedLayerId: selectedLayerId,
                onLayerSelected: (id) {
                  final layer = layers.firstWhere((l) => l.id == id);
                  _interaction.setSelectedLayer(layer.id);
                  setState(() {});
                },
                onLayerReordered: (newIndex) {
                  // TODO: 레이어 순서 변경 구현
                  setState(() {});
                },
                onLayerVisibilityToggled: (id) {
                  // TODO: LayerModel에 visible 필드 추가 후 구현
                  // final layer = layers.firstWhere((l) => l.id == id);
                  // vm.updateLayer(layer.copyWith(visible: !(layer.visible ?? true)));
                  setState(() {});
                },
              ),
            ),
          // 하단 썸네일 스트립
          AlbumReaderThumbnailStrip(
            pages: pages,
            pageController: hasInnerPages ? _pageController : null,
            previewBuilder: _layerBuilder,
            baseCanvasSize: _baseCanvasSize,
            height: 70.h,
          ),
          SizedBox(height: 10.h),
        ],
      ),
    );
  }

}
