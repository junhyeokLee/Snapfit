import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/entities/layer.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../../../shared/widgets/album_bottom_sheet.dart';
import '../controllers/text_editor_manager.dart';
import '../controllers/layer_interaction_manager.dart';
import '../controllers/layer_builder.dart';
import '../widgets/editor/layer_action_panel.dart';
import '../widgets/editor/page_editor_canvas.dart';
import '../widgets/editor/page_list_selector.dart';
import '../widgets/editor/editor_bottom_menu.dart';
import '../widgets/editor/decorate_panel.dart';
import '../widgets/editor/edit_cover.dart';
import '../widgets/editor/layer_manager_panel.dart';
import '../widgets/editor/template_selection_panel.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../viewmodels/home_view_model.dart';
import '../controllers/toolbar_action_handler.dart';

class PageEditorScreen extends ConsumerStatefulWidget {
  /// 편집할 내지 페이지 인덱스 (1 이상). null이면 현재 선택된 페이지 유지.
  /// 0(커버)은 페이지 편집에서 사용하지 않음.
  final int? initialPageIndex;

  const PageEditorScreen({super.key, this.initialPageIndex});

  @override
  ConsumerState<PageEditorScreen> createState() => _PageEditorScreenState();
}

class _PageEditorScreenState extends ConsumerState<PageEditorScreen> {
  final GlobalKey<EditCoverState> _coverEditorKey = GlobalKey<EditCoverState>();
  final GlobalKey _canvasKey = GlobalKey();
  Size _canvasSize = Size.zero;

  late final LayerInteractionManager _interaction;
  late final LayerBuilder _layerBuilder;
  late final ToolbarActionHandler _toolbarActionHandler;
  
  EditorMode _currentMode = EditorMode.none; // Current bottom panel mode

  // 저장 진행률 상태
  bool _isSaving = false;
  double _saveProgress = 0.0;
  Timer? _progressTimer;

