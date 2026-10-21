import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../domain/entities/album.dart';
import 'home_album_cover_thumbnail.dart';
import 'home_album_actions.dart';
import 'album_open_origin.dart';

/// 슬라이더용 앨범 커버 카드
class HomeAlbumSliderCard extends ConsumerStatefulWidget {
  final Album album;
  final int index;
  final double currentPage;
  final ValueListenable<double>? pagePosition;
  final GlobalKey? coverOriginKey;

  const HomeAlbumSliderCard({
    super.key,
    required this.album,
    required this.index,
    required this.currentPage,
    this.pagePosition,
    this.coverOriginKey,
  });

  @override
  ConsumerState<HomeAlbumSliderCard> createState() =>
      _HomeAlbumSliderCardState();
}

class _HomeAlbumSliderCardState extends ConsumerState<HomeAlbumSliderCard>
    with TickerProviderStateMixin {
  late final AnimationController _tapController;
  late final AnimationController _floatController;
  late final Animation<double> _tapScale;
  Timer? _pendingUnpress;
  final GlobalKey _coverOriginKey = GlobalKey();

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) || !TickerMode.of(context)) {
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
  Widget build(BuildContext context) {
    final coverSize = widget.album.physicalCoverSize;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 0.w, vertical: 0.h),
      child: LayoutBuilder(
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
          final maxReferenceSide = math.max(
            1.0,
            isScreenLandscape
                ? math.min(stageMaxHeight - 40, math.min(292.0, w * .84))
                : math.min(318.w, math.min(w * .84, stageMaxHeight - 48.h)),
          );
          // During rotation or on short screens, the available maximum can
          // fall below the preferred minimum. Keep the clamp bounds ordered.
          final squareReferenceSide =
              (isScreenLandscape ? stageMaxHeight * .76 : 306.w)
                  .clamp(
                    math.min(
                      isScreenLandscape ? 190.0 : 258.0,
                      maxReferenceSide,
                    ),
                    maxReferenceSide,
                  )
                  .toDouble();
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
                bookMotion: _floatController,
                shadowScaleMultiplier: 9.2,
                fallbackAsset: fallbackAsset,
              ),
            ),
          );

          final closedCover = AnimatedBuilder(
            animation: Listenable.merge([
              _floatController,
              widget.pagePosition,
            ]),
            builder: (context, child) {
              final focus = _focusFactor();
              final pageDelta =
                  widget.index -
                  (widget.pagePosition?.value ?? widget.currentPage);
              final gapPush = pageDelta * (w + 24);
              final phase = math.sin(_floatController.value * math.pi * 2);
              final floating = ((phase + 1) / 2) * focus;
              final floatOffset = -(isScreenLandscape ? 16.0 : 24.h) * floating;
              final focusedRotateY = -0.10 + (0.02 * floating);
              return Transform.translate(
                offset: Offset(gapPush, floatOffset),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, .00024)
                    ..rotateX(-.04 - .004 * floating)
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
      ),
    );
  }

  /// 눌림 애니메이션이 끝난 뒤에만 화면 전환 (짧게 눌러도 무조건 다 눌린 다음 넘어감)
  void _onTapThenNavigate(BuildContext context) {
    _cancelPendingUnpress();
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
