import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_catalog_categories.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/free_template_material_policy.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/point_shop/domain/premium_volume_registration.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import '../../tool/template_studio/export_price_application.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
    if (const bool.fromEnvironment('CAPTURE_APPROVED_ATELIER')) {
      final file = File('test/fixtures/atelier_approved_pages.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(_approvedAtelierPages()),
      );
    }
  });

  test('approved covers and concept spreads remain visually unchanged', () {
    final expected = jsonDecode(
      File('test/fixtures/atelier_approved_pages.json').readAsStringSync(),
    );
    expect(_approvedAtelierPages(), expected);
  });

  test(
    'one distinct premium edition per topic, with unique native identity',
    () {
      expect(
        AtelierEdition.values.map((e) => e.category).toSet(),
        templateTopicOrder.toSet(),
      );
      final covers = <String>{};
      final keys = publishedPremiumTemplates.map(pointShopTemplateKey).toList();
      expect(
        keys.toSet().length,
        keys.length,
        reason: 'Never reuse an existing paid product identity',
      );
      for (final e in AtelierEdition.values) {
        final item = publishedPremiumTemplates.singleWhere(
          (t) => t.id == e.catalogId,
        );
        expect(item.isPremium, true);
        expect(item.pageCount, 32);
        expect(pointShopTemplateKey(item), e.productKey);
        expect(covers.add(e.coverAsset), true);
        expect(File(e.coverAsset).existsSync(), true);
        expect(e.chapters.length, 16);
        expect(e.chapters.toSet().length, 16);
        final doc = e.document(CollectionAspect.square);
        expect(templateVisualMaterialKeys(doc).length, greaterThanOrEqualTo(6));
        expect(
          templateVisualMaterialKeys(doc),
          contains('sticker:${e.signatureMaterial}'),
        );
      }
    },
  );

  for (final e in AtelierEdition.values) {
    for (final aspect in CollectionAspect.values) {
      test('${e.id} ${aspect.name}: all 33 pages parse and fit', () {
        final doc = e.document(aspect);
        final pages = templateDocumentPages(doc);
        expect(pages.length, 33);
        expect(doc['aiGenerated'], false);
        final ids = <String>{};
        final roles = <String>{};
        for (final page in pages) {
          roles.add(page['role'] as String);
          for (final raw in page['layers'] as List) {
            expect(ids.add(raw['id'] as String), true);
            if (raw['imageUrl'] case final String path) {
              expect(File(path.substring(6)).existsSync(), true, reason: path);
            }
          }
          final layers = DataTemplateEngine.buildLayersFromJson(
            page,
            aspect.canvas,
          );
          for (final layer in layers) {
            final rect = layer.position & Size(layer.width, layer.height);
            expect(rect.left, greaterThanOrEqualTo(-.1), reason: layer.id);
            expect(rect.top, greaterThanOrEqualTo(-.1), reason: layer.id);
            expect(
              rect.right,
              lessThanOrEqualTo(aspect.canvas.width + .1),
              reason: layer.id,
            );
            expect(
              rect.bottom,
              lessThanOrEqualTo(aspect.canvas.height + .1),
              reason: layer.id,
            );
            if (layer.type != LayerType.text) continue;
            final painter = TextPainter(
              textDirection: TextDirection.ltr,
              text: TextSpan(text: layer.text, style: layer.textStyle),
              strutStyle: StrutStyle.fromTextStyle(
                layer.textStyle!,
                forceStrutHeight: true,
              ),
            )..layout(maxWidth: layer.width);
            expect(
              painter.height,
              lessThanOrEqualTo(layer.height + .5),
              reason:
                  '${e.title} ${aspect.name} ${page['name']}: ${layer.text}',
            );
            final raw = (page['layers'] as List).cast<Map>().singleWhere(
              (r) => r['id'] == layer.id,
            );
            if (raw['typographyMaxLines'] case final int maxLines) {
              expect(
                painter.computeLineMetrics().length,
                lessThanOrEqualTo(maxLines),
                reason:
                    '${e.title} ${aspect.name}: headline must not split an authored word: ${layer.text}',
              );
            }
            painter.dispose();
          }
        }
        expect(roles.length, greaterThanOrEqualTo(27));
      });
    }
  }

  test('approved prices prepare activation without granting ownership', () {
    final rows = pointShopPriceApplicationRows();
    for (final e in AtelierEdition.values) {
      expect(isPendingTemplateProduct(e.productKey), false);
      final row = rows.singleWhere((r) => r['product_key'] == e.productKey);
      expect(row['is_active'], true);
      expect(row['point_price'], atelierEditionProposedPointPrice);
      expect(
        pointShopLaunchPrices[e.productKey]!.points,
        atelierEditionProposedPointPrice,
      );
      expect(e.document(CollectionAspect.square)['catalogPublishable'], false);
    }
    expect(bundledCreationTemplates.length, 42);
  });

  test(
    'layered materials have explicit tiers without changing old free books',
    () {
      expect(atelierLayeredDecorations.length, 21);
      expect(atelierEditionMaterialPrices.length, 28);
      expect(
        atelierEditionMaterialPrices.values.where((p) => p == 0).length,
        7,
      );
      final rows = pointShopPriceApplicationRows();
      for (final spec in atelierEditionDecorations) {
        final key = 'sticker:${spec.id}';
        final price = atelierEditionMaterialPrices[spec.id]!;
        expect(pointShopLaunchPrices[key]!.points, price);
        expect(freeTemplateMaterialProductKeys.contains(key), price == 0);
        expect(
          rows.singleWhere((r) => r['product_key'] == key)['is_active'],
          true,
        );
      }
    },
  );

  test('every new kit is used and its photo sits beneath its aperture', () {
    for (final edition in AtelierEdition.values) {
      for (final aspect in CollectionAspect.values) {
        final doc = edition.document(aspect);
        final keys = templateVisualMaterialKeys(doc);
        for (final id in atelierLayeredMaterialKits[edition.id]!) {
          expect(keys, contains('sticker:$id'));
        }
        var windows = 0;
        for (final page in templateDocumentPages(doc).skip(1)) {
          final layers = (page['layers'] as List).cast<Map>();
          for (var i = 0; i < layers.length; i++) {
            if (layers[i]['style'] != edition.mountMaterial) continue;
            windows++;
            expect(i, greaterThan(0));
            final photo = layers[i - 1], mount = layers[i];
            expect(photo['type'], 'image');
            final window = atelierMountWindow(edition.mountMaterial);
            expect(
              photo['x'],
              closeTo(mount['x'] + window.left * mount['w'], .00001),
            );
            expect(
              photo['y'],
              closeTo(mount['y'] + window.top * mount['h'], .00001),
            );
            // No baked-in composite: user photos remain replaceable image layers.
            expect(photo['w'], closeTo(window.width * mount['w'], .00001));
            expect(photo['h'], closeTo(window.height * mount['h'], .00001));
          }
        }
        expect(windows, inInclusiveRange(1, 6), reason: edition.id);
      }
    }
  });

  test(
    'sixteen distinct photo arrangements and bounded material repetition per book',
    () {
      final byId = {for (final spec in studioDecorations) spec.id: spec};
      final byAsset = {
        for (final spec in studioDecorations)
          if (spec.assetPath != null) 'asset:${spec.assetPath}': spec,
      };
      for (final e in AtelierEdition.values) {
        for (final aspect in CollectionAspect.values) {
          final doc = e.document(aspect),
              pages = templateDocumentPages(doc).skip(1).toList();
          final geometry = <String>{}, materialPages = <String, int>{};
          for (var spread = 0; spread < 16; spread++) {
            final signature = <List<List<int>>>[];
            for (final page in pages.skip(spread * 2).take(2)) {
              final layers = (page['layers'] as List).cast<Map>();
              signature.add([
                for (final layer in layers.where((l) => l['type'] == 'image'))
                  [
                    for (final key in ['x', 'y', 'w', 'h'])
                      ((layer[key] as num) * 20).round(),
                  ],
              ]);
              final used = <String>{};
              for (final layer in layers.where(
                (l) => l['type'] == 'decoration' || l['type'] == 'sticker',
              )) {
                final spec = byId[layer['style']] ?? byAsset[layer['imageUrl']];
                if (spec != null) used.add(spec.id);
              }
              for (final key in used) {
                materialPages.update(
                  key,
                  (count) => count + 1,
                  ifAbsent: () => 1,
                );
              }
            }
            expect(
              geometry.add(jsonEncode(signature)),
              true,
              reason:
                  '${e.id}/${aspect.name}: repeated photo arrangement at spread ${spread + 1}',
            );
          }
          expect(materialPages.length, greaterThanOrEqualTo(12), reason: e.id);
          for (final entry in materialPages.entries) {
            // The already approved cinema apertures are retained, not expanded.
            final limit = entry.key == e.mountMaterial ? 6 : 4;
            expect(
              entry.value,
              lessThanOrEqualTo(limit),
              reason: '${e.id}: ${entry.key} dominates too many pages',
            );
          }
        }
      }
    },
  );

  test('landscape family opener keeps the original group photo ratio', () {
    final doc = AtelierEdition.tableStories.document(
      CollectionAspect.landscape,
    );
    final right = templateDocumentPages(doc)[2];
    final photo = (right['layers'] as List).cast<Map>().singleWhere(
      (l) =>
          l['imageUrl'] ==
          'asset:assets/templates/original_editorial/images/family_kitchen.png',
    );
    final canvas = CollectionAspect.landscape.canvas;
    expect(
      photo['w'] * canvas.width / (photo['h'] * canvas.height),
      closeTo(1.5, .00001),
    );
    expect(photo['frame'], 'studioDoubleMat');
  });

  test(
    'writing stock stays free, registered and used as separate editable paper',
    () {
      final used = {
        for (final e in AtelierEdition.values)
          ...templateVisualMaterialKeys(e.catalogDocument()),
      };
      for (final spec in atelierWritingPapers) {
        final key = 'sticker:${spec.id}';
        expect(spec.assetPath, isNull);
        expect(pointShopLaunchPrices[key]!.points, 0);
        expect(freeTemplateMaterialProductKeys, contains(key));
        expect(used, contains(key));
      }
    },
  );
}

Map<String, String> _approvedAtelierPages() => {
  for (final e in AtelierEdition.values)
    for (final aspect in CollectionAspect.values)
      for (final page in templateDocumentPages(e.document(aspect)))
        if (page['side'] == 'cover' ||
            [
              'prologue-',
              'specimen-',
              'invitation-',
              'shelves-',
            ].any((role) => (page['role'] as String).startsWith(role)) ||
            e == AtelierEdition.privateCinema &&
                (page['role'] as String).startsWith('darkroom-'))
          '${e.id}/${aspect.name}/${page['side'] == 'cover' ? 'cover' : page['role']}':
              sha256.convert(utf8.encode(jsonEncode(page))).toString(),
};
