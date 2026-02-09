import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../shared/snapfit_image.dart';
import '../../../../../core/cache/snapfit_cache_manager.dart';
import '../../../domain/entities/album.dart';
import '../cover/cover.dart';
import 'home_cover_frame.dart';
import 'home_album_helpers.dart';

/// 앨범 커버 썸네일
class HomeAlbumCoverThumbnail extends StatelessWidget {
  final Album album;
  final double height;
  final double? maxWidth;
  final bool showShadow;

  const HomeAlbumCoverThumbnail({
    super.key,
    required this.album,
    required this.height,
    this.maxWidth,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = parseCoverRatio(album.ratio);
    double width;
    double scaledHeight;
    final resolvedMaxWidth = maxWidth ?? (ratio > 1 ? 140.w : 150.w);
    if (ratio >= 1) {
      width = resolvedMaxWidth;
      scaledHeight = width / ratio;
      if (scaledHeight > height) {
        final scale = height / scaledHeight;
        scaledHeight = height;
        width = width * scale;
      }
    } else {
      scaledHeight = height;
      width = scaledHeight * ratio;
      if (width > resolvedMaxWidth) {
        final scale = resolvedMaxWidth / width;
        width = resolvedMaxWidth;
        scaledHeight = scaledHeight * scale;
      }
    }
    final shadowScale = (scaledHeight / 280).clamp(0.35, 0.7);
    final theme = resolveCoverTheme(album.coverTheme);
    final canvasSize = Size(width, scaledHeight);

    final layers = parseCoverLayers(
      album.coverLayersJson,
      canvasSize: canvasSize,
    );

    if (layers != null && layers.isNotEmpty) {
      return HomeCoverFrame(
        width: width,
        height: scaledHeight,
        shadowScale: shadowScale,
        showShadow: showShadow,
        child: CoverLayout(
          aspect: ratio,
          layers: layers,
          isInteracting: false,
          leftSpine: 12.w,
          onCoverSizeChanged: (_) {},
          buildImage: (layer) => buildStaticImage(layer),
          buildText: (layer) => buildStaticText(layer),
          sortedByZ: (list) => list..sort((a, b) => a.id.compareTo(b.id)),
          theme: theme,
        ),
      );
    }

    final imageUrl = album.coverThumbnailUrl ??
        album.coverPreviewUrl ??
        album.coverImageUrl;
    final hasUrl = imageUrl?.isNotEmpty == true;

    return HomeCoverFrame(
      width: width,
      height: scaledHeight,
      shadowScale: shadowScale,
      showShadow: showShadow,
      child: hasUrl
          ? SnapfitImage(
              urlOrGs: imageUrl!,
              fit: BoxFit.cover,
              cacheManager: snapfitImageCacheManager,
            )
          : Container(
              color: Colors.grey[300],
              child: Icon(
                Icons.photo_album_outlined,
                size: 28.sp,
                color: Colors.grey[600],
              ),
            ),
    );
  }
}
