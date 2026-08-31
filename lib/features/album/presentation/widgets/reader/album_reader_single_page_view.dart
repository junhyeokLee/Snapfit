import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:book_page_flip/book_page_flip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/cover_theme.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/album_page.dart';
import '../../../domain/entities/layer.dart';
import '../../controllers/layer_builder.dart';
import '../../controllers/layer_interaction_manager.dart';
import '../../views/album_reader_inner_detail_screen.dart';
import '../../views/page_editor_screen.dart';
import '../cover/cover.dart';
import '../home/home_cover_frame.dart';
import 'book_page_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 앨범 리더 단일 페이지 뷰
///
/// PageView에서 한 장씩 표시하되:
///   - 같은 쌍(1-2, 3-4, 5-6) 내에서는 서로 살짝 peek 허용
///   - 쌍 경계(2→3, 4→5)는 3D 책 넘기기로 전환
///   - 쌍이 다른 페이지는 완전히 숨겨 겹침 방지
class AlbumReaderSinglePageView extends ConsumerStatefulWidget {
  /// 모든 페이지 (0 = 커버, 1~ = 내지)
  final List<AlbumPage> allPages;
  final CoverSize selectedCover;
  final CoverTheme coverTheme;
  final PageController pageController;
  final LayerInteractionManager interaction;
  final LayerBuilder layerBuilder;
  final GlobalKey canvasKey;
  final ValueChanged<Size> onCanvasSizeChanged;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onStateChanged;
  final double maxSpreadWidthFactor;
  final Alignment contentAlignment;
  final bool focusMode;
  final ValueChanged<int>? onFocusPageChanged;
  final double focusBottomInset;
  final int? requestedFocusPageIndex;

  const AlbumReaderSinglePageView({
    super.key,
    required this.allPages,
    required this.selectedCover,
    required this.coverTheme,
    required this.pageController,
    required this.interaction,
    required this.layerBuilder,
    required this.canvasKey,
    required this.onCanvasSizeChanged,
    required this.onPageChanged,
    required this.onStateChanged,
    this.maxSpreadWidthFactor = 1.0,
    this.contentAlignment = Alignment.center,
    this.focusMode = false,
    this.onFocusPageChanged,
    this.focusBottomInset = 0,
    this.requestedFocusPageIndex,
  });

  @override
  ConsumerState<AlbumReaderSinglePageView> createState() =>
      _AlbumReaderSinglePageViewState();
}

