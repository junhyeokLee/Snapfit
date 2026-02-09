import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const _coverRadius = BorderRadius.only(
  topRight: Radius.circular(12),
  bottomRight: Radius.circular(12),
  bottomLeft: Radius.zero,
);

/// 앨범 카드가 제자리에서 사라락~ 페이드아웃되며 전환되는 오버레이 (이동/확대 없음)
class HomeExpandOverlay extends StatefulWidget {
  final Animation<double> animation;
  final ui.Image coverImage;
  final Rect cardRect;

  const HomeExpandOverlay({
    super.key,
    required this.animation,
    required this.coverImage,
    required this.cardRect,
  });

  @override
  State<HomeExpandOverlay> createState() => _HomeExpandOverlayState();
}

class _HomeExpandOverlayState extends State<HomeExpandOverlay> {
  @override
  void dispose() {
    widget.coverImage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.cardRect.width;
    final h = widget.cardRect.height;

    return Positioned(
      left: widget.cardRect.left,
      top: widget.cardRect.top,
      child: AnimatedBuilder(
        animation: widget.animation,
        builder: (context, _) {
          final t = widget.animation.value;
          final opacity = (1.0 - Curves.easeOutCubic.transform(t)).clamp(0.0, 1.0);
          return IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: SizedBox(
                width: w,
                height: h,
                child: ClipRRect(
                  borderRadius: _coverRadius,
                  child: RawImage(
                    image: widget.coverImage,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Paper: 커버가 오른쪽 등 기준으로 열리며 그 아래 부채꼴 페이지가 드러남
class HomeCoverOpenOverlay extends StatefulWidget {
  final Animation<double> animation;
  final ui.Image coverImage;
  final bool openFromRight;

  const HomeCoverOpenOverlay({
    super.key,
    required this.animation,
    required this.coverImage,
    this.openFromRight = true,
  });

  @override
  State<HomeCoverOpenOverlay> createState() => _HomeCoverOpenOverlayState();
}

class _HomeCoverOpenOverlayState extends State<HomeCoverOpenOverlay> {
  @override
  void dispose() {
    widget.coverImage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, _) {
        final t = widget.animation.value;
        final angleY = widget.openFromRight
            ? t * (3.141592 / 2)
            : -t * (3.141592 / 2);
        final opacity = (1.0 - t).clamp(0.0, 1.0);
        final alignment = widget.openFromRight ? Alignment.centerRight : Alignment.centerLeft;

        return IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Transform(
              alignment: alignment,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angleY),
              child: RawImage(
                image: widget.coverImage,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      },
    );
  }
}
