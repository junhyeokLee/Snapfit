import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../../core/templates/data_template_engine.dart';
import '../../../../../core/templates/template_document_pages.dart';
import '../../../domain/entities/layer.dart';
import '../../../data/bundled_creation_templates.dart';
import '../../../../store/domain/entities/premium_template.dart';
import '../../../../store/presentation/widgets/template_page_renderer.dart';
import 'creation_template_image.dart';
import '../../../../../core/templates/catalog_preview_assets.g.dart';
import '../../../../store/presentation/widgets/template_book_artwork.dart';
import '../cover/album_spine_image.dart';

/// Published jackets are drawn from their current editable artwork. Old bundled
/// bitmaps cannot mask a new cover and no replacement preview files are needed.
bool usesLiveCatalogArtwork(PremiumTemplate? template) {
  if (template == null) return false;
  final canonical = publishedCreationTemplates
      .where((item) => item.id == template.id)
      .firstOrNull;
  return canonical != null &&
      identical(canonical.documentBuilder, template.documentBuilder);
}

/// Current interiors use their editable layers without generating files.
bool usesLiveCatalogSpreadArtwork(PremiumTemplate template) =>
    usesLiveCatalogArtwork(template);

class CreationCatalogCover extends StatefulWidget {
  const CreationCatalogCover({
    super.key,
    required this.template,
    this.useThumbnail = false,
    this.showBookMaterial = false,
  });
  final PremiumTemplate template;
  final bool useThumbnail;
  final bool showBookMaterial;
  @override
  State<CreationCatalogCover> createState() => _CreationCatalogCoverState();
}

class _CreationCatalogCoverState extends State<CreationCatalogCover> {
  String? get _thumbnail {
    if (!widget.useThumbnail || widget.template.documentBuilder == null)
      return null;
    if (usesLiveCatalogArtwork(widget.template)) return null;
    final canonical = publishedCreationTemplates
        .where((t) => t.id == widget.template.id)
        .firstOrNull;
    if (canonical == null ||
        !identical(canonical.documentBuilder, widget.template.documentBuilder))
      return null;
    return catalogPreviewAssets['template:${widget.template.id}'];
  }

  // LRU retains 18 parsed covers, never native widget trees or parsed inner pages.
  static final _cache =
      <int, ({String source, Size canvas, List<LayerModel> layers})>{};
  static const _cacheLimit = 18;
  List<LayerModel>? _layers;
  Size _canvas = const Size(500, 500);
  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(CreationCatalogCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.template, widget.template) ||
        oldWidget.useThumbnail != widget.useThumbnail)
      _parse();
  }

  void _parse() {
    _layers = null;
    if (_thumbnail != null) return;
    try {
      final source = widget.template.templateJson;
      final cached = _cache.remove(widget.template.id);
      if (cached != null && cached.source == source) {
        _cache[widget.template.id] = cached;
        _layers = cached.layers;
        _canvas = cached.canvas;
        return;
      }
      final data = jsonDecode(source!) as Map<String, dynamic>;
      final metadata = data['metadata'] as Map? ?? const {};
      _canvas = Size(
        (data['designWidth'] as num? ?? metadata['designWidth'] as num? ?? 500)
            .toDouble(),
        (data['designHeight'] as num? ??
                metadata['designHeight'] as num? ??
                500)
            .toDouble(),
      );
      if (_canvas.width <= 0 || _canvas.height <= 0) return;
      final page = templateDocumentPages(data).firstOrNull;
      if (page == null) return;
      _layers = DataTemplateEngine.buildLayersFromJson({
        'strictLayout': true,
        'designWidth': _canvas.width,
        'designHeight': _canvas.height,
        'layers': page['layers'] ?? [],
      }, _canvas);
      _cache[widget.template.id] = (
        source: source,
        canvas: _canvas,
        layers: _layers!,
      );
      while (_cache.length > _cacheLimit) {
        _cache.remove(_cache.keys.first);
      }
    } catch (_) {
      _layers = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final thumbnail = _thumbnail;
    if (thumbnail != null) {
      return LayoutBuilder(
        builder: (context, bounds) {
          final pixels = bounds.hasBoundedWidth
              ? bounds.maxWidth * MediaQuery.devicePixelRatioOf(context)
              : 660.0;
          final width = ((pixels / 128).ceil() * 128).clamp(128, 1024);
          return _thumbnailArtwork(thumbnail, width);
        },
      );
    }
    return _nativeArtwork();
  }

  Widget _thumbnailArtwork(String thumbnail, int width) {
    if (widget.showBookMaterial) {
      final provider = ResizeImage(AssetImage(thumbnail), width: width);
      return Image(
        image: provider,
        fit: BoxFit.contain,
        frameBuilder: (context, child, _, __) {
          final bitmap = child is Semantics ? child.child : child;
          if (bitmap is! RawImage || bitmap.image == null) return child;
          final decoded = bitmap.image!;
          return TemplateBookArtwork(
            canvas: Size(decoded.width.toDouble(), decoded.height.toDouble()),
            firstPage: 0,
            paired: false,
            pageBuilder: (index, wrap) =>
                wrap ? AlbumSpineImage(image: provider) : child,
          );
        },
        errorBuilder: (_, __, ___) => CreationCatalogCover(
          template: widget.template,
          showBookMaterial: true,
        ),
      );
    }
    return Image.asset(
      thumbnail,
      fit: BoxFit.contain,
      cacheWidth: width,
      errorBuilder: (_, __, ___) =>
          CreationCatalogCover(template: widget.template),
    );
  }

  Widget _nativeArtwork() {
    if (_layers == null || _layers!.isEmpty)
      return widget.showBookMaterial
          ? TemplateBookArtwork(
              canvas: _canvas,
              firstPage: 0,
              paired: false,
              pageBuilder: (_, __) =>
                  CreationTemplateImage(url: widget.template.coverImageUrl),
            )
          : CreationTemplateImage(url: widget.template.coverImageUrl);
    return LayoutBuilder(
      builder: (context, constraints) {
        final pixels = constraints.hasBoundedWidth
            ? constraints.maxWidth * MediaQuery.devicePixelRatioOf(context)
            : 512.0;
        // Bucketing prevents new image-cache entries for tiny layout changes.
        final decodeWidth = ((pixels / 128).ceil() * 128).clamp(128, 1024);
        Widget artwork(bool wrap) => FittedBox(
          child: TemplatePageRenderer(
            layers: _layers!,
            width: _canvas.width,
            height: _canvas.height,
            designCanvasSize: _canvas,
            showCanvasChrome: !widget.showBookMaterial,
            wrapSpineArtwork: wrap,
            cacheNetworkImages: widget.showBookMaterial,
            preserveTypography: isBundledCreationTemplate(widget.template),
            imageDecodeWidth: decodeWidth,
          ),
        );
        return widget.showBookMaterial
            ? TemplateBookArtwork(
                canvas: _canvas,
                firstPage: 0,
                paired: false,
                pageBuilder: (_, wrap) => artwork(wrap),
              )
            : artwork(false);
      },
    );
  }
}
