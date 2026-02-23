import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/album_page.dart';
import '../../../domain/entities/layer.dart';
import '../../controllers/layer_builder.dart';
import '../../controllers/layer_interaction_manager.dart';

/// 앨범 리더용 편집 가능한 페이지 캔버스
/// 레이어 좌표는 에디터 기준(300x400)으로 저장되어 있으므로,
/// 실제 표시 크기(targetW x targetH)에 맞게 Transform.scale로 스케일링.
/// → 뷰모델 레이어 리스케일 없이 올바른 위치 유지.
class AlbumReaderEditableCanvas extends StatelessWidget {
  /// 에디터 기준 캔버스 크기 (내지 고정값)
  static const Size _innerEditorCanvasSize = Size(300, 400);

  final AlbumPage page;
  final double canvasW;   // 표시될 대상 너비
  final double canvasH;   // 표시될 대상 높이
  final GlobalKey canvasKey;
  final LayerInteractionManager interaction;
  final LayerBuilder layerBuilder;
  /// 리더 모드에서는 레이어 리스케일을 하지 않으므로 사용 안 함 (호환성 유지용)
  final ValueChanged<Size>? onCanvasSizeChanged;
  final bool showShadow;

  const AlbumReaderEditableCanvas({
    super.key,
    required this.page,
    required this.canvasW,
    required this.canvasH,
    required this.canvasKey,
    required this.interaction,
    required this.layerBuilder,
    this.onCanvasSizeChanged,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    // 에디터 기준 → 현재 표시 크기 스케일 계산
    final scaleX = canvasW / _innerEditorCanvasSize.width;
    final scaleY = canvasH / _innerEditorCanvasSize.height;
    final scale = math.min(scaleX, scaleY); // 비율 유지

    return Container(
      key: canvasKey,
      width: canvasW,
      height: canvasH,
      decoration: BoxDecoration(
        color: SnapFitColors.pureWhite,
        borderRadius: BorderRadius.circular(8.r),
        boxShadow: showShadow ? [
          BoxShadow(
            color: SnapFitColors.isDark(context)
                ? SnapFitColors.accentLight.withOpacity(0.2)
                : Colors.black45,
            blurRadius: 20,
          ),
        ] : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Container(color: SnapFitColors.pureWhite),
            // 에디터 기준 좌표 → Transform.scale로 올바른 위치에 렌더링
            Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: _innerEditorCanvasSize.width,
                height: _innerEditorCanvasSize.height,
                child: Stack(
                  clipBehavior: Clip.none,
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
