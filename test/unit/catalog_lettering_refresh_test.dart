import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_known_products.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';

const _directions = {
  -9303: ('Maker', '#4D3549'),
  -9302: ('Arirang2', '#214B47'),
  -9412: ('Paece', '#172E43'),
  -9452: ('Yeongwol', '#2F4B55'),
  -9463: ('Doldam', '#FFF4DB'),
};
String _copy(Object? value) => '$value'.replaceAll(RegExp(r'\s+'), '');
List<Map> _layers(Map page) => (page['layers'] as List).cast<Map>();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map before;
  setUpAll(() async {
    before =
        jsonDecode(
              utf8.decode(
                gzip.decode(
                  File(
                    'test/fixtures/catalog_lettering_before.json.gz',
                  ).readAsBytesSync(),
                ),
              ),
            )
            as Map;
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in fonts.cast<Map>()) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in (entry['fonts'] as List).cast<Map>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });

  for (final entry in _directions.entries) {
    test('${entry.key}: distinctive editable lettering preserves the book', () {
      final template = publishedCreationTemplates.singleWhere(
        (t) => t.id == entry.key,
      );
      final book = jsonDecode(template.templateJson!) as Map;
      final previous = before['${entry.key}'] as Map;
      expect(template.isPremium, isFalse);
      expect(book['innerPageCount'], previous['innerPageCount']);
      for (final aspect in CollectionAspect.printable) {
        final doc = book['variants'][aspect.name] as Map;
        final old = previous['variants'][aspect.name] as Map;
        expect(doc['pages'], old['pages'], reason: 'All interiors stay exact');
        final layers = _layers(doc['cover'] as Map);
        final oldLayers = _layers(old['cover'] as Map);
        expect(layers.length, oldLayers.length);
        expect(layers.map((l) => l['id']), oldLayers.map((l) => l['id']));
        expect(
          layers.where((l) => l['type'] != 'text').toList(),
          oldLayers.where((l) => l['type'] != 'text').toList(),
          reason: 'No new assets, frames, photos, crops or overlays',
        );
        for (final l in layers.where((l) => l['type'] == 'text')) {
          final source = oldLayers.singleWhere((s) => s['id'] == l['id']);
          if (entry.key == -9463 && '${l['id']}'.endsWith('_signature_title')) {
            expect(_copy(l['text']), _copy(walkingCatalogTitle));
            expect(_copy(l['editorialSourceText']), _copy('산책이라는 약속'));
          } else {
            expect(_copy(l['text']), _copy(source['text']));
          }
        }
        final rawTitle = layers.singleWhere(
          (l) => '${l['id']}'.endsWith('_signature_title'),
        );
        expect(rawTitle['style']['fontFamily'], entry.value.$1);
        expect(rawTitle['style']['color'], entry.value.$2);
        final title = DataTemplateEngine.buildLayersFromJson(
          Map<String, dynamic>.from(doc['cover'] as Map),
          aspect.canvas,
        ).singleWhere((l) => l.id == rawTitle['id']);
        expect(title.type, LayerType.text);
        final measured = TextPainter(
          text: TextSpan(text: title.text, style: title.textStyle),
          textDirection: TextDirection.ltr,
          strutStyle: StrutStyle.fromTextStyle(
            title.textStyle!,
            forceStrutHeight: true,
          ),
        )..layout(maxWidth: title.width);
        expect(measured.height, lessThanOrEqualTo(title.height + 1));
        expect(
          measured.computeLineMetrics().length,
          title.text!.split('\n').length,
        );
        measured.dispose();
        final saved = LayerExportMapper.toJson(
          title,
          canvasSize: aspect.canvas,
          isCover: true,
        );
        final reopened = LayerExportMapper.fromJson(
          Map<String, dynamic>.from(jsonDecode(jsonEncode(saved)) as Map),
          canvasSize: aspect.canvas,
          isCover: true,
        );
        expect(reopened.text, title.text);
        expect(reopened.textStyle!.fontFamily, title.textStyle!.fontFamily);
        expect(reopened.textStyle!.color, title.textStyle!.color);
      }
    });
  }

  test('walking rename retains source archive, stable key and free price', () {
    final collection = authoredCollections.singleWhere(
      (c) => c.id == 'our-walking-promise',
    );
    expect(collection.title, '산책이라는 약속');
    expect(FreeCollectionVolume.walkClub.title, '산책이라는 약속');
    for (final aspect in CollectionAspect.values) {
      final archive = FreeCollectionVolume.walkClub.document(aspect);
      final source = jsonEncode(archive);
      final current = collection.document(aspect);
      expect(jsonEncode(archive), source);
      expect(archive['title'], '산책이라는 약속');
      expect(current['title'], walkingCatalogTitle);
      expect(current['originalCatalogTitle'], '산책이라는 약속');
    }
    expect(collection.bundledId, -9463);
    expect(
      publishedCreationTemplates.singleWhere((t) => t.id == -9463).title,
      walkingCatalogTitle,
    );
    final product = pointShopKnownProducts.singleWhere(
      (p) => p.productKey == 'template:our-walking-promise',
    );
    expect(product.assetId, 'our-walking-promise');
    expect(product.title, walkingCatalogTitle);
    expect(pointShopLaunchPrices[product.productKey]!.points, 0);
  });
}
