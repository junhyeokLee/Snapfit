import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';

const _covers = {-9303, -9471, -9302, -9412, -9452, -9455, -9463, -9517};
const _paid = {-9512, -9513, -9516, -9517};
List<Map> _layers(Map page) => (page['layers'] as List).cast<Map>();
Rect _rect(Map l, Size size) => Rect.fromLTWH(
  (l['x'] as num) * size.width,
  (l['y'] as num) * size.height,
  (l['w'] as num) * size.width,
  (l['h'] as num) * size.height,
);
String _words(Object? value) => '$value'.replaceAll(RegExp(r'\s+'), '');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map before;
  setUpAll(() async {
    before =
        jsonDecode(
              utf8.decode(
                gzip.decode(
                  File(
                    'test/fixtures/catalog_quality_refresh_before.json.gz',
                  ).readAsBytesSync(),
                ),
              ),
            )
            as Map;
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest.cast<Map>()) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in (entry['fonts'] as List).cast<Map>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });

  for (final id in {..._covers, ..._paid}) {
    test(
      '$id: original content, photographs, inventory and identity survive',
      () {
        final template = publishedCreationTemplates.singleWhere(
          (t) => t.id == id,
        );
        final after = jsonDecode(template.templateJson!) as Map;
        final previous = before['$id'] as Map;
        expect(template.isPremium, _paid.contains(id));
        expect(after['innerPageCount'], previous['innerPageCount']);
        expect(
          templateVisualMaterialKeys(Map<String, dynamic>.from(after)),
          templateVisualMaterialKeys(Map<String, dynamic>.from(previous)),
        );
        for (final aspect in CollectionAspect.printable) {
          final old = (previous['variants'] as Map)[aspect.name] as Map;
          final current = (after['variants'] as Map)[aspect.name] as Map;
          for (final key in old.keys.where(
            (k) => k != 'cover' && k != 'pages',
          )) {
            if (id == -9463 && key == 'title') {
              expect(current[key], walkingCatalogTitle);
              expect(current['originalCatalogTitle'], old[key]);
              continue;
            }
            expect(current[key], old[key], reason: '$id/${aspect.name}/$key');
          }
          if (!_paid.contains(id)) expect(current['pages'], old['pages']);
          final pages = [
            current['cover'] as Map,
            ...(current['pages'] as List).cast<Map>(),
          ];
          final oldPages = [
            old['cover'] as Map,
            ...(old['pages'] as List).cast<Map>(),
          ];
          expect(pages.length, oldPages.length);
          for (final (index, page) in pages.indexed) {
            final layers = _layers(page), oldLayers = _layers(oldPages[index]);
            expect(
              layers.length,
              oldLayers.length,
              reason: '$id/$index: no layer growth',
            );
            expect(
              layers.map((l) => l['id']).toSet(),
              oldLayers.map((l) => l['id']).toSet(),
            );
            expect(
              layers.where((l) => l['type'] == 'image').toList(),
              oldLayers.where((l) => l['type'] == 'image').toList(),
              reason:
                  '$id/$index: photo size, crop, frame and order stay fixed',
            );
            expect(
              {
                for (final l in layers.where((l) => l['type'] == 'text'))
                  l['id']:
                      id == -9463 &&
                          index == 0 &&
                          '${l['id']}'.endsWith('_signature_title')
                      ? _words('산책이라는 약속')
                      : _words(l['text']),
              },
              {
                for (final l in oldLayers.where((l) => l['type'] == 'text'))
                  l['id']: _words(l['text']),
              },
            );
            if (id == -9463 && index == 0) {
              final title = layers.singleWhere(
                (l) => '${l['id']}'.endsWith('_signature_title'),
              );
              expect(_words(title['text']), _words(walkingCatalogTitle));
              expect(_words(title['editorialSourceText']), _words('산책이라는 약속'));
            }
          }
        }
      },
    );
  }

  test('native direct maps and serialized cover typography agree', () {
    for (final collection in authoredCollections.where(
      (c) => _covers.contains(c.bundledId),
    )) {
      for (final aspect in CollectionAspect.values) {
        final doc = collection.document(aspect);
        final direct = DataTemplateEngine.buildLayersFromJson(
          doc['cover'],
          aspect.canvas,
        );
        final decoded = DataTemplateEngine.buildLayersFromJson(
          Map<String, dynamic>.from(
            jsonDecode(jsonEncode(doc['cover'])) as Map,
          ),
          aspect.canvas,
        );
        for (final (index, layer) in direct.indexed) {
          if (layer.textStyle == null) continue;
          expect(layer.textStyle!.fontFamily, isNotNull, reason: layer.id);
          expect(layer.textStyle, decoded[index].textStyle, reason: layer.id);
          expect(layer.textStyle!.color!.a, 1, reason: layer.id);
        }
      }
    }
  });

  test(
    'companion cover title stays left of the photographed ears and face',
    () {
      final doc =
          jsonDecode(
                publishedCreationTemplates
                    .singleWhere((t) => t.id == -9517)
                    .templateJson!,
              )
              as Map;
      for (final aspect in CollectionAspect.printable) {
        final cover = (doc['variants'] as Map)[aspect.name]['cover'] as Map;
        final title = _layers(
          cover,
        ).singleWhere((l) => l['id'].toString().endsWith('_part_3'));
        expect(
          _rect(title, aspect.canvas).right,
          lessThanOrEqualTo(aspect.canvas.width * .43),
          reason:
              '${aspect.name}: the head begins beyond this clear left column',
        );
      }
    },
  );

  test(
    'paid opening typography survives serialization without mutating its source',
    () {
      for (final volume in [
        ConceptVolume.shoreDays,
        ConceptVolume.readingRoom,
        ConceptVolume.sharedSeasons,
        ConceptVolume.littleCompanion,
      ]) {
        for (final aspect in CollectionAspect.values) {
          final source = volume.document(aspect);
          final original = jsonEncode(source);
          final doc = refinePaidCatalogDocument(volume.id, aspect, source);
          expect(
            jsonEncode(source),
            original,
            reason: '${volume.id}/${aspect.name}',
          );
          for (final page in [
            doc['cover'] as Map,
            (doc['pages'] as List).first as Map,
          ]) {
            final direct = DataTemplateEngine.buildLayersFromJson(
              Map<String, dynamic>.from(page),
              aspect.canvas,
            );
            final decoded = DataTemplateEngine.buildLayersFromJson(
              Map<String, dynamic>.from(jsonDecode(jsonEncode(page)) as Map),
              aspect.canvas,
            );
            for (final (index, layer) in direct.indexed) {
              if (layer.textStyle == null) continue;
              expect(layer.textStyle!.fontFamily, isNotNull, reason: layer.id);
              expect(
                layer.textStyle,
                decoded[index].textStyle,
                reason: layer.id,
              );
            }
          }
        }
      }
    },
  );

  for (final aspect in CollectionAspect.printable) {
    test(
      '${aspect.name}: paid objects grow without covering pictures or copy',
      () {
        for (final id in _paid) {
          final doc =
              (jsonDecode(
                        publishedCreationTemplates
                            .singleWhere((t) => t.id == id)
                            .templateJson!,
                      )
                      as Map)['variants'][aspect.name]
                  as Map;
          var enlarged = 0;
          for (final page in (doc['pages'] as List).cast<Map>()) {
            final layers = _layers(page);
            for (final object in layers.where(
              (l) => l['materialPresenceRevision'] != null,
            )) {
              enlarged++;
              final bounds = _rect(object, aspect.canvas);
              expect(bounds.left, greaterThanOrEqualTo(31));
              expect(bounds.right, lessThanOrEqualTo(aspect.canvas.width - 31));
              expect(
                bounds.bottom,
                lessThanOrEqualTo(aspect.canvas.height - 48 + .001),
              );
              expect(
                bounds.width / bounds.height,
                closeTo(
                  (object['editorialMaterialAspect'] as num).toDouble(),
                  .00001,
                ),
              );
              for (final obstacle in layers.where(
                (l) => l['type'] == 'text' || l['type'] == 'image',
              )) {
                expect(
                  bounds
                      .deflate(.05)
                      .overlaps(_rect(obstacle, aspect.canvas).deflate(.05)),
                  isFalse,
                  reason:
                      '$id/${aspect.name}/${object['id']}/${obstacle['id']}',
                );
              }
            }
          }
          expect(
            enlarged,
            greaterThanOrEqualTo(4),
            reason: '$id: actual material upgrade',
          );
        }
      },
    );
  }
}
