import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../views/album_reader_screen.dart';
import 'cover_open_overlay.dart';
import 'expand_overlay.dart';

/// Paper: 앨범 페이지 편집 화면으로 갈 때 커버가 부채꼴로 펼쳐지며 드러나는 커스텀 라우트
class PaperUnfoldRoute extends PageRouteBuilder {
  PaperUnfoldRoute({Rect? cardRect, ui.Image? coverImage})
      : super(
          opaque: true,
          transitionDuration: const Duration(milliseconds: 450),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (context, animation, secondaryAnimation) {
            return _PaperUnfoldPage(
              cardRect: cardRect,
              coverImage: coverImage,
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            final rect = cardRect;

            if (coverImage != null && rect != null && rect.width > 0 && rect.height > 0) {
              return Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  FadeTransition(
                    opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
                      ),
                    ),
                    child: child,
                  ),
                  ExpandOverlay(
                    animation: curved,
                    coverImage: coverImage,
                    cardRect: rect,
                  ),
                ],
              );
            }
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
                alignment: Alignment.center,
                child: child,
              ),
            );
          },
        );
}

/// 라우트 위에 커버 열림 오버레이를 붙이고, 열림 애니메이션 후 앨범 페이지 편집 화면만 보이게 함
class _PaperUnfoldPage extends StatefulWidget {
  final Rect? cardRect;
  final ui.Image? coverImage;

  const _PaperUnfoldPage({this.cardRect, this.coverImage});

  @override
  State<_PaperUnfoldPage> createState() => _PaperUnfoldPageState();
}

class _PaperUnfoldPageState extends State<_PaperUnfoldPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _coverController;
  late final Animation<double> _coverAnimation;

  @override
  void initState() {
    super.initState();
    _coverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _coverAnimation = CurvedAnimation(
      parent: _coverController,
      curve: Curves.easeOutCubic,
    );
    _coverController.forward();
  }

  @override
  void dispose() {
    _coverController.dispose();
    widget.coverImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const content = AlbumReaderScreen();
    final hasOverlay = widget.coverImage != null &&
        widget.cardRect != null &&
        !widget.cardRect!.isEmpty;

    if (!hasOverlay) {
      return content;
    }

    final rect = widget.cardRect!;
    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        Positioned(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          child: CoverOpenOverlay(
            animation: _coverAnimation,
            coverImage: widget.coverImage!,
            openFromRight: true,
          ),
        ),
      ],
    );
  }
}
