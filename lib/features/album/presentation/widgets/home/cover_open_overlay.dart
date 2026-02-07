import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Paper: 커버가 오른쪽 등 기준으로 열리며 그 아래 부채꼴 페이지가 드러남
class CoverOpenOverlay extends StatefulWidget {
  final Animation<double> animation;
  final ui.Image coverImage;
  final bool openFromRight;

  const CoverOpenOverlay({
    super.key,
    required this.animation,
    required this.coverImage,
    this.openFromRight = true,
  });

  @override
  State<CoverOpenOverlay> createState() => _CoverOpenOverlayState();
}

class _CoverOpenOverlayState extends State<CoverOpenOverlay> {
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
