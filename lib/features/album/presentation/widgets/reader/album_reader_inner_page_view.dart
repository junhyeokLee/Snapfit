import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../domain/entities/album_page.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/cover_theme.dart';
import '../../controllers/layer_builder.dart';
import '../../controllers/layer_interaction_manager.dart';
import 'album_reader_editable_canvas.dart';
import 'album_reader_spread_canvas.dart';
import 'slow_page_physics.dart';

/// 앨범 리더 내지 페이지 뷰
class AlbumReaderInnerPageView extends StatelessWidget {
  final List<AlbumPage> pages;
  final CoverSize selectedCover;
  final CoverTheme coverTheme;
  final PageController pageController;
  final LayerInteractionManager interaction;
  final LayerBuilder layerBuilder;
  final GlobalKey canvasKey;
  final ValueChanged<Size> onCanvasSizeChanged;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onStateChanged;

  const AlbumReaderInnerPageView({
    super.key,
    required this.pages,
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

    // 커버 비율(width/height)
    final coverRatio = selectedCover.ratio; // 1.0=정방, <1=세로, >1=가로

    // 가로 앨범(ratio > 1): 높이를 기준으로 계산 (너비가 2배라서 너비 기준이면 너무 작아짐)
    // 세로·정방 앨범(ratio <= 1): 너비를 기준으로 계산 (한 페이지 = 화면 절반)
    final double pageW;
    final double pageH;

    if (coverRatio > 1.0) {
      // 가로형: 사용 가능한 높이의 45%를 한 페이지 높이로 사용
      final h = screenH * 0.45;
      final w = h * coverRatio;
      // 스프레드 너비(w*2)가 화면을 넘어가면 다시 너비 기준으로 클램프
      if (w * 2 > screenW - 32.w) {
        pageW = (screenW - 32.w) / 2;
        pageH = pageW / coverRatio;
      } else {
        pageW = w;
        pageH = h;
      }
    } else {
      // 세로·정방형: 스프레드 = 화면 너비 - 여백
      final spreadAvailW = screenW - 32.w;
      pageW = spreadAvailW / 2;
      pageH = (pageW / coverRatio).clamp(0.0, screenH * 0.58);
    }

    // Spread logic: Combine two pages into one.
    // If we have 10 pages, we'll have 5 spreads.
    final spreadCount = (pages.length / 2).ceil();

    return PageView.builder(
      controller: pageController,
      physics: const SlowPagePhysics(),
      itemCount: spreadCount,
      onPageChanged: (index) {
        onPageChanged(index * 2); // Notify approx page index
        onStateChanged();
      },
      itemBuilder: (context, index) {
        final leftIdx = index * 2;
        final rightIdx = leftIdx + 1;

        final leftPage = leftIdx < pages.length ? pages[leftIdx] : null;
        final rightPage = rightIdx < pages.length ? pages[rightIdx] : null;

        return Center(
          child: GestureDetector(
            onTap: () {
              if (interaction.selectedLayerId != null) {
                interaction.clearSelection();
                onStateChanged();
              }
            },
            behavior: HitTestBehavior.translucent,
            child: AlbumReaderSpreadCanvas(
              leftPage: leftPage,
              rightPage: rightPage,
              canvasW: pageW,
              canvasH: pageH,
              interaction: interaction,
              layerBuilder: layerBuilder,
              onCanvasSizeChanged: onCanvasSizeChanged,
            ),
          ),
        );
      },
    );
  }
}
