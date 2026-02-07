import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../../../../../core/cache/snapfit_cache_manager.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/cover_theme.dart';
import '../../../../../shared/snapfit_image.dart';
import '../../../domain/entities/album.dart';
import '../../../domain/entities/album_page.dart';
import '../../../domain/entities/layer.dart';

/// FannedPageStack 내부: 페이지 레이어 또는 커버 이미지 렌더링
class FannedPageContent extends StatelessWidget {
  final AlbumPage? page;
  final double pageWidth;
  final double pageHeight;
  final CoverSize selectedCover;
  final CoverTheme selectedTheme;
  final Size? coverCanvasSize;
  final Album? currentAlbum;

  const FannedPageContent({
    super.key,
    required this.page,
    required this.pageWidth,
    required this.pageHeight,
    required this.selectedCover,
    required this.selectedTheme,
    this.coverCanvasSize,
    this.currentAlbum,
  });

  @override
  Widget build(BuildContext context) {
    final layers = page?.layers ?? [];
    final baseSize = coverCanvasBaseSize(selectedCover);
    final isCover = page?.isCover ?? false;
    final baseW = isCover ? (coverCanvasSize?.width ?? baseSize.width) : baseSize.width;
    final baseH = isCover ? (coverCanvasSize?.height ?? baseSize.height) : baseSize.height;

    if (layers.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(decoration: selectedTheme.backgroundDecoration),
          ...layers.map((layer) {
            final rx = layer.position.dx / baseW;
            final ry = layer.position.dy / baseH;
            return Positioned(
              left: rx * pageWidth,
              top: ry * pageHeight,
              child: Transform.rotate(
                angle: layer.rotation * (3.14159265359 / 180),
                child: Transform.scale(
                  alignment: Alignment.topLeft,
                  scale: layer.scale * (pageWidth / baseW),
                  child: SizedBox(
                    width: layer.width,
                    height: layer.height,
                    child: layer.type == LayerType.text
                        ? Text(
                            layer.text ?? '',
                            style: layer.textStyle,
                            textAlign: layer.textAlign,
                          )
                        : _imageWidget(layer),
                  ),
                ),
              ),
            );
          }),
        ],
      );
    }

    if (page != null && page!.isCover && currentAlbum != null) {
      final url = currentAlbum!.coverPreviewUrl ??
          currentAlbum!.coverThumbnailUrl ??
          currentAlbum!.coverImageUrl;
      if (url != null && url.isNotEmpty) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(decoration: selectedTheme.backgroundDecoration),
            ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: SnapfitImage(
                urlOrGs: url,
                fit: BoxFit.cover,
                cacheManager: snapfitImageCacheManager,
              ),
            ),
          ],
        );
      }
    }

    return Container(
      decoration: selectedTheme.backgroundDecoration,
      child: Center(
        child: Text(
          page?.isCover == true ? '표지' : '${page?.pageIndex ?? 0}',
          style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
        ),
      ),
    );
  }

  Widget _imageWidget(LayerModel layer) {
    final url = layer.previewUrl ?? layer.imageUrl ?? layer.originalUrl;
    if (url != null && url.isNotEmpty) {
      return SnapfitImage(
        urlOrGs: url,
        fit: BoxFit.cover,
        cacheManager: snapfitImageCacheManager,
      );
    }
    if (layer.asset != null) {
      return AssetEntityImage(layer.asset!, fit: BoxFit.cover);
    }
    return Icon(Icons.image, size: 28.sp, color: Colors.grey[400]);
  }
}
