import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/layer.dart';
import '../../controllers/layer_builder.dart';
import '../../controllers/layer_interaction_manager.dart';
import '../../viewmodels/album_editor_view_model.dart';

/// 페이지 편집 캔버스
class PageEditorCanvas extends StatelessWidget {
  final GlobalKey canvasKey;
  final double canvasW;
  final double canvasH;
  final List<LayerModel> layers;
  final LayerInteractionManager interaction;
  final LayerBuilder layerBuilder;
  final ValueChanged<Size> onCanvasSizeChanged;
  final Color? backgroundColor;
  final bool isCover;

  const PageEditorCanvas({
    super.key,
    required this.canvasKey,
    required this.canvasW,
    required this.canvasH,
    required this.layers,
    required this.interaction,
    required this.layerBuilder,
    required this.onCanvasSizeChanged,
    this.backgroundColor,
    this.isCover = false,
  });

  @override
  Widget build(BuildContext context) {
    // Cover Style Constants matching Home
    const coverRadius = BorderRadius.only(
      topRight: Radius.circular(12),
      bottomRight: Radius.circular(12),
      bottomLeft: Radius.zero,
      topLeft: Radius.zero,
    );

    return Container(
      key: canvasKey,
      width: canvasW,
      height: canvasH,
      decoration: isCover
          ? BoxDecoration(
              color: backgroundColor ?? SnapFitColors.pureWhite,
              borderRadius: coverRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(14, 12),
                ),
                BoxShadow(
                  color: const Color(0xFF5c5d8d).withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(24, 12),
                ),
              ],
            )
          : BoxDecoration(
              color: backgroundColor ?? SnapFitColors.pureWhite,
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
        borderRadius: isCover ? coverRadius : BorderRadius.circular(8.r),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 0 && constraints.maxHeight > 0) {
              onCanvasSizeChanged(Size(constraints.maxWidth, constraints.maxHeight));
            }
            if (layers.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.dashboard_customize_outlined,
                      size: 48.sp,
                      color: SnapFitColors.deepCharcoal.withOpacity(0.35),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      "템플릿을 선택하거나\n사진/텍스트를 추가하세요",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: SnapFitColors.deepCharcoal.withOpacity(0.6),
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
              );
            }
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Container(color: backgroundColor ?? SnapFitColors.pureWhite),
                ...interaction.sortByZ(layers).map((layer) {
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
