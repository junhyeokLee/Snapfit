import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/constants/cover_theme.dart';
import '../../../domain/entities/layer.dart';
import '../../controllers/layer_builder.dart';

/// 앨범 페이지 레이어들을 스케일하여 표시하는 공통 위젯
class AlbumReaderPageContent extends StatelessWidget {
  final List<LayerModel> layers;
  final double targetW;
  final double targetH;
  final LayerBuilder previewBuilder;
  final Size baseCanvasSize;
  final CoverTheme? theme; // [New] 테마 배경 지원

  const AlbumReaderPageContent({
    super.key,
    required this.layers,
    required this.targetW,
    required this.targetH,
    required this.previewBuilder,
    required this.baseCanvasSize,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final scale = math.min(targetW / baseCanvasSize.width, targetH / baseCanvasSize.height);
    return SizedBox(
      width: targetW,
      height: targetH,
      child: Center(
        child: Transform.scale(
          scale: scale,
          child: SizedBox(
            width: baseCanvasSize.width,
            height: baseCanvasSize.height,
            child: IgnorePointer(
              ignoring: true,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 배경: 테마가 있으면 테마 이미지/그라데이션, 없으면 흰색
                  Container(
                    decoration: BoxDecoration(
                      color: theme == null ? Colors.white : null,
                      image: theme?.imageAsset != null
                          ? DecorationImage(
                              image: AssetImage(theme!.imageAsset!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      gradient: theme?.imageAsset == null ? theme?.gradient : null,
                    ),
                  ),
                  ...layers.map((layer) {
                    return layer.type == LayerType.text
                        ? previewBuilder.buildText(layer)
                        : previewBuilder.buildImage(layer);
                  }),
                  // [New] 커버의 경우 좌측 책등(Spine) 그림자 효과 추가
                  if (theme != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 14.0, // kCoverSpineWidth 대응
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withOpacity(0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
