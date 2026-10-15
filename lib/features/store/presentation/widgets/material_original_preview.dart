import 'package:flutter/widgets.dart';

import '../../../../core/templates/studio_decoration_catalog.dart';
import '../../../../core/templates/studio_word_art_catalog.dart';
import '../../../../shared/widgets/experience_style.dart';

/// Uses the same artwork proportions in the catalog, detail and thumbnail export.
class MaterialOriginalPreview extends StatelessWidget {
  const MaterialOriginalPreview({
    super.key,
    required this.productKey,
    required this.child,
  });

  final String productKey;
  final Widget child;

  static Color backgroundFor(String productKey) {
    final id = productKey.split(':').last;
    if (const {
      'materialVellumBand',
      'travelDocumentPocket',
      'travelPhotoSleeve',
      'studioVellum',
    }.contains(id))
      return const Color(0xFFD5DFDA);
    return studioDecorationById(id)?.category == StudioDecorationCategory.paper
        ? const Color(0xFFE6EDE9)
        : ExperienceStyle.wash;
  }

  @override
  Widget build(BuildContext context) {
    final spec = studioDecorationById(productKey.split(':').last);
    final art = studioWordArts
        .where((art) => art.productKey == productKey)
        .firstOrNull;
    final ratio =
        spec?.aspectRatio ??
        art?.sourceSize.aspectRatio ??
        (productKey.startsWith('frame:') ? 1.0 : null);
    if (ratio == null) return child;
    return Center(
      child: AspectRatio(aspectRatio: ratio, child: child),
    );
  }
}