class _AlbumReaderSinglePageViewState
    extends ConsumerState<AlbumReaderSinglePageView> {
  static const double _bookFlipControlVelocity = 0.02;
  static const double _bookFlipListVelocity = 6.8;
  static const BookFlipPhysics _bookFlipPhysics = BookFlipPhysics(
    springStiffness: 56,
    springDampingRatio: 1.08,
    commitThreshold: 0.44, // 높을수록 페이지를 더 많이 끌어야 넘어감
    commitVelocity: 3.2, // 높을수록 짧게 휙 하는 손동작으로는 덜 넘어감
    velocityLookAhead: 0.012, // 손을 땔 때 속도 예측 영향을 줄여서 조금 움직였는데도 넘어가는 현상 감소
    settleEpsilon: 0.11,
  );
  static const BookFlipPhysics _bookFlipControlPhysics = BookFlipPhysics(
    springStiffness: 64,
    springDampingRatio: 1.06,
    commitThreshold: 0.44,
    commitVelocity: 3.2,
    velocityLookAhead: 0.012,
    settleEpsilon: 0.14,
  );
  static const BookFlipPhysics _bookFlipListPhysics = BookFlipPhysics(
    springStiffness: 3400,
    springDampingRatio: 1.08,
    commitThreshold: 0.56,
    commitVelocity: 1.65,
    velocityLookAhead: 0.06,
    settleEpsilon: 0.98,
  );
  static const double _openSpreadCommitDistance = 136.0;
  static const double _openSpreadCommitVelocity = 420.0;
  static const double _openSpreadDragProgressScale = 0.64;

  bool _isCoverPressed = false;
  bool _isTurningWithControl = false;
  late int _focusPageIndex;
  late final BookFlipController _bookFlipController;
  int? _requestedFocusPage;
  bool _syncingSpreadFromFocus = false;
  int? _animatedTargetSpread;
  Completer<void>? _flipEndCompleter;
  bool _isAnimatingToRequestedSpread = false;
  bool _isCoverFlipActive = false;
  int _coverFlipDirection = 0;
  bool _isDraggingOpenSpread = false;
  int? _openSpreadPointer;
  Offset _openSpreadStartLocal = Offset.zero;
  Offset _openSpreadLastLocal = Offset.zero;
  double _openSpreadTotalDx = 0;
  int _openSpreadStartMicros = 0;
  int _openSpreadStartSpread = 0;
  int _openSpreadDirection = 0;
  bool _suppressNextTapUp = false;
  final GlobalKey _bookFlipCoverBoundaryKey = GlobalKey(
    debugLabel: 'book_flip_cover_boundary',
  );
  final GlobalKey _bookFlipCoverBackBoundaryKey = GlobalKey(
    debugLabel: 'book_flip_cover_back_boundary',
  );
  final GlobalKey _bookFlipFallbackCoverBoundaryKey = GlobalKey(
    debugLabel: 'book_flip_fallback_cover_boundary',
  );

  BookFlipPhysics get _activeBookFlipPhysics => _isAnimatingToRequestedSpread
      ? _bookFlipListPhysics
      : _isTurningWithControl
      ? _bookFlipControlPhysics
      : _bookFlipPhysics;

  @override
  void initState() {
    super.initState();
    _focusPageIndex = _focusPageForSpread(widget.pageController.initialPage);
    _bookFlipController = BookFlipController(
      initialSpread: widget.pageController.initialPage,
    );
    widget.pageController.addListener(_syncFocusFromSpread);
  }

  @override
  void dispose() {
    widget.pageController.removeListener(_syncFocusFromSpread);
    _bookFlipController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AlbumReaderSinglePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.focusMode) return;
    final requested = widget.requestedFocusPageIndex;
    if (requested == null ||
        requested == oldWidget.requestedFocusPageIndex ||
        requested == _focusPageIndex) {
      return;
    }

    final target =
        requested.clamp(0, math.max(0, widget.allPages.length - 1)) as int;
    _animateFocusToPage(target);
  }

  void onStateChanged() {
    if (mounted) widget.onStateChanged();
  }

  int _focusPageForSpread(int spreadIndex) {
    if (spreadIndex <= 0) return 0;
    return (1 + ((spreadIndex - 1) * 2)).clamp(
      0,
      math.max(0, widget.allPages.length - 1),
    );
  }

  int _spreadForFocusPage(int pageIndex) {
    if (pageIndex <= 0) return 0;
    return 1 + ((pageIndex - 1) ~/ 2);
  }

  int get _bookPageCount {
    final count = widget.allPages.length + 1;
    return count.isEven ? count : count + 1;
  }

  int get _bookSpreadCount => math.max(1, _bookPageCount ~/ 2);

  void _syncFocusFromSpread() {
    if (!widget.focusMode ||
        _syncingSpreadFromFocus ||
        !widget.pageController.hasClients) {
      return;
    }
    final target = _focusPageForSpread(
      (widget.pageController.page ?? 0).round(),
    );
    if (target == _focusPageIndex || target == _requestedFocusPage) return;
    _requestedFocusPage = target;
    setState(() {
      _focusPageIndex = target;
      _bookFlipController.goToSpread(_spreadForFocusPage(target));
    });
    _requestedFocusPage = null;
  }

  Future<void> _syncSpreadFromFocus(int pageIndex) async {
    if (!widget.focusMode || !widget.pageController.hasClients) {
      widget.onFocusPageChanged?.call(pageIndex);
      return;
    }

    final targetSpread = _spreadForFocusPage(pageIndex);
    final currentSpread = (widget.pageController.page ?? 0).round();
    if (targetSpread != currentSpread) {
      _syncingSpreadFromFocus = true;
      try {
        widget.pageController.jumpToPage(targetSpread);
      } finally {
        _syncingSpreadFromFocus = false;
      }
    }
    widget.onFocusPageChanged?.call(pageIndex);
  }

  Future<void> _turnFocusPage(int direction) async {
    if (widget.allPages.isEmpty) return;

    final currentSpread = _spreadForFocusPage(_focusPageIndex);
    final maxSpread =
        math.max(_bookSpreadCount, _bookFlipController.totalSpreads) - 1;
    final targetSpread = (currentSpread + direction).clamp(0, maxSpread);
    if (targetSpread == currentSpread) return;

    if (_bookFlipController.isAnimating) return;
    if (_bookFlipController.isReady &&
        _bookFlipController.currentSpread != currentSpread) {
      _bookFlipController.goToSpread(currentSpread);
    }

    final isCoverEdgeFlip =
        (currentSpread <= 0 && direction > 0) ||
        (currentSpread == 1 && direction < 0);

    if (isCoverEdgeFlip) {
      setState(() {
        _isTurningWithControl = true;
        _isCoverFlipActive = true;
        _coverFlipDirection = direction;
        _bookFlipController.goToSpread(currentSpread);
      });
      await WidgetsBinding.instance.endOfFrame;
      await _waitForBookFlipReady();
    } else {
      setState(() {
        _isTurningWithControl = true;
        _isCoverFlipActive = false;
        _coverFlipDirection = 0;
      });
      await WidgetsBinding.instance.endOfFrame;
    }

    final flipEnd = isCoverEdgeFlip ? _waitForFlipEnd() : null;
    final started = direction > 0
        ? _bookFlipController.nextSpread(velocity: _bookFlipControlVelocity)
        : _bookFlipController.previousSpread(
            velocity: -_bookFlipControlVelocity,
          );
    if (started) {
      if (flipEnd != null) {
        var completed = true;
        await flipEnd.timeout(
          const Duration(milliseconds: 1600),
          onTimeout: () {
            completed = false;
          },
        );
        if (mounted) {
          _clearFlipEndWaiter();
          final settledSpread =
              (completed ? targetSpread : _bookFlipController.currentSpread)
                      .clamp(0, math.max(0, _bookSpreadCount - 1))
                  as int;
          final visiblePage = _focusPageForSpread(settledSpread);
          setState(() {
            _focusPageIndex = visiblePage;
            _isTurningWithControl = false;
            _isCoverFlipActive = false;
            _coverFlipDirection = 0;
            _isDraggingOpenSpread = false;
            _bookFlipController.goToSpread(settledSpread);
          });
          await _syncSpreadFromFocus(visiblePage);
        }
      }
      return;
    }
    if (isCoverEdgeFlip) {
      _clearFlipEndWaiter();
    }

    final syncedTarget = _focusPageForSpread(targetSpread);
    setState(() {
      _focusPageIndex = syncedTarget;
      _isTurningWithControl = false;
      _isCoverFlipActive = false;
      _coverFlipDirection = 0;
      _bookFlipController.goToSpread(targetSpread);
    });
    await _syncSpreadFromFocus(syncedTarget);
  }

  Future<void> _animateFocusToPage(int pageIndex) async {
    if (!widget.focusMode || widget.allPages.isEmpty) return;

    _animatedTargetSpread = _spreadForFocusPage(pageIndex);
    if (_isAnimatingToRequestedSpread) return;

    setState(() => _isAnimatingToRequestedSpread = true);
    await WidgetsBinding.instance.endOfFrame;
    try {
      final targetSpread =
          _animatedTargetSpread!.clamp(0, math.max(0, _bookSpreadCount - 1))
              as int;
      final currentSpread = _bookFlipController.totalSpreads > 0
          ? _bookFlipController.currentSpread
          : _spreadForFocusPage(_focusPageIndex);

      if (currentSpread == targetSpread) {
        await _finishAnimatedSpreadJump(targetSpread);
        return;
      }

      if (_bookFlipController.isAnimating) {
        await _waitForFlipEnd().timeout(
          const Duration(milliseconds: 70),
          onTimeout: () {},
        );
      }

      final distance = (targetSpread - currentSpread).abs();
      final visualTurnCount = math.min(distance, 5);

      for (var turn = 1; mounted && turn <= visualTurnCount; turn += 1) {
        final latestTarget =
            (_animatedTargetSpread ?? targetSpread).clamp(
                  0,
                  math.max(0, _bookSpreadCount - 1),
                )
                as int;
        final remainingTurns = visualTurnCount - turn + 1;
        final spreadNow = _bookFlipController.totalSpreads > 0
            ? _bookFlipController.currentSpread
            : _spreadForFocusPage(_focusPageIndex);
        final remainingDistance = (latestTarget - spreadNow).abs();
        if (remainingDistance == 0) break;

        final hop = math.max(1, (remainingDistance / remainingTurns).ceil());
        final fromSpread = (latestTarget > spreadNow)
            ? math.min(latestTarget - 1, spreadNow + hop - 1)
            : math.max(latestTarget + 1, spreadNow - hop + 1);

        if (fromSpread != spreadNow) {
          _bookFlipController.goToSpread(fromSpread);
          setState(() {
            _focusPageIndex = _focusPageForSpread(fromSpread);
            _isCoverFlipActive = false;
            _coverFlipDirection = 0;
          });
          await _syncSpreadFromFocus(_focusPageForSpread(fromSpread));
          await Future<void>.delayed(const Duration(milliseconds: 8));
        }

        final turnDirection = latestTarget > fromSpread ? 1 : -1;
        final flipEnd = _waitForFlipEnd();
        final started = turnDirection > 0
            ? _bookFlipController.nextSpread(velocity: _bookFlipListVelocity)
            : _bookFlipController.previousSpread(
                velocity: -_bookFlipListVelocity,
              );

        if (!started) {
          _clearFlipEndWaiter();
          break;
        }

        await flipEnd.timeout(
          const Duration(milliseconds: 58),
          onTimeout: () {},
        );
      }

      final finalTarget =
          (_animatedTargetSpread ?? targetSpread).clamp(
                0,
                math.max(0, _bookSpreadCount - 1),
              )
              as int;
      await _finishAnimatedSpreadJump(finalTarget);
    } finally {
      if (mounted) {
        setState(() => _isAnimatingToRequestedSpread = false);
      } else {
        _isAnimatingToRequestedSpread = false;
      }
    }
  }

  Future<void> _finishAnimatedSpreadJump(int spread) async {
    if (!mounted) return;

    final targetPage = _focusPageForSpread(spread);
    _animatedTargetSpread = null;
    setState(() {
      _focusPageIndex = targetPage;
      _isCoverFlipActive = false;
      _coverFlipDirection = 0;
      _isDraggingOpenSpread = false;
      _bookFlipController.goToSpread(spread);
    });
    await _syncSpreadFromFocus(targetPage);
  }

  Future<void> _waitForFlipEnd() {
    final pending = _flipEndCompleter;
    if (pending != null && !pending.isCompleted) return pending.future;

    final completer = Completer<void>();
    _flipEndCompleter = completer;
    return completer.future;
  }

  Future<void> _waitForBookFlipReady() async {
    if (_bookFlipController.isReady) return;

    for (var tick = 0; mounted && tick < 24; tick += 1) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (_bookFlipController.isReady) return;
    }
  }

  void _clearFlipEndWaiter() {
    final completer = _flipEndCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _flipEndCompleter = null;
  }

  Future<void> _openFocusEditor() async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PageEditorScreen(initialPageIndex: _focusPageIndex),
      ),
    );
  }

  void _openFocusDetail({
    required double tapX,
    required double stageWidth,
    required double pageWidth,
    required double pageHeight,
  }) {
    final spread = _bookFlipController.totalSpreads > 0
        ? _bookFlipController.currentSpread
        : _spreadForFocusPage(_focusPageIndex);
    if (spread <= 0 || widget.allPages.length <= 1) return;

    final leftPageIndex = 1 + ((spread - 1) * 2);
    final rightPageIndex = leftPageIndex + 1;
    var targetPageIndex = tapX < stageWidth / 2
        ? leftPageIndex
        : rightPageIndex;
    if (targetPageIndex >= widget.allPages.length) {
      targetPageIndex = widget.allPages.length - 1;
    }

    setState(() => _focusPageIndex = targetPageIndex);
    _openInnerDetail(
      screenW: stageWidth,
      singlePageW: pageWidth,
      singlePageH: pageHeight,
      spreadIndex: spread,
      tapX: tapX,
    );
  }

  Widget _buildFocusCard(
    int pageIndex,
    double pageWidth,
    double pageHeight, {
    Key? cardKey,
    GlobalKey? coverBoundaryKey,
  }) {
    final page = widget.allPages[pageIndex];
    if (pageIndex == 0) {
      return _CoverPageCard(
        key: cardKey ?? GlobalObjectKey(page),
        page: page,
        pageW: pageWidth,
        pageH: pageHeight,
        selectedCover: widget.selectedCover,
        coverTheme: widget.coverTheme,
        interaction: widget.interaction,
        layerBuilder: widget.layerBuilder,
        coverKey: coverBoundaryKey ?? widget.canvasKey,
        onCoverSizeChanged: widget.onCanvasSizeChanged,
      );
    }

    return _InnerPageCard(
      key: cardKey ?? ValueKey('focus_inner_page_${page.id}'),
      page: page,
      pageW: pageWidth,
      pageH: pageHeight,
      interaction: widget.interaction,
      layerBuilder: widget.layerBuilder,
    );
  }

  Widget _buildBookFlipPage(
    int bookPageIndex,
    double pageWidth,
    double pageHeight,
  ) {
    if (bookPageIndex == 0) {
      return SizedBox(
        width: pageWidth,
        height: pageHeight,
        child: _buildFocusCard(
          0,
          pageWidth,
          pageHeight,
          cardKey: const ValueKey('book_flip_cover_back_page'),
          coverBoundaryKey: _bookFlipCoverBackBoundaryKey,
        ),
      );
    }
    if (bookPageIndex > widget.allPages.length) {
      return _BlankBookPage(pageWidth: pageWidth, pageHeight: pageHeight);
    }

    final albumPageIndex = bookPageIndex - 1;
    return SizedBox(
      width: pageWidth,
      height: pageHeight,
      child: _buildFocusCard(
        albumPageIndex,
        pageWidth,
        pageHeight,
        cardKey: ValueKey('book_flip_album_page_$albumPageIndex'),
        coverBoundaryKey: albumPageIndex == 0
            ? _bookFlipCoverBoundaryKey
            : null,
      ),
    );
  }

  Widget _buildStaticFocusSpread(double pageWidth, double pageHeight) {
    final spread = _spreadForFocusPage(_focusPageIndex);
    return _buildStaticBookSpread(spread, pageWidth, pageHeight);
  }

  Widget _buildStaticBookSpread(
    int spread,
    double pageWidth,
    double pageHeight,
  ) {
    if (spread <= 0) {
      return Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: pageWidth,
          height: pageHeight,
          child: _buildFocusCard(
            0,
            pageWidth,
            pageHeight,
            cardKey: const ValueKey('book_flip_fallback_cover_card'),
            coverBoundaryKey: _bookFlipFallbackCoverBoundaryKey,
          ),
        ),
      );
    }

    final leftBookPage = spread * 2;
    final rightBookPage = leftBookPage + 1;

    return Row(
      children: [
        SizedBox(
          width: pageWidth,
          height: pageHeight,
          child: _buildBookFlipPage(leftBookPage, pageWidth, pageHeight),
        ),
        SizedBox(
          width: pageWidth,
          height: pageHeight,
          child: _buildBookFlipPage(rightBookPage, pageWidth, pageHeight),
        ),
      ],
    );
  }

  void _handleBookSpreadChanged(int spread, {required bool ended}) {
    if (!ended) return;

    final target = _focusPageForSpread(spread);
    if (!mounted) return;
    setState(() {
      _focusPageIndex = target;
      _isTurningWithControl = false;
      _isCoverFlipActive = false;
      _coverFlipDirection = 0;
      _isDraggingOpenSpread = false;
    });
    unawaited(_syncSpreadFromFocus(target));
    _clearFlipEndWaiter();
  }

  void _handleOpenSpreadPointerDown(PointerDownEvent event) {
    if ((_isCoverFlipActive || _isTurningWithControl) &&
        !_bookFlipController.isAnimating) {
      setState(() {
        _isCoverFlipActive = false;
        _isTurningWithControl = false;
        _coverFlipDirection = 0;
      });
    }
    if (_isCoverFlipActive || _isTurningWithControl) return;
    if (!_bookFlipController.isReady) return;
    if (_openSpreadPointer != null) return;
    final currentSpread = _bookFlipController.totalSpreads > 0
        ? _bookFlipController.currentSpread
        : _spreadForFocusPage(_focusPageIndex);
    if (_bookFlipController.currentSpread != currentSpread) {
      _bookFlipController.goToSpread(currentSpread);
    }
    final started = _bookFlipController.dragStart(event.localPosition);
    if (!started || !mounted) return;
    _openSpreadPointer = event.pointer;
    _openSpreadStartLocal = event.localPosition;
    _openSpreadLastLocal = event.localPosition;
    _openSpreadTotalDx = 0;
    _openSpreadStartMicros = event.timeStamp.inMicroseconds;
    _openSpreadStartSpread = currentSpread;
    _openSpreadDirection = 0;
    setState(() {
      _isDraggingOpenSpread = true;
      _suppressNextTapUp = false;
    });
  }

  void _handleOpenSpreadPointerMove(PointerMoveEvent event) {
    if (!_isDraggingOpenSpread || event.pointer != _openSpreadPointer) return;
    final dx = event.localPosition.dx - _openSpreadLastLocal.dx;
    _openSpreadLastLocal = event.localPosition;
    _openSpreadTotalDx += dx;
    if (_openSpreadTotalDx.abs() > 8) {
      _suppressNextTapUp = true;
    }
    if (_openSpreadDirection == 0 && _openSpreadTotalDx.abs() > 14) {
      _openSpreadDirection = _openSpreadTotalDx < 0 ? 1 : -1;
      final maxSpread =
          math.max(_bookSpreadCount, _bookFlipController.totalSpreads) - 1;
      final targetSpread = (_openSpreadStartSpread + _openSpreadDirection)
          .clamp(0, maxSpread);
      final isCoverEdgeFlip =
          (_openSpreadStartSpread <= 0 && _openSpreadDirection > 0) ||
          (_openSpreadStartSpread == 1 && _openSpreadDirection < 0);
      if (isCoverEdgeFlip &&
          targetSpread != _openSpreadStartSpread &&
          mounted) {
        setState(() {
          _isCoverFlipActive = true;
          _coverFlipDirection = _openSpreadDirection;
        });
      }
    }
    if (_openSpreadDirection != 0) {
      _bookFlipController.dragToDistance(
        localPosition: _openSpreadStartLocal,
        direction: _openSpreadDirection > 0
            ? FlipDirection.forward
            : FlipDirection.backward,
        distance: _openSpreadTotalDx.abs() * _openSpreadDragProgressScale,
      );
    }
  }

  void _handleOpenSpreadPointerUp(PointerUpEvent event) {
    if (!_isDraggingOpenSpread || event.pointer != _openSpreadPointer) return;
    final elapsedSeconds =
        (event.timeStamp.inMicroseconds - _openSpreadStartMicros) / 1000000.0;
    final velocity = elapsedSeconds > 0
        ? _openSpreadTotalDx / elapsedSeconds
        : 0.0;
    final shouldCommit =
        _openSpreadTotalDx.abs() >= _openSpreadCommitDistance ||
        velocity.abs() >= _openSpreadCommitVelocity;
    _bookFlipController.dragEndWithDecision(velocity, commit: shouldCommit);
    _openSpreadPointer = null;
    _openSpreadStartLocal = Offset.zero;
    _openSpreadLastLocal = Offset.zero;
    _openSpreadTotalDx = 0;
    _openSpreadStartMicros = 0;
    _openSpreadStartSpread = 0;
    _openSpreadDirection = 0;
    if (mounted) setState(() => _isDraggingOpenSpread = false);
  }

  void _handleOpenSpreadPointerCancel(PointerCancelEvent event) {
    if (!_isDraggingOpenSpread || event.pointer != _openSpreadPointer) return;
    _bookFlipController.dragCancel();
    _openSpreadPointer = null;
    _openSpreadStartLocal = Offset.zero;
    _openSpreadLastLocal = Offset.zero;
    _openSpreadTotalDx = 0;
    _openSpreadStartMicros = 0;
    _openSpreadStartSpread = 0;
    _openSpreadDirection = 0;
    if (mounted) setState(() => _isDraggingOpenSpread = false);
  }

  Widget _buildBookFlipFocusReader(
    double pageWidth,
    double pageHeight, {
    bool silentFallback = false,
  }) {
    Widget fallbackSpread(BuildContext context) => silentFallback
        ? SizedBox(width: pageWidth * 2, height: pageHeight)
        : _BookFlipLoadingPlaceholder(
            pageWidth: pageWidth,
            pageHeight: pageHeight,
            showPaper: _spreadForFocusPage(_focusPageIndex) > 0,
            child: _buildStaticFocusSpread(pageWidth, pageHeight),
          );

    return BookFlip.builder(
      key: ValueKey(
        'book_flip_${_bookPageCount}_${pageWidth.toStringAsFixed(1)}_${pageHeight.toStringAsFixed(1)}',
      ),
      pageCount: _bookPageCount,
      pageSize: Size(pageWidth, pageHeight),
      pixelRatio: 1.0,
      pageBuilder: (context, index) =>
          _buildBookFlipPage(index, pageWidth, pageHeight),
      controller: _bookFlipController,
      physics: _activeBookFlipPhysics,
      fit: BookFit.contain,
      transparentPages: const <int>{0},
      material: const BookFlipMaterial(
        stiffness: 0.28,
        weight: 0.34,
        gloss: 0.0,
        translucency: 0.0,
        thickness: 1.05,
      ),
      curl: _isCoverFlipActive
          ? const BookFlipCurl(bend: 0.98, foldTilt: 0.86, droop: 0.34)
          : const BookFlipCurl(bend: 0.74, foldTilt: 0.62, droop: 0.28),
      effects: const BookFlipEffects(
        gloss: false,
        grain: false,
        castShadow: true,
        spineShadow: false,
        edge: false,
        translucency: false,
      ),
      meshResolution: 54,
      onFlipStart: (spread, direction) {
        final isCoverEdgeFlip =
            (spread <= 0 && direction == FlipDirection.forward) ||
            (spread == 1 && direction == FlipDirection.backward);
        if (!isCoverEdgeFlip || !mounted) return;
        final coverDirection = direction == FlipDirection.forward ? 1 : -1;
        if (_isCoverFlipActive && _coverFlipDirection == coverDirection) {
          return;
        }
        setState(() {
          _isCoverFlipActive = true;
          _coverFlipDirection = coverDirection;
        });
      },
      onFlipEnd: (spread) => _handleBookSpreadChanged(spread, ended: true),
      loadingBuilder: fallbackSpread,
      errorBuilder: fallbackSpread,
    );
  }

  Widget _buildFocusReader(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = constraints.biggest;
        final media = MediaQuery.of(context);
        final ratio = widget.selectedCover.ratio;
        final bottomInset = math.max(
          widget.focusBottomInset,
          math.max(media.viewPadding.bottom, media.viewInsets.bottom),
        );
        final isLandscape = screen.width > screen.height;
        final railInset = isLandscape ? 72.0 : 0.0;
        final usableHeight = math.max(260.0, screen.height - bottomInset);
        final horizontalMargin = isLandscape ? 34.0 : 48.0;
        final verticalMargin = isLandscape ? 70.0 : 38.0;
        final maxSpreadWidth = screen.width - railInset - horizontalMargin;
        final maxSpreadHeight = usableHeight - verticalMargin;
        var pageHeight = maxSpreadHeight;
        var pageWidth = pageHeight * ratio;
        if (pageWidth * 2 > maxSpreadWidth) {
          pageWidth = maxSpreadWidth / 2;
          pageHeight = pageWidth / ratio;
        }
        final currentSpread = _bookFlipController.totalSpreads > 0
            ? _bookFlipController.currentSpread
            : _spreadForFocusPage(_focusPageIndex);
        final showClosedCover =
            _focusPageIndex == 0 &&
            !_bookFlipController.isAnimating &&
            !_isCoverFlipActive;
        final stageWidth = pageWidth * 2;
        final stageHeight = pageHeight;
        final minTop = isLandscape ? 0.0 : 12.0;
        final centeredTop = (usableHeight - stageHeight) / 2;
        final stageTop = math.max(
          minTop,
          isLandscape ? centeredTop - 20.0 : centeredTop,
        );
        final stageOffsetX = 0.0;

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              top: stageTop,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _bookFlipController,
                  builder: (context, child) {
                    final flipProgress = _bookFlipController.flipProgress.clamp(
                      0.0,
                      1.0,
                    );
                    final coverSettleStart = _coverFlipDirection < 0
                        ? 0.48
                        : 0.68;
                    final delayedCoverProgress =
                        ((flipProgress - coverSettleStart) /
                                (1.0 - coverSettleStart))
                            .clamp(0.0, 1.0);
                    final stageProgress = Curves.easeInOutCubic.transform(
                      delayedCoverProgress,
                    );
                    final coverCenteredOffset = -pageWidth / 2;
                    var dynamicStageOffset = stageOffsetX;
                    if (showClosedCover) {
                      dynamicStageOffset += coverCenteredOffset;
                    } else if (_isCoverFlipActive && _coverFlipDirection != 0) {
                      if (_coverFlipDirection > 0) {
                        dynamicStageOffset += ui.lerpDouble(
                          coverCenteredOffset,
                          0,
                          stageProgress,
                        )!;
                      } else {
                        dynamicStageOffset += ui.lerpDouble(
                          0,
                          coverCenteredOffset,
                          stageProgress,
                        )!;
                      }
                    } else if (currentSpread <= 0 && _focusPageIndex == 0) {
                      dynamicStageOffset += coverCenteredOffset;
                    }

                    return Transform.translate(
                      offset: Offset(dynamicStageOffset, 0),
                      child: child,
                    );
                  },
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 680),
                    curve: Curves.easeInOutCubic,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: stageWidth,
                      height: stageHeight,
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: _handleOpenSpreadPointerDown,
                        onPointerMove: _handleOpenSpreadPointerMove,
                        onPointerUp: _handleOpenSpreadPointerUp,
                        onPointerCancel: _handleOpenSpreadPointerCancel,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: showClosedCover
                              ? () => _turnFocusPage(1)
                              : null,
                          onTapUp: (details) {
                            if (showClosedCover || _isCoverFlipActive) return;
                            if (_suppressNextTapUp) {
                              _suppressNextTapUp = false;
                              return;
                            }
                            _openFocusDetail(
                              tapX: details.localPosition.dx,
                              stageWidth: stageWidth,
                              pageWidth: pageWidth,
                              pageHeight: pageHeight,
                            );
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              AnimatedBuilder(
                                animation: _bookFlipController,
                                builder: (context, bookFlipChild) {
                                  final controllerSpread =
                                      _bookFlipController.currentSpread;
                                  final isCoverEdgeAnimating =
                                      _isCoverFlipActive &&
                                      _bookFlipController.isAnimating &&
                                      _coverFlipDirection > 0 &&
                                      controllerSpread <= 1;
                                  return _PremiumSpreadStage(
                                    isLandscape: isLandscape,
                                    hidePaper:
                                        showClosedCover ||
                                        _isCoverFlipActive ||
                                        isCoverEdgeAnimating,
                                    child:
                                        bookFlipChild ??
                                        const SizedBox.shrink(),
                                  );
                                },
                                child: IgnorePointer(
                                  ignoring: true,
                                  child: Opacity(
                                    opacity: showClosedCover ? 0.02 : 1.0,
                                    child: _buildBookFlipFocusReader(
                                      pageWidth,
                                      pageHeight,
                                      silentFallback: showClosedCover,
                                    ),
                                  ),
                                ),
                              ),
                              if (showClosedCover)
                                IgnorePointer(
                                  child: _PremiumSpreadStage(
                                    isLandscape: isLandscape,
                                    hidePaper: true,
                                    child: _buildStaticFocusSpread(
                                      pageWidth,
                                      pageHeight,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (isLandscape)
              Positioned(
                left: 0,
                right: 0,
                bottom: 6 + bottomInset,
                child: Center(
                  child: SizedBox(
                    width: math.min(326.0, screen.width - railInset - 48),
                    child: _FocusReaderControls(
                      canGoBack:
                          _spreadForFocusPage(_focusPageIndex) > 0 ||
                          _bookFlipController.currentSpread > 0,
                      canGoForward:
                          _spreadForFocusPage(_focusPageIndex) <
                              _bookSpreadCount - 1 ||
                          _bookFlipController.currentSpread <
                              _bookSpreadCount - 1,
                      onPrevious: () => _turnFocusPage(-1),
                      onEdit: _openFocusEditor,
                      onNext: () => _turnFocusPage(1),
                    ),
                  ),
                ),
              )
            else
              Positioned(
                left: 0,
                right: 0,
                bottom: bottomInset + 8,
                child: Center(
                  child: SizedBox(
                    width: math.min(342.0, screen.width - 48),
                    child: _FocusReaderControls(
                      canGoBack:
                          _spreadForFocusPage(_focusPageIndex) > 0 ||
                          _bookFlipController.currentSpread > 0,
                      canGoForward:
                          _spreadForFocusPage(_focusPageIndex) <
                              _bookSpreadCount - 1 ||
                          _bookFlipController.currentSpread <
                              _bookSpreadCount - 1,
                      onPrevious: () => _turnFocusPage(-1),
                      onEdit: _openFocusEditor,
                      onNext: () => _turnFocusPage(1),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _turnSpread({
    required int direction,
    required int itemCount,
  }) async {
    if (_isTurningWithControl || !widget.pageController.hasClients) return;

    final current = (widget.pageController.page ?? 0).round();
    final target = (current + direction).clamp(0, itemCount - 1);
    if (target == current) return;

    setState(() => _isTurningWithControl = true);
    try {
      // Uses the same controller as a finger swipe, keeping the existing
      // renderer, page pairing, and thumbnail selection in lockstep.
      await widget.pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 620),
        curve: Curves.easeOutCubic,
      );
    } finally {
      if (mounted) setState(() => _isTurningWithControl = false);
    }
  }

  void _openInnerDetail({
    required double screenW,
    required double singlePageW,
    required double singlePageH,
    required int spreadIndex,
    double? tapX,
  }) {
    if (spreadIndex <= 0) return;

    final leftIndex = 1 + (spreadIndex - 1) * 2;
    final rightIndex = leftIndex + 1;

    int tappedPageIdx = tapX == null || tapX < screenW / 2
        ? leftIndex
        : rightIndex;

    if (tappedPageIdx >= widget.allPages.length) {
      tappedPageIdx = widget.allPages.length - 1;
    }

    final innerPages = widget.allPages.sublist(1);
    final innerInitialIndex = tappedPageIdx - 1;

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
          opacity: animation,
          child: AlbumReaderInnerDetailScreen(
            innerPages: innerPages,
            initialPageIndex: innerInitialIndex,
            singlePageW: singlePageW,
            singlePageH: singlePageH,
            interaction: widget.interaction,
            layerBuilder: widget.layerBuilder,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.focusMode) return _buildFocusReader(context);

    final screenW = MediaQuery.sizeOf(context).width;
    final screenH = MediaQuery.sizeOf(context).height;

    // 표시 가능한 최대 너비 (여백 포함)
    final availW = (screenW - 20.w) * widget.maxSpreadWidthFactor;

    final double maxH = screenH * 0.62;

    // 단일 페이지 비율
    final coverRatio = widget.selectedCover.ratio;

    // [Size Fix] 모든 앨범의 높이를 '정사각형 2페이지가 화면 가로에 꽉 찼을 때'를 기준으로 통일합니다.
    // 1. 정사각형 2페이지가 가로(availW)에 꽉 차려면, 한 페이지 너비는 availW / 2 가 되어야 합니다.
    // 2. 정사각형이므로 높이 역시 availW / 2 가 됩니다.
    final double singlePageW;
    final double singlePageH;

    if (coverRatio >= 1.0) {
      // [Size Fix] 정사각형(1:1)과 가로형은 펼쳤을 때의 전체 가로 너비(availW)를 동일하게 맞춥니다.
      double w = availW / 2;
      double h = w / coverRatio;
      if (h > maxH) {
        h = maxH;
        w = h * coverRatio;
      }
      singlePageW = w;
      singlePageH = h;
    } else {
      // 세로형은 높이를 정사각형 기준 높이(availW / 2)와 동일하게 맞추어 시각적 일관성을 유지합니다.
      double h = availW / 2;
      if (h > maxH) h = maxH;
      singlePageH = h;
      singlePageW = singlePageH * coverRatio;
    }

    // 아이템 수 계산: 커버(1) + 내지 쌍 개수
    final int innerPageCount = math.max(0, widget.allPages.length - 1);
    final int spreadCount = (innerPageCount / 2).ceil();
    final int itemCount = 1 + spreadCount;

    // 0 미만 바운스 방지
    final safePage =
        (widget.pageController.hasClients
                ? (widget.pageController.page ?? 0.0)
                : 0.0)
            .clamp(0.0, (itemCount - 1).toDouble());

    // 터치 이벤트를 뷰 외곽에 감싸는 PageView 레이어
    final pageView = BookPageView(
      pageController: widget.pageController,
      itemCount: itemCount,
      onPageChanged: (index) {
        widget.onPageChanged(index);
        onStateChanged();
      },
      // PageView는 더 이상 화면 렌더링에 관여하지 않고 터치 제스처와 스크롤 상태만 제공
      itemBuilder: (context, index, offset) {
        return const SizedBox.shrink(); // 터치 인식용 투명 컨테이너
      },
    );

    return Stack(
      alignment: widget.contentAlignment,
      children: [
        // 1. 실제 화면 렌더링 레이어 (터치 비활성)
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: widget.pageController,
              builder: (context, child) {
                final double page = widget.pageController.hasClients
                    ? (widget.pageController.page ?? 0.0)
                    : 0.0;

                // 0 -> 1 전환 구간(커버 펼침) 및 상시 바닥 그림자 처리
                // GPU 스케일 텍스처 재생성 깜박임 방지용 상시 가속 유도 (1.0 -> 0.9999)
                double currentScale = 1;
                double shadowAlpha = 0.15; // 평상시 바닥 기본 그림자 농도를 대폭 상향
                double shadowBlur = 50.0;
                double shadowSpread = 5.0;

                if (page >= 0.0 && page < 1.0) {
                  // page 값이 진행되는 동안 (0.0 ~ 1.0), sin 곡선(0.0 -> 1.0 -> 0.0)을 그림
                  final bounceRatio = math.sin(page * math.pi);
                  currentScale =
                      0.9999 -
                      (bounceRatio *
                          0.12); // 최대 88% 로 작아짐 (0.8799). 1.0 으로 리셋 시 텍스처 파괴(Flicker) 발생 방지
                  shadowAlpha =
                      0.15 + (bounceRatio * 0.1); // 공중 바운스 시 진해짐(0.25)
                  shadowBlur = 50.0 + (bounceRatio * 50.0); // 더 넓게 퍼짐(100.0)
                  shadowSpread = 5.0 + (bounceRatio * 20.0); // 밖으로 크게 번짐
                }

                // 탭다운(누름)에 의한 수동 스케일은 커버가 가만히 있을 때만(0.0) 적용
                if (page == 0.0 && _isCoverPressed) {
                  currentScale = 0.95;
                  shadowAlpha = 0.20;
                  shadowBlur = 30.0;
                  shadowSpread = -5.0;
                }

                return Stack(
                  alignment: widget.contentAlignment,
                  children: [
                    // 앨범 하단에 상시 깔리는 통짜 그림자 (입체감 부여)
                    if (shadowAlpha > 0.01)
                      Container(
                        width: singlePageW * 2, // 펼쳤을 때의 전체 너비
                        height: singlePageH,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: shadowAlpha,
                              ),
                              blurRadius: shadowBlur,
                              spreadRadius: shadowSpread,
                              offset: Offset(0, shadowBlur / 2),
                            ),
                          ],
                        ),
                      ),

                    // 책 자체는 스케일 트랜스폼 처리 (Tween 래퍼를 걷어내어 재빌드 반짝임 원천 차단)
                    Transform.scale(
                      scale: currentScale,
                      child: Align(
                        alignment: widget.contentAlignment,
                        child: _GlobalPageFlipRenderer(
                          page: page,
                          itemCount: itemCount,
                          singleW: singlePageW,
                          doubleH: singlePageH,
                          allPages: widget.allPages,
                          selectedCover: widget.selectedCover,
                          coverTheme: widget.coverTheme,
                          interaction: widget.interaction,
                          layerBuilder: widget.layerBuilder,
                          canvasKey: widget.canvasKey,
                          onCanvasSizeChanged: widget.onCanvasSizeChanged,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        // 2. 터치 제스처 레이어 (PageView)
        Positioned.fill(
          child: GestureDetector(
            onTapDown: (_) {
              if (safePage < 0.5) {
                setState(() => _isCoverPressed = true);
              }
            },
            onTapUp: (details) {
              if (_isCoverPressed) {
                setState(() => _isCoverPressed = false);
              }
              // 내지 영역 탭 시 상세 보기 열기
              if (safePage >= 0.5 &&
                  widget.interaction.selectedLayerId == null) {
                final currentIndex = safePage.round();
                _openInnerDetail(
                  screenW: screenW,
                  singlePageW: singlePageW,
                  singlePageH: singlePageH,
                  spreadIndex: currentIndex,
                  tapX: details.localPosition.dx,
                );
              }
            },
            onTapCancel: () {
              if (_isCoverPressed) {
                setState(() => _isCoverPressed = false);
              }
            },
            onTap: () {
              if (widget.interaction.selectedLayerId != null) {
                widget.interaction.clearSelection();
                onStateChanged();
              } else if (safePage < 0.5) {
                // 커버를 탭하면 첫 스프레드로 펼친 뒤 상세 보기로 바로 이어진다.
                widget.pageController
                    .animateToPage(
                      1,
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeInOutCubic,
                    )
                    .then((_) {
                      if (!mounted) return;
                      if (widget.interaction.selectedLayerId != null) return;
                      _openInnerDetail(
                        screenW: screenW,
                        singlePageW: singlePageW,
                        singlePageH: singlePageH,
                        spreadIndex: 1,
                      );
                    });
              }
            },
            behavior: HitTestBehavior.translucent,
            child: pageView,
          ),
        ),

        // The controls are intentionally above the PageView gesture layer.
        // They drive the same controller rather than introducing a second
        // transition path for button navigation.
        Positioned(
          left: 18.w,
          bottom: 12.h,
          child: AnimatedBuilder(
            animation: widget.pageController,
            builder: (context, _) {
              final current = widget.pageController.hasClients
                  ? (widget.pageController.page ?? 0).round()
                  : 0;
              return _ReaderPageTurnControl(
                icon: Icons.chevron_left_rounded,
                semanticLabel: '이전 스프레드',
                enabled: current > 0 && !_isTurningWithControl,
                onTap: () => _turnSpread(direction: -1, itemCount: itemCount),
              );
            },
          ),
        ),
        Positioned(
          right: 18.w,
          bottom: 12.h,
          child: AnimatedBuilder(
            animation: widget.pageController,
            builder: (context, _) {
              final current = widget.pageController.hasClients
                  ? (widget.pageController.page ?? 0).round()
                  : 0;
              return _ReaderPageTurnControl(
                icon: Icons.chevron_right_rounded,
                semanticLabel: '다음 스프레드',
                enabled: current < itemCount - 1 && !_isTurningWithControl,
                onTap: () => _turnSpread(direction: 1, itemCount: itemCount),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReaderPageTurnControl extends StatelessWidget {
  const _ReaderPageTurnControl({
    required this.icon,
    required this.semanticLabel,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: enabled ? 1 : 0.28,
          child: Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, size: 28.sp, color: const Color(0xFF1B1916)),
          ),
        ),
      ),
    );
  }
}

class _BlankBookPage extends StatelessWidget {
  const _BlankBookPage({required this.pageWidth, required this.pageHeight});

  final double pageWidth;
  final double pageHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: pageWidth,
      height: pageHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF5),
          border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
        ),
      ),
    );
  }
}

class _BookFlipLoadingPlaceholder extends StatelessWidget {
  const _BookFlipLoadingPlaceholder({
    required this.pageWidth,
    required this.pageHeight,
    this.showPaper = true,
    this.child,
  });

  final double pageWidth;
  final double pageHeight;
  final bool showPaper;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final spread = SizedBox(
      width: pageWidth * 2,
      height: pageHeight,
      child: child ?? const SizedBox.shrink(),
    );

    if (!showPaper) return spread;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF5),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: spread,
    );
  }
}

class _PremiumSpreadStage extends StatelessWidget {
  const _PremiumSpreadStage({
    required this.child,
    required this.isLandscape,
    this.hidePaper = false,
  });

  final Widget child;
  final bool isLandscape;
  final bool hidePaper;

  @override
  Widget build(BuildContext context) {
    final floorShadowAlpha = isLandscape ? 0.11 : 0.075;
    final contactShadowAlpha = isLandscape ? 0.13 : 0.09;
    final cardShadowAlpha = isLandscape ? 0.055 : 0.052;
    final spineWidth = isLandscape ? 58.0 : 42.0;
    final spineCreaseWidth = isLandscape ? 18.0 : 13.0;
    final edgeDepth = isLandscape ? 7.0 : 5.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final halfWidth = width / 2;

        if (hidePaper) {
          return ClipRect(child: child);
        }

        Widget pageEdge({required Alignment alignment}) {
          final isRight = alignment == Alignment.centerRight;
          return Align(
            alignment: alignment,
            child: Transform.translate(
              offset: Offset(isRight ? edgeDepth * 0.92 : -edgeDepth * 0.92, 0),
              child: SizedBox(
                width: edgeDepth,
                height: height - 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: isRight
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      end: isRight
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      colors: const [
                        Color(0xFFE7DDCF),
                        Color(0xFFFDF8EE),
                        Color(0xFFE2D6C6),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.022),
                        blurRadius: 2,
                        offset: Offset(isRight ? 1 : -1, 0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        Widget paperStack() {
          return Center(
            child: SizedBox(
              width: math.max(0, halfWidth - 10),
              height: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xFFD9CCBB).withValues(alpha: 0.24),
                      const Color(0xFFFFFCF5).withValues(alpha: 0.0),
                      const Color(0xFFD9CCBB).withValues(alpha: 0.18),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: width * 0.12,
              right: width * 0.12,
              bottom: isLandscape ? -22 : -18,
              height: isLandscape ? 46 : 38,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999.r),
                  gradient: RadialGradient(
                    colors: [
                      Colors.black.withValues(alpha: floorShadowAlpha),
                      Colors.black.withValues(alpha: floorShadowAlpha * 0.22),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.48, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              left: width * 0.06,
              right: width * 0.06,
              bottom: -6,
              height: 18,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.black.withValues(alpha: contactShadowAlpha),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: cardShadowAlpha),
                    blurRadius: isLandscape ? 18 : 16,
                    offset: Offset(0, isLandscape ? 8 : 7),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  IgnorePointer(
                    child: pageEdge(alignment: Alignment.centerLeft),
                  ),
                  IgnorePointer(
                    child: pageEdge(alignment: Alignment.centerRight),
                  ),
                  Positioned(
                    left: 4,
                    right: 4,
                    top: -2,
                    height: 7,
                    child: IgnorePointer(child: paperStack()),
                  ),
                  Positioned(
                    left: 4,
                    right: 4,
                    bottom: -2,
                    height: 7,
                    child: IgnorePointer(child: paperStack()),
                  ),
                  Positioned.fill(child: child),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: SizedBox(
                          width: spineWidth,
                          height: double.infinity,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  const Color(0xFF6B5843).withValues(
                                    alpha: isLandscape ? 0.085 : 0.06,
                                  ),
                                  const Color(
                                    0xFFFFFCF5,
                                  ).withValues(alpha: 0.22),
                                  const Color(0xFF6B5843).withValues(
                                    alpha: isLandscape ? 0.09 : 0.065,
                                  ),
                                  Colors.transparent,
                                ],
                                stops: const [0, 0.34, 0.5, 0.66, 1],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          width: spineCreaseWidth,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(
                                  alpha: isLandscape ? 0.075 : 0.052,
                                ),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Row(
                        children: [
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerRight,
                                  end: Alignment.centerLeft,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.035),
                                    Colors.transparent,
                                  ],
                                  stops: const [0, 0.16],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.032),
                                    Colors.transparent,
                                  ],
                                  stops: const [0, 0.16],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FocusReaderControls extends StatelessWidget {
  const _FocusReaderControls({
    required this.canGoBack,
    required this.canGoForward,
    required this.onPrevious,
    required this.onEdit,
    required this.onNext,
  });

  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback onEdit;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final isLandscape = screen.width > screen.height;
    final controlHeight = isLandscape ? 44.0 : 44.0;
    final sideButtonSize = isLandscape ? 38.0 : 38.0;
    final primaryWidth = isLandscape ? 72.0 : 64.0;
    final primaryHeight = isLandscape ? 34.0 : 32.0;
    final editFontSize = isLandscape ? 12.0 : 12.0;
    final iconSize = isLandscape ? 25.0 : 24.0;

    Widget action({
      required IconData icon,
      required bool enabled,
      required VoidCallback onTap,
      bool primary = false,
      required String label,
    }) {
      return Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: enabled ? 1 : 0.28,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: primary ? primaryWidth : sideButtonSize,
                height: primary ? primaryHeight : sideButtonSize,
                decoration: BoxDecoration(
                  color: primary ? const Color(0xFF1B1916) : Colors.transparent,
                  borderRadius: BorderRadius.circular(primary ? 99.r : 99.r),
                ),
                child: primary
                    ? Center(
                        child: Text(
                          '편집',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: editFontSize,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    : Icon(
                        icon,
                        color: const Color(0xFF1B1916),
                        size: iconSize,
                      ),
              ),
            ),
          ),
        ),
      );
    }

    final children = [
      Expanded(
        child: action(
          icon: Icons.chevron_left_rounded,
          enabled: canGoBack,
          onTap: onPrevious,
          label: '이전 페이지',
        ),
      ),
      Expanded(
        child: action(
          icon: Icons.edit_outlined,
          enabled: true,
          onTap: onEdit,
          primary: true,
          label: '현재 페이지 편집',
        ),
      ),
      Expanded(
        child: action(
          icon: Icons.chevron_right_rounded,
          enabled: canGoForward,
          onTap: onNext,
          label: '다음 페이지',
        ),
      ),
    ];

    return Container(
      height: controlHeight,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(99.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(children: children),
    );
  }
}

// ── 단일 렌더러 기반 플립 애니메이션 ───────────────────────────────
class _GlobalPageFlipRenderer extends StatefulWidget {
  final double page;
  final int itemCount;
  final double singleW;
  final double doubleH;
  final List<AlbumPage> allPages;
  final dynamic selectedCover; // 타입 생략, 넘어오는 그대로 사용
  final dynamic coverTheme;
  final LayerInteractionManager interaction;
  final LayerBuilder layerBuilder;
  final GlobalKey canvasKey;
  final Function(Size) onCanvasSizeChanged;

  const _GlobalPageFlipRenderer({
    required this.page,
    required this.itemCount,
    required this.singleW,
    required this.doubleH,
    required this.allPages,
    required this.selectedCover,
    required this.coverTheme,
    required this.interaction,
    required this.layerBuilder,
    required this.canvasKey,
    required this.onCanvasSizeChanged,
  });

  @override
  State<_GlobalPageFlipRenderer> createState() =>
      _GlobalPageFlipRendererState();
}

class _GlobalPageFlipRendererState extends State<_GlobalPageFlipRenderer> {
  final Map<String, Widget> _cachedInnerCards = {};

  @override
  void didUpdateWidget(covariant _GlobalPageFlipRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 사이즈/테마/페이지 데이터가 바뀐 경우에만 캐시를 비운다.
    if (oldWidget.singleW != widget.singleW ||
        oldWidget.doubleH != widget.doubleH ||
        oldWidget.selectedCover != widget.selectedCover ||
        oldWidget.coverTheme != widget.coverTheme ||
        oldWidget.allPages.length != widget.allPages.length) {
      _cachedInnerCards.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 0 미만 바운스, itemCount 이상 바운스 처리
    final double safePage = widget.page.clamp(
      0.0,
      (widget.itemCount - 1).toDouble(),
    );
    final int currentIndex = safePage.floor();
    final int nextIndex = currentIndex + 1;
    final double fraction = safePage - currentIndex; // 0.0 ~ 1.0

    // --- 스와이프 도중 및 정지(0.0) 상태의 3D 렌더링 통합 (위젯 트리 교체로 인한 반짝임 방지) ---
    // GPU 텍스처 가속 무효화 버스트(Flickering) 방지 핵심 트릭:
    // angle이 완벽한 0.0이면 플러터가 2D 모드로 렌더를 최적화하다가 0.01 회전 시 3D 텍스처로 강제 재파싱하며 이미지가 번쩍거립니다.
    // 이를 막기 위해 어떠한 경우에도 아주 미세한 기본 회전값을 유지해 GPU 뎁스버퍼를 항상 살려둡니다.
    double angle = fraction * math.pi;
    if (angle == 0.0) {
      angle = 0.00005; // 육안으로 절대 보이지 않는 3D 강제 활성 기울기
    }

    // Layer 0: 바닥 배경
    Widget layer0Background;
    if (currentIndex == 0) {
      // 커버가 열릴 때: 바닥 우측(2페이지)만 깔아두어 커버가 왼쪽으로 넘어가면서 자연스럽게 2페이지가 노출됨.
      layer0Background = Center(
        child: _buildInnerSpreadHalf(nextIndex, isLeft: false),
      );

      // 커버가 닫혀갈 때(fraction -> 0) 2페이지가 우측에서 제자리 소멸하면 부자연스러우므로,
      // 완전히 덮이는 시점(fraction=0)에 화면 중앙(Center)으로 스르륵 따라 오도록 슬라이드 시킴
      final double slideOffset = -(widget.singleW / 2) * (1.0 - fraction);
      layer0Background = Transform.translate(
        offset: Offset(slideOffset, 0),
        child: layer0Background,
      );

      // 커버가 완전히 덮이기 직전(0.2 ~ 0.0 구간)에 서서히 페이드아웃 시키되,
      // 투명도 0.0 으로 완전히 소멸시키면 플러터 렌더 최적화가 발동되어 다음 스와이프 시작 시 첫 프레임에 로딩 버스트(Jank/깜박임)가 터지므로,
      // 육안에 안 보이는 1% (0.01) 투명도를 유지해 백그라운드에 텍스처를 미리 살려둡니다.
      layer0Background = Opacity(
        opacity: (0.01 + fraction * 5).clamp(0.01, 1.0),
        child: layer0Background,
      );
    } else {
      // 핵심 해결: 내지 넘길 때 바닥에 다음 스프레드 '전체'를 통짜로 깔아버리면,
      // 넘어간 뒤 해당 영역이 '절반' 레이아웃으로 교체되는 순간 부모 트리 구조가 달라져(Layout Shift) 화면 전체가 번쩍임!
      // 따라서 어차피 왼쪽은 layer1Left가 덮고 있으므로 바닥엔 항상 오른쪽 '절반'만 그리도록 통일시킵니다.
      layer0Background = Center(
        child: nextIndex == 0
            ? _buildCoverCard()
            : _buildInnerSpreadHalf(nextIndex, isLeft: false),
      );
    }

    // Layer 1: A의 왼쪽 바닥 부분
    Widget layer1Left = const SizedBox.shrink();
    if (currentIndex > 0) {
      layer1Left = Center(
        child: _buildInnerSpreadHalf(currentIndex, isLeft: true),
      );
    }

    // Layer 2: A의 들리는 오른쪽 판
    Widget layer2Right = const SizedBox.shrink();
    if (fraction < 0.5) {
      final angle = fraction * math.pi;
      if (currentIndex == 0) {
        layer2Right = Center(
          child: Transform(
            alignment: Alignment.centerLeft,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateY(angle),
            child: _buildCoverCard(),
          ),
        );
      } else {
        layer2Right = Center(
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateY(angle),
            child: _buildInnerSpreadHalf(currentIndex, isLeft: false),
          ),
        );
      }
    }

    // Layer 3: B의 거울상 뒷면 강하
    Widget layer3Left = const SizedBox.shrink();
    if (fraction >= 0.5 && nextIndex < widget.itemCount) {
      final angle = (1.0 - fraction) * math.pi;
      if (nextIndex == 0) {
        layer3Left = Center(
          child: Transform(
            alignment: Alignment.centerLeft,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateY(-angle),
            child: _buildCoverCard(),
          ),
        );
      } else {
        layer3Left = Center(
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateY(-angle),
            child: _buildInnerSpreadHalf(nextIndex, isLeft: true),
          ),
        );
      }
    }

    return Stack(
      children: [layer0Background, layer1Left, layer2Right, layer3Left],
    );
  }

  // 입체적인 제본선(책등) 그라데이션
  Widget _buildSpine() {
    return Container(
      width: 2.w,
      height: widget.doubleH * 0.98, // 카드 위아래 여백을 고려하여 아주 살짝 짧게
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 1.0,
            spreadRadius: 0.5,
          ),
        ],
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.05),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.05),
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }

  // 절반만 렌더링 (나머지는 투명 사이즈박스로 축 위치 보존)
  Widget _buildInnerSpreadHalf(int index, {required bool isLeft}) {
    if (index >= widget.itemCount || index == 0) return const SizedBox.shrink();

    final leftIndex = 1 + (index - 1) * 2;
    final rightIndex = leftIndex + 1;
    final lPage = leftIndex < widget.allPages.length
        ? widget.allPages[leftIndex]
        : null;
    final rPage = rightIndex < widget.allPages.length
        ? widget.allPages[rightIndex]
        : null;

    return OverflowBox(
      maxWidth: double.infinity,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          isLeft
              ? SizedBox(
                  width: widget.singleW,
                  height: widget.doubleH,
                  child: lPage != null
                      ? _buildInnerCard(lPage)
                      : Container(color: SnapFitColors.pureWhite),
                )
              : SizedBox(width: widget.singleW),

          isLeft ? _buildSpine() : SizedBox(width: 2.w), // 2.w 맞춤

          !isLeft
              ? SizedBox(
                  width: widget.singleW,
                  height: widget.doubleH,
                  child: rPage != null
                      ? _buildInnerCard(rPage)
                      : Container(color: SnapFitColors.pureWhite),
                )
              : SizedBox(width: widget.singleW),
        ],
      ),
    );
  }

  Widget _buildCoverCard() {
    return _CoverPageCard(
      key: GlobalObjectKey(
        widget.allPages.isNotEmpty ? widget.allPages[0] : 'cover',
      ),
      page: widget.allPages[0],
      pageW: widget.singleW,
      pageH: widget.doubleH,
      selectedCover: widget.selectedCover,
      coverTheme: widget.coverTheme,
      interaction: widget.interaction,
      layerBuilder: widget.layerBuilder,
      coverKey: widget.canvasKey,
      onCoverSizeChanged: widget.onCanvasSizeChanged,
    );
  }

  Widget _buildInnerCard(AlbumPage page) {
    final key =
        '${page.id}_${_pageRenderSignature(page)}_${widget.singleW.toStringAsFixed(3)}_${widget.doubleH.toStringAsFixed(3)}';
    final cached = _cachedInnerCards[key];
    if (cached != null) return cached;
    final card = _InnerPageCard(
      key: ValueKey('inner_page_${page.id}'),
      page: page,
      pageW: widget.singleW,
      pageH: widget.doubleH,
      interaction: widget.interaction,
      layerBuilder: widget.layerBuilder,
    );
    if (_cachedInnerCards.length > 200) {
      _cachedInnerCards.clear();
    }
    _cachedInnerCards[key] = card;
    return card;
  }

  int _pageRenderSignature(AlbumPage page) {
    return Object.hashAll([
      page.backgroundColor,
      page.layers.length,
      ...page.layers.map(
        (l) => Object.hash(
          l.id,
          l.type,
          l.asset?.id,
          l.previewUrl,
          l.imageUrl,
          l.originalUrl,
          l.position.dx,
          l.position.dy,
          l.width,
          l.height,
          l.scale,
          l.rotation,
          l.opacity,
          l.zIndex,
          l.imageBackground,
          l.imageTemplate,
          l.text,
        ),
      ),
    ]);
  }
}

class _CoverPageCard extends StatelessWidget {
  final AlbumPage page;
  final double pageW;
  final double pageH;
  final CoverSize selectedCover;
  final CoverTheme coverTheme;
  final LayerInteractionManager interaction;
  final LayerBuilder layerBuilder;
  final GlobalKey coverKey;
  final ValueChanged<Size> onCoverSizeChanged;

  const _CoverPageCard({
    super.key,
    required this.page,
    required this.pageW,
    required this.pageH,
    required this.selectedCover,
    required this.coverTheme,
    required this.interaction,
    required this.layerBuilder,
    required this.coverKey,
    required this.onCoverSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    // [10단계 Fix] 리더 화면의 커버도 500xH 논리 고정 좌표계를 사용하여 렌더링합니다.
    final double aspect = selectedCover.ratio > 0 ? selectedCover.ratio : 1.0;
    const double logicalW = kCoverReferenceWidth; // 500.0
    final double logicalH = logicalW / aspect;

    // 실제 화면 대비 스케일 계산
    final double scale = pageW / logicalW;

    final shadowScale = (pageH / 280).clamp(0.45, 1.75);

    return HomeCoverFrame(
      width: pageW,
      height: pageH,
      shadowScale: shadowScale,
      showShadow: true,
      child: RepaintBoundary(
        key: coverKey,
        child: OverflowBox(
          // 논리 사이즈로 강제 렌더링 후 스케일링
          minWidth: logicalW,
          maxWidth: logicalW,
          minHeight: logicalH,
          maxHeight: logicalH,
          alignment: Alignment.center,
          child: Transform.scale(
            scale: scale,
            child: CoverLayout(
              aspect: aspect,
              layers: interaction.sortByZ(page.layers),
              isInteracting: false,
              leftSpine: 14.0,
              backgroundColor: page.backgroundColor != null
                  ? Color(page.backgroundColor!).withAlpha(0xFF)
                  : null,
              onCoverSizeChanged: onCoverSizeChanged,
              buildImage: (layer) =>
                  layerBuilder.buildImage(layer, isCover: true),
              buildText: (layer) =>
                  layerBuilder.buildText(layer, isCover: true),
              sortedByZ: interaction.sortByZ,
              theme: coverTheme,
            ),
          ),
        ),
      ),
    );
  }
}

// ── 내지 페이지 카드 ──────────────────────────────────────────────
class _InnerPageCard extends StatelessWidget {
  final AlbumPage page;
  final double pageW;
  final double pageH;
  final LayerInteractionManager interaction;
  final LayerBuilder layerBuilder;

  const _InnerPageCard({
    super.key,
    required this.page,
    required this.pageW,
    required this.pageH,
    required this.interaction,
    required this.layerBuilder,
  });

  @override
  Widget build(BuildContext context) {
    // [Inner Page Fix] 에디터와 동일하게 커버 비율을 반영한 논리적 베이스 사이즈 계산
    final ratio = pageW / pageH;
    final logicalW = kCoverReferenceWidth;
    final logicalH = kCoverReferenceWidth / ratio;
    final logicalBaseSize = Size(logicalW, logicalH);

    final scale = pageW / logicalW;

    final pageBackgroundColor = page.backgroundColor != null
        ? Color(page.backgroundColor!)
        : SnapFitColors.pureWhite;

    return ClipRect(
      child: RepaintBoundary(
        child: Container(
          width: pageW,
          height: pageH,
          color: pageBackgroundColor,
          child: Stack(
            clipBehavior: Clip.none, // 페이지 밖으로 살짝 나가는 요소(그림자 등) 허용
            children: [
              Transform.scale(
                scale: scale,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: logicalBaseSize.width,
                  height: logicalBaseSize.height,
                  child: Stack(
                    clipBehavior: Clip.none, // 회전된 레이어의 모서리가 잘리는 현상 방지
                    children: interaction.sortByZ(page.layers).map((layer) {
                      if (layer.type == LayerType.image ||
                          layer.type == LayerType.sticker ||
                          layer.type == LayerType.decoration) {
                        return layerBuilder.buildImage(layer);
                      }
                      return layerBuilder.buildText(layer);
                    }).toList(),
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
