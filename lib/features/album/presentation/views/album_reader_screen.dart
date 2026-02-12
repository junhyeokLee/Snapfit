import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/cover_size.dart';
import '../../../../core/utils/screen_logger.dart';
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
import '../viewmodels/home_view_model.dart';

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
    ScreenLogger.enter('AlbumReaderScreen', '앨범 뷰어 · 커버/내지 스프레드 · 페이지 편집 진입');
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

    // 백그라운드 생성 중(업로드 중)일 때 로딩 화면 표시
    if (state.isCreatingInBackground) {
      return Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,ㅎ
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: SnapFitColors.textPrimaryOf(context), size: 18.sp),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: SnapFitColors.accent,
              ),
              SizedBox(height: 24.h),
              Text(
                '앨범을 생성하고 있습니다...',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: SnapFitColors.textPrimaryOf(context),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                '잠시만 기다려주세요',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: SnapFitColors.textSecondaryOf(context),
                ),
              ),
            ],
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
        backgroundColor: SnapFitColors.backgroundOf(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(''), // AppBar 높이 통일 (AlbumCreateFlowScreen과 동일)
        leading: IconButton(
          icon: Icon(Icons.close, color: SnapFitColors.textPrimaryOf(context)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: () async {
                try {
                  final vm = ref.read(albumEditorViewModelProvider.notifier);
                  await vm.saveFullAlbum();
                  if (mounted) {
                    // 홈 화면 갱신
                    ref.read(homeViewModelProvider.notifier).refresh();

                    // 홈 화면으로 이동 (모든 스택 제거)
                    Navigator.popUntil(context, (route) => route.isFirst);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('앨범이 저장되었습니다!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('저장 실패: $e')),
                    );
                  }
                }
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
          ),
        ],
      ),
      body: Stack(
        children: [
          // 메인 컬럼: 캔버스 (TopBar는 AppBar로 이동됨)
          Column(
            children: [

              // 중앙 캔버스 영역 - EditCover와 동일한 Expanded 구조 (하단 위젯 없음!)
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
            ],
          ),
          // 하단 툴바들 - Stack 오버레이로 배치 (Expanded 높이에 영향 없음)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                        setState(() {});
                      },
                      onLayerVisibilityToggled: (id) {
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
