import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/entities/layer.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/constants/cover_size.dart';
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
import '../widgets/editor/text_style_picker_sheet.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../../../../shared/widgets/image_frame_style_picker.dart';
import '../viewmodels/home_view_model.dart';
import '../controllers/toolbar_action_handler.dart';
import '../widgets/editor/page_editor_overlays.dart';
import '../viewmodels/gallery_notifier.dart'; // Add import

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
    _progressTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_saveProgress < 0.85) {
          // 0~85%: 빠르게 증가 (저장 시작 느낌)
          _saveProgress += 0.05;
        } else if (_saveProgress < 0.97) {
          // 85~97%: 아주 천천히 증가 → 90%서 멈추는 느낌 제거
          _saveProgress += 0.003;
        }
        // 97% 이상: 타이머 계속 돌지만 값은 고정 (실제 완료 시 100% 점프)
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
      // [Inner Page Fix] 내지는 항상 300x400 논리적 좌표계를 사용함. 
      // 인터랙션 매니저가 스냅 가이드나 좌표 계산 시 이 기준을 따르게 함.
      getCoverSize: () {
        final currentVm = ref.read(albumEditorViewModelProvider.notifier);
        final aspect = currentVm.selectedCover.ratio;
        if (currentVm.currentPageIndex == 0) {
          // [10단계 Fix] 커버 편집 시에도 500xH 논리 좌표계를 사용함
          return Size(kCoverReferenceWidth, kCoverReferenceWidth / aspect);
        }
        // [Inner Page Fix] 내지의 경우 300xH 논리적 베이스 사이즈 계산
        return Size(300.0, 300.0 / aspect);
      },
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
    
    final gallery = ref.read(galleryProvider);
    if (gallery.albums.isEmpty) {
      await ref.read(galleryProvider.notifier).fetchInitialData();
    }
    if (!mounted) return;
    final asset = await showPhotoSelectionSheet(context, ref);
    if (asset == null || !mounted) return;
    
    final vm = ref.read(albumEditorViewModelProvider.notifier); // vm 정의 추가
    await vm.updateSlotImage(layer.id, asset);
    if (mounted) setState(() {});
  }

  /// 앨범 저장 로직 추출
  Future<void> _onSaveAlbum(AlbumEditorViewModel vm, List<LayerModel> layers) async {
    if (_isSaving) return;

    try {
      setState(() {
        _isSaving = true;
        _simulateProgress();
      });

      // 1. Z-index 정렬 동기화 (VM 현재 페이지 레이어를 _z 순서로 맞춰 저장 시 순서 유지)
      final currentPage = vm.currentPage;
      if (currentPage != null && currentPage.layers.isNotEmpty) {
        final sorted = _interaction.sortByZ(List.of(currentPage.layers));
        vm.updatePageLayers(sorted, recordHistory: false);
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
  }


  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(albumEditorViewModelProvider);
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final state = asyncState.value;
    final canUndo = state?.canUndo ?? false;
    final canRedo = state?.canRedo ?? false;

    // aspect: 내지 LayoutBuilder에서 canvasH 계산에 사용
    final double aspect = vm.selectedCover.ratio;
    
    // Logic for displaying layers
    // If initialPageIndex is set, we might be forcing a specific page
    // But generally we should follow vm.currentPageIndex which is the source of truth
    final currentPageIndex = vm.currentPageIndex;
    final List<LayerModel> layers = (state != null && state.layers.isNotEmpty) 
        ? state.layers 
        : [];
        
    final pages = vm.pages; // For the top selector

    return WillPopScope(
      onWillPop: () => _handleWillPop(vm, layers),
      child: Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: SnapFitColors.textPrimaryOf(context)),
          onPressed: () async {
            final shouldPop = await _handleWillPop(vm, layers);
            if (shouldPop && mounted) {
              Navigator.pop(context);
            }
          },
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
            onPressed: _isSaving ? null : () => _onSaveAlbum(vm, layers),
            child: Text(
              "저장",
              style: TextStyle(
                color: _isSaving ? SnapFitColors.textMutedOf(context) : SnapFitColors.accent,
                fontWeight: FontWeight.bold,
                fontSize: 16.sp
              ),
            ),
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: SnapFitColors.readerGradientOf(context),
          ),
        ),
        child: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
            children: [
              // 1. Top Page Selector (리스트–아이콘과 같은 여백으로 정리)
              Padding(
                padding: EdgeInsets.only(top: 16.h),
                child: PageListSelector(
                  pages: pages,
                  currentPageIndex: currentPageIndex,
                  onPageSelected: (index) {
                    vm.goToPage(index);
                    // 페이지 전환 시 _canvasSize 리셋 → 다음 렌더에서 PageEditorCanvas가 실제 크기 재측정
                    setState(() => _canvasSize = Size.zero);
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
                  // 커버와 동일한 수평 패딩(16px)을 적용해 내지 크기를 정확히 일치시킴
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const double sidePadding = 16.0;
                      final double innerW = constraints.maxWidth - sidePadding * 2;
                      final double innerH = innerW / aspect;

                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: sidePadding),
                          child: PageEditorCanvas(
                            canvasKey: _canvasKey,
                            canvasW: innerW,
                            canvasH: innerH,
                            layers: layers,
                            interaction: _interaction,
                            layerBuilder: _layerBuilder,
                            onCanvasSizeChanged: (size) {
                              // 실제 측정된 캔버스 크기로 갱신
                              if (_canvasSize != size) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!mounted) return;
                                  setState(() => _canvasSize = size);
                                  vm.loadPendingEditAlbumIfNeeded(size);
                                  vm.setCoverCanvasSize(size, isCover: vm.currentPageIndex == 0);
                                });
                              }
                            },
                            backgroundColor: vm.currentPage?.backgroundColor != null
                                ? Color(vm.currentPage!.backgroundColor!)
                                : null,
                            isCover: vm.currentPage?.isCover ?? false,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Undo / Redo (앨범 커버 위, 리스트–아이콘과 동일한 간격)
              Padding(
                padding: EdgeInsets.only(bottom:50.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: canUndo
                          ? () {
                              vm.undo();
                              _interaction.clearSelection();
                              if (mounted) setState(() {});
                            }
                          : null,
                      icon: Icon(
                        Icons.undo_rounded,
                        size: 22.sp,
                        color: canUndo
                            ? SnapFitColors.textPrimaryOf(context)
                            : SnapFitColors.textMutedOf(context),
                      ),
                      tooltip: '되돌리기',
                      style: IconButton.styleFrom(
                        backgroundColor: canUndo
                            ? SnapFitColors.textPrimaryOf(context).withValues(alpha: 0.08)
                            : null,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    IconButton(
                      onPressed: canRedo
                          ? () {
                              vm.redo();
                              _interaction.clearSelection();
                              if (mounted) setState(() {});
                            }
                          : null,
                      icon: Icon(
                        Icons.redo_rounded,
                        size: 22.sp,
                        color: canRedo
                            ? SnapFitColors.textPrimaryOf(context)
                            : SnapFitColors.textMutedOf(context),
                      ),
                      tooltip: '다시하기',
                      style: IconButton.styleFrom(
                        backgroundColor: canRedo
                            ? SnapFitColors.textPrimaryOf(context).withValues(alpha: 0.08)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              // Bottom Menu
              EditorBottomMenu(
                currentMode: _currentMode,
                isCover: currentPageIndex == 0,
                onModeChanged: (mode) => _handleModeChange(mode, layers),
                onAddPhoto: () {
                  // 커버일 때 캔버스 크기가 아직 0이면 커버 기준 크기 사용
                  final size = (currentPageIndex == 0 &&
                          (_canvasSize.width <= 0 || _canvasSize.height <= 0))
                      ? Size(kCoverReferenceWidth, kCoverReferenceWidth / aspect)
                      : _canvasSize;
                  _toolbarActionHandler.addPhoto(size);
                },
                onCover: () => _toolbarActionHandler.openCoverTheme(),
              ),
            ],
          ),
          ),

          // 4. Layer Action Panel (커버/내지 공통 — 하나만 표시, 위치 통일)
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
                onOpenDecorateSheet: (LayerModel layer) => _openDecorateSheetForLayer(layer),
              ),
            ),
          
          // 저장 중 진행률 오버레이
          if (_isSaving)
            PageEditorSaveOverlay(progress: _saveProgress),

          // 전역 로딩 오버레이 (생성 플로우 전환용)
          if (state?.isCreatingInBackground ?? false)
            const PageEditorPreparingOverlay(),
        ],
      ),
      ),
    ),
    );
  }

  Future<bool> _handleWillPop(AlbumEditorViewModel vm, List<LayerModel> layers) async {
    final asyncState = ref.read(albumEditorViewModelProvider);
    final hasChanges = asyncState.value?.canUndo ?? false;
    if (!hasChanges) return true;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('변경 내용을 저장할까요?'),
          content: const Text('나가기 전에 편집한 내용을 저장하시겠어요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('discard'),
              child: const Text('저장 안함'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('cancel'),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('save'),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    if (result == 'discard' || result == null) {
      return true; // 그냥 나가기
    }
    if (result == 'cancel') {
      return false;
    }
    if (result == 'save') {
      // 기존 저장 로직은 홈으로 이동(popUntil)까지 처리하므로 여기서는 추가 pop을 막는다.
      await _onSaveAlbum(vm, layers);
      return false;
    }
    return true;
  }

  void _openDecorateSheetForLayer(LayerModel layer) {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    if (layer.type == LayerType.image) {
      ImageFrameStylePicker.show(context, currentKey: layer.imageBackground ?? '').then((key) {
        if (key != null && mounted) {
          vm.updateImageFrame(layer.id, key);
          setState(() {});
        }
      });
    } else {
      TextStylePickerSheet.show(context, currentKey: layer.textBackground ?? '').then((key) {
        if (key != null && mounted) {
          vm.updateTextStyle(layer.id, key);
          setState(() {});
        }
      });
    }
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
          return LayerManagerPanel(
            layers: layers,
            interaction: _interaction,
          );
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
