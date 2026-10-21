import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_catalog_cover.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/presentation/widgets/catalog_edition_artwork.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

class _CountedTemplate extends PremiumTemplate {
  _CountedTemplate(PremiumTemplate template)
    : super(
        id: template.id,
        title: template.title,
        coverImageUrl: template.coverImageUrl,
        previewImages: template.previewImages,
        pageCount: template.pageCount,
        userCount: template.userCount,
        documentBuilder: template.documentBuilder,
      );

  int documentReads = 0;

  @override
  String? get templateJson {
    documentReads++;
    return super.templateJson;
  }
}

PremiumTemplate get _travel => publishedCreationTemplates.singleWhere(
  (template) => template.id == windAtlasBundledId,
);

Widget _card(Widget child, {double width = 320, double height = 160}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );

void main() {
  test('all current jackets and spreads bypass archived bitmaps', () {
    expect(usesLiveCatalogArtwork(_travel), isTrue);
    expect(usesLiveCatalogArtwork(_travel.copyWith(isLiked: true)), isTrue);
    expect(usesLiveCatalogArtwork(null), isFalse);
    expect(
      usesLiveCatalogArtwork(_travel.copyWith(templateJson: '{"pages":[]}')),
      isFalse,
    );
    for (final template in publishedCreationTemplates.where(
      (template) => template.id != windAtlasBundledId,
    )) {
      expect(usesLiveCatalogArtwork(template), isTrue, reason: template.title);
      expect(usesLiveCatalogSpreadArtwork(template), isTrue);
      expect(
        usesLiveCatalogArtwork(template.copyWith(templateJson: '{"pages":[]}')),
        isFalse,
      );
    }
  });

  testWidgets('travel list cover uses the current editable cover layers', (
    tester,
  ) async {
    final template = _travel;
    final document = jsonDecode(template.templateJson!) as Map<String, dynamic>;
    final expected = ((document['cover'] as Map)['layers'] as List)
        .map((layer) => (layer as Map)['id'])
        .toList();
    await tester.pumpWidget(
      _card(
        CreationCatalogCover(template: template, useThumbnail: true),
        width: 156,
        height: 156,
      ),
    );

    final renderer = tester.widget<TemplatePageRenderer>(
      find.byType(TemplatePageRenderer),
    );
    expect(renderer.layers.map((layer) => layer.id), expected);
    expect(renderer.preserveTypography, isTrue);
    expect(renderer.imageDecodeWidth, inInclusiveRange(128, 1024));
    expect(
      tester.widgetList<Image>(find.byType(Image)).where((image) {
        final provider = image.image;
        final asset = provider is AssetImage
            ? provider
            : provider is ResizeImage && provider.imageProvider is AssetImage
            ? provider.imageProvider as AssetImage
            : null;
        return asset?.assetName.contains('catalog_thumbnails/') ?? false;
      }),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('all 68 store covers render current layers across LRU eviction', (
    tester,
  ) async {
    final catalog = publishedCreationTemplates;
    expect(catalog, hasLength(68));
    // Revisiting both tiers exercises the bounded 18-cover LRU.
    for (final template in [
      ...catalog,
      catalog.first,
      publishedPremiumTemplates.first,
    ]) {
      final document =
          jsonDecode(template.templateJson!) as Map<String, dynamic>;
      final expected = ((document['cover'] as Map)['layers'] as List)
          .map((layer) => (layer as Map)['id'])
          .toList();
      await tester.pumpWidget(
        _card(
          CreationCatalogCover(template: template, useThumbnail: true),
          width: 156,
          height: 156,
        ),
      );
      final renderer = tester.widget<TemplatePageRenderer>(
        find.byType(TemplatePageRenderer),
      );
      expect(
        renderer.layers.map((layer) => layer.id),
        expected,
        reason: template.title,
      );
      expect(renderer.preserveTypography, isTrue, reason: template.title);
      expect(renderer.imageDecodeWidth, inInclusiveRange(128, 1024));
      expect(tester.takeException(), isNull, reason: template.title);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('travel spread reads pages 3 and 4 and bounds image decoding', (
    tester,
  ) async {
    final template = _CountedTemplate(_travel);
    final pages = templateDocumentPages(
      jsonDecode(_travel.templateJson!) as Map<String, dynamic>,
    );
    await tester.pumpWidget(
      _card(CatalogSpreadPreview(template: template, decodeWidth: 8192)),
    );

    expect(
      find.byKey(const ValueKey('catalog-live-spread--9304')),
      findsOneWidget,
    );
    final renderers = tester
        .widgetList<TemplatePageRenderer>(find.byType(TemplatePageRenderer))
        .toList();
    expect(renderers, hasLength(2));
    for (var index = 0; index < renderers.length; index++) {
      expect(
        renderers[index].layers.map((layer) => layer.id),
        (pages[index + 3]['layers'] as List).map(
          (layer) => (layer as Map)['id'],
        ),
      );
      expect(renderers[index].preserveTypography, isTrue);
      expect(renderers[index].imageDecodeWidth, 1024);
    }
    expect(template.documentReads, 1);

    await tester.pumpWidget(
      _card(
        CatalogSpreadPreview(template: template, decodeWidth: 256),
        width: 128,
        height: 64,
      ),
    );
    expect(template.documentReads, 1);
    expect(
      tester
          .widgetList<TemplatePageRenderer>(find.byType(TemplatePageRenderer))
          .map((renderer) => renderer.imageDecodeWidth),
      everyElement(128),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('paid spread reads its current editable pages once', (
    tester,
  ) async {
    final template = _CountedTemplate(publishedPremiumTemplates.first);
    await tester.pumpWidget(_card(CatalogSpreadPreview(template: template)));

    expect(find.byType(TemplatePageRenderer), findsNWidgets(2));
    expect(template.documentReads, 1);
    expect(find.byKey(ValueKey('catalog-spread-${template.id}')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('all 68 spreads use current pages across LRU eviction', (
    tester,
  ) async {
    final catalog = publishedCreationTemplates;
    expect(catalog, hasLength(68));
    for (final template in [
      ...catalog,
      catalog.first,
      publishedPremiumTemplates.first,
    ]) {
      final pages = templateDocumentPages(
        jsonDecode(template.templateJson!) as Map<String, dynamic>,
      );
      await tester.pumpWidget(_card(CatalogSpreadPreview(template: template)));
      final renderers = tester
          .widgetList<TemplatePageRenderer>(find.byType(TemplatePageRenderer))
          .toList();
      expect(renderers, hasLength(2), reason: template.title);
      for (var index = 0; index < 2; index++) {
        expect(
          renderers[index].layers.map((l) => l.id),
          (pages[index + 3]['layers'] as List).map((l) => (l as Map)['id']),
          reason: template.title,
        );
        expect(renderers[index].preserveTypography, isTrue);
        expect(renderers[index].imageDecodeWidth, inInclusiveRange(128, 1024));
      }
      expect(tester.takeException(), isNull, reason: template.title);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
