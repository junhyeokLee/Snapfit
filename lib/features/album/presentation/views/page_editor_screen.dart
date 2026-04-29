import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/entities/layer.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/constants/cover_size.dart';
import '../../../../core/utils/platform_ui.dart';
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
import '../widgets/editor/design_template_panel.dart';
import '../widgets/editor/text_style_picker_sheet.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../../../../shared/widgets/image_frame_style_picker.dart';
import '../viewmodels/home_view_model.dart';
import '../controllers/toolbar_action_handler.dart';
import '../widgets/editor/page_editor_overlays.dart';
import '../viewmodels/gallery_notifier.dart'; // Add import
import '../../data/api/storage_service.dart';

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
  int? _lastSyncedPageIndex;
  String? _lastLayerSyncSignature;

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
        // 페이지도 커버와 동일한 500xH 논리 좌표계를 사용
        return Size(kCoverReferenceWidth, kCoverReferenceWidth / aspect);
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
  Future<void> _onSaveAlbum(
    AlbumEditorViewModel vm,
    List<LayerModel> layers,
  ) async {
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
      if (!isSuccess) {
        final error = ref.read(albumEditorViewModelProvider).error;
        if (error is StorageQuotaExceededException) {
          throw error;
        }
        throw StateError('앨범 저장에 실패했습니다.');
      }

      if (isSuccess) {
        // 성공 시 진행률 100%
        _progressTimer?.cancel();
        if (mounted) {
          setState(() => _saveProgress = 1.0);
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (context.mounted && isSuccess) {
        // 3. 홈 화면 갱신 및 이동
        await ref.read(homeViewModelProvider.notifier).refresh();
        if (!context.mounted) return;

        Navigator.popUntil(context, (route) => route.isFirst);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('앨범이 저장되었습니다!')));
      }
    } catch (e) {
      if (e is StorageQuotaExceededException && context.mounted) {
        setState(() => _isSaving = false);
        await _showQuotaExceededSheet(context);
        return;
      }
      if (context.mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    } finally {
      _progressTimer?.cancel();
    }
  }

  Future<void> _showQuotaExceededSheet(BuildContext context) async {
    final shouldSubscribe = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: SnapFitColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '저장 공간이 부족합니다',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  '무료 플랜 용량(1GB)을 초과했습니다. 구독 후 10GB까지 계속 저장할 수 있어요.',
                  style: TextStyle(
                    color: SnapFitColors.textSecondaryOf(context),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('준비중'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('닫기'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldSubscribe != true || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('구독 및 결제 기능은 현재 준비중입니다.')));
  }

  Future<void> _confirmDeleteCurrentPage(AlbumEditorViewModel vm) async {
    if (!vm.canDeleteCurrentPage) return;
    final pageNumber = vm.currentPageIndex;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SnapFitColors.surfaceOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text(
          '페이지 삭제',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
        content: Text(
          '$pageNumber페이지를 삭제할까요?',
          style: TextStyle(
            fontSize: 14.sp,
            height: 1.5,
            color: SnapFitColors.textSecondaryOf(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              '취소',
              style: TextStyle(color: SnapFitColors.textMutedOf(context)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '삭제',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;
    vm.deleteCurrentPage();
    _interaction.clearSelection();
    setState(() => _canvasSize = Size.zero);
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
    final layerSyncSignature =
        '$currentPageIndex:${layers.length}:${layers.map((e) => e.id).join('|')}';

    if (_lastSyncedPageIndex != currentPageIndex) {
      _lastSyncedPageIndex = currentPageIndex;
      _lastLayerSyncSignature = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _interaction.resetForPageChange();
      });
    } else if (_lastLayerSyncSignature != layerSyncSignature) {
      _lastLayerSyncSignature = layerSyncSignature;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _interaction.syncLayers(layers);
      });
    }

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
            icon: Icon(
              platformBackIcon(),
              color: SnapFitColors.textPrimaryOf(context),
            ),
            onPressed: () async {
              final shouldPop = await _handleWillPop(vm, layers);
              if (shouldPop && mounted) {
                Navigator.pop(context);
              }
            },
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Undo/Redo 버튼을 타이틀 왼쪽에 배치
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.undo_rounded,
                      size: 20.sp,
                      color: canUndo
                          ? SnapFitColors.textPrimaryOf(context)
                          : SnapFitColors.textMutedOf(context),
                    ),
                    onPressed: canUndo
                        ? () {
                            vm.undo();
                            _interaction.clearSelection();
                            if (mounted) setState(() {});
                          }
                        : null,
                    tooltip: '되돌리기',
                  ),
                  SizedBox(width: 4.w),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.redo_rounded,
                      size: 20.sp,
                      color: canRedo
                          ? SnapFitColors.textPrimaryOf(context)
                          : SnapFitColors.textMutedOf(context),
                    ),
                    onPressed: canRedo
                        ? () {
                            vm.redo();
                            _interaction.clearSelection();
                            if (mounted) setState(() {});
                          }
                        : null,
                    tooltip: '다시하기',
                  ),
                ],
              ),
              SizedBox(width: 8.w),
              Text(
                "스냅핏 만들기",
                style: TextStyle(
                  color: SnapFitColors.textPrimaryOf(context),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : () => _onSaveAlbum(vm, layers),
              child: Text(
                "저장",
                style: TextStyle(
                  color: _isSaving
                      ? SnapFitColors.textMutedOf(context)
                      : SnapFitColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16.sp,
                ),
              ),
            ),
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
                        canDeleteCurrentPage: vm.canDeleteCurrentPage,
                        onDeleteCurrentPage: () =>
                            _confirmDeleteCurrentPage(vm),
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
                              showBottomToolbar:
                                  false, // Hide Cover's internal toolbar
                              interaction:
                                  _interaction, // Pass shared interaction
                              canvasKey: _canvasKey, // Pass shared key
                              onSizeChanged: (size) {
                                _canvasSize =
                                    size; // Sync size for Write/Photo actions
                              },
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                const double sidePadding = 16.0;
                                final double availW =
                                    constraints.maxWidth - sidePadding * 2;
                                final double availH = constraints.maxHeight;
                                const double logicalW = kCoverReferenceWidth;
                                final double logicalH = logicalW / aspect;

                                // 커버와 동일하게 가로/세로 모두 고려해 캔버스 표시 크기를 계산한다.
                                // (일부 비율에서 하단/우측 터치 좌표가 어긋나는 현상 방지)
                                final double scaleByWidth = availW / logicalW;
                                final double scaleByHeight = availH / logicalH;
                                final double scale = math.min(
                                  scaleByWidth,
                                  scaleByHeight,
                                );
                                final double innerW = logicalW * scale;
                                final double innerH = logicalH * scale;

                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: sidePadding,
                                    ),
                                    child: SizedBox(
                                      width: innerW,
                                      height: innerH,
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
                                            WidgetsBinding.instance
                                                .addPostFrameCallback((_) {
                                                  if (!mounted) return;
                                                  setState(
                                                    () => _canvasSize = size,
                                                  );
                                                  vm.loadPendingEditAlbumIfNeeded(
                                                    size,
                                                  );
                                                  vm.setCoverCanvasSize(
                                                    size,
                                                    isCover:
                                                        vm.currentPageIndex ==
                                                        0,
                                                  );
                                                });
                                          }
                                        },
                                        backgroundColor:
                                            vm.currentPage?.backgroundColor !=
                                                null
                                            ? Color(
                                                vm
                                                    .currentPage!
                                                    .backgroundColor!,
                                              )
                                            : null,
                                        isCover:
                                            vm.currentPage?.isCover ?? false,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    // 툴바 영역은 항상 동일 높이로 확보하여 커버/캔버스의 위아래 위치가 변하지 않도록 한다.
                    // 툴바 영역은 충분한 고정 높이(옵시티 슬라이더 포함)를 확보해서
                    // RenderFlex overflow가 발생하지 않도록 한다.
                    SizedBox(
                      height: 80.h,
                      child: Center(
                        child: _interaction.selectedLayerId != null
                            ? LayerActionPanel(
                                layers: layers,
                                interaction: _interaction,
                                textEditor: TextEditorManager(
                                  context,
                                  ref.read(
                                    albumEditorViewModelProvider.notifier,
                                  ),
                                ),
                                onRefresh: () => setState(() {}),
                                onOpenGallery: (LayerModel layer) =>
                                    _openGalleryForPlaceholder(layer),
                                onOpenDecorateSheet: (LayerModel layer) =>
                                    _openDecorateSheetForLayer(layer),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),

                    // Bottom Menu (고정)
                    EditorBottomMenu(
                      currentMode: _currentMode,
                      isCover: currentPageIndex == 0,
                      showCoverMenuItem: false,
                      onModeChanged: (mode) => _handleModeChange(mode, layers),
                      onAddPhoto: () {
                        // 커버일 때 캔버스 크기가 아직 0이면 커버 기준 크기 사용
                        final size =
                            (currentPageIndex == 0 &&
                                (_canvasSize.width <= 0 ||
                                    _canvasSize.height <= 0))
                            ? Size(
                                kCoverReferenceWidth,
                                kCoverReferenceWidth / aspect,
                              )
                            : _canvasSize;
                        _toolbarActionHandler.addPhoto(size);
                      },
                      onCover: () => _toolbarActionHandler.openCoverTheme(),
                    ),
                  ],
                ),
              ),

              // 저장 중 진행률 오버레이
              if (_isSaving) PageEditorSaveOverlay(progress: _saveProgress),

              // 백그라운드 이미지 업로드 진행률 배지 (저장 이후에도 계속 업로드되는 경우)
              if (!_isSaving &&
                  (state?.backgroundUploadProgress ?? 0) > 0 &&
                  (state?.backgroundUploadProgress ?? 0) < 1)
                Positioned(
                  bottom: 80.h,
                  left: 16.w,
                  right: 16.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: SnapFitColors.overlayStrongOf(context),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 14.r,
                          height: 14.r,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: state!.backgroundUploadProgress,
                            color: SnapFitColors.accent,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          '사진 업로드 중... ${(state.backgroundUploadProgress * 100).toInt()}%',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 전역 로딩 오버레이 (생성 플로우 전환용)
              if (state?.isCreatingInBackground ?? false)
                const PageEditorPreparingOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _handleWillPop(
    AlbumEditorViewModel vm,
    List<LayerModel> layers,
  ) async {
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

  void _handleModeChange(EditorMode mode, List<LayerModel> layers) {
    if (mode == EditorMode.none) {
      setState(() => _currentMode = mode);
      return;
    }

    if (mode == EditorMode.text) {
      _currentMode = EditorMode.none;
      final vm = ref.read(albumEditorViewModelProvider.notifier);
      // Legacy logic: responsive size based on canvas
      final effectiveSize = _canvasSize == Size.zero
          ? const Size(300, 400)
          : _canvasSize;
      TextEditorManager(context, vm).openAndCreateNew(
        Size(effectiveSize.width * 0.92, effectiveSize.height * 0.18),
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
}
