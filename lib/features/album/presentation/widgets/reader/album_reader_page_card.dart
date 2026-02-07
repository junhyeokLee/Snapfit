import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../domain/entities/layer.dart';
import '../../controllers/layer_builder.dart';
import 'album_reader_page_content.dart';

/// 앨범 보기 화면의 메인 페이지 카드 (그림자 + 스와이프 델타 그라데이션)
class AlbumReaderPageCard extends StatelessWidget {
  final List<LayerModel> layers;
  final double targetW;
  final double targetH;
  final LayerBuilder previewBuilder;
  final Size baseCanvasSize;
  final double delta;

  const AlbumReaderPageCard({
    super.key,
    required this.layers,
    required this.targetW,
    required this.targetH,
    required this.previewBuilder,
    required this.baseCanvasSize,
    required this.delta,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(10.r);
    return Container(
      width: targetW,
      height: targetH,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: borderRadius,
            child: AlbumReaderPageContent(
              layers: layers,
              targetW: targetW,
              targetH: targetH,
              previewBuilder: previewBuilder,
              baseCanvasSize: baseCanvasSize,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: delta >= 0 ? Alignment.topCenter : Alignment.bottomCenter,
                    end: delta >= 0 ? Alignment.bottomCenter : Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.22 * delta.abs()),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
