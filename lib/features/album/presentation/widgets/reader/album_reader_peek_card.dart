import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../domain/entities/layer.dart';
import '../../controllers/layer_builder.dart';
import 'album_reader_page_content.dart';

/// 앨범 보기 화면의 좌/우 peek 카드 (옆 페이지 미리보기)
class AlbumReaderPeekCard extends StatelessWidget {
  final List<LayerModel> layers;
  final double targetW;
  final double targetH;
  final LayerBuilder previewBuilder;
  final Size baseCanvasSize;

  const AlbumReaderPeekCard({
    super.key,
    required this.layers,
    required this.targetW,
    required this.targetH,
    required this.previewBuilder,
    required this.baseCanvasSize,
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
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: AlbumReaderPageContent(
          layers: layers,
          targetW: targetW,
          targetH: targetH,
          previewBuilder: previewBuilder,
          baseCanvasSize: baseCanvasSize,
        ),
      ),
    );
  }
}
