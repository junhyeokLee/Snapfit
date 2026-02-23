import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/cover_theme.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/album_page.dart';
import '../../../domain/entities/layer.dart';
import '../../controllers/layer_builder.dart';
import '../../controllers/layer_interaction_manager.dart';
import '../cover/cover.dart';
import 'book_page_view.dart';

/// 앨범 리더 단일 페이지 뷰
///
/// PageView에서 한 장씩 표시하되:
///   - 같은 쌍(1-2, 3-4, 5-6) 내에서는 서로 살짝 peek 허용
///   - 쌍 경계(2→3, 4→5)는 3D 책 넘기기로 전환
///   - 쌍이 다른 페이지는 완전히 숨겨 겹침 방지
class AlbumReaderSinglePageView extends StatelessWidget {
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
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final screenH = MediaQuery.sizeOf(context).height;

    // 표시 가능한 최대 너비 (좌우 여백 포함)
    final availW = screenW - 40.w;

    // 커버 비율 (width/height)
    final coverRatio = selectedCover.ratio;

    // 페이지 크기 계산 (화면 최대 62% 높이 제한)
    final double pageW;
    final double pageH;

    final maxH = screenH * 0.62;
    final hFromW = availW / coverRatio;

    if (hFromW <= maxH) {
      pageW = availW;
      pageH = hFromW;
    } else {
      pageH = maxH;
      pageW = maxH * coverRatio;
    }

    return BookPageView(
      pageController: pageController,
      itemCount: allPages.length,
      onPageChanged: (index) {
        onPageChanged(index);
        onStateChanged();
      },
      itemBuilder: (context, index) {
        final page = allPages[index];
        return Center(
          child: GestureDetector(
            onTap: () {
              if (interaction.selectedLayerId != null) {
                interaction.clearSelection();
                onStateChanged();
              }
            },
            behavior: HitTestBehavior.translucent,
            child: page.isCover
                ? _CoverPageCard(
                    page: page,
                    pageW: pageW,
                    pageH: pageH,
                    selectedCover: selectedCover,
                    coverTheme: coverTheme,
                    interaction: interaction,
                    layerBuilder: layerBuilder,
                    coverKey: canvasKey,
                    onCoverSizeChanged: onCanvasSizeChanged,
                  )
                : _InnerPageCard(
                    page: page,
                    pageW: pageW,
                    pageH: pageH,
                    interaction: interaction,
                    layerBuilder: layerBuilder,
                  ),
          ),
        );
      },
    );
  }
}

// ── 커버 페이지 카드 ──────────────────────────────────────────────
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
    return Container(
      width: pageW,
      height: pageH,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 30,
            offset: const Offset(0, 14),
            spreadRadius: 2,
          ),
        ],
      ),
      child: RepaintBoundary(
        key: coverKey,
        child: CoverLayout(
          aspect: selectedCover.ratio,
          layers: interaction.sortByZ(page.layers),
          isInteracting: false,
          leftSpine: 14.0,
          onCoverSizeChanged: onCoverSizeChanged,
          buildImage: (layer) => layerBuilder.buildImage(layer, isCover: true),
          buildText: (layer) => layerBuilder.buildText(layer, isCover: true),
          sortedByZ: interaction.sortByZ,
          theme: coverTheme,
        ),
      ),
    );
  }
}

// ── 내지 페이지 카드 ──────────────────────────────────────────────
class _InnerPageCard extends StatelessWidget {
  /// 에디터 기준 캔버스 크기 (내지 고정값)
  static const Size _editorBaseSize = Size(300, 400);

  final AlbumPage page;
  final double pageW;
  final double pageH;
  final LayerInteractionManager interaction;
  final LayerBuilder layerBuilder;

  const _InnerPageCard({
    required this.page,
    required this.pageW,
    required this.pageH,
    required this.interaction,
    required this.layerBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final scaleX = pageW / _editorBaseSize.width;
    final scaleY = pageH / _editorBaseSize.height;
    final scale = math.min(scaleX, scaleY);

    return ClipRect(
      child: Container(
        width: pageW,
        height: pageH,
        color: SnapFitColors.pureWhite,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: _editorBaseSize.width,
                height: _editorBaseSize.height,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: interaction.sortByZ(page.layers).map((layer) {
                    if (layer.type == LayerType.image) {
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
    );
  }
}
