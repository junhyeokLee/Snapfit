import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../domain/entities/album.dart';
import 'home_album_cover_thumbnail.dart';
import 'home_album_actions.dart';
import 'home_album_progress_builder.dart';
import 'album_open_origin.dart';

/// 슬라이더용 앨범 커버 카드
class HomeAlbumSliderCard extends ConsumerStatefulWidget {
  final Album album;
  final int index;
  final double currentPage;
  final ValueListenable<double>? pagePosition;
  final GlobalKey? coverOriginKey;
  final bool animateIdle;

  const HomeAlbumSliderCard({
    super.key,
    required this.album,
    required this.index,
    required this.currentPage,
    this.pagePosition,
    this.coverOriginKey,
    this.animateIdle = true,
  });

  @override
  ConsumerState<HomeAlbumSliderCard> createState() =>
      _HomeAlbumSliderCardState();
}

class _HomeAlbumSliderCardState extends ConsumerState<HomeAlbumSliderCard>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _tapController;
  late final AnimationController _floatController;
  late final Animation<double> _tapScale;
  Timer? _pendingUnpress;
  final GlobalKey _coverOriginKey = GlobalKey();
  late Listenable _bookMotion;
  bool _motionEnabled = false;
  bool _appActive = true;
  Widget? _sizedLayout;
  (double, Size)? _coverGeometry;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _tapScale = Tween<double>(
      begin: 1,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _tapController, curve: Curves.easeOut));
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );
    _bookMotion = Listenable.merge([_floatController, widget.pagePosition]);
    widget.pagePosition?.addListener(_syncFloatAnimation);
    WidgetsBinding.instance.addObserver(this);
    _appActive =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sizedLayout = null;
    _motionEnabled =
        !MediaQuery.disableAnimationsOf(context) && TickerMode.of(context);
    _syncFloatAnimation();
  }

  @override
  void didUpdateWidget(covariant HomeAlbumSliderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sizedLayout = null;
    if (oldWidget.pagePosition != widget.pagePosition) {
      oldWidget.pagePosition?.removeListener(_syncFloatAnimation);
      widget.pagePosition?.addListener(_syncFloatAnimation);
      _bookMotion = Listenable.merge([_floatController, widget.pagePosition]);
    }
    _syncFloatAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _syncFloatAnimation();
  }

  void _syncFloatAnimation() {
    if (!widget.animateIdle ||
        !_motionEnabled ||
        !_appActive ||
        _focusFactor() == 0) {
      _floatController.stop();
    } else if (!_floatController.isAnimating) {
      _floatController.repeat();
    }
  }

  void _cancelPendingUnpress() {
    _pendingUnpress?.cancel();
    _pendingUnpress = null;
  }

  @override
  void dispose() {
    _cancelPendingUnpress();
    WidgetsBinding.instance.removeObserver(this);
    widget.pagePosition?.removeListener(_syncFloatAnimation);
    _tapController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  /// 0..1, 포커스일수록 1 (중앙에 가까울수록 1)
  double _focusFactor() {
    final diff =
        ((widget.pagePosition?.value ?? widget.currentPage) - widget.index)
            .abs();
    if (diff >= 1) return 0;
    return 1 - diff;
  }

  @override
  Widget build(BuildContext context) => HomeAlbumProgressBuilder(
    album: widget.album,
    builder: (context, progress) {
      // Paint immediately using small ratio metadata. The shared progress
      // worker supplies the saved print size without decoding JSON in build.
      final coverSize =
          progress?.coverSize ??
          widget.album.cachedPhysicalCoverSize ??
          widget.album.estimatedPhysicalCoverSize;
      final geometry = (coverSize.ratio, coverSize.realSize);
      if (_sizedLayout == null || _coverGeometry != geometry) {
        _coverGeometry = geometry;
        _sizedLayout = _buildSizedCover(coverSize);
      }
      // A progress-only update must not reconstruct or relayout the artwork.
      return _sizedLayout!;
    },
  );

  Widget _buildSizedCover(CoverSize coverSize) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;
        final screen = MediaQuery.sizeOf(context);
        final isScreenLandscape = screen.width > screen.height;
        final ratio = coverSize.ratio;
        final bool isLandscape = ratio > 1.12;
        final bool isPortrait = ratio < 0.88;
        final fallbackAsset = isPortrait
            ? 'assets/snapfit_home_portrait.jpg'
            : isLandscape
            ? 'assets/snapfit_home_landscape.jpg'
            : 'assets/snapfit_home_square.jpg';
        final stageMaxHeight = math.max(h, 1.0);
        // Scale proportionally to screen width (design base: 390px).
        final sw = screen.width;
        final maxReferenceSide = math.max(
          1.0,
          math.min(
            stageMaxHeight - 24,
            math.min(w * .9, isScreenLandscape ? 420.0 : sw * .88),
          ),
        );
        final squareReferenceSide = maxReferenceSide;
        final previewCm = math.max(
          20.0,
          math.max(coverSize.realSize.width, coverSize.realSize.height),
        );
        final contentWidth =
            squareReferenceSide * coverSize.realSize.width / previewCm;
        final contentHeight =
            squareReferenceSide * coverSize.realSize.height / previewCm;
        final coverContent = OverflowBox(
          minWidth: 0,
          minHeight: 0,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          alignment: Alignment.center,
          child: SizedBox(
            key: widget.coverOriginKey ?? _coverOriginKey,
            width: contentWidth,
            height: contentHeight,
            child: HomeAlbumCoverThumbnail(
              album: widget.album,
              height: contentHeight,
              maxWidth: contentWidth,
              showShadow: true,
              showBookDepth: true,
              bookMotion: _bookMotion,
              shadowScaleMultiplier: widget.animateIdle ? 9.2 : 1.0,
              fallbackAsset: fallbackAsset,
            ),
          ),
        );

        final closedCover = AnimatedBuilder(
          animation: _bookMotion,
          builder: (context, child) {
            final focus = _focusFactor();
            final pageDelta =
                widget.index -
                (widget.pagePosition?.value ?? widget.currentPage);
            final gapPush = pageDelta * (w + 24);
            final floating = widget.animateIdle
                ? ((math.sin(_floatController.value * math.pi * 2) + 1) / 2) *
                      focus
                : 0.0;
            final floatOffset =
                -(isScreenLandscape ? 16.0 : screen.height * (24 / 844)) *
                floating;
            final focusedRotateY = widget.animateIdle
                ? -0.10 + (0.02 * floating)
                : -.04;
            return Transform.translate(
              offset: Offset(gapPush, floatOffset),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, .00024)
                  ..rotateX(widget.animateIdle ? -.04 - .004 * floating : -.01)
                  ..rotateY(focusedRotateY),
                child: child,
              ),
            );
          },
          child: Center(child: coverContent),
        );

        return GestureDetector(
          onTapDown: (_) {
            _cancelPendingUnpress();
            _tapController.forward();
          },
          onTapUp: (_) {
            _cancelPendingUnpress();
            _pendingUnpress = Timer(const Duration(milliseconds: 120), () {
              if (mounted) _tapController.reverse();
              _pendingUnpress = null;
            });
          },
          onTapCancel: () {
            _cancelPendingUnpress();
            _tapController.reverse();
          },
          onTap: () => _onTapThenNavigate(context),
          child: AnimatedBuilder(
            animation: _tapScale,
            builder: (context, child) {
              return Transform.scale(
                scale: _tapScale.value,
                alignment: Alignment.center,
                child: Opacity(opacity: _tapScale.value, child: child),
              );
            },
            child: closedCover,
          ),
        );
      },
    );
  }

  /// Calm covers open immediately; the optional floating stage keeps its press.
  void _onTapThenNavigate(BuildContext context) {
    _cancelPendingUnpress();
    // The calm home cover opens on release, without waiting for an idle/press
    // animation. Keep the older animated presentation available to other users.
    if (!widget.animateIdle || MediaQuery.disableAnimationsOf(context)) {
      _tapController.reset();
      _handleTap(context);
      return;
    }
    _tapController.forward();
    void onStatus(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _tapController.removeStatusListener(onStatus);
        _tapController.reset();
        _handleTap(context);
      }
    }

    if (_tapController.status == AnimationStatus.completed) {
      _tapController.reset();
      _handleTap(context);
      return;
    }
    _tapController.addStatusListener(onStatus);
  }

  Future<void> _handleTap(BuildContext context) async {
    try {
      await HomeAlbumActions.openAlbum(
        context,
        ref,
        widget.album,
        canContinue: () =>
            mounted && TickerMode.getValuesNotifier(context).value.enabled,
        coverOrigin: () =>
            AlbumOpenOrigin.capture(widget.coverOriginKey ?? _coverOriginKey),
      );
    } catch (e) {
      if (mounted) _tapController.reverse();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('앨범 편집을 열 수 없습니다: $e')));
      }
    }
  }
}
