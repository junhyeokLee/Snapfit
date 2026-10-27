import 'package:flutter/material.dart';

import '../../../../core/templates/catalog_editorial_assets.g.dart';
import '../../../../core/data/catalog_preview.dart';
import '../../../../shared/widgets/catalog_preview_builder.dart';
import '../../../album/data/bundled_creation_templates.dart';
import '../../../album/presentation/widgets/create_flow/creation_catalog_cover.dart';
import '../../domain/entities/premium_template.dart';
import 'template_page_renderer.dart';

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
    '동아리' || '스포츠·도전' => const CatalogEditionPalette(
      Color(0xFFE4F4F3),
      Color(0xFF203F40),
      Color(0xFF14AAA8),
    ),
    '졸업·새출발' => const CatalogEditionPalette(
      Color(0xFFF1EEE6),
      Color(0xFF203F40),
      Color(0xFF14AAA8),
    ),
    _ => const CatalogEditionPalette(
      Color(0xFFDFE5EE),
      Color(0xFF354D73),
      Color(0xFFB4CEE5),
    ),
  };
}

String? catalogEditorialSpread(PremiumTemplate template) {
  final canonical = publishedCreationTemplateById(template.id);
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
  Widget build(BuildContext context) =>
      _LiveCatalogSpread(template: template, decodeWidth: decodeWidth);
}

class _LiveCatalogSpread extends StatelessWidget {
  const _LiveCatalogSpread({required this.template, required this.decodeWidth});

  final PremiumTemplate template;
  final int decodeWidth;

  @override
  Widget build(BuildContext context) => CatalogPreviewBuilder(
    template: template,
    needsSpread: true,
    builder: (context, snapshot) => _artwork(snapshot.data),
  );

  Widget _artwork(CatalogPreview? preview) {
    if (preview == null ||
        preview.spread.length != 2 ||
        preview.spread.any((page) => page.isEmpty)) {
      return const SizedBox.shrink();
    }
    final canvas = preview.canvas;
    final imageDecodeWidth = ((decodeWidth / 2 / 128).ceil() * 128).clamp(
      128,
      1024,
    );
    return RepaintBoundary(
      key: ValueKey('catalog-live-spread-${template.id}'),
      child: Semantics(
        image: true,
        label:
            '${template.title} ${CatalogPreview.firstSpreadPage}-${CatalogPreview.firstSpreadPage + 1}쪽',
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: canvas.width * 2,
            height: canvas.height,
            child: Row(
              children: [
                for (final page in preview.spread)
                  TemplatePageRenderer(
                    layers: page,
                    width: canvas.width,
                    height: canvas.height,
                    designCanvasSize: canvas,
                    preserveTypography: true,
                    imageDecodeWidth: imageDecodeWidth,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Read-only book surfaces with cached artwork for unchanged collections.
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
            right: box.maxWidth * .025,
            top: box.maxHeight * .07,
            width: box.maxWidth * .84,
            height: box.maxHeight * .77,
            child: Transform.rotate(
              angle: .025,
              child: _PaperSurface(
                child: CatalogSpreadPreview(
                  template: template,
                  decodeWidth: featured ? 768 : 384,
                ),
              ),
            ),
          ),
          Positioned(
            left: box.maxWidth * .025,
            bottom: box.maxHeight * .025,
            width: box.maxWidth * .52,
            height: box.maxHeight * .92,
            child: Transform.rotate(angle: -.035, child: cover),
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
              color: Colors.black.withValues(alpha: .13),
              blurRadius: 14,
              offset: const Offset(0, 7),
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
