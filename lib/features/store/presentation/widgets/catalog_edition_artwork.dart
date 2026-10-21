import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/templates/catalog_editorial_assets.g.dart';
import '../../../../core/templates/data_template_engine.dart';
import '../../../../core/templates/template_document_pages.dart';
import '../../../album/data/bundled_creation_templates.dart';
import '../../../album/domain/entities/layer.dart';
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
    if (usesLiveCatalogSpreadArtwork(template)) {
      return _LiveCatalogSpread(template: template, decodeWidth: decodeWidth);
    }
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

class _LiveCatalogSpread extends StatefulWidget {
  const _LiveCatalogSpread({required this.template, required this.decodeWidth});

  final PremiumTemplate template;
  final int decodeWidth;

  @override
  State<_LiveCatalogSpread> createState() => _LiveCatalogSpreadState();
}

class _LiveCatalogSpreadState extends State<_LiveCatalogSpread> {
  // Retain only two parsed pages per book. Bound the catalog's LRU rather
  // than retaining widget trees or all interiors for every scrolling card.
  static final _cache =
      <int, ({String source, Size canvas, List<List<LayerModel>> pages})>{};
  static const _cacheLimit = 18;
  static const _firstPage = 3;
  Size _canvas = const Size(500, 500);
  List<List<LayerModel>> _pages = const [];

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(_LiveCatalogSpread oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.template, widget.template)) _read();
  }

  void _read() {
    _pages = const [];
    try {
      final source = widget.template.templateJson;
      if (source == null) return;
      final cached = _cache.remove(widget.template.id);
      if (cached != null && cached.source == source) {
        _cache[widget.template.id] = cached;
        _canvas = cached.canvas;
        _pages = cached.pages;
        return;
      }
      final document = jsonDecode(source) as Map<String, dynamic>;
      final metadata = document['metadata'] as Map? ?? const {};
      final canvas = Size(
        (document['designWidth'] as num? ??
                metadata['designWidth'] as num? ??
                500)
            .toDouble(),
        (document['designHeight'] as num? ??
                metadata['designHeight'] as num? ??
                500)
            .toDouble(),
      );
      if (!canvas.width.isFinite ||
          !canvas.height.isFinite ||
          canvas.width <= 0 ||
          canvas.height <= 0) {
        return;
      }
      final pages = templateDocumentPages(document)
          .skip(_firstPage)
          .take(2)
          .map(
            (page) => DataTemplateEngine.buildLayersFromJson({
              'strictLayout': true,
              'designWidth': canvas.width,
              'designHeight': canvas.height,
              'layers': page['layers'] ?? const [],
            }, canvas),
          )
          .toList();
      if (pages.length != 2 || pages.any((page) => page.isEmpty)) return;
      _canvas = canvas;
      _pages = pages;
      _cache[widget.template.id] = (
        source: source,
        canvas: canvas,
        pages: pages,
      );
      while (_cache.length > _cacheLimit) {
        _cache.remove(_cache.keys.first);
      }
    } on FormatException {
      _pages = const [];
    } on TypeError {
      _pages = const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pages.length != 2) return const SizedBox.shrink();
    final decodeWidth = ((widget.decodeWidth / 2 / 128).ceil() * 128).clamp(
      128,
      1024,
    );
    return RepaintBoundary(
      key: ValueKey('catalog-live-spread-${widget.template.id}'),
      child: Semantics(
        image: true,
        label: '${widget.template.title} $_firstPage-${_firstPage + 1}쪽',
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: _canvas.width * 2,
            height: _canvas.height,
            child: Row(
              children: [
                for (final page in _pages)
                  TemplatePageRenderer(
                    layers: page,
                    width: _canvas.width,
                    height: _canvas.height,
                    designCanvasSize: _canvas,
                    preserveTypography: true,
                    imageDecodeWidth: decodeWidth,
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
