import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/templates/studio_decoration_catalog.dart';
import '../../../core/templates/studio_phrase_catalog.dart';
import '../../../core/templates/studio_word_art_catalog.dart';
import '../../../core/templates/frame_preview_photos.dart';
import '../../../shared/widgets/image_frame_style_picker.dart';
import '../../../shared/widgets/studio_decoration.dart';
import '../../../shared/widgets/studio_word_art_preview.dart';
import '../../album/data/bundled_creation_templates.dart';
import '../../album/presentation/widgets/create_flow/creation_catalog_cover.dart';
import '../domain/point_shop_template_key.dart';
import '../../store/data/api/template_provider.dart';

class PointShopArtwork extends StatelessWidget {
  const PointShopArtwork({
    super.key,
    required this.productKey,
    this.showBookMaterial = false,
  });
  final String productKey;
  final bool showBookMaterial;

  @override
  Widget build(BuildContext context) {
    final template = publishedCreationTemplates
        .where((item) => pointShopTemplateKey(item) == productKey)
        .firstOrNull;
    if (template != null) {
      return CreationCatalogCover(
        template: template,
        useThumbnail: true,
        showBookMaterial: showBookMaterial,
      );
    }
    if (productKey.startsWith('template:')) {
      return Consumer(
        builder: (context, ref, _) {
          final template = ref
              .watch(templateListProvider)
              .asData
              ?.value
              .where((item) => pointShopTemplateKey(item) == productKey)
              .firstOrNull;
          return template == null
              ? const Icon(Icons.auto_stories_outlined, size: 40)
              : CreationCatalogCover(
                  template: template,
                  useThumbnail: true,
                  showBookMaterial: showBookMaterial,
                );
        },
      );
    }
    final decoration = studioDecorations
        .where((item) => 'sticker:${item.id}' == productKey)
        .firstOrNull;
    if (decoration != null) return StudioDecoration(spec: decoration);
    final art = studioWordArts
        .where((item) => item.productKey == productKey)
        .firstOrNull;
    if (art != null) return StudioWordArtPreview(art: art);
    final phrase = studioPhrases
        .where((item) => 'phrase:${item.id}' == productKey)
        .firstOrNull;
    if (phrase != null) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          phrase.text,
          style: phrase.lettering.style,
          textAlign: phrase.alignment,
        ),
      );
    }
    final frame = imageFrameStyles
        .where((item) => 'frame:${item.key}' == productKey)
        .firstOrNull;
    final photo = framePreviewPhotos[frame?.key];
    if (frame != null && photo != null) {
      return ImageFramePreview(
        style: frame,
        child: Image.asset(photo, fit: BoxFit.cover, cacheWidth: 384),
      );
    }
    return const Icon(Icons.auto_stories_outlined, size: 40);
  }
}
