import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../domain/entities/layer.dart';
import '../../controllers/layer_builder.dart';
import '../../controllers/layer_interaction_manager.dart';

/// 페이지 편집 화면의 큰 캔버스 (레이어 렌더링)
class PageEditorCanvas extends StatelessWidget {
  final GlobalKey canvasKey;
  final double targetW;
  final double targetH;
  final Size baseCanvasSize;
  final List<LayerModel> layers;
  final LayerInteractionManager interaction;
  final LayerBuilder layerBuilder;

  const PageEditorCanvas({
    super.key,
    required this.canvasKey,
    required this.targetW,
    required this.targetH,
    required this.baseCanvasSize,
    required this.layers,
    required this.interaction,
    required this.layerBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final scale = math.min(targetW / baseCanvasSize.width, targetH / baseCanvasSize.height);
    return Container(
      key: canvasKey,
      width: targetW,
      height: targetH,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 20)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: Center(
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: baseCanvasSize.width,
              height: baseCanvasSize.height,
              child: layers.isEmpty
                  ? _buildEmptyHint()
                  : Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(color: Colors.white),
                        ...interaction.sortByZ(layers).map((layer) {
                          if (layer.type == LayerType.image) {
                            return layerBuilder.buildImage(layer);
                          }
                          return layerBuilder.buildText(layer);
                        }),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyHint() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.dashboard_customize_outlined, size: 48.sp, color: Colors.grey.shade400),
          SizedBox(height: 8.h),
          Text(
            "템플릿을 선택하거나\n사진/텍스트를 추가하세요",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp),
          ),
        ],
      ),
    );
  }
}
