import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/entities/layer.dart';
import '../../controllers/layer_builder.dart';

/// 앨범 페이지 레이어들을 스케일하여 표시하는 공통 위젯
class AlbumReaderPageContent extends StatelessWidget {
  final List<LayerModel> layers;
  final double targetW;
  final double targetH;
  final LayerBuilder previewBuilder;
  final Size baseCanvasSize;

  const AlbumReaderPageContent({
    super.key,
    required this.layers,
    required this.targetW,
    required this.targetH,
    required this.previewBuilder,
    required this.baseCanvasSize,
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
                  Container(color: Colors.white),
                  ...layers.map((layer) {
                    return layer.type == LayerType.text
                        ? previewBuilder.buildText(layer)
                        : previewBuilder.buildImage(layer);
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
