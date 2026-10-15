import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/cover_theme.dart';
import '../../../../../core/constants/snapfit_colors.dart';
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
  final Color? backgroundColor;
  final CoverSizeChanged onCoverSizeChanged;
  final BuildImageLayer buildImage;
  final BuildImageLayer? buildWrappedImage;
  final BuildTextLayer buildText;
  final SortedByZ sortedByZ;
  final CoverTheme theme;
  final GlobalKey? contentKey;
  final List<double> activeVerticalGuides;
  final List<double> activeHorizontalGuides;
  final bool showEmptyGuide;

  /// Closed-book preview only; persisted editor and print artwork is unchanged.
  final bool wrapSpineArtwork;

  /// Flat document presentation; artwork and its coordinate system stay intact.
  final bool flatPresentation;

  const CoverLayout({
    super.key,
    required this.aspect,
    required this.layers,
    required this.isInteracting,
    required this.leftSpine,
    this.backgroundColor,
    required this.onCoverSizeChanged,
    required this.buildImage,
    this.buildWrappedImage,
    required this.buildText,
    required this.sortedByZ,
    required this.theme,
    this.contentKey,
    this.activeVerticalGuides = const <double>[],
    this.activeHorizontalGuides = const <double>[],
    this.showEmptyGuide = false,
    this.wrapSpineArtwork = false,
    this.flatPresentation = false,
  });

  LayerModel _displayLayer(LayerModel layer, Size size) {
    if (!wrapSpineArtwork ||
        layer.type != LayerType.image ||
        !layer.hasImageSource ||
        !(const <String?>{
          null,
          '',
          'none',
          'rasterCover',
        }).contains(layer.imageBackground) ||
        layer.rotation.abs() > .0001 ||
        (layer.scale - 1).abs() > .0001 ||
        layer.position.dx <= 0 ||
        layer.position.dx > leftSpine + .5 ||
        layer.position.dy > .5 ||
        layer.position.dx + layer.width < size.width - .5 ||
        layer.position.dy + layer.height < size.height - .5) {
      return layer;
    }
    // Full-bleed photos wrap the virtual binding; stored/printed layers stay intact.
    final width = layer.width + layer.position.dx;
    final offset = layer.imageOffset;
    return layer.copyWith(
      position: Offset(0, layer.position.dy),
      width: width,
      imageOffset: offset == null
          ? null
          : Offset(offset.dx * width / layer.width, offset.dy),
    );
  }

  bool _canCurvePhoto(LayerModel layer, Size size) =>
      wrapSpineArtwork &&
      buildWrappedImage != null &&
      layer.type == LayerType.image &&
      layer.hasImageSource &&
      (const <String?>{
        null,
        '',
        'none',
        'rasterCover',
      }).contains(layer.imageBackground) &&
      layer.rotation.abs() < .0001 &&
      (layer.scale - 1).abs() < .0001 &&
      layer.position.dx.abs() < .5 &&
      layer.position.dy.abs() < .5 &&
      (layer.width - size.width).abs() < .5 &&
      (layer.height - size.height).abs() < .5;

  Widget _buildLayer(LayerModel layer, Size size, {bool curve = true}) {
    final styleKey = ValueKey(
      '${layer.id}_${layer.textBackground ?? ''}_${layer.imageBackground ?? ''}',
    );
    return KeyedSubtree(
      key: styleKey,
      child: layer.type == LayerType.text
          ? buildText(layer)
          : curve && _canCurvePhoto(layer, size)
          ? buildWrappedImage!(layer)
          : buildImage(layer),
    );
  }

  /// A second view of the same cached artwork for the narrow outside binding.
  /// No editor keys, size callbacks, guides or additional photo downloads.
  Widget bindingPreview(Size size) => RepaintBoundary(
    child: Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        _CoverBackground(
          leftSpine: leftSpine,
          theme: theme,
          backgroundColor: backgroundColor,
          showSpine: false,
        ),
        ...sortedByZ(layers)
            .map((source) => _displayLayer(source, size))
            .where(
              (layer) =>
                  layer.rotation.abs() > .0001 ||
                  (layer.scale - 1).abs() > .0001 ||
                  (layer.position.dx < size.width * .02 &&
                      layer.position.dx + layer.width > 0),
            )
            .map((layer) => _buildLayer(layer, size, curve: false)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final hasCustomBackgroundColor = backgroundColor != null;
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          final maxH = constraints.maxHeight;
          // scale 계산
          double scale = 1.0;

          return Transform.scale(
            scale: scale,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
              child: AspectRatio(
                aspectRatio: aspect,
                child: _AnimatedCoverContainer(
                  theme: theme,
                  flatPresentation: flatPresentation,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            flatPresentation ? 0 : 12,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: flatPresentation
                              ? BorderRadius.zero
                              : const BorderRadius.only(
                            topRight: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: LayoutBuilder(
                            builder: (context, coverCts) {
                              final coverSize = coverCts.biggest;
                              // 빌드 중 setState 호출 방지를 위해 postFrameCallback 사용
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                onCoverSizeChanged(coverSize);
                              });
                              return RepaintBoundary(
                                key: contentKey,
                                child: Stack(
                                  fit: StackFit.expand,
                                  clipBehavior: Clip.none,
                                  children: [
                                    _CoverBackground(
                                      leftSpine: leftSpine,
                                      theme: theme,
                                      backgroundColor: backgroundColor,
                                      showSpine:
                                          !flatPresentation && !wrapSpineArtwork,
                                      flatPresentation: flatPresentation,
                                    ),
                                    if (showEmptyGuide && layers.isEmpty)
                                      const _CoverEmptyGuide(),
                                    ...sortedByZ(layers).map((sourceLayer) {
                                      final layer = _displayLayer(
                                        sourceLayer,
                                        coverSize,
                                      );
                                      return _buildLayer(layer, coverSize);
                                    }),
                                    if (!flatPresentation &&
                                        !hasCustomBackgroundColor &&
                                        !wrapSpineArtwork)
                                      IgnorePointer(
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: CustomPaint(
                                            painter: SpinePainter(
                                              baseStart: Colors.white
                                                  .withOpacity(0.1),
                                              baseEnd: Colors.white.withOpacity(
                                                0.1,
                                              ),
                                            ),
                                            size: Size(
                                              kCoverSpineWidth,
                                              MediaQuery.of(
                                                context,
                                              ).size.height,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (isInteracting)
                                      IgnorePointer(
                                        ignoring: true,
                                        child: CustomPaint(
                                          painter: GridOverlayPainter(
                                            leftSpine: leftSpine,
                                          ),
                                        ),
                                      ),
                                    if (isInteracting &&
                                        (activeVerticalGuides.isNotEmpty ||
                                            activeHorizontalGuides.isNotEmpty))
                                      IgnorePointer(
                                        ignoring: true,
                                        child: CustomPaint(
                                          painter: _SnapGuidePainter(
                                            verticalGuides:
                                                activeVerticalGuides,
                                            horizontalGuides:
                                                activeHorizontalGuides,
                                            leftSpine: leftSpine,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
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

class _CoverEmptyGuide extends StatelessWidget {
  const _CoverEmptyGuide();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(52, 46, 38, 42),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF7).withOpacity(0.82),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: const Color(0xFF8E7D67).withOpacity(0.18),
                width: 1.2,
              ),
            ),
            child: CustomPaint(
              painter: _DashedGuidePainter(),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: const Color(0xFF13C8EC).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_photo_alternate_outlined,
                        color: Color(0xFF13AFCF),
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '표지에 담을 사진을 올려보세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: SnapFitColors.deepCharcoal.withOpacity(0.82),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.62),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '앨범 제목을 입력하면 더 특별해져요',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SnapFitColors.deepCharcoal.withOpacity(0.62),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8E7D67).withOpacity(0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(26),
    ).deflate(1.5);
    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 10), paint);
        distance += 18;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    if (oldDelegate.horizontalGuides.length != horizontalGuides.length) {
      return true;
    }
    for (int i = 0; i < verticalGuides.length; i++) {
      if (oldDelegate.verticalGuides[i] != verticalGuides[i]) return true;
    }
    for (int i = 0; i < horizontalGuides.length; i++) {
      if (oldDelegate.horizontalGuides[i] != horizontalGuides[i]) return true;
    }
    return false;
  }
}

class _CoverBackground extends StatelessWidget {
  final double leftSpine;
  final CoverTheme theme;
  final Color? backgroundColor;
  final bool showSpine;
  final bool flatPresentation;

  const _CoverBackground({
    required this.leftSpine,
    required this.theme,
    this.backgroundColor,
    this.showSpine = true,
    this.flatPresentation = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 기본 커버 배경 (테마)
        Container(
          decoration: BoxDecoration(
            borderRadius: flatPresentation
                ? BorderRadius.zero
                : const BorderRadius.only(
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            color: backgroundColor,
            image: backgroundColor == null && theme.imageAsset != null
                ? DecorationImage(
                    image: AssetImage(theme.imageAsset!),
                    fit: BoxFit.cover,
                  )
                : null,
            gradient: backgroundColor == null && theme.imageAsset == null
                ? theme.gradient
                : null,
          ),
        ),
        // Spine 영역 어두운 그림자 (공통)
        if (backgroundColor == null && showSpine)
          IgnorePointer(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: leftSpine,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withOpacity(0.10),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 1.0],
                  ),
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
  final bool flatPresentation;
  const _AnimatedCoverContainer({
    required this.child,
    required this.theme,
    this.flatPresentation = false,
  });

  @override
  State<_AnimatedCoverContainer> createState() =>
      _AnimatedCoverContainerState();
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
    if (widget.flatPresentation) return widget.child;
    // Animate scale and shadow when theme changes
    final bool animate = _animating;
    final double scale = animate ? 1.03 : 1.0;
    final List<BoxShadow> boxShadow = animate
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 18,
              offset: const Offset(24, 64),
            ),
            BoxShadow(
              color: const Color(0xFF5c5d8d).withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(32, 64),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.09),
              blurRadius: 12,
              offset: const Offset(18, 48),
            ),
            BoxShadow(
              color: const Color(0xFF5c5d8d).withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(26, 48),
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
