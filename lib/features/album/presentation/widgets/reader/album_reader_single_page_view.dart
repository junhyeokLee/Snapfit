import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:book_page_flip/book_page_flip.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../../../core/navigation/web_app_location.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import '../../../../../shared/widgets/album_stage_style.dart';
import '../../../../../shared/widgets/album_navigation_dock.dart';

import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/cover_theme.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/album_page.dart';
import '../../../domain/entities/album.dart';
import '../../../domain/entities/album_page_render_signature.dart';
import '../../../domain/entities/layer.dart';
import '../../../service/album_collaboration_session.dart';
import '../../controllers/layer_builder.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../controllers/layer_interaction_manager.dart';
import '../../providers/album_edit_session_provider.dart';
import '../../utils/reader_image_quality.dart';
import '../../views/album_reader_inner_detail_screen.dart';
import '../../views/page_editor_screen.dart';
import '../cover/cover.dart';
import '../home/home_cover_frame.dart';
import 'book_page_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../shared/widgets/experience_icon.dart';
import '../../../../../shared/widgets/snapfit_motion.dart';

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
  final bool singlePageFocus;
  final VoidCallback? onTogglePageList;
  final bool pageListVisible;
  final ValueChanged<int>? onFocusPageChanged;
  final double focusBottomInset;
  final int? requestedFocusPageIndex;
  final GlobalKey? openingCoverKey;
  final ValueListenable<bool>? openingCoverVisible;
  final VoidCallback? onPrepareBookOrder;

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
    this.singlePageFocus = false,
    this.onTogglePageList,
    this.pageListVisible = false,
    this.onFocusPageChanged,
    this.focusBottomInset = 0,
    this.requestedFocusPageIndex,
    this.openingCoverKey,
    this.openingCoverVisible,
    this.onPrepareBookOrder,
  });

  @override
  ConsumerState<AlbumReaderSinglePageView> createState() =>
      _AlbumReaderSinglePageViewState();
}

