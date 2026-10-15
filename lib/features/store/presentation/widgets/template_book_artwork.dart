import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/catalog_artwork_hero.dart';
import '../../../album/presentation/widgets/home/home_cover_frame.dart';

/// A read-only book surface; source page geometry and artwork are untouched.
class TemplateBookArtwork extends StatelessWidget {
  const TemplateBookArtwork({
    super.key,
    required this.canvas,
    required this.firstPage,
    required this.paired,
    required this.pageBuilder,
    this.onPageTap,
    this.heroTag,
    this.showShadow = true,
  });

  final Size canvas;
  final int firstPage;
  final bool paired, showShadow;
  final Widget Function(int index, bool wrapSpine) pageBuilder;
  final ValueChanged<int>? onPageTap;
  final Object? heroTag;

  Widget _page(int index, {bool wrapSpine = false}) {
    final artwork = pageBuilder(index, wrapSpine);
    if (onPageTap == null) return artwork;
    return Semantics(
      button: true,
      label: index == 0 ? '표지 크게 보기' : '$index쪽 크게 보기',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onPageTap!(index),
        child: artwork,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final ratio = canvas.width / canvas.height;
      final width = math.min(
        bounds.maxWidth,
        bounds.maxHeight * ratio * (paired ? 2 : 1),
      );
      final height = width / ratio / (paired ? 2 : 1);
      if (width <= 0 || height <= 0) return const SizedBox();
      if (kIsWeb) return Center(child: RepaintBoundary(child: SizedBox(
        width: width,
        height: height,
        child: ClipRect(child: Row(children: [
          Expanded(child: _page(firstPage)),
          if (paired) Expanded(child: _page(firstPage + 1)),
        ])),
      )));
      final cover = firstPage == 0;
      final artwork = cover
          ? CatalogArtworkHero(
              tag: heroTag,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, .00024)
                  ..rotateX(-.04)
                  ..rotateY(-.10),
                child: HomeCoverFrame(
                  key: const ValueKey('template-book-cover'),
                  width: width,
                  height: height,
                  shadowScale: 1,
                  showShadow: showShadow,
                  showBookDepth: true,
                  bindingArtwork: pageBuilder(0, false),
                  child: _page(0, wrapSpine: true),
                ),
              ),
            )
          : DecoratedBox(
              key: ValueKey('template-book-spread-$firstPage'),
              decoration: BoxDecoration(
                boxShadow: showShadow
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: SnapFitColors.isDark(context) ? .24 : .11,
                          ),
                          blurRadius: width * .065,
                          spreadRadius: -width * .012,
                          offset: Offset(0, width * .022),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 1,
                    bottom: -math.min(2.0, width * .006),
                    child: const ColoredBox(color: Color(0xFFE7EAE4)),
                  ),
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.white,
                      child: Row(
                        children: [
                          Expanded(child: _page(firstPage)),
                          if (paired) Expanded(child: _page(firstPage + 1)),
                        ],
                      ),
                    ),
                  ),
                  if (paired)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: TemplateSpreadFinishPainter(),
                        ),
                      ),
                    ),
                ],
              ),
            );
      return Center(
        child: RepaintBoundary(
          child: SizedBox(width: width, height: height, child: artwork),
        ),
      );
    },
  );
}

class TemplateSpreadFinishPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.width / 2;
    final fold = math.min(8.0, size.width * .025);
    final rect = Rect.fromLTWH(center - fold, 0, fold * 2, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Colors.transparent,
            Color(0x0A000000),
            Color(0x1C000000),
            Color(0x0E000000),
            Colors.transparent,
          ],
          stops: [0, .38, .5, .6, 1],
        ).createShader(rect),
    );
    canvas.drawLine(
      Offset(center + .5, 0),
      Offset(center + .5, size.height),
      Paint()
        ..color = const Color(0x2EFFFFFF)
        ..strokeWidth = .6,
    );
  }

  @override
  bool shouldRepaint(covariant TemplateSpreadFinishPainter oldDelegate) =>
      false;
}
