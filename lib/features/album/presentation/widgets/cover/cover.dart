import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/cover_theme.dart';
import '../../../../../shared/widgets/grid_overlay_painter.dart';
import '../../../../../shared/widgets/spine_painter.dart';
import 'package:flutter/material.dart';

import '../../../domain/entities/layer.dart';


typedef BuildImageLayer = Widget Function(LayerModel layer);
typedef BuildTextLayer = Widget Function(LayerModel layer);
typedef SortedByZ = List<LayerModel> Function(List<LayerModel> layers);
typedef CoverSizeChanged = void Function(Size size);

class CoverLayout extends StatelessWidget {
  final double aspect;
  final List<LayerModel> layers;
  final bool isInteracting;
  final double leftSpine;
  final CoverSizeChanged onCoverSizeChanged;
  final BuildImageLayer buildImage;
  final BuildTextLayer buildText;
  final SortedByZ sortedByZ;
  final CoverTheme theme;


  const CoverLayout({
    super.key,
    required this.aspect,
    required this.layers,
    required this.isInteracting,
    required this.leftSpine,
    required this.onCoverSizeChanged,
    required this.buildImage,
    required this.buildText,
    required this.sortedByZ,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth < constraints.maxHeight
              ? constraints.maxWidth
              : constraints.maxHeight;
          final maxH = constraints.maxHeight < constraints.maxWidth
              ? constraints.maxHeight
              : constraints.maxWidth;
          // scale 계산
          double scale = 1.04;
          
          return Transform.scale(
            scale: scale,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
              child: AspectRatio(
                aspectRatio: aspect,
                child: _AnimatedCoverContainer(
                  theme: theme,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: LayoutBuilder(
                            builder: (context, coverCts) {
                              final coverSize = coverCts.biggest;
                              // 빌드 중 setState 호출 방지를 위해 postFrameCallback 사용
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                print('[CoverLayout] Canvas Size: ${coverSize.width.toStringAsFixed(1)} x ${coverSize.height.toStringAsFixed(1)}');
                                onCoverSizeChanged(coverSize);
                              });
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  _CoverBackground(leftSpine: leftSpine, theme: theme),
                                  ...sortedByZ(layers).map((layer) {
                                    switch (layer.type) {
                                      case LayerType.image:
                                        return buildImage(layer);
                                      case LayerType.text:
                                        return buildText(layer);
                                    }
                                  }),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: CustomPaint(
                                      painter: SpinePainter(
                                        baseStart: Colors.white.withOpacity(0.1),
                                        baseEnd: Colors.white.withOpacity(0.1),
                                      ),
                                      size: Size(18.w, double.infinity),
                                    ),
                                  ),
                                  if (isInteracting)
                                    IgnorePointer(
                                      ignoring: true,
                                      child: CustomPaint(
                                        painter: GridOverlayPainter(leftSpine: leftSpine),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CoverBackground extends StatelessWidget {
  final double leftSpine;
  final CoverTheme theme;
  const _CoverBackground({required this.leftSpine, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 기본 커버 배경 (테마)
        Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            image: theme.imageAsset != null
                ? DecorationImage(
              image: AssetImage(theme.imageAsset!),
              fit: BoxFit.cover,
            )
                : null,
            gradient: theme.imageAsset == null ? theme.gradient : null,
          ),
        ),

        // Spine 영역 어두운 그림자 (공통)
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: leftSpine,
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
      ],
    );
  }
}
class _AnimatedCoverContainer extends StatefulWidget {
  final Widget child;
  final CoverTheme theme;
  const _AnimatedCoverContainer({required this.child, required this.theme});

  @override
  State<_AnimatedCoverContainer> createState() => _AnimatedCoverContainerState();
}

class _AnimatedCoverContainerState extends State<_AnimatedCoverContainer> {
  bool _animating = false;

  @override
  void didUpdateWidget(covariant _AnimatedCoverContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.theme != widget.theme) {
      setState(() {
        _animating = true;
      });
      // Reset animating after animation duration
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _animating = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Animate scale and shadow when theme changes
    final bool animate = _animating;
    final double scale = animate ? 1.03 : 1.0;
    final List<BoxShadow> boxShadow = animate
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 20,
              offset: const Offset(32, 90),
            ),
            BoxShadow(
              color: const Color(0xFF5c5d8d).withOpacity(0.18),
              blurRadius: 18,
              offset: const Offset(44, 90),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(24, 72),
            ),
            BoxShadow(
              color: const Color(0xFF5c5d8d).withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(34, 72),
            ),
          ];
    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
            bottomLeft: Radius.circular(0),
          ),
          boxShadow: boxShadow,
        ),
        clipBehavior: Clip.none,
        child: widget.child,
      ),
    );
  }
}