class _AlbumReaderSinglePageViewState
    extends ConsumerState<AlbumReaderSinglePageView>
    with SingleTickerProviderStateMixin {
  static const double _bookFlipControlVelocity = 0.02;
  static const double _bookFlipListVelocity = 4.8;
  static const BookFlipPhysics _bookFlipPhysics = BookFlipPhysics(
    springStiffness: 160,
    springDampingRatio: 1.0,
    commitThreshold: 0.44, // 높을수록 페이지를 더 많이 끌어야 넘어감
    commitVelocity: 3.2, // 높을수록 짧게 휙 하는 손동작으로는 덜 넘어감
    velocityLookAhead: 0.012, // 손을 땔 때 속도 예측 영향을 줄여서 조금 움직였는데도 넘어가는 현상 감소
    settleEpsilon: 0.012,
  );
  static const BookFlipPhysics _bookFlipControlPhysics = BookFlipPhysics(
    springStiffness: 150,
    springDampingRatio: 1.0,
    commitThreshold: 0.44,
    commitVelocity: 3.2,
    velocityLookAhead: 0.012,
    settleEpsilon: 0.012,
  );
  static const BookFlipPhysics _bookFlipListPhysics = BookFlipPhysics(
    springStiffness: 1900,
    springDampingRatio: 1.08,
    commitThreshold: 0.56,
    commitVelocity: 1.65,
    velocityLookAhead: 0.06,
    settleEpsilon: 0.86,
  );
  static const double _openSpreadFlingMinDistance = 44.0;
  static const double _openSpreadCommitVelocity = 420.0;
  static const double _openSpreadDragProgressScale = 0.64;

  bool _isCoverPressed = false;
  bool _isTurningWithControl = false;
  int? _pendingControlDirection;
  int? _queuedTurnDirection;
  int? _expectedFocusEcho;
  int _focusEchoEpoch = 0;
  int? _requestedPreparationSpread;
  late int _focusPageIndex;
  int _bookContentSignature = 0;
  int _bookContentRevision = 0;
  bool _readerPhotoFailed = false;
  (Size, double, int, int)? _bookRenderConfiguration;
  int _bookRenderEpoch = 0;
  bool _bookRendererReplacing = false;
  late final BookFlipController _bookFlipController;
  int? _requestedFocusPage;
  bool _syncingSpreadFromFocus = false;
  int? _animatedTargetSpread;
  Completer<void>? _flipEndCompleter;
  bool _isAnimatingToRequestedSpread = false;
  bool _isCoverFlipActive = false;
  int _coverFlipDirection = 0;
  bool _isDraggingOpenSpread = false;
  bool _bookDragStarted = false;
  bool _waitingForDragPages = false;
  bool _dragReplayQueued = false;
  Offset _openSpreadLocalPosition = Offset.zero;
  int? _openSpreadPointer;
  Offset _openSpreadLastPosition = Offset.zero;
  VelocityTracker? _openSpreadVelocityTracker;
  double _openSpreadTotalDx = 0;
  int _openSpreadStartSpread = 0;
  int _openSpreadDirection = 0;
  double _openSpreadPageWidth = 1;
  bool _openSpreadReducedMotion = false;
  Duration? _openSpreadLastMoveTime;
  double _openSpreadInstantVelocity = 0;
  double _openSpreadPanStartProgress = 0;
  bool _canContinueSettledTurn = false;
  bool _suppressNextTapUp = false;
  late final AnimationController _focusPanController;
  bool _isPanningFocus = false;
  bool _focusPanCommit = true;
  bool _focusPanFinishingSoon = false;
  bool _isJumpingFocus = false;
  int _focusPanEpoch = 0;
  int _focusRequestEpoch = 0;
  int? _pendingSingleFocusRequest;
  int? _focusTurnSourcePage;
  int? _focusTurnTargetPage;
  bool? _lastSinglePageFocusActive;
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
    if (widget.singlePageFocus && widget.requestedFocusPageIndex != null) {
      _focusPageIndex = widget.requestedFocusPageIndex!
          .clamp(0, math.max(0, widget.allPages.length - 1))
          .toInt();
    }
    _bookFlipController = BookFlipController(
      initialSpread: _spreadForFocusPage(_focusPageIndex),
    )..addListener(_resumePreparedInput);
    _focusPanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    widget.pageController.addListener(_syncFocusFromSpread);
    _bookContentSignature = _currentBookContentSignature;
  }

  int get _currentBookContentSignature => Object.hash(
    widget.selectedCover,
    widget.coverTheme,
    Object.hashAll(widget.allPages.map(albumPageRenderSignature)),
  );

  void _resetOpenSpreadTracking() {
    _isDraggingOpenSpread = false;
    _bookDragStarted = false;
    _waitingForDragPages = false;
    _openSpreadLocalPosition = Offset.zero;
    _openSpreadPointer = null;
    _openSpreadLastPosition = Offset.zero;
    _openSpreadVelocityTracker = null;
    _openSpreadTotalDx = 0;
    _openSpreadStartSpread = 0;
    _openSpreadDirection = 0;
    _openSpreadPageWidth = 1;
    _openSpreadReducedMotion = false;
    _openSpreadLastMoveTime = null;
    _openSpreadInstantVelocity = 0;
    _openSpreadPanStartProgress = 0;
    _canContinueSettledTurn = false;
  }

  bool get _usesPreviewPointerMotion => widget.singlePageFocus;

  double get _openSpreadMotionScale =>
      _usesPreviewPointerMotion ? 1 / .85 : _openSpreadDragProgressScale;

  // Both faces belong to the same book; only the camera changes within a spread.
  double _focusCameraOffset(int pageIndex, double pageWidth) =>
      pageIndex > 0 && pageIndex.isOdd ? pageWidth / 2 : -pageWidth / 2;

  bool get _singlePageFocusActive {
    final size = MediaQuery.sizeOf(context);
    return widget.singlePageFocus && size.width <= size.height;
  }

  int? get _explicitFocusRequest {
    final requested = widget.requestedFocusPageIndex
        ?.clamp(0, math.max(0, widget.allPages.length - 1))
        .toInt();
    if (requested == null) return null;
    if (_pendingSingleFocusRequest == requested) return requested;
    return _focusTurnTargetPage == requested ? requested : null;
  }

  void _cancelFocusForLayout() {
    final requested = _explicitFocusRequest;
    if (requested != null) _focusPageIndex = requested;
    _clearFocusCamera();
    _resetOpenSpreadTracking();
    _isTurningWithControl = false;
    _isCoverFlipActive = false;
    _coverFlipDirection = 0;
    _isJumpingFocus = true;
    try {
      _bookFlipController.goToSpread(_spreadForFocusPage(_focusPageIndex));
    } finally {
      _isJumpingFocus = false;
    }
  }

  void _clearFocusCamera() {
    _pendingControlDirection = null;
    _queuedTurnDirection = null;
    _expectedFocusEcho = null;
    _requestedPreparationSpread = null;
    _focusPanEpoch++;
    _focusRequestEpoch++;
    _pendingSingleFocusRequest = null;
    _focusPanController.stop();
    _isPanningFocus = false;
    _focusPanFinishingSoon = false;
    _focusTurnSourcePage = null;
    _focusTurnTargetPage = null;
  }

  void _beginFocusTransition(int targetPage, {required bool pan}) {
    _focusPanEpoch++;
    _focusTurnSourcePage = _focusPageIndex;
    _focusTurnTargetPage = targetPage;
    _isPanningFocus = pan;
    if (pan) {
      _focusPanController.value = 0;
    }
  }

  Future<void> _settleFocusPan({
    required bool commit,
    Duration? duration,
  }) async {
    final source = _focusTurnSourcePage;
    final target = _focusTurnTargetPage;
    if (!_isPanningFocus || source == null || target == null) return;
    final epoch = _focusPanEpoch;
    _focusPanCommit = commit;
    setState(() => _isTurningWithControl = true);
    try {
      if (!SnapFitMotion.reduced(context)) {
        await _focusPanController
            .animateTo(
              commit ? 1 : 0,
              curve: BookFlipCurl.albumPreviewTiming,
              duration:
                  duration ??
                  Duration(
                    microseconds:
                        ((330 +
                                    ((commit ? 1 : 0) -
                                                _focusPanController.value)
                                            .abs() *
                                        170) *
                                1000)
                            .round(),
                  ),
            )
            .orCancel;
      }
    } on TickerCanceled {
      return;
    }
    if (!mounted || epoch != _focusPanEpoch) return;
    final page = commit ? target : source;
    final queuedDirection = _queuedTurnDirection;
    setState(() {
      _focusPageIndex = page;
      _isTurningWithControl = false;
      _clearFocusCamera();
    });
    await _syncSpreadFromFocus(page);
    if (mounted && queuedDirection != null) {
      unawaited(_turnFocusPage(queuedDirection));
    }
  }

  Future<void> _finishFocusPageJump(int pageIndex) async {
    final page = pageIndex
        .clamp(0, math.max(0, widget.allPages.length - 1))
        .toInt();
    _clearFlipEndWaiter();
    _clearFocusCamera();
    _isJumpingFocus = true;
    try {
      _bookFlipController.goToSpread(_spreadForFocusPage(page));
    } finally {
      _isJumpingFocus = false;
    }
    setState(() {
      _focusPageIndex = page;
      _animatedTargetSpread = null;
      _isAnimatingToRequestedSpread = false;
      _isTurningWithControl = false;
      _isCoverFlipActive = false;
      _coverFlipDirection = 0;
      _suppressNextTapUp = _suppressNextTapUp || _openSpreadPointer != null;
      _resetOpenSpreadTracking();
    });
    await _syncSpreadFromFocus(page);
  }

  Future<void> _turnSingleFocusPage(int direction) async {
    final target = (_focusPageIndex + direction)
        .clamp(0, math.max(0, widget.allPages.length - 1))
        .toInt();
    if (target == _focusPageIndex) return;
    final currentSpread = _spreadForFocusPage(_focusPageIndex);
    final targetSpread = _spreadForFocusPage(target);
    if (SnapFitMotion.reduced(context) ||
        (_readerPhotoFailed &&
            (!_bookFlipController.isReady ||
                !_bookFlipController.isSpreadReady(targetSpread)))) {
      await _finishFocusPageJump(target);
      return;
    }
    if (currentSpread == targetSpread) {
      setState(() => _beginFocusTransition(target, pan: true));
      await _settleFocusPan(commit: true);
      return;
    }
    if (!_bookFlipController.isReady ||
        !_bookFlipController.isSpreadReady(targetSpread)) {
      _pendingControlDirection = direction;
      _requestPreparedSpread(targetSpread);
      return;
    }
    if (_bookFlipController.currentSpread != currentSpread) {
      _bookFlipController.goToSpread(currentSpread);
    }
    setState(() {
      _beginFocusTransition(target, pan: false);
      _isTurningWithControl = true;
      _isCoverFlipActive = currentSpread == 0 || targetSpread == 0;
      _coverFlipDirection = _isCoverFlipActive ? direction : 0;
    });
    // 앨범 곡면은 고정되어 있어 다음 프레임까지 입력을 묶어 둘 필요가 없다.
    final started = direction > 0
        ? _bookFlipController.nextSpread(velocity: _bookFlipControlVelocity)
        : _bookFlipController.previousSpread(
            velocity: -_bookFlipControlVelocity,
          );
    if (!started) {
      _isTurningWithControl = false;
      _pendingControlDirection = direction;
      _requestPreparedSpread(targetSpread);
    }
  }

  // Called during layout, before deciding which live pages to show. Only a real
  // capture configuration change invalidates navigation; ordinary turns reuse
  // the same renderer, snapshots and image cache.
  void _syncBookRenderer(Size size, double pixelRatio) {
    final configuration = (
      size,
      pixelRatio,
      _bookPageCount,
      _bookContentRevision,
    );
    if (_bookRenderConfiguration == configuration) return;
    final previous = _bookRenderConfiguration;
    _bookRenderConfiguration = configuration;
    final epoch = ++_bookRenderEpoch;
    if (previous == null) return;

    final requestedPage = _isAnimatingToRequestedSpread
        ? widget.requestedFocusPageIndex
        : _explicitFocusRequest;
    final spread =
        (_animatedTargetSpread ??
                _spreadForFocusPage(requestedPage ?? _focusPageIndex))
            .clamp(0, _bookSpreadCount - 1);
    final focusedPage = (requestedPage ?? _focusPageIndex)
        .clamp(0, math.max(0, widget.allPages.length - 1))
        .toInt();
    _focusPageIndex = _spreadForFocusPage(focusedPage) == spread
        ? focusedPage
        : _focusPageForSpread(spread);
    _animatedTargetSpread = null;
    _isAnimatingToRequestedSpread = false;
    _isTurningWithControl = false;
    _isCoverFlipActive = false;
    _coverFlipDirection = 0;
    _clearFocusCamera();
    _suppressNextTapUp = _openSpreadPointer != null;
    _resetOpenSpreadTracking();
    _readerPhotoFailed = false;
    _bookRendererReplacing = true;
    _clearFlipEndWaiter();

    // The old renderer must detach first: jumping it during layout would emit
    // its completion callback while the replacement subtree is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || epoch != _bookRenderEpoch) return;
      _bookFlipController.goToSpread(spread);
      setState(() => _bookRendererReplacing = false);
      unawaited(_syncSpreadFromFocus(_focusPageIndex));
    });
  }

  void _syncBookContent() {
    // Do not rasterise each editor gesture on the reader route underneath it.
    if (ModalRoute.of(context)?.isCurrent == false) return;
    final signature = _currentBookContentSignature;
    if (signature == _bookContentSignature) return;
    _bookContentSignature = signature;
    _bookContentRevision++;
    _readerPhotoFailed = false;
    _focusPageIndex = _focusPageIndex.clamp(
      0,
      math.max(0, widget.allPages.length - 1),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final singlePageFocus = _singlePageFocusActive;
    if (_lastSinglePageFocusActive != null &&
        _lastSinglePageFocusActive != singlePageFocus) {
      _cancelFocusForLayout();
    }
    _lastSinglePageFocusActive = singlePageFocus;
    _syncBookContent();
  }

  @override
  void dispose() {
    widget.pageController.removeListener(_syncFocusFromSpread);
    _clearFlipEndWaiter();
    _bookFlipController.removeListener(_resumePreparedInput);
    _bookFlipController.dispose();
    _focusPanController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AlbumReaderSinglePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageController != widget.pageController) {
      oldWidget.pageController.removeListener(_syncFocusFromSpread);
      widget.pageController.addListener(_syncFocusFromSpread);
    }
    _syncBookContent();
    if (oldWidget.singlePageFocus != widget.singlePageFocus) {
      _cancelFocusForLayout();
    }
    if (!widget.focusMode) return;
    final requested = widget.requestedFocusPageIndex;
    if (requested != oldWidget.requestedFocusPageIndex &&
        requested == _expectedFocusEcho &&
        requested == _focusPageIndex) {
      _expectedFocusEcho = null;
      return;
    }
    if (requested == null ||
        requested == oldWidget.requestedFocusPageIndex ||
        (requested == _focusPageIndex &&
            !_isAnimatingToRequestedSpread &&
            !_isPanningFocus &&
            !_isTurningWithControl &&
            !_bookFlipController.isAnimating)) {
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

  int get _controlNavigationSpread {
    final target = _focusTurnTargetPage;
    if (target != null) return _spreadForFocusPage(target);
    final direction = _bookFlipController.flipDirection;
    return _bookFlipController.isAnimating && direction != null
        ? (_bookFlipController.currentSpread +
                  (direction == FlipDirection.forward ? 1 : -1))
              .clamp(0, _bookSpreadCount - 1)
        : _spreadForFocusPage(_focusPageIndex);
  }

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
    _clearFocusCamera();
    setState(() {
      _focusPageIndex = target;
      _bookFlipController.goToSpread(_spreadForFocusPage(target));
    });
    _requestedFocusPage = null;
  }

  Future<void> _syncSpreadFromFocus(int pageIndex) async {
    if (!widget.focusMode || !widget.pageController.hasClients) {
      _notifyFocusPage(pageIndex);
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
    _notifyFocusPage(pageIndex);
  }

  void _notifyFocusPage(int pageIndex) {
    final callback = widget.onFocusPageChanged;
    if (callback == null) return;
    final epoch = ++_focusEchoEpoch;
    _expectedFocusEcho = widget.requestedFocusPageIndex == pageIndex
        ? null
        : pageIndex;
    // 부모의 다음 build 반영이 방금 시작한 연속 넘김을 새 선택으로 취소하지 않는다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (epoch == _focusEchoEpoch) _expectedFocusEcho = null;
    });
    callback(pageIndex);
  }

  Future<void> _turnFocusPage(int direction) async {
    if (widget.allPages.isEmpty ||
        ModalRoute.of(context)?.isCurrent == false ||
        (_singlePageFocusActive && _pendingSingleFocusRequest != null) ||
        _isAnimatingToRequestedSpread ||
        _openSpreadPointer != null) {
      return;
    }
    if (_isTurningWithControl || _bookFlipController.isAnimating) {
      // 새 입력은 하나만 보존해 오래된 연타가 나중에 계속 재생되지 않게 한다.
      _queuedTurnDirection = direction;
      if (_isPanningFocus && !_focusPanFinishingSoon) {
        _focusPanFinishingSoon = true;
        unawaited(
          _settleFocusPan(
            commit: _focusPanCommit,
            duration: const Duration(milliseconds: 80),
          ),
        );
      } else {
        _bookFlipController.finishTurnSoon();
      }
      return;
    }
    _requestedPreparationSpread = null;

    if (_singlePageFocusActive) {
      await _turnSingleFocusPage(direction);
      return;
    }

    final currentSpread = _spreadForFocusPage(_focusPageIndex);
    final targetSpread = (currentSpread + direction).clamp(
      0,
      _bookSpreadCount - 1,
    );
    if (targetSpread == currentSpread) return;
    if (SnapFitMotion.reduced(context) ||
        (_readerPhotoFailed &&
            (!_bookFlipController.isReady ||
                !_bookFlipController.isSpreadReady(targetSpread)))) {
      await _finishAnimatedSpreadJump(targetSpread);
      return;
    }
    if (!_bookFlipController.isReady ||
        !_bookFlipController.isSpreadReady(targetSpread)) {
      _pendingControlDirection = direction;
      _requestPreparedSpread(targetSpread);
      return;
    }
    if (_bookFlipController.currentSpread != currentSpread) {
      _bookFlipController.goToSpread(currentSpread);
    }

    final epoch = _bookRenderEpoch;
    final isCoverEdgeFlip =
        (currentSpread == 0 && direction > 0) ||
        (currentSpread == 1 && direction < 0);
    setState(() {
      _isTurningWithControl = true;
      _isCoverFlipActive = isCoverEdgeFlip;
      _coverFlipDirection = isCoverEdgeFlip ? direction : 0;
    });
    if (!widget.singlePageFocus) await WidgetsBinding.instance.endOfFrame;
    if (!mounted ||
        epoch != _bookRenderEpoch ||
        _isAnimatingToRequestedSpread) {
      return;
    }

    final started = direction > 0
        ? _bookFlipController.nextSpread(velocity: _bookFlipControlVelocity)
        : _bookFlipController.previousSpread(
            velocity: -_bookFlipControlVelocity,
          );
    if (!started) {
      _isTurningWithControl = false;
      _pendingControlDirection = direction;
      _requestPreparedSpread(targetSpread);
    }
    // onFlipEnd is the single source of the settled spread, including a user's
    // re-grab/cancel. No delayed control completion may force its old target.
  }

  Future<void> _animateFocusToPage(int pageIndex) async {
    if (!widget.focusMode || widget.allPages.isEmpty) return;
    if (_singlePageFocusActive) {
      _pendingSingleFocusRequest = pageIndex;
      final requestEpoch = ++_focusRequestEpoch;
      // Parent focus callbacks must not rebuild the reader screen during build.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted ||
          requestEpoch != _focusRequestEpoch ||
          !_singlePageFocusActive ||
          widget.requestedFocusPageIndex?.clamp(
                0,
                math.max(0, widget.allPages.length - 1),
              ) !=
              pageIndex) {
        if (requestEpoch == _focusRequestEpoch) {
          _pendingSingleFocusRequest = null;
        }
        return;
      }
      if (!_isPanningFocus &&
          !_isTurningWithControl &&
          _openSpreadPointer == null &&
          !_bookFlipController.isAnimating &&
          (pageIndex - _focusPageIndex).abs() == 1) {
        await _turnSingleFocusPage(pageIndex > _focusPageIndex ? 1 : -1);
      } else {
        await _finishFocusPageJump(pageIndex);
      }
      return;
    }

    _animatedTargetSpread = _spreadForFocusPage(pageIndex);
    if (_isAnimatingToRequestedSpread) return;

    final epoch = _bookRenderEpoch;
    setState(() {
      _isAnimatingToRequestedSpread = true;
      _suppressNextTapUp = _suppressNextTapUp || _openSpreadPointer != null;
      _resetOpenSpreadTracking();
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || epoch != _bookRenderEpoch) return;
    try {
      final targetSpread =
          _animatedTargetSpread!.clamp(0, math.max(0, _bookSpreadCount - 1))
              as int;
      final currentSpread = _bookFlipController.totalSpreads > 0
          ? _bookFlipController.currentSpread
          : _spreadForFocusPage(_focusPageIndex);

      if (currentSpread == targetSpread ||
          SnapFitMotion.reduced(context) ||
          !_bookFlipController.isReady) {
        await _finishAnimatedSpreadJump(targetSpread);
        return;
      }

      if (_bookFlipController.isAnimating) {
        await _waitForFlipEnd().timeout(
          const Duration(milliseconds: 70),
          onTimeout: () {},
        );
      }
      if (!mounted || epoch != _bookRenderEpoch) return;

      final distance = (targetSpread - currentSpread).abs();
      final visualTurnCount = math.min(distance, 5);

      for (
        var turn = 1;
        mounted && epoch == _bookRenderEpoch && turn <= visualTurnCount;
        turn += 1
      ) {
        if (SnapFitMotion.reduced(context)) break;
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
          await Future<void>.delayed(const Duration(milliseconds: 14));
        }

        if (!mounted || epoch != _bookRenderEpoch) return;
        if (_animatedTargetSpread != latestTarget) continue;
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
          const Duration(milliseconds: 92),
          onTimeout: () {},
        );
      }

      if (!mounted || epoch != _bookRenderEpoch) return;
      final finalTarget =
          (_animatedTargetSpread ?? targetSpread).clamp(
                0,
                math.max(0, _bookSpreadCount - 1),
              )
              as int;
      await _finishAnimatedSpreadJump(finalTarget);
    } finally {
      if (mounted && epoch == _bookRenderEpoch) {
        setState(() => _isAnimatingToRequestedSpread = false);
      }
    }
  }

  Future<void> _finishAnimatedSpreadJump(int spread) async {
    if (!mounted) return;

    final requestedPage = _isAnimatingToRequestedSpread
        ? widget.requestedFocusPageIndex
        : null;
    // A spread jump may target its right page after editing or reordering.
    final targetPage =
        requestedPage != null && _spreadForFocusPage(requestedPage) == spread
        ? requestedPage
              .clamp(0, math.max(0, widget.allPages.length - 1))
              .toInt()
        : _focusPageForSpread(spread);
    _animatedTargetSpread = null;
    setState(() {
      _focusPageIndex = targetPage;
      _isCoverFlipActive = false;
      _coverFlipDirection = 0;
      _isTurningWithControl = false;
      _resetOpenSpreadTracking();
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

  void _clearFlipEndWaiter() {
    final completer = _flipEndCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _flipEndCompleter = null;
  }

  Future<void> _openFocusEditor() async {
    if (!mounted || widget.allPages.isEmpty) return;
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final album = vm.album;
    if (album?.allowsEditing == false) return;
    final requestedPage = widget.requestedFocusPageIndex;
    final focusedPage =
        _isAnimatingToRequestedSpread && _animatedTargetSpread != null
        ? requestedPage != null &&
                  _spreadForFocusPage(requestedPage) == _animatedTargetSpread
              ? requestedPage
              : _focusPageForSpread(_animatedTargetSpread!)
        : _focusPageIndex;
    final viewedId =
        widget.allPages[focusedPage.clamp(0, widget.allPages.length - 1)].id;
    final editingPage = vm.pages.indexWhere((page) => page.id == viewedId);
    if (editingPage < 0) return;
    final session = vm.editSessionIdentity;
    final owner = ref.read(albumEditorOwnerReaderProvider)();
    await Navigator.push(
      context,
      snapFitRoute(page: PageEditorScreen(
          initialPageIndex: editingPage,
          returnToPreviousOnSave: true,
        ), settings: album != null && album.id > 0
            ? WebAppRouteSettings(
                WebAppLocation(WebAppPage.editor, '${album.id}'),
              )
            : null),
    );
    if (!mounted) return;
    if (!identical(ref.read(albumEditorViewModelProvider.notifier), vm) ||
        !identical(vm.editSessionIdentity, session) ||
        vm.album?.id != album?.id ||
        vm.album?.userId != album?.userId ||
        ref.read(albumEditorOwnerReaderProvider)() != owner) {
      return;
    }
    _restoreFocusedPage(vm, viewedId, editingPage);
  }

  void _restoreFocusedPage(
    AlbumEditorViewModel vm,
    String pageId,
    int fallbackIndex,
  ) {
    if (vm.pages.isEmpty) return;
    final retained = pageId.isEmpty
        ? -1
        : vm.pages.indexWhere((page) => page.id == pageId);
    final target = retained >= 0
        ? retained
        : fallbackIndex.clamp(0, vm.pages.length - 1).toInt();
    final spread = _spreadForFocusPage(target);
    _clearFocusCamera();
    // An old turn may still be awaiting a frame or completion behind the route.
    if (_isAnimatingToRequestedSpread ||
        _isTurningWithControl ||
        _bookFlipController.isAnimating) {
      _bookRenderEpoch++;
      _clearFlipEndWaiter();
    }
    // Finish any old turn before restoring the exact side of the spread.
    _bookFlipController.goToSpread(spread);
    setState(() {
      _focusPageIndex = target;
      _animatedTargetSpread = null;
      _isAnimatingToRequestedSpread = false;
      _isTurningWithControl = false;
      _isCoverFlipActive = false;
      _coverFlipDirection = 0;
      _bookRendererReplacing = false;
      _resetOpenSpreadTracking();
    });
    if (!widget.focusMode && widget.pageController.hasClients) {
      widget.pageController.jumpToPage(spread);
    }
    unawaited(_syncSpreadFromFocus(target));
  }

  void _openFocusDetail({
    required double tapX,
    required double stageWidth,
    required double pageWidth,
    required double pageHeight,
  }) {
    if (_singlePageFocusActive &&
        (_isPanningFocus || _bookFlipController.isAnimating)) {
      return;
    }
    final spread = _bookFlipController.totalSpreads > 0
        ? _bookFlipController.currentSpread
        : _spreadForFocusPage(_focusPageIndex);
    if (spread <= 0 || widget.allPages.length <= 1) return;

    final leftPageIndex = 1 + ((spread - 1) * 2);
    final rightPageIndex = leftPageIndex + 1;
    if (_singlePageFocusActive) {
      // The detail route also resolves the side from book-local tap coordinates.
      tapX = _focusPageIndex.isOdd ? pageWidth / 2 : pageWidth * 1.5;
    }
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

  LayerBuilder _readerImageBuilder(double pageWidth, double pageHeight) {
    final base = Size(
      kCoverReferenceWidth,
      kCoverReferenceWidth / widget.selectedCover.ratio,
    );
    return LayerBuilder(
      widget.interaction,
      () => base,
      previewImageDecodeWidth: readerPageDecodeWidth(
        Size(pageWidth, pageHeight),
        MediaQuery.devicePixelRatioOf(context),
      ),
    );
  }

  Widget _buildFocusCard(
    int pageIndex,
    double pageWidth,
    double pageHeight, {
    Key? cardKey,
    GlobalKey? coverBoundaryKey,
    bool showBookDepth = false,
  }) {
    final page = widget.allPages[pageIndex];
    final builder = _readerImageBuilder(pageWidth, pageHeight);
    if (pageIndex == 0) {
      return _CoverPageCard(
        key: cardKey ?? GlobalObjectKey(page),
        page: page,
        pageW: pageWidth,
        pageH: pageHeight,
        selectedCover: widget.selectedCover,
        coverTheme: widget.coverTheme,
        interaction: widget.interaction,
        layerBuilder: builder,
        coverKey: coverBoundaryKey ?? widget.canvasKey,
        onCoverSizeChanged: widget.onCanvasSizeChanged,
        showBookDepth: showBookDepth,
      );
    }

    return _InnerPageCard(
      key: cardKey ?? ValueKey('focus_inner_page_${page.id}'),
      page: page,
      pageW: pageWidth,
      pageH: pageHeight,
      interaction: widget.interaction,
      layerBuilder: builder,
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
          key: widget.openingCoverKey,
          width: pageWidth,
          height: pageHeight,
          child: _openingCoverVisibility(
            _buildFocusCard(
              0,
              pageWidth,
              pageHeight,
              cardKey: const ValueKey('book_flip_fallback_cover_card'),
              coverBoundaryKey: _bookFlipFallbackCoverBoundaryKey,
              showBookDepth: true,
            ),
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

  Widget _openingCoverVisibility(Widget child) {
    final visibility = widget.openingCoverVisible;
    if (visibility == null) return child;
    return ValueListenableBuilder<bool>(
      valueListenable: visibility,
      child: child,
      builder: (_, visible, child) =>
          Opacity(opacity: visible ? 1 : 0, child: child),
    );
  }

  void _handleBookSpreadChanged(int spread, {required bool ended}) {
    if (!ended || _isJumpingFocus) return;

    final sourcePage = _focusTurnSourcePage;
    final targetPage = _focusTurnTargetPage;
    final target =
        _singlePageFocusActive && sourcePage != null && targetPage != null
        ? _spreadForFocusPage(targetPage) == spread
              ? targetPage
              : sourcePage
        : _focusPageForSpread(spread);
    if (!mounted) return;
    final queuedDirection = _queuedTurnDirection;
    setState(() {
      _focusPageIndex = target;
      _isTurningWithControl = false;
      _isCoverFlipActive = false;
      _coverFlipDirection = 0;
      _isDraggingOpenSpread = false;
      _clearFocusCamera();
    });
    unawaited(_syncSpreadFromFocus(target));
    _clearFlipEndWaiter();
    if (queuedDirection != null) {
      unawaited(_turnFocusPage(queuedDirection));
    }
  }

  void _requestPreparedSpread(int spread) {
    if (_requestedPreparationSpread == spread) return;
    _requestedPreparationSpread = spread;
    _bookFlipController.requestSpread(spread);
  }

  void _resumePreparedInput() {
    if (!mounted ||
        widget.allPages.isEmpty ||
        _bookRendererReplacing ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    if (_waitingForDragPages && _openSpreadPointer != null) {
      _driveOpenSpreadDrag();
    }
    final direction = _pendingControlDirection;
    if (direction == null ||
        _openSpreadPointer != null ||
        _isTurningWithControl ||
        _isAnimatingToRequestedSpread ||
        _bookFlipController.isAnimating) {
      return;
    }
    final target = _singlePageFocusActive
        ? _spreadForFocusPage(
            (_focusPageIndex + direction)
                .clamp(0, widget.allPages.length - 1)
                .toInt(),
          )
        : (_spreadForFocusPage(_focusPageIndex) + direction).clamp(
            0,
            _bookSpreadCount - 1,
          );
    if (!_bookFlipController.isReady ||
        !_bookFlipController.isSpreadReady(target)) {
      return;
    }
    _pendingControlDirection = null;
    unawaited(_turnFocusPage(direction));
  }

  void _schedulePreparedDragReplay() {
    if (_dragReplayQueued) return;
    _dragReplayQueued = true;
    // 텍스처 준비 직후에는 실제 책 캔버스의 첫 배치가 한 프레임 늦을 수 있다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dragReplayQueued = false;
      if (mounted) _resumePreparedInput();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _driveOpenSpreadDrag() {
    if (!_isDraggingOpenSpread ||
        _openSpreadDirection == 0 ||
        _openSpreadReducedMotion ||
        _isPanningFocus) {
      return;
    }
    final target = _singlePageFocusActive && _focusTurnTargetPage != null
        ? _spreadForFocusPage(_focusTurnTargetPage!)
        : (_openSpreadStartSpread + _openSpreadDirection).clamp(
            0,
            _bookSpreadCount - 1,
          );
    if (!_bookFlipController.isReady ||
        !_bookFlipController.isSpreadReady(target)) {
      _waitingForDragPages = true;
      _requestPreparedSpread(target);
      return;
    }
    // 준비 완료 알림이 같은 손가락의 현재 위치를 이어받는다.
    _waitingForDragPages = false;
    if (!_bookDragStarted) {
      _bookDragStarted = true;
      if (!_bookFlipController.dragStart(_openSpreadLocalPosition)) {
        _bookDragStarted = false;
        _waitingForDragPages = true;
        _schedulePreparedDragReplay();
        return;
      }
    }
    _bookFlipController.dragToDistance(
      localPosition: _openSpreadLocalPosition,
      direction: _openSpreadDirection > 0
          ? FlipDirection.forward
          : FlipDirection.backward,
      distance:
          -_openSpreadDirection * _openSpreadTotalDx * _openSpreadMotionScale,
    );
  }

  void _handleOpenSpreadPointerDown(PointerDownEvent event, double pageWidth) {
    if (_singlePageFocusActive && _pendingSingleFocusRequest != null) return;
    if (_isTurningWithControl &&
        !_isPanningFocus &&
        !_bookFlipController.isAnimating) {
      return;
    }
    if (_isAnimatingToRequestedSpread) return;
    if (_openSpreadPointer != null) return;
    final regrabPan = _isPanningFocus;
    _canContinueSettledTurn =
        widget.singlePageFocus &&
        (regrabPan
            ? _focusPanController.isAnimating &&
                  _focusPanCommit &&
                  _focusPanController.value >= .8
            : _bookFlipController.settlingDirection != null &&
                  _bookFlipController.flipProgress >= .8);
    _openSpreadPanStartProgress = regrabPan ? _focusPanController.value : 0;
    if (regrabPan) {
      _focusPanEpoch++;
      _focusPanController.stop();
      _focusPanFinishingSoon = false;
    }
    _pendingControlDirection = null;
    _queuedTurnDirection = null;
    _requestedPreparationSpread = null;
    final focusedSpread = _spreadForFocusPage(_focusPageIndex);
    final currentSpread = _bookFlipController.isAnimating
        ? _bookFlipController.currentSpread
        : focusedSpread;
    if (_bookFlipController.currentSpread != currentSpread) {
      _bookFlipController.goToSpread(currentSpread);
    }
    final reducedMotion = SnapFitMotion.reduced(context);
    final ready = _bookFlipController.isReady;
    final started =
        reducedMotion ||
        regrabPan ||
        !ready ||
        _bookFlipController.dragStart(event.localPosition);
    if (!started || !mounted) return;
    _bookDragStarted = !reducedMotion && !regrabPan && ready;
    _waitingForDragPages = false;
    _openSpreadPointer = event.pointer;
    _openSpreadLocalPosition = event.localPosition;
    _openSpreadLastPosition = event.position;
    _openSpreadLastMoveTime = event.timeStamp;
    _openSpreadInstantVelocity = 0;
    _openSpreadVelocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
    _openSpreadTotalDx = 0;
    _openSpreadStartSpread = currentSpread;
    _openSpreadPageWidth = math.max(1, pageWidth);
    _openSpreadReducedMotion = reducedMotion;
    _openSpreadDirection = regrabPan
        ? ((_focusTurnTargetPage ?? _focusPageIndex) - _focusPageIndex).sign
        : reducedMotion
        ? 0
        : switch (_bookFlipController.flipDirection) {
            FlipDirection.forward => 1,
            FlipDirection.backward => -1,
            null => 0,
          };
    setState(() {
      _isDraggingOpenSpread = true;
      _isTurningWithControl = false;
      _suppressNextTapUp = false;
    });
  }

  void _continueFromSettledTurn() {
    final direction = _openSpreadDirection;
    final spread = (_openSpreadStartSpread + direction).clamp(
      0,
      _bookSpreadCount - 1,
    );
    final page = _singlePageFocusActive
        ? _focusTurnTargetPage ?? _focusPageIndex
        : _focusPageForSpread(spread);
    final targetSpread = _spreadForFocusPage(page);
    // 거의 착지한 이전 동작을 끝낸 뒤 현재 손가락의 이동을 다음 쪽에 연결한다.
    _isJumpingFocus = true;
    try {
      _bookFlipController.goToSpread(targetSpread);
    } finally {
      _isJumpingFocus = false;
    }
    _clearFlipEndWaiter();
    setState(() {
      _clearFocusCamera();
      _focusPageIndex = page;
      _isTurningWithControl = false;
      _isCoverFlipActive = false;
      _coverFlipDirection = 0;
      _openSpreadStartSpread = targetSpread;
      _openSpreadDirection = 0;
      _openSpreadPanStartProgress = 0;
      _bookDragStarted = false;
      _waitingForDragPages = false;
    });
    unawaited(_syncSpreadFromFocus(page));
  }

  void _handleOpenSpreadPointerMove(PointerMoveEvent event) {
    if (!_isDraggingOpenSpread || event.pointer != _openSpreadPointer) return;
    _openSpreadLocalPosition = event.localPosition;
    // Screen-space travel excludes the cover stage's own centring movement.
    final dx = event.position.dx - _openSpreadLastPosition.dx;
    _openSpreadLastPosition = event.position;
    final previousTime = _openSpreadLastMoveTime;
    if (dx != 0 && previousTime != null) {
      final elapsed = (event.timeStamp - previousTime).inMicroseconds;
      if (elapsed > 0) _openSpreadInstantVelocity = dx * 1000000 / elapsed;
    }
    _openSpreadLastMoveTime = event.timeStamp;
    _openSpreadVelocityTracker?.addPosition(event.timeStamp, event.position);
    _openSpreadTotalDx += dx;
    if (_openSpreadTotalDx.abs() > (widget.singlePageFocus ? 5 : 8)) {
      _suppressNextTapUp = true;
    }
    if (_canContinueSettledTurn && _openSpreadTotalDx.abs() > 5) {
      _canContinueSettledTurn = false;
      if (-_openSpreadDirection * _openSpreadTotalDx > 0) {
        _continueFromSettledTurn();
      }
    }
    if (_openSpreadDirection == 0 &&
        _openSpreadTotalDx.abs() > (widget.singlePageFocus ? 5 : 14)) {
      _openSpreadDirection = _openSpreadTotalDx < 0 ? 1 : -1;
      if (_singlePageFocusActive) {
        final target = (_focusPageIndex + _openSpreadDirection)
            .clamp(0, widget.allPages.length - 1)
            .toInt();
        if (target == _focusPageIndex) {
          if (!_openSpreadReducedMotion) _bookFlipController.dragCancel();
          return;
        }
        final pan = _spreadForFocusPage(target) == _openSpreadStartSpread;
        if (pan && !_openSpreadReducedMotion) {
          _bookFlipController.dragCancel();
        }
        setState(() => _beginFocusTransition(target, pan: pan));
      }
      final maxSpread =
          math.max(_bookSpreadCount, _bookFlipController.totalSpreads) - 1;
      final targetSpread = (_openSpreadStartSpread + _openSpreadDirection)
          .clamp(0, maxSpread);
      final isCoverEdgeFlip =
          (_openSpreadStartSpread <= 0 && _openSpreadDirection > 0) ||
          (_openSpreadStartSpread == 1 && _openSpreadDirection < 0);
      if (!_isPanningFocus &&
          !_openSpreadReducedMotion &&
          isCoverEdgeFlip &&
          targetSpread != _openSpreadStartSpread &&
          mounted) {
        setState(() {
          _isCoverFlipActive = true;
          _coverFlipDirection = _openSpreadDirection;
        });
      }
    }
    if (_singlePageFocusActive) {
      if (_focusTurnTargetPage == null) return;
      if (_isPanningFocus) {
        if (!_openSpreadReducedMotion) {
          _focusPanController.value =
              (_openSpreadPanStartProgress +
                      -_openSpreadDirection *
                          _openSpreadTotalDx *
                          _openSpreadMotionScale /
                          _openSpreadPageWidth)
                  .clamp(0.0, 1.0);
        }
        return;
      }
    }
    _driveOpenSpreadDrag();
  }

  void _handleOpenSpreadPointerUp(PointerUpEvent event) {
    if (!_isDraggingOpenSpread || event.pointer != _openSpreadPointer) return;
    final rawVelocity = _usesPreviewPointerMotion
        ? _openSpreadInstantVelocity
        : _openSpreadVelocityTracker?.getVelocity().pixelsPerSecond.dx ?? 0.0;
    final movementTime = _openSpreadLastMoveTime;
    final velocity =
        _usesPreviewPointerMotion &&
            movementTime != null &&
            event.timeStamp - movementTime > const Duration(milliseconds: 120)
        ? 0.0
        : rawVelocity;
    final waitingForPaper = !_bookDragStarted || _waitingForDragPages;
    final progress =
        (_openSpreadReducedMotion || waitingForPaper) && !_isPanningFocus
        ? (-_openSpreadDirection *
                  _openSpreadTotalDx *
                  _openSpreadMotionScale /
                  _openSpreadPageWidth)
              .clamp(0.0, 1.0)
        : _isPanningFocus
        ? _focusPanController.value
        : _bookFlipController.flipProgress;
    final forwardVelocity = -_openSpreadDirection * velocity;
    final shouldCommit = _usesPreviewPointerMotion
        ? progress > .38 || (progress > .08 && forwardVelocity > 600)
        : progress >= _bookFlipPhysics.commitThreshold ||
              (progress >= 0.12 &&
                  _openSpreadTotalDx.abs() >= _openSpreadFlingMinDistance &&
                  forwardVelocity >= _openSpreadCommitVelocity);
    final reducedMotion = _openSpreadReducedMotion;
    final direction = _openSpreadDirection;
    final panning = _isPanningFocus;
    if (!reducedMotion && !panning && !waitingForPaper) {
      _bookFlipController.dragEndWithDecision(
        velocity * _openSpreadMotionScale,
        commit: shouldCommit,
      );
    }
    if (!reducedMotion && !panning && waitingForPaper && _bookDragStarted) {
      _bookFlipController.dragCancel();
    }
    _bookDragStarted = false;
    _waitingForDragPages = false;
    _openSpreadPointer = null;
    _openSpreadLastPosition = Offset.zero;
    _openSpreadVelocityTracker = null;
    _openSpreadTotalDx = 0;
    _openSpreadStartSpread = 0;
    _openSpreadDirection = 0;
    if (mounted) {
      setState(() {
        _isDraggingOpenSpread = false;
        if (!reducedMotion && waitingForPaper && !panning) {
          // 아직 엔진이 시작되지 않은 손동작에는 완료 콜백이 오지 않는다.
          _clearFocusCamera();
          _isCoverFlipActive = false;
          _coverFlipDirection = 0;
        }
      });
    }
    if (panning) {
      unawaited(_settleFocusPan(commit: shouldCommit));
      return;
    }
    if (!reducedMotion && waitingForPaper && shouldCommit && direction != 0) {
      unawaited(_turnFocusPage(direction));
      return;
    }
    if (reducedMotion && shouldCommit && direction != 0) {
      unawaited(_turnFocusPage(direction));
    }
  }

  void _handleOpenSpreadPointerCancel(PointerCancelEvent event) {
    if (!_isDraggingOpenSpread || event.pointer != _openSpreadPointer) return;
    final panning = _isPanningFocus;
    final waitingForPaper = !_bookDragStarted || _waitingForDragPages;
    if (!_openSpreadReducedMotion && !panning && _bookDragStarted) {
      _bookFlipController.dragCancel();
    }
    _bookDragStarted = false;
    _waitingForDragPages = false;
    _openSpreadPointer = null;
    _openSpreadLastPosition = Offset.zero;
    _openSpreadVelocityTracker = null;
    _openSpreadTotalDx = 0;
    _openSpreadStartSpread = 0;
    _openSpreadDirection = 0;
    if (mounted) {
      setState(() {
        _isDraggingOpenSpread = false;
        if (waitingForPaper && !panning) {
          _clearFocusCamera();
          _isCoverFlipActive = false;
          _coverFlipDirection = 0;
        }
      });
    }
    if (panning) unawaited(_settleFocusPan(commit: false));
  }

  Widget _buildBookFlipFocusReader(
    double pageWidth,
    double pageHeight, {
    required double pixelRatio,
  }) {
    final epoch = _bookRenderEpoch;
    // The live spread above the renderer also supplies its loading/error view.
    // Never mount a second copy of that cover (and its GlobalKeys) underneath it.
    Widget fallbackSpread(BuildContext context) =>
        SizedBox(width: pageWidth * 2, height: pageHeight);

    return BookFlip.builder(
      key: ValueKey(
        'book_flip_${widget.singlePageFocus ? 'album' : 'material'}_${_bookPageCount}_${pageWidth.toStringAsFixed(1)}_${pageHeight.toStringAsFixed(1)}_${_bookContentRevision}_$epoch',
      ),
      pageCount: _bookPageCount,
      progressive: true,
      preparationPaused: _isPanningFocus,
      pageSize: Size(pageWidth, pageHeight),
      pixelRatio: pixelRatio,
      preparePage: (context, index) async {
        if (index > widget.allPages.length) return;
        final page = widget.allPages[index == 0 ? 0 : index - 1];
        try {
          await _readerImageBuilder(
            pageWidth,
            pageHeight,
          ).prepareImages(context, page.layers);
        } on BookFlipPreparationPaused {
          rethrow;
        } catch (_) {
          if (mounted && context.mounted && epoch == _bookRenderEpoch) {
            setState(() => _readerPhotoFailed = true);
          }
          rethrow;
        }
      },
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
      curl: widget.singlePageFocus
          ? BookFlipCurl.albumPreview
          : _isCoverFlipActive
          ? const BookFlipCurl(bend: 0.9, foldTilt: 0.78, droop: 0.2)
          : const BookFlipCurl(
              bend: 0.48,
              foldTilt: 0.72,
              droop: 0.08,
              roll: 1.0,
            ),
      effects: const BookFlipEffects(
        gloss: false,
        grain: false,
        castShadow: true,
        spineShadow: false,
        edge: false,
        translucency: false,
      ),
      meshResolution: widget.singlePageFocus ? 41 : 54,
      onFlipStart: (spread, direction) {
        if (!mounted || epoch != _bookRenderEpoch) return;
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
      onFlipEnd: (spread) {
        if (!mounted || epoch != _bookRenderEpoch) return;
        _handleBookSpreadChanged(spread, ended: true);
      },
      loadingBuilder: fallbackSpread,
      errorBuilder: fallbackSpread,
    );
  }

  Widget _buildFocusReader(BuildContext context) {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
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
        final landscapeHeaderSpace = math.max(
          48.0,
          media.textScaler.scale(13) * 1.2 + 30,
        );
        final verticalMargin = isLandscape ? landscapeHeaderSpace + 76 : 38.0;
        final maxSpreadWidth = screen.width - railInset - horizontalMargin;
        final maxSpreadHeight = usableHeight - verticalMargin;
        var pageHeight = maxSpreadHeight;
        var pageWidth = pageHeight * ratio;
        final visiblePageCount = _singlePageFocusActive ? 1 : 2;
        if (pageWidth * visiblePageCount > maxSpreadWidth) {
          pageWidth = maxSpreadWidth / visiblePageCount;
          pageHeight = pageWidth / ratio;
        }
        final capturePixelRatio = readerCapturePixelRatio(
          Size(pageWidth, pageHeight),
          _bookPageCount,
          media.devicePixelRatio,
        );
        _syncBookRenderer(Size(pageWidth, pageHeight), capturePixelRatio);
        final currentSpread =
            !_bookRendererReplacing && _bookFlipController.totalSpreads > 0
            ? _bookFlipController.currentSpread
            : _spreadForFocusPage(_focusPageIndex);
        final showClosedCover =
            _focusPageIndex == 0 &&
            (_bookRendererReplacing || !_bookFlipController.isAnimating) &&
            !_isCoverFlipActive;
        final stageWidth = pageWidth * 2;
        final stageHeight = pageHeight;
        final minTop = isLandscape ? landscapeHeaderSpace : 12.0;
        final centeredTop = (usableHeight - stageHeight) / 2;
        final stageTop = math.max(
          minTop,
          isLandscape ? centeredTop - 20.0 : centeredTop,
        );
        final stageOffsetX = 0.0;
        final stageOverflow = widget.singlePageFocus ? 28.0 : 16.0;

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              top: stageTop - stageOverflow,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: screen.width,
                  height: stageHeight + stageOverflow * 2,
                  child: ClipRect(
                    key: const ValueKey('reader-page-viewport'),
                    clipBehavior: _singlePageFocusActive
                        ? Clip.hardEdge
                        : Clip.none,
                    child: OverflowBox(
                      minWidth: stageWidth,
                      maxWidth: stageWidth,
                      minHeight: stageHeight,
                      maxHeight: stageHeight,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _bookFlipController,
                          _focusPanController,
                        ]),
                        builder: (context, child) {
                          final flipProgress = _bookFlipController.flipProgress
                              .clamp(0.0, 1.0);
                          final coverSettleStart = _coverFlipDirection < 0
                              ? 0.72
                              : 0.68;
                          final delayedCoverProgress =
                              ((flipProgress - coverSettleStart) /
                                      (1.0 - coverSettleStart))
                                  .clamp(0.0, 1.0);
                          final stageProgress = widget.singlePageFocus
                              ? flipProgress *
                                    flipProgress *
                                    (3 - 2 * flipProgress)
                              : Curves.easeInOutCubic.transform(
                                  delayedCoverProgress,
                                );
                          final coverCenteredOffset = -pageWidth / 2;
                          var dynamicStageOffset = stageOffsetX;
                          if (_singlePageFocusActive) {
                            final source =
                                _focusTurnSourcePage ?? _focusPageIndex;
                            final target = _focusTurnTargetPage ?? source;
                            final progress = _isPanningFocus
                                ? _focusPanController.value
                                : flipProgress *
                                      flipProgress *
                                      (3 - 2 * flipProgress);
                            dynamicStageOffset += ui.lerpDouble(
                              _focusCameraOffset(source, pageWidth),
                              _focusCameraOffset(target, pageWidth),
                              progress,
                            )!;
                          } else if (showClosedCover) {
                            dynamicStageOffset += coverCenteredOffset;
                          } else if (_isCoverFlipActive &&
                              _coverFlipDirection != 0) {
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
                          } else if (currentSpread <= 0 &&
                              _focusPageIndex == 0) {
                            dynamicStageOffset += coverCenteredOffset;
                          }

                          return Transform.translate(
                            key: const ValueKey('reader-focus-transform'),
                            offset: Offset(dynamicStageOffset, 0),
                            child: child,
                          );
                        },
                        // Entry size is already interpolated by the opening overlay.
                        // Keep this subtree stable through handoff and rotate directly
                        // to the new viewport, without another size-animation ticker.
                        child: SizedBox(
                          key: const ValueKey('reader-focus-book'),
                          width: stageWidth,
                          height: stageHeight,
                          child: Listener(
                            behavior: HitTestBehavior.translucent,
                            onPointerDown: (event) =>
                                _handleOpenSpreadPointerDown(event, pageWidth),
                            onPointerMove: _handleOpenSpreadPointerMove,
                            onPointerUp: _handleOpenSpreadPointerUp,
                            onPointerCancel: _handleOpenSpreadPointerCancel,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: showClosedCover
                                  ? () {
                                      if (_suppressNextTapUp) {
                                        _suppressNextTapUp = false;
                                        return;
                                      }
                                      _turnFocusPage(1);
                                    }
                                  : null,
                              onTapUp: (details) {
                                if (showClosedCover || _isCoverFlipActive)
                                  return;
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
                                            isCoverEdgeAnimating ||
                                            !_bookFlipController.isAnimating,
                                        child:
                                            bookFlipChild ??
                                            const SizedBox.shrink(),
                                      );
                                    },
                                    child: IgnorePointer(
                                      ignoring: true,
                                      child: ClipRect(
                                        clipBehavior:
                                            widget.singlePageFocus &&
                                                !showClosedCover
                                            ? Clip.none
                                            : Clip.hardEdge,
                                        clipper: showClosedCover
                                            ? const _ClosedCoverClipper()
                                            : null,
                                        child: Opacity(
                                          opacity: showClosedCover ? 0.02 : 1.0,
                                          child: _buildBookFlipFocusReader(
                                            pageWidth,
                                            pageHeight,
                                            pixelRatio: capturePixelRatio,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (showClosedCover)
                                    IgnorePointer(
                                      child: _PremiumSpreadStage(
                                        isLandscape: isLandscape,
                                        hidePaper: true,
                                        child: KeyedSubtree(
                                          key: ValueKey(_bookContentRevision),
                                          child: _buildStaticFocusSpread(
                                            pageWidth,
                                            pageHeight,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (!showClosedCover)
                                    AnimatedBuilder(
                                      animation: _bookFlipController,
                                      child: IgnorePointer(
                                        key: const ValueKey(
                                          'reader-live-spread',
                                        ),
                                        child: _PremiumSpreadStage(
                                          isLandscape: isLandscape,
                                          child: KeyedSubtree(
                                            key: ValueKey(_bookContentRevision),
                                            child: _buildStaticFocusSpread(
                                              pageWidth,
                                              pageHeight,
                                            ),
                                          ),
                                        ),
                                      ),
                                      builder: (context, child) => Visibility(
                                        visible:
                                            _bookRendererReplacing ||
                                            !_bookFlipController.isReady ||
                                            (!_bookFlipController.isAnimating &&
                                                !_isCoverFlipActive),
                                        maintainState: true,
                                        child: child!,
                                      ),
                                    ),
                                  if (_readerPhotoFailed)
                                    Align(
                                      alignment: Alignment.bottomCenter,
                                      child: TextButton.icon(
                                        key: const ValueKey(
                                          'reader-retry-photos',
                                        ),
                                        onPressed: () => setState(() {
                                          _readerPhotoFailed = false;
                                          _bookContentRevision++;
                                        }),
                                        icon: const ExperienceIcon('RefreshCw', size: 18),
                                        label: const Text('사진 다시 불러오기'),
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
              ),
            ),
            if (_singlePageFocusActive)
              Positioned(
                left: 0,
                right: 0,
                bottom: bottomInset + 8,
                child: _SinglePageReaderControls(
                  currentPage: _focusPageIndex,
                  navigationPage: _focusTurnTargetPage ?? _focusPageIndex,
                  pageCount: math.max(0, widget.allPages.length - 1),
                  busy:
                      _openSpreadPointer != null ||
                      _pendingSingleFocusRequest != null ||
                      _isAnimatingToRequestedSpread,
                  onPrevious: () => _turnFocusPage(-1),
                  onNext: () => _turnFocusPage(1),
                  onTogglePageList: widget.onTogglePageList,
                  pageListVisible: widget.pageListVisible,
                ),
              )
            else if (isLandscape)
              Positioned(
                left: 0,
                right: 0,
                bottom: 6 + bottomInset,
                child: Center(
                  child: SizedBox(
                    width: math.min(326.0, screen.width - railInset - 48),
                    child: _FocusReaderControls(
                      canGoBack: _controlNavigationSpread > 0,
                      canGoForward:
                          _controlNavigationSpread < _bookSpreadCount - 1,
                      onPrevious: () => _turnFocusPage(-1),
                      canEdit: vm.album?.allowsEditing != false,
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
                      canGoBack: _controlNavigationSpread > 0,
                      canGoForward:
                          _controlNavigationSpread < _bookSpreadCount - 1,
                      onPrevious: () => _turnFocusPage(-1),
                      canEdit: vm.album?.allowsEditing != false,
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

  Future<void> _openInnerDetail({
    required double screenW,
    required double singlePageW,
    required double singlePageH,
    required int spreadIndex,
    double? tapX,
  }) async {
    if (spreadIndex <= 0 || widget.allPages.length <= 1) return;
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final album = vm.album;
    final session = vm.editSessionIdentity;
    final owner = ref.read(albumEditorOwnerReaderProvider)();
    final actor = ref.read(albumCollaborationActorProvider);

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
    var viewedId = widget.allPages[tappedPageIdx].id;

    final action = await Navigator.push<AlbumReaderInnerDetailAction>(
      context,
      PageRouteBuilder<AlbumReaderInnerDetailAction>(
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
            onPageFocused: (id) => viewedId = id,
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (!identical(ref.read(albumEditorViewModelProvider.notifier), vm) ||
        !identical(vm.editSessionIdentity, session) ||
        vm.album?.id != album?.id ||
        vm.album?.userId != album?.userId ||
        ref.read(albumEditorOwnerReaderProvider)() != owner ||
        ref.read(albumCollaborationActorProvider) != actor) {
      return;
    }
    _restoreFocusedPage(vm, viewedId, tappedPageIdx);
    if (action == AlbumReaderInnerDetailAction.prepareBook) {
      widget.onPrepareBookOrder?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.focusMode) return _buildFocusReader(context);

    final screenW = MediaQuery.sizeOf(context).width;
    final screenH = MediaQuery.sizeOf(context).height;

    // 표시 가능한 최대 너비 (여백 포함)
    final availW = (screenW - 20) * widget.maxSpreadWidthFactor;

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
          left: 18,
          bottom: 12,
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
          right: 18,
          bottom: 12,
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AlbumStageStyle.glass(context),
              shape: BoxShape.circle,
              border: Border.all(color: AlbumStageStyle.line(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, size: 28, color: AlbumStageStyle.ink(context)),
          ),
        ),
      ),
    );
  }
}

// Keep the renderer warm without showing its unused left half behind a closed book.
class _ClosedCoverClipper extends CustomClipper<Rect> {
  const _ClosedCoverClipper();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height);

  @override
  bool shouldReclip(covariant _ClosedCoverClipper oldClipper) => false;
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
    final floorShadowAlpha = hidePaper ? 0.0 : (isLandscape ? 0.08 : 0.06);
    final contactShadowAlpha = hidePaper ? 0.0 : (isLandscape ? 0.05 : 0.04);
    final cardShadowAlpha = hidePaper ? 0.0 : 0.04;
    final spineWidth = isLandscape ? 48.0 : 34.0;
    final spineCreaseWidth = isLandscape ? 14.0 : 10.0;
    final edgeDepth = isLandscape ? 5.0 : 4.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final halfWidth = width / 2;

        Widget pageEdge({required Alignment alignment}) {
          if (hidePaper) return const SizedBox.shrink();
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
          if (hidePaper) return const SizedBox.shrink();
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
                  borderRadius: BorderRadius.circular(999),
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: contactShadowAlpha),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                // Keep the book mounted when cover chrome disappears; moving
                // its element would re-rasterise every page at the transition.
                color: hidePaper ? Colors.transparent : const Color(0xFFFFFCF5),
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
                                    alpha: hidePaper
                                        ? 0
                                        : (isLandscape ? 0.085 : 0.06),
                                  ),
                                  const Color(
                                    0xFFFFFCF5,
                                  ).withValues(alpha: hidePaper ? 0 : 0.22),
                                  const Color(0xFF6B5843).withValues(
                                    alpha: hidePaper
                                        ? 0
                                        : (isLandscape ? 0.09 : 0.065),
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
                                  alpha: hidePaper
                                      ? 0
                                      : (isLandscape ? 0.075 : 0.052),
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
                                    Colors.black.withValues(
                                      alpha: hidePaper ? 0 : 0.035,
                                    ),
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
                                    Colors.black.withValues(
                                      alpha: hidePaper ? 0 : 0.032,
                                    ),
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

class _SinglePageReaderControls extends StatelessWidget {
  const _SinglePageReaderControls({
    required this.currentPage,
    required this.navigationPage,
    required this.pageCount,
    required this.busy,
    required this.onPrevious,
    required this.onNext,
    required this.onTogglePageList,
    required this.pageListVisible,
  });

  final int currentPage;
  final int navigationPage;
  final int pageCount;
  final bool busy;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onTogglePageList;
  final bool pageListVisible;

  @override
  Widget build(BuildContext context) {
    final ink = AlbumStageStyle.ink(context);
    return Column(
      key: const ValueKey('reader-controls'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: '이전 페이지',
              onPressed: !busy && navigationPage > 0 ? onPrevious : null,
              icon: const ExperienceIcon('ChevronLeft'),
            ),
            SizedBox(
              width: 124,
              child: Semantics(
                liveRegion: true,
                excludeSemantics: true,
                label: currentPage == 0
                    ? '표지, 내지 전체 $pageCount쪽'
                    : '내지 $currentPage쪽, 전체 $pageCount쪽',
                child: Text(
                  key: const ValueKey('reader-page-position'),
                  currentPage == 0
                      ? '표지 / $pageCount쪽'
                      : '$currentPage / $pageCount쪽',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: ink),
                ),
              ),
            ),
            IconButton(
              tooltip: '다음 페이지',
              onPressed: !busy && navigationPage < pageCount ? onNext : null,
              icon: const ExperienceIcon('ChevronRight'),
            ),
          ],
        ),
        if (onTogglePageList != null)
          Tooltip(
            message: pageListVisible ? '쪽 목록 닫기' : '쪽 목록 열기',
            child: TextButton.icon(
              key: const ValueKey('reader-page-list-toggle'),
              onPressed: onTogglePageList,
              icon: Icon(
                pageListVisible
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.grid_view_rounded,
                size: 16,
              ),
              label: const Text('전체 쪽'),
              style: TextButton.styleFrom(
                foregroundColor: ink.withValues(alpha: .7),
                minimumSize: const Size(96, 44),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }
}

class _FocusReaderControls extends StatelessWidget {
  const _FocusReaderControls({
    this.canEdit = true,
    required this.canGoBack,
    required this.canGoForward,
    required this.onPrevious,
    required this.onEdit,
    required this.onNext,
  });

  final bool canGoBack;
  final bool canEdit;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback onEdit;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final ink = AlbumStageStyle.ink(context);
    // A tinted surface gives separation without a live backdrop blur.
    return DecoratedBox(
      key: const ValueKey('reader-controls'),
      decoration: BoxDecoration(
        color: AlbumStageStyle.glass(context),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AlbumStageStyle.line(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: AlbumNavigationDock(
          height: 52,
          onPrevious: canGoBack ? onPrevious : null,
          onNext: canGoForward ? onNext : null,
          primary: Tooltip(
            message: canEdit ? '현재 페이지 편집' : '보기 전용 앨범',
            child: Semantics(
              button: true,
              enabled: canEdit,
              label: canEdit ? '현재 페이지 편집' : '보기 전용 앨범',
              excludeSemantics: true,
              onTap: canEdit ? onEdit : null,
              child: Material(
                color: AlbumStageStyle.controlFill(context),
                borderRadius: BorderRadius.circular(26),
                child: InkWell(
                  onTap: canEdit ? onEdit : null,
                  borderRadius: BorderRadius.circular(26),
                  child: SizedBox(
                    height: 48,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            canEdit
                                ? Icons.edit_outlined
                                : Icons.visibility_outlined,
                            size: 17,
                            color: ink.withValues(alpha: canEdit ? 1 : .45),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              canEdit ? '편집' : '보기',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: ink.withValues(alpha: canEdit ? 1 : .45),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
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
      ),
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
      width: 2,
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

          isLeft ? _buildSpine() : SizedBox(width: 2), // 2 맞춤

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
      albumPageRenderSignature(page),
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
  final bool showBookDepth;

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
    this.showBookDepth = false,
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

    final artwork = CoverLayout(
      aspect: aspect,
      layers: interaction.sortByZ(page.layers),
      isInteracting: false,
      leftSpine: 14.0,
      wrapSpineArtwork: true,
      backgroundColor: page.backgroundColor != null
          ? Color(page.backgroundColor!).withAlpha(0xFF)
          : null,
      onCoverSizeChanged: onCoverSizeChanged,
      buildImage: (layer) => layerBuilder.buildImage(layer, isCover: true),
      buildWrappedImage: (layer) =>
          layerBuilder.buildImage(layer, isCover: true, wrapSpine: true),
      buildText: (layer) => layerBuilder.buildText(layer, isCover: true),
      sortedByZ: interaction.sortByZ,
      theme: coverTheme,
    );

    Widget fitArtwork(Widget child) => OverflowBox(
      minWidth: logicalW,
      maxWidth: logicalW,
      minHeight: logicalH,
      maxHeight: logicalH,
      alignment: Alignment.center,
      child: Transform.scale(scale: scale, child: child),
    );

    return HomeCoverFrame(
      width: pageW,
      height: pageH,
      shadowScale: shadowScale,
      showShadow: true,
      showBookDepth: showBookDepth,
      showMaterial: true,
      bindingColor: page.backgroundColor != null
          ? Color(page.backgroundColor!).withAlpha(0xFF)
          : coverTheme.gradient.colors.first,
      bindingArtwork: showBookDepth
          ? fitArtwork(artwork.bindingPreview(Size(logicalW, logicalH)))
          : null,
      child: RepaintBoundary(key: coverKey, child: fitArtwork(artwork)),
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
              FittedBox(
                fit: BoxFit.contain,
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
