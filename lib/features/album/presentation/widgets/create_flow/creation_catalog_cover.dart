import 'package:flutter/material.dart';
import '../../../../../core/data/catalog_preview.dart';
import '../../../../../shared/widgets/catalog_preview_builder.dart';
import '../../../../../shared/widgets/catalog_cover_skeleton.dart';
import '../../../data/bundled_creation_templates.dart';
import '../../../../store/domain/entities/premium_template.dart';
import '../../../../store/presentation/widgets/template_page_renderer.dart';
import 'creation_template_image.dart';
import '../../../../store/presentation/widgets/template_book_artwork.dart';

/// Published jackets are drawn from their current editable artwork. Old bundled
/// bitmaps cannot mask a new cover and no replacement preview files are needed.
bool usesLiveCatalogArtwork(PremiumTemplate? template) =>
    canonicalCatalogPreviewId(template) != null;

/// Current interiors use their editable layers without generating files.
bool usesLiveCatalogSpreadArtwork(PremiumTemplate template) =>
    usesLiveCatalogArtwork(template);

class CreationCatalogCover extends StatelessWidget {
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
  Widget build(BuildContext context) => CatalogPreviewBuilder(
    template: template,
    needsCover: true,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return Semantics(
          label: '${template.title} 표지 불러오는 중',
          child: CatalogCoverSkeleton(
            key: ValueKey('catalog-cover-skeleton-${template.id}'),
          ),
        );
      }
      return _nativeArtwork(snapshot.data);
    },
  );

  Widget _nativeArtwork(CatalogPreview? preview) {
    final canvas = preview?.canvas ?? const Size(500, 500);
    final layers = preview?.cover;
    return LayoutBuilder(
      builder: (context, constraints) {
        final pixels = constraints.hasBoundedWidth
            ? constraints.maxWidth * MediaQuery.devicePixelRatioOf(context)
            : 512.0;
        // Bucketing prevents new image-cache entries for tiny layout changes.
        final decodeWidth = ((pixels / 128).ceil() * 128).clamp(128, 1024);
        if (layers == null || layers.isEmpty) {
          Widget image() => CreationTemplateImage(
            url: template.coverImageUrl,
            decodeWidth: decodeWidth,
          );
          return showBookMaterial
              ? TemplateBookArtwork(
                  canvas: canvas,
                  firstPage: 0,
                  paired: false,
                  pageBuilder: (_, __) => image(),
                )
              : image();
        }
        Widget artwork(bool wrap) => FittedBox(
          child: TemplatePageRenderer(
            layers: layers,
            width: canvas.width,
            height: canvas.height,
            designCanvasSize: canvas,
            showCanvasChrome: !showBookMaterial,
            wrapSpineArtwork: wrap,
            cacheNetworkImages: showBookMaterial,
            preserveTypography: isBundledCreationTemplate(template),
            imageDecodeWidth: decodeWidth,
          ),
        );
        return showBookMaterial
            ? TemplateBookArtwork(
                canvas: canvas,
                firstPage: 0,
                paired: false,
                pageBuilder: (_, wrap) => artwork(wrap),
              )
            : artwork(false);
      },
    );
  }
}
