import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'focus_wrap.dart';

/// 앨범 카드가 제자리에서 사라락~ 페이드아웃되며 전환되는 오버레이
class ExpandOverlay extends StatefulWidget {
  final Animation<double> animation;
  final ui.Image coverImage;
  final Rect cardRect;

  const ExpandOverlay({
    super.key,
    required this.animation,
    required this.coverImage,
    required this.cardRect,
  });

  @override
  State<ExpandOverlay> createState() => _ExpandOverlayState();
}

class _ExpandOverlayState extends State<ExpandOverlay> {
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
                  borderRadius: coverRadius,
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
