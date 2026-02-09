import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../domain/entities/album_page.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/cover_theme.dart';
import '../../controllers/layer_builder.dart';
import '../../controllers/layer_interaction_manager.dart';
import 'album_reader_editable_canvas.dart';
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
    final screenH = MediaQuery.sizeOf(context).height;
    final pageH = (screenH * 0.58).clamp(260.0, 520.0);
    final pageW = pageH * (6 / 8); // 내지 페이지는 세로형 비율 고정

    return PageView.builder(
      controller: pageController,
      physics: const SlowPagePhysics(),
      itemCount: pages.length,
      onPageChanged: (index) {
        onPageChanged(index);
        onStateChanged();
      },
      itemBuilder: (context, index) {
        final page = pages[index];
        return Center(
          child: GestureDetector(
            onTap: () {
              if (interaction.selectedLayerId != null) {
                interaction.clearSelection();
                onStateChanged();
              }
            },
            behavior: HitTestBehavior.translucent,
            child: AlbumReaderEditableCanvas(
              page: page,
              canvasW: pageW,
              canvasH: pageH,
              canvasKey: canvasKey,
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
