import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../domain/entities/album.dart';
import 'home_focus_wrap.dart';
import 'home_album_cover_thumbnail.dart';
import 'home_album_actions.dart';

/// 슬라이더용 앨범 커버 카드
class HomeAlbumSliderCard extends ConsumerStatefulWidget {
  final Album album;
  final int index;
  final double currentPage;

  const HomeAlbumSliderCard({
    super.key,
    required this.album,
    required this.index,
    required this.currentPage,
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
    )..repeat();
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
    final diff = (widget.currentPage - widget.index).abs();
    if (diff >= 1) return 0;
    return 1 - diff;
  }

  @override
  Widget build(BuildContext context) {
    final coverSize = coverSizes.firstWhere(
      (s) => s.ratio.toString() == widget.album.ratio,
      orElse: () => coverSizes.first,
    );
    final focus = _focusFactor();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 0.w, vertical: 0.h),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final ratio = coverSize.ratio;
          final bool isLandscape = ratio > 1.12;
          final bool isPortrait = ratio < 0.88;
          final fallbackAsset = isPortrait
              ? 'assets/snapfit_home_portrait.jpg'
              : isLandscape
              ? 'assets/snapfit_home_landscape.jpg'
              : 'assets/snapfit_home_square.jpg';
          final stageMaxHeight = math.max(h, 1.0);
          final squareReferenceSide = (314.w)
              .clamp(258.0, math.min(328.w, stageMaxHeight * 0.78))
              .toDouble();
          final contentWidth =
              squareReferenceSide * coverSize.realSize.width / 20;
          final contentHeight =
              squareReferenceSide * coverSize.realSize.height / 20;
          final pageDelta = (widget.index - widget.currentPage).clamp(
            -1.0,
            1.0,
          );
          final gapPush = pageDelta * 214.w;
          final sideLift = (1 - focus) * 38.h;
          final coverContent = OverflowBox(
            minWidth: 0,
            minHeight: 0,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            alignment: Alignment.center,
            child: SizedBox(
              width: contentWidth,
              height: contentHeight,
              child: HomeAlbumCoverThumbnail(
                album: widget.album,
                height: contentHeight,
                maxWidth: contentWidth,
                showShadow: true,
                shadowScaleMultiplier: 6.8 + (2.4 * focus),
                fallbackAsset: fallbackAsset,
              ),
            ),
          );

          final closedCover = AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              final phase = math.sin(_floatController.value * math.pi * 2);
              final floating = ((phase + 1) / 2) * focus;
              final floatOffset = -24.h * floating;
              final focusedRotateY = -0.16 + (0.11 * floating);
              final focusedRotateZ = -0.024 + (0.052 * floating);
              final sideRotateY = pageDelta == 0 ? 0.0 : -0.244 * pageDelta;
              final sideRotateZ = pageDelta == 0 ? 0.0 : 0.122 * pageDelta;

              return HomeFocusWrap(
                focus: focus,
                applyShadow: false,
                child: Opacity(
                  opacity: 0.45 + (0.55 * focus),
                  child: Transform.translate(
                    offset: Offset(gapPush, sideLift + floatOffset),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0015)
                        ..rotateY(
                          (focusedRotateY * focus) +
                              (sideRotateY * (1 - focus)),
                        )
                        ..rotateZ(
                          (focusedRotateZ * focus) +
                              (sideRotateZ * (1 - focus)),
                        ),
                      child: child,
                    ),
                  ),
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
      await HomeAlbumActions.openAlbum(context, ref, widget.album);
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
