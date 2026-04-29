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
  /// 내지 페이지 배경색 (ARGB). null이면 theme이 있을 때만 테마 배경, 없으면 흰색
  final Color? backgroundColor;

  const AlbumReaderPageContent({
    super.key,
    required this.layers,
    required this.targetW,
    required this.targetH,
    required this.previewBuilder,
    required this.baseCanvasSize,
    this.theme,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    // [Fix] 수동 스케일 대신 FittedBox를 사용하여 내부 논리 해상도를 강제 유지하고
    // 폰트나 요소 크기가 왜곡되지 않게 비율 맞춰 축소
    return SizedBox(
      width: targetW,
      height: targetH,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.center,
        child: SizedBox(
          width: baseCanvasSize.width,
          height: baseCanvasSize.height,
          child: IgnorePointer(
            ignoring: true,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 배경: backgroundColor 우선, 없으면 테마가 있으면 테마 이미지/그라데이션, 없으면 흰색
                Container(
                  decoration: BoxDecoration(
                    color:
                        backgroundColor ??
                        (theme == null ? Colors.white : null),
                    image: theme?.imageAsset != null
                        ? DecorationImage(
                            image: AssetImage(theme!.imageAsset!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    gradient: theme?.imageAsset == null
                        ? theme?.gradient
                        : null,
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
    );
  }
}
