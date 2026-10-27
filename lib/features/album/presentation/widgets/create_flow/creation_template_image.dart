import 'package:flutter/material.dart';
import '../../../../../core/utils/image_url_policy.dart';
import '../../../../../shared/snapfit_image.dart';
import '../../../../../shared/widgets/catalog_cover_skeleton.dart';

class CreationTemplateImage extends StatelessWidget {
  const CreationTemplateImage({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
    this.decodeWidth,
  });
  final String url;
  final BoxFit fit;
  final int? decodeWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: _buildImage);

  Widget _buildImage(BuildContext context, BoxConstraints bounds) {
    const fallback = Center(
      child: Icon(Icons.photo_album_outlined, color: Color(0xFF7C8C88)),
    );
    final pixels = bounds.hasBoundedWidth
        ? bounds.maxWidth * MediaQuery.devicePixelRatioOf(context)
        : 1024.0;
    final cacheWidth =
        decodeWidth ?? ((pixels / 128).ceil() * 128).clamp(128, 1024).toInt();
    final asset = bundledTemplateAssetPath(url);
    if (asset != null || url.startsWith('assets/')) {
      return Image.asset(
        asset ?? url,
        fit: fit,
        cacheWidth: cacheWidth,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    if (url.isEmpty) return fallback;
    return SnapfitImage(
      urlOrGs: url,
      fit: fit,
      memCacheWidth: cacheWidth,
      error: fallback,
      placeholder: const CatalogCoverSkeleton(),
    );
  }
}
