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
import '../../../../shared/widgets/snapfit_motion.dart';
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
import '../utils/album_save_error_message.dart';
import '../controllers/toolbar_action_handler.dart';
import '../widgets/editor/page_editor_overlays.dart';
import '../viewmodels/gallery_notifier.dart'; // Add import
import '../../data/api/storage_service.dart';

class _PageEditorEntranceReveal extends StatelessWidget {
  final Widget child;
  final Duration delay;
  final bool includeScale;

  const _PageEditorEntranceReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.includeScale = false,
  });

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 360);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: delay + duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final totalMs = (delay + duration).inMilliseconds;
        final t = delay == Duration.zero
            ? value
            : ((value * totalMs - delay.inMilliseconds) /
                      duration.inMilliseconds)
                  .clamp(0.0, 1.0);
        final scale = includeScale ? 0.96 + (0.04 * t) : 1.0;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - t)),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: child,
    );
  }
}

class _PageEditorPageTurnReveal extends StatelessWidget {
  const _PageEditorPageTurnReveal({
    super.key,
    required this.forward,
    required this.child,
  });

  final bool forward;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: SnapFitMotion.pageTurn,
      curve: SnapFitMotion.pageTurnCurve,
      builder: (context, value, child) {
        final direction = forward ? 1.0 : -1.0;
        final t = value.clamp(0.0, 1.0);
        final settleT = ((t - 0.72) / 0.28).clamp(0.0, 1.0);
        final settlePulse = math.sin(settleT * math.pi);
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..translate(18.0 * direction * (1 - t), 0.0)
          ..rotateY(direction * 0.16 * (1 - t));
        return Opacity(
          key: const Key('pageEditorPageTurnOpacity'),
          opacity: (0.18 + t * 0.82).clamp(0.0, 1.0),
          child: Transform(
            key: const Key('pageEditorPageTurnReveal'),
            alignment: Alignment.center,
            transform: matrix,
            child: Transform.scale(
              key: const Key('pageEditorPageSettleScale'),
              scale: 0.965 + (0.035 * t) + (0.006 * settlePulse),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        (0.16 * (1 - t) + 0.045 * settlePulse).clamp(0.0, 0.18),
                      ),
                      blurRadius: 18 + 10 * (1 - t) + 8 * settlePulse,
                      offset: Offset(0, 8 + 6 * (1 - t) + 3 * settlePulse),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.passthrough,
                  children: [
                    child ?? const SizedBox.shrink(),
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: forward ? 0 : null,
                      left: forward ? null : 0,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: 0.18 * (1 - t),
                          child: Container(
                            key: const Key('pageEditorPageEdgeHighlight'),
                            width: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}

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
  Timer? _editorHintTimer;
  int? _lastSyncedPageIndex;
  String? _lastLayerSyncSignature;
  bool _showEditorHint = false;
  int _pageTurnNonce = 0;
  bool _pageTurnForward = true;

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
    _editorHintTimer?.cancel();
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
    if (_showEditorHint) setState(() => _showEditorHint = false);

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

        // popUntil 이전에 캡처해야 한다. popUntil 이후 context는 deactivated 상태가
        // 되어 SnackBar 애니메이션 완료 시점에 ancestor 조회가 실패한다.
        final messenger = ScaffoldMessenger.of(context);
        Navigator.popUntil(context, (route) => route.isFirst);
        messenger.showSnackBar(const SnackBar(content: Text('앨범이 저장되었습니다!')));
      }
    } catch (e) {
      if (e is StorageQuotaExceededException && context.mounted) {
        setState(() => _isSaving = false);
        await _showQuotaExceededSheet(context);
        return;
      }
      if (context.mounted) {
        setState(() => _isSaving = false);
        final message = albumSaveErrorMessage(e);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 실패: $message')));
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

    void handlePageSelected(int index) {
      if (index == currentPageIndex) return;
      _pageTurnForward = index > currentPageIndex;
      _pageTurnNonce++;
      _interaction.clearSelection();
      vm.goToPage(index);
      // 페이지 전환 시 _canvasSize 리셋 → 다음 렌더에서 PageEditorCanvas가 실제 크기 재측정
      setState(() => _canvasSize = Size.zero);
    }

    void handleAddPage() {
      _pageTurnForward = true;
      _pageTurnNonce++;
      vm.addPage();
      setState(() {});
    }

    Widget buildPageSelector() {
      return SnapFitFadeIn(
        key: const Key('pageEditorSelectorReveal'),
        delay: const Duration(milliseconds: 80),
        child: PageListSelector(
          pages: pages,
          currentPageIndex: currentPageIndex,
          onPageSelected: handlePageSelected,
          onAddPage: handleAddPage,
          canDeleteCurrentPage: vm.canDeleteCurrentPage,
          onDeleteCurrentPage: () => _confirmDeleteCurrentPage(vm),
        ),
      );
    }

    Widget buildCanvasArea({required EdgeInsets padding}) {
      return Padding(
        padding: padding,
        child: _PageEditorEntranceReveal(
          key: const Key('pageEditorCanvasReveal'),
          delay: Duration.zero,
          includeScale: true,
          child: _PageEditorPageTurnReveal(
            key: ValueKey('page-turn-$currentPageIndex-$_pageTurnNonce'),
            forward: _pageTurnForward,
            child: _buildWorkspaceFrame(
              context,
              child: currentPageIndex == 0
                  ? EditCover(
                      key: _coverEditorKey,
                      editAlbum: vm.album,
                      showAppBar: false,
                      initialCoverSize: vm.selectedCover,
                      showBottomToolbar: false,
                      interaction: _interaction,
                      canvasKey: _canvasKey,
                      onSizeChanged: (size) {
                        _canvasSize = size;
                      },
                    )
                  : LayoutBuilder(
                      key: ValueKey(currentPageIndex),
                      builder: (context, constraints) {
                        const double sidePadding = 16.0;
                        final double availW =
                            constraints.maxWidth - sidePadding * 2;
                        final double availH = constraints.maxHeight;
                        const double logicalW = kCoverReferenceWidth;
                        final double logicalH = logicalW / aspect;

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
                                  if (_canvasSize != size) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (!mounted) return;
                                          setState(() => _canvasSize = size);
                                          vm.loadPendingEditAlbumIfNeeded(size);
                                          vm.setCoverCanvasSize(
                                            size,
                                            isCover: vm.currentPageIndex == 0,
                                          );
                                        });
                                  }
                                },
                                backgroundColor:
                                    vm.currentPage?.backgroundColor != null
                                    ? Color(vm.currentPage!.backgroundColor!)
                                    : null,
                                isCover: vm.currentPage?.isCover ?? false,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      );
    }

    Widget buildLayerActions() {
      return AnimatedSwitcher(
        duration: SnapFitMotion.medium,
        switchInCurve: SnapFitMotion.entrance,
        switchOutCurve: Curves.easeInCubic,
        child: _interaction.selectedLayerId != null
            ? LayerActionPanel(
                layers: layers,
                interaction: _interaction,
                textEditor: TextEditorManager(
                  context,
                  ref.read(albumEditorViewModelProvider.notifier),
                ),
                onRefresh: () => setState(() {}),
                onOpenGallery: (LayerModel layer) =>
                    _openGalleryForPlaceholder(layer),
                onOpenDecorateSheet: (LayerModel layer) =>
                    _openDecorateSheetForLayer(layer),
              )
            : const SizedBox.shrink(),
      );
    }

    Widget buildInlinePanel() {
      if (_currentMode == EditorMode.none) return const SizedBox.shrink();
      return _EditorToolPanelReveal(
        child: _buildInlineToolPanel(context, _currentMode, layers),
      );
    }

    Widget buildBottomMenu() {
      return SnapFitFadeIn(
        key: const Key('pageEditorDockReveal'),
        delay: const Duration(milliseconds: 140),
        beginOffset: const Offset(0, 0.055),
        child: EditorBottomMenu(
          currentMode: _currentMode,
          isCover: currentPageIndex == 0,
          showCoverMenuItem: false,
          canUndo: canUndo,
          canRedo: canRedo,
          onUndo: () {
            vm.undo();
            _interaction.clearSelection();
            if (mounted) setState(() {});
          },
          onRedo: () {
            vm.redo();
            _interaction.clearSelection();
            if (mounted) setState(() {});
          },
          onModeChanged: (mode) => _handleModeChange(mode, layers),
          onAddPhoto: () {
            final size =
                (currentPageIndex == 0 &&
                    (_canvasSize.width <= 0 || _canvasSize.height <= 0))
                ? Size(kCoverReferenceWidth, kCoverReferenceWidth / aspect)
                : _canvasSize;
            _toolbarActionHandler.addPhoto(size);
          },
          onCover: () => _toolbarActionHandler.openCoverTheme(),
        ),
      );
    }

    Widget buildLandscapeLayout() {
      // 편집 화면은 도구 접근성이 우선이다. read 톤은 색/프레임으로 맞추고,
      // UX 구조는 안정적인 page rail(좌) + canvas + command rail(우)를 유지한다.
      return Row(
        children: [
          SizedBox(
            width: 72,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 56, 2, 18),
              child: buildPageSelector(),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: buildCanvasArea(
                    padding: const EdgeInsets.fromLTRB(12, 54, 12, 18),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 58,
                  width: 152,
                  child: buildLayerActions(),
                ),
                if (_currentMode != EditorMode.none)
                  Positioned(
                    left: 12,
                    top: 132,
                    width: 176,
                    bottom: 18,
                    child: SingleChildScrollView(child: buildInlinePanel()),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 76,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 56, 10, 18),
              child: buildBottomMenu(),
            ),
          ),
        ],
      );
    }

    return WillPopScope(
      onWillPop: () => _handleWillPop(vm, layers),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          toolbarHeight: 64.h,
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
              _EditorMiniHistoryButton(
                icon: Icons.undo_rounded,
                enabled: canUndo,
                tooltip: '되돌리기',
                onTap: () {
                  vm.undo();
                  _interaction.clearSelection();
                  if (mounted) setState(() {});
                },
              ),
              SizedBox(width: 8.w),
              _EditorMiniHistoryButton(
                icon: Icons.redo_rounded,
                enabled: canRedo,
                tooltip: '다시하기',
                onTap: () {
                  vm.redo();
                  _interaction.clearSelection();
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 12.w),
              child: SnapFitPressable(
                onTap: _isSaving ? null : () => _onSaveAlbum(vm, layers),
                pressedScale: 0.96,
                borderRadius: BorderRadius.circular(999.r),
                child: AnimatedOpacity(
                  duration: SnapFitMotion.fast,
                  opacity: _isSaving ? 0.45 : 1,
                  child: Container(
                    height: 34.h,
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999.r),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1F1B16), Color(0xFF3B3026)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: SnapFitColors.accent.withOpacity(0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Text(
                      '저장',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
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
              _buildEditorStudioBackground(context),
              SafeArea(
                bottom: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isLandscape =
                        constraints.maxWidth > constraints.maxHeight;
                    if (isLandscape) return buildLandscapeLayout();

                    return Column(
                      children: [
                        // 1. Top Page Selector (리스트–아이콘과 같은 여백으로 정리)
                        Padding(
                          padding: EdgeInsets.only(top: 8.h),
                          child: SnapFitFadeIn(
                            key: const Key('pageEditorSelectorReveal'),
                            delay: const Duration(milliseconds: 80),
                            child: PageListSelector(
                              pages: pages,
                              currentPageIndex: currentPageIndex,
                              onPageSelected: (index) {
                                if (index == currentPageIndex) return;
                                _pageTurnForward = index > currentPageIndex;
                                _pageTurnNonce++;
                                _interaction.clearSelection();
                                vm.goToPage(index);
                                // 페이지 전환 시 _canvasSize 리셋 → 다음 렌더에서 PageEditorCanvas가 실제 크기 재측정
                                setState(() => _canvasSize = Size.zero);
                              },
                              onAddPage: () {
                                _pageTurnForward = true;
                                _pageTurnNonce++;
                                vm.addPage();
                                setState(() {}); // Refresh UI
                              },
                              canDeleteCurrentPage: vm.canDeleteCurrentPage,
                              onDeleteCurrentPage: () =>
                                  _confirmDeleteCurrentPage(vm),
                            ),
                          ),
                        ),
                        // 2. Main Canvas Area
                        // AnimatedSwitcher를 사용하지 않는다: EditCover와 PageEditorCanvas가
                        // 동일한 _canvasKey를 공유하므로 전환 애니메이션 중 두 위젯이 동시에
                        // 트리에 존재하면 GlobalKey 충돌이 발생한다.
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(10.w, 2.h, 10.w, 2.h),
                            child: _PageEditorEntranceReveal(
                              key: const Key('pageEditorCanvasReveal'),
                              delay: Duration.zero,
                              includeScale: true,
                              child: _PageEditorPageTurnReveal(
                                key: ValueKey(
                                  'page-turn-$currentPageIndex-$_pageTurnNonce',
                                ),
                                forward: _pageTurnForward,
                                child: _buildWorkspaceFrame(
                                  context,
                                  child: currentPageIndex == 0
                                      ? EditCover(
                                          key: _coverEditorKey,
                                          editAlbum: vm.album,
                                          showAppBar: false,
                                          initialCoverSize: vm.selectedCover,
                                          showBottomToolbar: false,
                                          interaction: _interaction,
                                          canvasKey: _canvasKey,
                                          onSizeChanged: (size) {
                                            _canvasSize = size;
                                          },
                                        )
                                      : LayoutBuilder(
                                          key: ValueKey(currentPageIndex),
                                          builder: (context, constraints) {
                                            const double sidePadding = 16.0;
                                            final double availW =
                                                constraints.maxWidth -
                                                sidePadding * 2;
                                            final double availH =
                                                constraints.maxHeight;
                                            const double logicalW =
                                                kCoverReferenceWidth;
                                            final double logicalH =
                                                logicalW / aspect;

                                            final double scaleByWidth =
                                                availW / logicalW;
                                            final double scaleByHeight =
                                                availH / logicalH;
                                            final double scale = math.min(
                                              scaleByWidth,
                                              scaleByHeight,
                                            );
                                            final double innerW =
                                                logicalW * scale;
                                            final double innerH =
                                                logicalH * scale;

                                            return Center(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
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
                                                      if (_canvasSize != size) {
                                                        WidgetsBinding.instance
                                                            .addPostFrameCallback((
                                                              _,
                                                            ) {
                                                              if (!mounted)
                                                                return;
                                                              setState(
                                                                () =>
                                                                    _canvasSize =
                                                                        size,
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
                                                        vm
                                                                .currentPage
                                                                ?.backgroundColor !=
                                                            null
                                                        ? Color(
                                                            vm
                                                                .currentPage!
                                                                .backgroundColor!,
                                                          )
                                                        : null,
                                                    isCover:
                                                        vm
                                                            .currentPage
                                                            ?.isCover ??
                                                        false,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 툴바 영역은 항상 동일 높이로 확보하여 커버/캔버스의 위아래 위치가 변하지 않도록 한다.
                        // 툴바 영역은 충분한 고정 높이(옵시티 슬라이더 포함)를 확보해서
                        // RenderFlex overflow가 발생하지 않도록 한다.
                        SizedBox(
                          height: 72.h,
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: SnapFitMotion.medium,
                              switchInCurve: SnapFitMotion.entrance,
                              switchOutCurve: Curves.easeInCubic,
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
                        ),

                        if (_currentMode != EditorMode.none)
                          Padding(
                            key: const Key('editorAtelierPanel'),
                            padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 10.h),
                            child: _EditorToolPanelReveal(
                              child: _buildInlineToolPanel(
                                context,
                                _currentMode,
                                layers,
                              ),
                            ),
                          ),

                        // Bottom Menu (고정)
                        Padding(
                          padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 8.h),
                          child: SnapFitFadeIn(
                            key: const Key('pageEditorDockReveal'),
                            delay: const Duration(milliseconds: 140),
                            beginOffset: const Offset(0, 0.055),
                            child: EditorBottomMenu(
                              currentMode: _currentMode,
                              isCover: currentPageIndex == 0,
                              showCoverMenuItem: false,
                              canUndo: canUndo,
                              canRedo: canRedo,
                              onUndo: () {
                                vm.undo();
                                _interaction.clearSelection();
                                if (mounted) setState(() {});
                              },
                              onRedo: () {
                                vm.redo();
                                _interaction.clearSelection();
                                if (mounted) setState(() {});
                              },
                              onModeChanged: (mode) =>
                                  _handleModeChange(mode, layers),
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
                              onCover: () =>
                                  _toolbarActionHandler.openCoverTheme(),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              if (_showEditorHint &&
                  !_isSaving &&
                  _interaction.selectedLayerId == null)
                _buildEditorHint(context, isCover: currentPageIndex == 0),

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

  Widget _buildEditorStudioBackground(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: SnapFitColors.readerGradientOf(context),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -78.h,
              right: -54.w,
              child: _AmbientOrb(
                size: 190.w,
                color: const Color(
                  0xFFE8D4B8,
                ).withOpacity(isDark ? 0.10 : 0.30),
              ),
            ),
            Positioned(
              top: 130.h,
              left: -86.w,
              child: _AmbientOrb(
                size: 230.w,
                color: const Color(
                  0xFFD6B892,
                ).withOpacity(isDark ? 0.10 : 0.20),
              ),
            ),
            Positioned(
              bottom: 76.h,
              right: -92.w,
              child: _AmbientOrb(
                size: 250.w,
                color: SnapFitColors.deepCharcoal.withOpacity(
                  isDark ? 0.10 : 0.06,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspaceFrame(BuildContext context, {required Widget child}) {
    final isDark = SnapFitColors.isDark(context);
    return Container(
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22.r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [Colors.white.withOpacity(0.09), Colors.white.withOpacity(0.03)]
              : [
                  Colors.white.withOpacity(0.74),
                  const Color(0xFFFFF8F1).withOpacity(0.78),
                  const Color(0xFFEFE2D0).withOpacity(0.50),
                ],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.10)
              : SnapFitColors.deepCharcoal.withOpacity(0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.30 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFFD6B892).withOpacity(isDark ? 0.08 : 0.10),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(18.r), child: child),
    );
  }

  Widget _buildEditorHint(BuildContext context, {required bool isCover}) {
    return Positioned(
      top: 104.h,
      left: 20.w,
      right: 20.w,
      child: IgnorePointer(
        child: SnapFitFadeIn(
          delay: const Duration(milliseconds: 220),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: SnapFitColors.surfaceOf(context).withOpacity(0.94),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: SnapFitColors.overlayLightOf(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 34.w,
                  height: 34.w,
                  decoration: BoxDecoration(
                    color: SnapFitColors.accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.touch_app_outlined,
                    size: 18.sp,
                    color: SnapFitColors.accent,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    isCover
                        ? '표지에 담을 사진과 제목을 더해 첫인상을 완성해보세요.'
                        : '사진을 넣고 레이아웃을 고르면 한 쪽의 이야기가 시작돼요.',
                    style: TextStyle(
                      color: SnapFitColors.textSecondaryOf(context),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
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

  Widget _buildInlineToolPanel(
    BuildContext context,
    EditorMode mode,
    List<LayerModel> layers,
  ) {
    final title = switch (mode) {
      EditorMode.layout => '레이아웃',
      EditorMode.template => '템플릿',
      EditorMode.layer => '레이어',
      EditorMode.sticker => '스티커',
      EditorMode.backgroundColor => '배경',
      _ => '',
    };
    final panel = switch (mode) {
      EditorMode.sticker => const DecoratePanel(
        mode: DecorateSheetMode.sticker,
      ),
      EditorMode.backgroundColor => const DecoratePanel(
        mode: DecorateSheetMode.backgroundColor,
      ),
      EditorMode.layer => LayerManagerPanel(
        layers: layers,
        interaction: _interaction,
      ),
      EditorMode.layout => const TemplateSelectionPanel(title: '레이아웃'),
      EditorMode.template => const DesignTemplatePanel(closeOnApply: false),
      _ => const SizedBox.shrink(),
    };

    return _InlineEditorAtelierPanel(
      title: title,
      onClose: () => setState(() => _currentMode = EditorMode.none),
      child: panel,
    );
  }

  void _handleModeChange(EditorMode mode, List<LayerModel> layers) {
    if (_showEditorHint) {
      setState(() => _showEditorHint = false);
    }
    if (mode == EditorMode.none) {
      setState(() => _currentMode = mode);
      return;
    }

    if (mode == EditorMode.text) {
      setState(() => _currentMode = EditorMode.none);
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
  }
}

class _EditorToolPanelReveal extends StatelessWidget {
  const _EditorToolPanelReveal({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: SnapFitMotion.entrance,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - value)),
            child: Transform.scale(
              scale: 0.985 + (0.015 * value),
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class _InlineEditorAtelierPanel extends StatelessWidget {
  const _InlineEditorAtelierPanel({
    required this.title,
    required this.onClose,
    required this.child,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 0.48.sh,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xF21A1E26) : const Color(0xF7FFFCF7),
          borderRadius: BorderRadius.circular(28.r),
          border: Border.all(color: SnapFitColors.overlayLightOf(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.32 : 0.12),
              blurRadius: 26,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28.r),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: SnapFitMotion.fast,
                  switchInCurve: SnapFitMotion.entrance,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(key: ValueKey(title), child: child),
                ),
              ),
              Positioned(
                top: 8.h,
                right: 8.w,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: SnapFitColors.surfaceOf(context).withOpacity(0.82),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: SnapFitColors.overlayLightOf(context),
                    ),
                  ),
                  child: IconButton(
                    tooltip: '$title 닫기',
                    visualDensity: VisualDensity.compact,
                    onPressed: onClose,
                    icon: Icon(
                      Icons.close_rounded,
                      color: SnapFitColors.textSecondaryOf(context),
                      size: 20.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _AmbientOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(color: color, blurRadius: 70, spreadRadius: 28),
          ],
        ),
      ),
    );
  }
}

class _EditorMiniHistoryButton extends StatelessWidget {
  const _EditorMiniHistoryButton({
    required this.icon,
    required this.enabled,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SnapFitPressable(
        onTap: enabled ? onTap : null,
        pressedScale: 0.94,
        borderRadius: BorderRadius.circular(999.r),
        child: AnimatedOpacity(
          duration: SnapFitMotion.fast,
          opacity: enabled ? 1 : 0.34,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.62),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.76)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(icon, size: 19, color: const Color(0xFF171717)),
          ),
        ),
      ),
    );
  }
}
