import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../shared/widgets/grid_overlay_painter.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../domain/entities/layer.dart';
import '../../controllers/layer_builder.dart';
import '../../controllers/layer_interaction_manager.dart';

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
    // [10단계 Fix] 커버와 내지 모두 논리적 고정 좌표계(Fixed Logic Size)를 사용합니다.
    // 커버는 500.0px 기준, 내지는 300.0px 기준으로 모든 레이어를 배치한 뒤
    // 최종적으로 현재 캔버스(물리적 크기)에 맞춰 스케일링합니다.
    final double physicalAspect = canvasW / canvasH;

    // 1. 페이지도 커버와 동일한 논리 사이즈(500xH)로 통일
    const double innerLogicalW = kCoverReferenceWidth;
    final double innerLogicalH = innerLogicalW / physicalAspect;

    // 2. 커버용 논리 사이즈 (500xH)
    final double coverLogicalW = kCoverReferenceWidth;
    final double coverLogicalH = coverLogicalW / physicalAspect;

    final Size effectiveBaseSize = isCover
        ? Size(coverLogicalW, coverLogicalH)
        : Size(innerLogicalW, innerLogicalH);

    // 커버·내지 공통 스타일 (책 형태 동일하게)
    // 오른쪽 모서리만 둥글게 (왼쪽은 spine/제본 부분이므로 직각)
    const sharedRadius = BorderRadius.only(
      topRight: Radius.circular(12),
      bottomRight: Radius.circular(12),
      topLeft: Radius.zero,
      bottomLeft: Radius.zero,
    );

    // 커버 그림자는 Transform.scale(canvasW/500) 내부에 있어 scale 비율만큼 줄어 보임.
    // 내지도 시각적으로 동일하게 보이도록 같은 비율(coverScale)을 offset·blurRadius에 적용.
    final double coverScale = canvasW / kCoverReferenceWidth;
    final sharedShadow = [
      BoxShadow(
        color: Colors.black.withOpacity(0.12),
        blurRadius: 10 * coverScale,
        offset: Offset(24 * coverScale, 72 * coverScale),
      ),
      BoxShadow(
        color: const Color(0xFF5c5d8d).withOpacity(0.12),
        blurRadius: 10 * coverScale,
        offset: Offset(34 * coverScale, 72 * coverScale),
      ),
    ];

    return Container(
      width: canvasW,
      height: canvasH,
      decoration: BoxDecoration(
        color: backgroundColor ?? SnapFitColors.pureWhite,
        borderRadius: sharedRadius, // 커버·내지 동일한 borderRadius
        boxShadow: sharedShadow, // 커버·내지 동일한 그림자
      ),
      child: ClipRRect(
        borderRadius: sharedRadius,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 0 && constraints.maxHeight > 0) {
              // 에디터의 실측 사이즈를 보고함 (ViewModel은 내지일 경우 리스케일링 무시함)
              onCanvasSizeChanged(
                Size(constraints.maxWidth, constraints.maxHeight),
              );
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
            // 커버(EditCover)와 동일하게 FittedBox 기반으로 스케일링해
            // 하단 영역에서 발생하던 위치 의존 hit-test 오차를 줄인다.
            return FittedBox(
              fit: BoxFit.fill,
              alignment: Alignment.topLeft,
              child: SizedBox(
                key: canvasKey,
                width: effectiveBaseSize.width,
                height: effectiveBaseSize.height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      color: backgroundColor ?? SnapFitColors.pureWhite,
                    ),
                    ...interaction.sortByZ(layers).map((layer) {
                      final styleKey = ValueKey(
                        '${layer.id}_${layer.textBackground ?? ''}_${layer.imageBackground ?? ''}',
                      );
                      switch (layer.type) {
                        case LayerType.image:
                        case LayerType.sticker:
                        case LayerType.decoration:
                          return KeyedSubtree(
                            key: styleKey,
                            child: layerBuilder.buildImage(
                              layer,
                              isCover: isCover,
                            ),
                          );
                        case LayerType.text:
                          return KeyedSubtree(
                            key: styleKey,
                            child: layerBuilder.buildText(
                              layer,
                              isCover: isCover,
                            ),
                          );
                      }
                    }),
                    // 내지 편집 시에도 커버와 동일하게, 드래그/회전 중일 때만
                    // 중앙 가이드선을 레이어 위에 렌더링. 논리 캔버스와 동일한 크기로 고정해 가운데가 정확히 맞도록 함.
                    if (interaction.isInteractingNow)
                      Positioned(
                        left: 0,
                        top: 0,
                        child: IgnorePointer(
                          child: SizedBox(
                            width: effectiveBaseSize.width,
                            height: effectiveBaseSize.height,
                            child: CustomPaint(
                              painter: GridOverlayPainter(
                                leftSpine: isCover ? 14.0 : 0.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (interaction.isInteractingNow &&
                        (interaction.activeVerticalGuides.isNotEmpty ||
                            interaction.activeHorizontalGuides.isNotEmpty))
                      Positioned(
                        left: 0,
                        top: 0,
                        child: IgnorePointer(
                          child: SizedBox(
                            width: effectiveBaseSize.width,
                            height: effectiveBaseSize.height,
                            child: CustomPaint(
                              painter: _SnapGuidePainter(
                                verticalGuides:
                                    interaction.activeVerticalGuides,
                                horizontalGuides:
                                    interaction.activeHorizontalGuides,
                                leftSpine: isCover ? 14.0 : 0.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // [Spine fix] 에디터에서도 표지 편집 시 좌측의 책등(Spine) 영역을 시각적으로 표시하여 위치 인지 오류 방지
                    if (isCover)
                      IgnorePointer(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 14.0, // kCoverSpineWidth = 14.0
                            height: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.black.withOpacity(0.18),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SnapGuidePainter extends CustomPainter {
  final List<double> verticalGuides;
  final List<double> horizontalGuides;
  final double leftSpine;

  const _SnapGuidePainter({
    required this.verticalGuides,
    required this.horizontalGuides,
    required this.leftSpine,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.45)
      ..strokeWidth = 1.2;

    for (final x in verticalGuides) {
      if (x < leftSpine || x > size.width) continue;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (final y in horizontalGuides) {
      if (y < 0 || y > size.height) continue;
      canvas.drawLine(Offset(leftSpine, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SnapGuidePainter oldDelegate) {
    if (oldDelegate.leftSpine != leftSpine) return true;
    if (oldDelegate.verticalGuides.length != verticalGuides.length) return true;
    if (oldDelegate.horizontalGuides.length != horizontalGuides.length)
      return true;
    for (int i = 0; i < verticalGuides.length; i++) {
      if (oldDelegate.verticalGuides[i] != verticalGuides[i]) return true;
    }
    for (int i = 0; i < horizontalGuides.length; i++) {
      if (oldDelegate.horizontalGuides[i] != horizontalGuides[i]) return true;
    }
    return false;
  }
}
