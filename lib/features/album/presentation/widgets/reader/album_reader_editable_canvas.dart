import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/album_page.dart';
import '../../../domain/entities/layer.dart';
import '../../controllers/layer_builder.dart';
import '../../controllers/layer_interaction_manager.dart';

/// 편집 가능한 페이지 캔버스
class AlbumReaderEditableCanvas extends StatelessWidget {
  final AlbumPage page;
  final double canvasW;
  final double canvasH;
  final GlobalKey canvasKey;
  final LayerInteractionManager interaction;
  final LayerBuilder layerBuilder;
  final ValueChanged<Size> onCanvasSizeChanged;

  const AlbumReaderEditableCanvas({
    super.key,
    required this.page,
    required this.canvasW,
    required this.canvasH,
    required this.canvasKey,
    required this.interaction,
    required this.layerBuilder,
    required this.onCanvasSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: canvasKey,
      width: canvasW,
      height: canvasH,
      decoration: BoxDecoration(
        color: SnapFitColors.pureWhite,
        borderRadius: BorderRadius.circular(8.r),
        boxShadow: [
          BoxShadow(
            color: SnapFitColors.isDark(context)
                ? SnapFitColors.accentLight.withOpacity(0.2)
                : Colors.black45,
            blurRadius: 20,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 0 && constraints.maxHeight > 0) {
              onCanvasSizeChanged(Size(constraints.maxWidth, constraints.maxHeight));
            }
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Container(color: SnapFitColors.pureWhite),
                ...interaction.sortByZ(page.layers).map((layer) {
                  if (layer.type == LayerType.image) {
                    return layerBuilder.buildImage(layer);
                  }
                  return layerBuilder.buildText(layer);
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}
