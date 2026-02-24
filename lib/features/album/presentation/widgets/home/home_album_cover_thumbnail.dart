import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../shared/snapfit_image.dart';
import '../../../../../core/cache/snapfit_cache_manager.dart';
import '../../../domain/entities/album.dart';
import '../../../domain/entities/layer.dart';
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
    
    // 1. 실제 표시될 대상(TARGET) 크기 결정
    double targetW;
    double targetH;
    final resolvedMaxWidth = maxWidth ?? (ratio > 1 ? 140.w : 150.w);
    
    if (ratio >= 1) {
      targetW = resolvedMaxWidth;
      targetH = targetW / ratio;
      if (targetH > height) {
        targetH = height;
        targetW = targetH * ratio;
      }
    } else {
      targetH = height;
      targetW = targetH * ratio;
      if (targetW > resolvedMaxWidth) {
        targetW = resolvedMaxWidth;
        targetH = targetW / ratio;
      }
    }

    // 2. [핵심] 고정된 기준(REFERENCE) 사이즈 정의 (비례 유지를 위해 충분히 큰 사이즈 사용)
    const double refWidth = kCoverReferenceWidth;
    final double refHeight = refWidth / ratio;
    final Size refCanvasSize = Size(refWidth, refHeight);

    // 3. 기준 사이즈를 바탕으로 레이어 파싱 (비비율 보존)
    final layers = parseCoverLayers(
      album.coverLayersJson,
      canvasSize: refCanvasSize,
    );
    
    final shadowScale = (targetH / 280).clamp(0.35, 0.7);
    final theme = resolveCoverTheme(album.coverTheme);

    // 4. 기준 사이즈로 렌더링 후 FittedBox로 전체 스케일링
    Widget buildFrame({required List<LayerModel> layers}) {
      return SizedBox(
        width: targetW,
        height: targetH,
        child: FittedBox(
          fit: BoxFit.contain,
          child: HomeCoverFrame(
            width: refWidth,
            height: refHeight,
            shadowScale: shadowScale, // 그림자는 대상 크기에 맞게 미리 계산됨
            showShadow: showShadow,
            child: CoverLayout(
              aspect: ratio,
              layers: layers,
              isInteracting: false,
              leftSpine: kCoverSpineWidth,
              onCoverSizeChanged: (_) {},
              buildImage: (layer) => buildStaticImage(layer),
              buildText: (layer) => buildStaticText(layer),
              sortedByZ: (list) => list..sort((a, b) => a.id.compareTo(b.id)),
              theme: theme,
            ),
          ),
        ),
      );
    }

    if (layers != null && layers.isNotEmpty) {
      return buildFrame(layers: layers);
    }

    // 레이어가 없어도 테마가 있으면 테마 배경 유지
    if (album.coverTheme?.isNotEmpty == true) {
      return buildFrame(layers: const []);
    }

    final imageUrl = album.coverThumbnailUrl ??
        album.coverPreviewUrl ??
        album.coverImageUrl;
    final hasUrl = imageUrl?.isNotEmpty == true;

    return HomeCoverFrame(
      width: targetW,
      height: targetH,
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
                size: 28.w,
                color: Colors.grey[600],
              ),
            ),
    );
  }
}
