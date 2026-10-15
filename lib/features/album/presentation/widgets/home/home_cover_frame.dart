import 'package:flutter/material.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import 'album_book_volume.dart';
import '../cover/album_spine_image.dart';

export 'album_book_volume.dart' show AlbumBookDepthPainter;

/// 커버 프레임
class HomeCoverFrame extends StatelessWidget {
  final double width;
  final double height;
  final double shadowScale;
  final bool showShadow;
  final bool showBookDepth;
  final bool showMaterial;
  final double? bookDepth;
  final Listenable? bookMotion;
  final Color bindingColor;
  final Widget child;
  final Widget? bindingArtwork;

  const HomeCoverFrame({
    super.key,
    required this.width,
    required this.height,
    required this.shadowScale,
    required this.showShadow,
    required this.child,
    this.bindingArtwork,
    this.showBookDepth = false,
    this.showMaterial = false,
    this.bookDepth,
    this.bookMotion,
    this.bindingColor = const Color(0xfff2f3f0),
  });

  static double depthForWidth(double width) =>
      width * AlbumBookVolume.depthRatio;

  @override
  Widget build(BuildContext context) {
    // Closed covers use the same width-normalized light in home and reader.
    final clampedShadowScale = (showBookDepth ? 10.0 : shadowScale).clamp(
      0.35,
      10.0,
    );
    final shadowCanvasScale = showBookDepth
        ? width / kCoverReferenceWidth
        : 1.0;
    final radius = showBookDepth || showMaterial
        ? AlbumBookVolume.radiusForWidth(width)
        : const BorderRadius.only(
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
          );
    final face = Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        ClipRRect(borderRadius: radius, child: child),
        if (showMaterial || showBookDepth)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(painter: AlbumCoverFinishPainter()),
              ),
            ),
          ),
      ],
    );

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: SnapFitColors.isDark(context)
                          ? (showBookDepth ? .30 : .34)
                          : showBookDepth
                          ? .13
                          : 0.13,
                    ),
                    blurRadius:
                        (showBookDepth ? 56 : 22 + clampedShadowScale * 7) *
                        shadowCanvasScale,
                    spreadRadius:
                        (showBookDepth ? -8 : -2 - clampedShadowScale * .35) *
                        shadowCanvasScale,
                    offset: Offset(
                      (showBookDepth ? -4 : 2 * clampedShadowScale) *
                          shadowCanvasScale,
                      (showBookDepth ? 22 : 6 * clampedShadowScale) *
                          shadowCanvasScale,
                    ),
                  ),
                  if (showBookDepth)
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: SnapFitColors.isDark(context) ? .20 : .115,
                      ),
                      blurRadius: 14 * shadowCanvasScale,
                      spreadRadius: -2 * shadowCanvasScale,
                      offset: Offset(-1, 4) * shadowCanvasScale,
                    ),
                ]
              : null,
        ),
        child: showBookDepth
            ? AlbumBookVolume(
                depth: bookDepth ?? depthForWidth(width),
                motion: bookMotion,
                bindingColor: bindingColor,
                bindingArtwork: bindingArtwork,
                child: face,
              )
            : face,
      ),
    );
  }
}

class AlbumCoverFinishPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final rect = Offset.zero & size;
    final face = AlbumBookVolume.radiusForWidth(w).toRRect(rect);
    canvas.save();
    canvas.clipRRect(face);
    // The lighting follows the same projected surface as the photograph's UVs.
    final spine = Rect.fromLTWH(
      0,
      0,
      w * AlbumSpineSurface.flatStart,
      size.height,
    );
    final colors = <Color>[];
    final stops = <double>[];
    for (var i = 0; i <= AlbumSpineSurface.segments; i++) {
      final u = AlbumSpineSurface.flatStart * i / AlbumSpineSurface.segments;
      final light = AlbumSpineSurface.light(u);
      colors.add(
        (light >= 0 ? Colors.white : Colors.black).withValues(
          alpha: light.abs(),
        ),
      );
      stops.add(AlbumSpineSurface.projectedX(u) / AlbumSpineSurface.flatStart);
    }
    canvas.drawRect(
      spine,
      Paint()
        ..shader = LinearGradient(
          colors: colors,
          stops: stops,
        ).createShader(spine),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: .024),
            Colors.white.withValues(alpha: .008),
            Colors.transparent,
          ],
          stops: const [0, .45, 1],
        ).createShader(rect),
    );
    canvas.drawLine(
      Offset(w * .008, w * .0008),
      Offset(w * .978, w * .0008),
      Paint()
        ..color = Colors.white.withValues(alpha: .10)
        ..strokeWidth = w * .0016,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AlbumCoverFinishPainter oldDelegate) => false;
}
