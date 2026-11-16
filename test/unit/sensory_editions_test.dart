import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/free_template_material_policy.dart';
import 'package:snap_fit/core/templates/studio_word_art_catalog.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/shared/widgets/studio_material.dart';
import '../../tool/template_studio/export_price_application.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font
        in jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List) {
      final loader = FontLoader(font['family'] as String);
      for (final face in font['fonts'] as List) {
        loader.addFont(rootBundle.load(face['asset'] as String));
      }
      await loader.load();
    }
  });

  test(
    'both complete books have independent photographs and exact usable material inventories',
    () {
      final allNew = <String>{};
      final old = storyEditions
          .where((e) => e.qualityRevision != sensoryEditionRevision)
          .expand((e) => e.photoAssets)
          .toSet();
      for (final e in sensoryStoryEditions) {
        expect(e.photoAssets.toSet().length, 5);
        expect(e.photoAssets.toSet().intersection(old), isEmpty);
        for (final path in e.photoAssets) {
          expect(File(path).existsSync(), isTrue);
          expect(allNew.add(path), isTrue);
        }
        expect(
          publishedCreationTemplateById(e.catalogId)?.isPremium,
          e.isPremium,
        );
        for (final aspect in CollectionAspect.printable) {
          final doc = storyEditionDocument(e, aspect);
          expect(doc['pages'], hasLength(24));
          expect(doc['publicationStatus'], 'bundled');
          expect(doc['accessTier'], e.isPremium ? 'premium' : 'free');
          expect(
            templateVisualMaterialKeys(doc),
            e.includedMaterialKeys.toSet(),
          );
          expect(e.includedMaterialKeys.toSet(), hasLength(8));
          if (!e.isPremium) expect(freeTemplateMaterialIssues(doc), isEmpty);
        }
      }
      expect(
        allNew
            .map(
              (path) => sha256.convert(File(path).readAsBytesSync()).toString(),
            )
            .toSet(),
        hasLength(10),
      );
    },
  );

  test('free and paid release rows are active and keep the declared tier', () {
    final rows = pointShopPriceApplicationRows();
    validatePointShopCatalogRelease(rows);
    for (final e in sensoryStoryEditions) {
      final keys = [e.productKey, ...e.includedMaterialKeys];
      for (final key in keys) {
        final row = rows.singleWhere((r) => r['product_key'] == key);
        expect(row['is_active'], isTrue, reason: key);
        final free =
            !e.isPremium || freeTemplateMaterialProductKeys.contains(key);
        expect(row['point_price'], free ? 0 : greaterThan(0), reason: key);
      }
      expect(
        pointShopLaunchPrices[e.productKey]?.points,
        e.isPremium ? 1800 : 0,
      );
    }
  });

  for (final e in sensoryStoryEditions) {
    for (final aspect in CollectionAspect.printable) {
      test(
        '${e.id} ${aspect.name}: whole-source photo apertures and editable text fit actual fonts',
        () {
          final doc = storyEditionDocument(e, aspect);
          final pages = [doc['cover'], ...doc['pages'] as List];
          for (final source in pages.cast<Map<String, dynamic>>()) {
            final layers = DataTemplateEngine.buildLayersFromJson(
              source,
              aspect.canvas,
            );
            for (final model in layers) {
              expect(model.position.dx, greaterThanOrEqualTo(-.5));
              expect(model.position.dy, greaterThanOrEqualTo(-.5));
              expect(
                model.position.dx + model.width,
                lessThanOrEqualTo(aspect.canvas.width + .5),
              );
              expect(
                model.position.dy + model.height,
                lessThanOrEqualTo(aspect.canvas.height + .5),
              );
              if (model.type == LayerType.text) {
                final painter = TextPainter(
                  text: TextSpan(text: model.text, style: model.textStyle),
                  textDirection: TextDirection.ltr,
                  textAlign: model.textAlign ?? TextAlign.left,
                )..layout(maxWidth: model.width);
                expect(
                  painter.height,
                  lessThanOrEqualTo(model.height + 1.25),
                  reason: '${e.id} ${aspect.name} ${model.text}',
                );
                painter.dispose();
              }
            }
            for (final raw in (source['layers'] as List).cast<Map>()) {
              if (raw['type'] != 'image') continue;
              final size = Size(
                (raw['w'] as num).toDouble() * aspect.canvas.width,
                (raw['h'] as num).toDouble() * aspect.canvas.height,
              );
              final inner = StudioMaterial.photoInsets(
                raw['frame'] as String,
                size,
              ).deflateRect(Offset.zero & size);
              expect(
                inner.width / inner.height,
                closeTo(1.5, .00001),
                reason: '${e.id} ${aspect.name} ${raw['frame']}',
              );
            }
          }
        },
      );
    }
  }

  test(
    'all four title assemblies remain native editable text at insertion sizes',
    () {
      for (final id in [
        'story-coffee-notebook',
        'story-night-city-archive',
        'sensory-coffee-note',
        'sensory-night-index',
      ]) {
        final art = studioWordArtById(id)!;
        for (final aspect in CollectionAspect.printable) {
          final layers = art.buildLayers(aspect.canvas);
          expect(
            layers.where((l) => l.type == LayerType.text).length,
            greaterThanOrEqualTo(3),
          );
          expect(layers.last.id, endsWith('-main'));
          expect(layers.last.text, art.text);
          expect(layers.every((l) => l.width > 0 && l.height > 0), isTrue);
        }
      }
    },
  );
}
