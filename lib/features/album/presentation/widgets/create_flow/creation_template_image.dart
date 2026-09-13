import 'package:flutter/material.dart';
import '../../../../../core/utils/image_url_policy.dart';
import '../../../../../shared/snapfit_image.dart';

class CreationTemplateImage extends StatelessWidget {
  const CreationTemplateImage({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
  });
  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    const fallback = Center(
      child: Icon(Icons.photo_album_outlined, color: Color(0xFF7C8C88)),
    );
    final asset = bundledTemplateAssetPath(url);
    if (asset != null || url.startsWith('assets/')) {
      return Image.asset(
        asset ?? url,
        fit: fit,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    if (url.isEmpty) return fallback;
    return SnapfitImage(
      urlOrGs: url,
      fit: fit,
      error: fallback,
      placeholder: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      ),
    );
  }
}