  void _simulateProgress() {
    _saveProgress = 0.0;
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_saveProgress < 0.9) {
          _saveProgress += 0.05;
        } else {
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    ScreenLogger.enter(
      'PageEditorScreen',
      widget.initialPageIndex != null
          ? '내지 페이지 편집 (페이지 ${widget.initialPageIndex})'
          : '내지 페이지 편집',
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
      onLayerTap: (layer) => setState(() {}),
      onTapPlaceholder: (layer) => _openGalleryForPlaceholder(layer),
    );
    _layerBuilder = LayerBuilder(_interaction, () => _canvasSize);
    _toolbarActionHandler = ToolbarActionHandler(context, ref);

    // 내지 페이지만 편집: initialPageIndex가 있으면 즉시 해당 페이지로 이동
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

    // 캔버스 크기 초기화 (ViewModel 상태 기반)
    final isCover = vm.currentPageIndex == 0;
    final activeCanvasFromState = isCover ? state?.coverCanvasSize : state?.innerCanvasSize;
    
    if (activeCanvasFromState != null && activeCanvasFromState != Size.zero && _canvasSize == Size.zero) {
      _canvasSize = activeCanvasFromState;
    }
    
    // [Fix] 캔버스 비율 엄격 고정 (내지는 3:4, 커버는 선택된 비율)
    final double aspect = isCover ? vm.selectedCover.ratio : (3/4);
    final double defaultW = 300.w;
    final double defaultH = defaultW / aspect;
    
    final canvasW = _canvasSize != Size.zero ? _canvasSize.width : defaultW; 
    final canvasH = _canvasSize != Size.zero ? _canvasSize.height : defaultH;
    
    // Logic for displaying layers
    // If initialPageIndex is set, we might be forcing a specific page
    // But generally we should follow vm.currentPageIndex which is the source of truth
    final currentPageIndex = vm.currentPageIndex;
    final List<LayerModel> layers = (state != null && state.layers.isNotEmpty) 
        ? state.layers 
        : [];
        
    final pages = vm.pages; // For the top selector

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: SnapFitColors.backgroundOf(context),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: SnapFitColors.textPrimaryOf(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "스냅핏 만들기",
          style: TextStyle(
            color: SnapFitColors.textPrimaryOf(context),
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () async {
               // 저장 로직 실행
               try {
                 setState(() {
                   _isSaving = true;
                   _simulateProgress();
                 });

                 // 1. Z-index 정렬 동기화
                 if (layers.isNotEmpty) {
                   final sorted = _interaction.sortByZ(layers);
                   vm.updatePageLayers(sorted);
                 }

                  // 2. 서버 저장
                  Uint8List? coverCapture;
                  try {
                    coverCapture = await _coverEditorKey.currentState?.captureCoverBytes();
                  } catch (e) {
                    debugPrint('Failed to capture cover in Screen: $e');
                  }
                  
                  final isSuccess = await vm.saveFullAlbum(coverImageBytes: coverCapture);
                  
                  if (isSuccess) {
                   // 성공 시 진행률 100%
                   _progressTimer?.cancel();
                   if (mounted) {
                     setState(() => _saveProgress = 1.0);
                   }
                   await Future.delayed(const Duration(milliseconds: 300));
                 }

                 if (context.mounted) {
                   // 3. 홈 화면 갱신 및 이동
                   await ref.read(homeViewModelProvider.notifier).refresh();
                   if (!context.mounted) return;
                   
                   Navigator.popUntil(context, (route) => route.isFirst);
                   
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('앨범이 저장되었습니다!')),
                   );
                 }
               } catch (e) {
                 if (context.mounted) {
                   setState(() => _isSaving = false);
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('저장 실패: $e')),
                   );
                 }
               } finally {
                 _progressTimer?.cancel();
               }
            },
            child: Text(
              "완료",
              style: TextStyle(
                color: _isSaving ? SnapFitColors.textMutedOf(context) : SnapFitColors.accent,
                fontWeight: FontWeight.bold,
                fontSize: 16.sp
              ),
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 1. Top Page Selector
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: PageListSelector(
                  pages: pages,
                  currentPageIndex: currentPageIndex,
                  onPageSelected: (index) {
                    vm.goToPage(index);
                    setState(() {}); // Refresh UI
                  },
                  onAddPage: () {
                    vm.addPage();
                    setState(() {}); // Refresh UI
                  },
                ),
              ),
              
              // 2. Main Canvas Area
              Expanded(
                child: currentPageIndex == 0 
                  ? EditCover(
                      key: _coverEditorKey,
                      editAlbum: vm.album,
                      showAppBar: false,
                      initialCoverSize: vm.selectedCover,
                      showBottomToolbar: false, // Hide Cover's internal toolbar
                      interaction: _interaction, // Pass shared interaction
                      canvasKey: _canvasKey,     // Pass shared key
                      onSizeChanged: (size) {
                        _canvasSize = size; // Sync size for Write/Photo actions
                      },
                    )
                  : GestureDetector(
                  onTap: () {
                    if (_interaction.selectedLayerId != null) {
                      _interaction.clearSelection();
                      setState(() {});
                    }
                  },
                  behavior: HitTestBehavior.translucent,
                  child: Center(
                    child: PageEditorCanvas(
                      canvasKey: _canvasKey,
                      canvasW: canvasW,
                      canvasH: canvasH,
                      layers: layers,
                      interaction: _interaction,
                      layerBuilder: _layerBuilder,
                      onCanvasSizeChanged: (size) {
                        _canvasSize = size;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          vm.loadPendingEditAlbumIfNeeded(size);
                          // [Fix] 현재 페이지 타입에 맞춰 리사이징 타겟 지정
                          vm.setCoverCanvasSize(size, isCover: vm.currentPageIndex == 0); 
                        });
                      },
                      backgroundColor: vm.currentPage?.backgroundColor != null 
                          ? Color(vm.currentPage!.backgroundColor!) 
                          : null,
                      isCover: vm.currentPage?.isCover ?? false,
                    ),
                  ),
                ),
              ),

              // Bottom Menu
              EditorBottomMenu(
                currentMode: _currentMode,
                isCover: currentPageIndex == 0,
                onModeChanged: (mode) => _handleModeChange(mode, layers),
                onAddPhoto: () => _toolbarActionHandler.addPhoto(_canvasSize),
                onCover: () => _toolbarActionHandler.openCoverTheme(),
              ),
            ],
          ),

          // 4. Layer Action Panel
          if (_interaction.selectedLayerId != null)
            Positioned(
              bottom: 100.h, // Bottom Menu 위에 위치
              left: 20.w,
              right: 20.w,
              child: LayerActionPanel(
                layers: layers,
                interaction: _interaction,
                textEditor: TextEditorManager(context, ref.read(albumEditorViewModelProvider.notifier)),
                onRefresh: () => setState(() {}),
                onOpenGallery: (LayerModel layer) => _openGalleryForPlaceholder(layer),
              ),
            ),
          
          // 저장 중 진행률 오버레이
          if (_isSaving)
            Container(
              color: SnapFitColors.overlayStrongOf(context),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      value: _saveProgress,
                      strokeWidth: 4,
                      color: SnapFitColors.accent,
                      backgroundColor: Colors.white24,
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      '저장 중... ${(_saveProgress * 100).toInt()}%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // 전역 로딩 오버레이 (생성 플로우 전환용)
          if (state?.isCreatingInBackground ?? false)
            Container(
              color: SnapFitColors.backgroundOf(context),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 3,
                      color: SnapFitColors.accent,
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      '앨범을 준비하고 있습니다...',
                      style: TextStyle(
                        color: SnapFitColors.textPrimaryOf(context),
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '잠시만 기다려주세요.',
                      style: TextStyle(
                        color: SnapFitColors.textSecondaryOf(context),
                        fontSize: 14.sp,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleModeChange(EditorMode mode, List<LayerModel> layers) {
    if (mode == EditorMode.none) {
      setState(() => _currentMode = mode);
      return;
    }

    if (mode == EditorMode.text) {
       _currentMode = EditorMode.none;
       final vm = ref.read(albumEditorViewModelProvider.notifier);
       // Legacy logic: responsive size based on canvas
       final effectiveSize = _canvasSize == Size.zero ? const Size(300, 400) : _canvasSize;
       TextEditorManager(context, vm).openAndCreateNew(
         Size(
           effectiveSize.width * 0.92,
           effectiveSize.height * 0.18,
         ),
       );
       return;
    }

    setState(() => _currentMode = mode);

    // Bottom Sheet 호출
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        if (mode == EditorMode.decorate) {
          return DecoratePanel(onClose: () => Navigator.pop(ctx));
        } else if (mode == EditorMode.layer) {
          return LayerManagerPanel(layers: layers);
        } else if (mode == EditorMode.template) {
           return const TemplateSelectionPanel(); // TODO: Update template selector visuals if needed
        }
        return const SizedBox.shrink();
      }
    ).then((_) {
      if (mounted) setState(() => _currentMode = EditorMode.none);
    });
  }

}
