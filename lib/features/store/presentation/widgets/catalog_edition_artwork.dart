import 'package:flutter/material.dart';

import '../../../../core/templates/catalog_editorial_assets.g.dart';
import '../../../album/data/bundled_creation_templates.dart';
import '../../../album/presentation/widgets/create_flow/creation_catalog_cover.dart';
import '../../domain/entities/premium_template.dart';

class CatalogEditionPalette {
  const CatalogEditionPalette(this.paper, this.ink, this.accent);
  final Color paper, ink, accent;
  static CatalogEditionPalette of(String? category) => switch (category) {
    '여행' => const CatalogEditionPalette(
      Color(0xFFDDE9E5),
      Color(0xFF195853),
      Color(0xFFE6CB77),
    ),
    '웨딩' => const CatalogEditionPalette(
      Color(0xFFF1DFDD),
      Color(0xFF6C3448),
      Color(0xFFE8B6AC),
    ),
    '커플·기념일' => const CatalogEditionPalette(
      Color(0xFFF2DED5),
      Color(0xFF8A4038),
      Color(0xFFF0B5A2),
    ),
    '성장·육아' => const CatalogEditionPalette(
      Color(0xFFF1E9CF),
      Color(0xFF655636),
      Color(0xFFE8CA73),
    ),
    '가족·친구' => const CatalogEditionPalette(
      Color(0xFFE2E8D7),
      Color(0xFF426047),
      Color(0xFFD7DFA7),
    ),
    '반려동물' => const CatalogEditionPalette(
      Color(0xFFE4DFEA),
      Color(0xFF5A4966),
      Color(0xFFD7C0DC),
    ),
    _ => const CatalogEditionPalette(
      Color(0xFFDFE5EE),
      Color(0xFF354D73),
      Color(0xFFB4CEE5),
    ),
  };
}

String? catalogEditorialSpread(PremiumTemplate template) {
  final canonical = publishedCreationTemplates
      .where((t) => t.id == template.id)
      .firstOrNull;
  if (canonical == null ||
      !identical(canonical.documentBuilder, template.documentBuilder))
    return null;
  return catalogEditorialAssets[template.id];
}

class CatalogSpreadPreview extends StatelessWidget {
  const CatalogSpreadPreview({
    super.key,
    required this.template,
    this.decodeWidth = 512,
  });
  final PremiumTemplate template;
  final int decodeWidth;
  @override
  Widget build(BuildContext context) {
    final asset = catalogEditorialSpread(template);
    if (asset == null) return const SizedBox.shrink();
    final firstPage = catalogEditorialFirstPages[template.id];
    return RepaintBoundary(
      child: Image.asset(
        asset,
        key: ValueKey('catalog-spread-${template.id}'),
        fit: BoxFit.contain,
        cacheWidth: decodeWidth,
        semanticLabel: firstPage == null
            ? template.title
            : '${template.title} $firstPage-${firstPage + 1}쪽',
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}

/// Real printed surfaces, pre-rendered once; no live document parsing in a list.
class CatalogEditionArtwork extends StatelessWidget {
  const CatalogEditionArtwork({
    super.key,
    required this.template,
    this.featured = true,
  });
  final PremiumTemplate template;
  final bool featured;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final hasSpread = catalogEditorialSpread(template) != null;
      final cover = CreationCatalogCover(
        template: template,
        useThumbnail: true,
        showBookMaterial: true,
      );
      if (!hasSpread)
        return Padding(padding: const EdgeInsets.all(20), child: cover);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: box.maxWidth * .015,
            top: box.maxHeight * .10,
            width: box.maxWidth * .91,
            height: box.maxHeight * .68,
            child: Transform.rotate(
              angle: .10,
              child: _PaperSurface(
                child: CatalogSpreadPreview(
                  template: template,
                  decodeWidth: featured ? 768 : 384,
                ),
              ),
            ),
          ),
          Positioned(
            left: box.maxWidth * .055,
            bottom: box.maxHeight * .025,
            width: box.maxWidth * .57,
            height: box.maxHeight * .88,
            child: Transform.rotate(angle: -.085, child: cover),
          ),
        ],
      );
    },
  );
}

class _PaperSurface extends StatelessWidget {
  const _PaperSurface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(
    child: AspectRatio(
      aspectRatio: 2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .18),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            Center(
              child: FractionallySizedBox(
                widthFactor: .014,
                child: ColoredBox(color: Colors.black.withValues(alpha: .06)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
