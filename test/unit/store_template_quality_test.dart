import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/data/catalog_preview_document.dart';
import 'package:snap_fit/core/data/catalog_detail_artwork_revisions.g.dart';
import 'package:snap_fit/core/data/catalog_detail_assets.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/store/presentation/utils/template_detail_document.dart';

const _ids = {-9422, -9443, -9451};
const _revision = 'objects-company-dates-2026-11-02';
const _photos = {
  -9422: ['studio_laptop.jpg', 'artist_palette.jpg', 'wardrobe.jpg'],
  -9443: ['daily_friends.png', 'family_friends.png'],
  -9451: ['couple_cafe.png', 'travel_cafe.png'],
};
List<Map> _layers(Map page) => (page['layers'] as List).cast<Map>();
String _words(Object? value) => '$value'.replaceAll(RegExp(r'\s+'), '');
Rect _rect(Map l, Size size) => Rect.fromLTWH(
  (l['x'] as num) * size.width,
  (l['y'] as num) * size.height,
  (l['w'] as num) * size.width,
  (l['h'] as num) * size.height,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map before;
  final fonts = <String>{};
  setUpAll(() async {
    before =
        jsonDecode(
              utf8.decode(
                gzip.decode(
                  File(
                    'test/fixtures/store_template_quality_before.json.gz',
                  ).readAsBytesSync(),
                ),
              ),
            )
            as Map;
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest.cast<Map>()) {
      fonts.add(entry['family'] as String);
      final loader = FontLoader(entry['family'] as String);
      for (final font in (entry['fonts'] as List).cast<Map>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });

  test(
    'the other 130 live catalog documents retain their exact native layouts',
    () {
      final hashes =
          jsonDecode(
                File(
                  'test/fixtures/store_template_quality_unaffected_compact_sha256.json',
                ).readAsStringSync(),
              )
              as Map;
      final unaffected = publishedCreationTemplates.where(
        (t) => !_ids.contains(t.id),
      );
      expect(unaffected.length, 130);
      expect(hashes.keys.toSet(), unaffected.map((t) => '${t.id}').toSet());
      for (final template in unaffected) {
        final compact = compactCatalogPreviewDocument(template.templateJson!)!;
        final digest = sha256
            .convert(utf8.encode(jsonEncode(compact)))
            .toString();
        expect(
          digest,
          hashes['${template.id}'],
          reason: '${template.id}: unrelated artwork changed',
        );
      }
    },
  );

  test('all 145 historical detail asset paths retain their exact bytes', () {
    final previous =
        jsonDecode(
              File(
                'test/fixtures/store_template_quality_previous_detail_assets_sha256.json',
              ).readAsStringSync(),
            )
            as Map;
    expect(previous, hasLength(145));
    for (final entry in previous.entries) {
      final file = File('assets/templates/detail_documents/${entry.key}');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'Historical detail URLs must remain available.',
      );
      expect(
        sha256.convert(file.readAsBytesSync()).toString(),
        entry.value,
        reason: '${entry.key}: an existing asset was rewritten',
      );
    }
  });

  for (final id in _ids) {
    test(
      '$id: the actual detail asset route matches every current sale variant',
      () async {
        final template = publishedCreationTemplates.singleWhere(
          (t) => t.id == id,
        );
        final request = TemplateDetailDocuments.acquire(template);
        final detail = await request.future;
        expect(detail, isNotNull);
        final canonical = template.templateJson!;
        final digest = sha256.convert(utf8.encode(canonical)).toString();
        expect(
          sha256.convert(utf8.encode(detail!.source)).toString(),
          digest,
          reason: 'A current card must never open an older full detail book.',
        );
        expect(catalogDetailArtworkRevisions['$id'], digest.substring(0, 16));
        expect(
          catalogDetailAssetPath('$id'),
          contains('.${digest.substring(0, 16)}.json.gz'),
          reason: 'An already opened browser must fetch the new artwork URL.',
        );
        final source = jsonDecode(canonical) as Map<String, dynamic>;
        expect(detail.book.pages, templateDocumentPages(source));
        expect(
          detail.variants.keys.toSet(),
          CollectionAspect.printable.map((a) => a.name).toSet(),
        );
        for (final aspect in CollectionAspect.printable) {
          final variant = Map<String, dynamic>.from(
            source['variants'][aspect.name] as Map,
          );
          final actual = detail.variants[aspect.name]!;
          expect(actual.canvas, aspect.canvas);
          expect(
            actual.pages,
            templateDocumentPages(variant),
            reason:
                '$id/${aspect.name}: the large live preview and native export must agree',
          );
          expect(actual.pages.first['coverArtDirection'], _revision);
          expect(
            _layers(actual.pages.first).where((l) => l['type'] == 'image'),
            hasLength(1),
          );
        }
      },
    );
    test(
      '$id: identity, rights, copy and every other page remain unchanged',
      () {
        final template = publishedCreationTemplates.singleWhere(
          (t) => t.id == id,
        );
        final current = jsonDecode(template.templateJson!) as Map;
        final previous = before['$id'] as Map;
        expect(template.isPremium, isFalse);
        expect(current['id'], previous['id']);
        expect(current['title'], previous['title']);
        expect(current['category'], previous['category']);
        expect(current['innerPageCount'], previous['innerPageCount']);
        expect(
          templateVisualMaterialKeys(Map<String, dynamic>.from(current)),
          templateVisualMaterialKeys(Map<String, dynamic>.from(previous)),
        );
        for (final aspect in CollectionAspect.printable) {
          final old = previous['variants'][aspect.name] as Map;
          final next = current['variants'][aspect.name] as Map;
          for (final key in old.keys.where(
            (k) => k != 'cover' && k != 'pages',
          )) {
            expect(next[key], old[key], reason: '$id/${aspect.name}/$key');
          }
          expect(next['coverArtDirection'], _revision);
          expect(next['editorialArtDirection'], _revision);
          final oldPages = (old['pages'] as List).cast<Map>();
          final pages = (next['pages'] as List).cast<Map>();
          expect(pages.length, oldPages.length);
          for (final (i, page) in pages.indexed) {
            if (i != 2 && i != 3) {
              expect(
                page,
                oldPages[i],
                reason: '$id/${aspect.name}/page${i + 1}',
              );
            }
          }
          for (final (page, prior) in [
            (next['cover'] as Map, old['cover'] as Map),
            (pages[2], oldPages[2]),
            (pages[3], oldPages[3]),
          ]) {
            final layers = _layers(page);
            final originals = _layers(prior)
                .where(
                  (l) =>
                      !(identical(page, next['cover']) &&
                          '${l['id']}'.endsWith('_signature_companion')),
                )
                .toList();
            expect(
              layers.map((l) => '${l['id']}:${l['type']}').toSet(),
              originals.map((l) => '${l['id']}:${l['type']}').toSet(),
            );
            expect(layers.length, originals.length);
            expect(
              {
                for (final l in layers.where((l) => l['type'] == 'text'))
                  l['id']: _words(l['text']),
              },
              {
                for (final l in originals.where((l) => l['type'] == 'text'))
                  l['id']: _words(l['text']),
              },
            );
          }
          final photos = [
            for (final p in pages.skip(2).take(2))
              for (final l in _layers(p).where((l) => l['type'] == 'image')) l,
          ];
          expect(
            photos.map((l) => '${l['imageUrl']}'.split('/').last).toList(),
            _photos[id],
          );
          for (final photo in photos) {
            expect(photo['editorialSourcePhoto'], isNotNull);
            expect(photo['editable'], isTrue);
            expect(photo['frame'], 'none');
            expect(
              File(
                '${photo['imageUrl']}'.replaceFirst('asset:', ''),
              ).existsSync(),
              isTrue,
            );
          }
          expect(
            _layers(next['cover'])
                .where((l) => l['type'] == 'image')
                .map((l) => l['imageUrl'])
                .toList(),
            _layers(old['cover'])
                .where((l) => l['type'] == 'image')
                .map((l) => l['imageUrl'])
                .take(1)
                .toList(),
          );
        }
      },
    );

    test(
      '$id: actual fonts fit and edited photos survive save/reopen at all sale sizes',
      () {
        final current =
            jsonDecode(
                  publishedCreationTemplates
                      .singleWhere((t) => t.id == id)
                      .templateJson!,
                )
                as Map;
        for (final aspect in CollectionAspect.printable) {
          final variant = current['variants'][aspect.name] as Map;
          final pages = [
            variant['cover'] as Map,
            ...(variant['pages'] as List).cast<Map>().skip(2).take(2),
          ];
          for (final (index, page) in pages.indexed) {
            final layers = DataTemplateEngine.buildLayersFromJson(
              Map<String, dynamic>.from(page),
              aspect.canvas,
            );
            final cleared = AlbumCreationTemplate.preparePages(
              [layers],
              sourceCanvas: aspect.canvas,
              cover: aspect.cover,
            ).single;
            for (final (i, layer) in layers.indexed) {
              final reason = '$id/${aspect.name}/$index/${layer.id}';
              final bounds = Rect.fromLTWH(
                layer.position.dx,
                layer.position.dy,
                layer.width,
                layer.height,
              );
              expect(bounds.isFinite, isTrue, reason: reason);
              expect(bounds.width, greaterThan(0), reason: reason);
              expect(bounds.height, greaterThan(0), reason: reason);
              expect(bounds.left, greaterThanOrEqualTo(-.5), reason: reason);
              expect(bounds.top, greaterThanOrEqualTo(-.5), reason: reason);
              expect(
                bounds.right,
                lessThanOrEqualTo(aspect.canvas.width + .5),
                reason: reason,
              );
              expect(
                bounds.bottom,
                lessThanOrEqualTo(aspect.canvas.height + .5),
                reason: reason,
              );
              final restored = LayerExportMapper.fromJson(
                Map<String, dynamic>.from(
                  jsonDecode(
                        jsonEncode(
                          LayerExportMapper.toJson(
                            layer,
                            canvasSize: aspect.canvas,
                            isCover: index == 0,
                          ),
                        ),
                      )
                      as Map,
                ),
                canvasSize: aspect.canvas,
                isCover: index == 0,
              );
              expect(restored.id, layer.id, reason: reason);
              expect(
                restored.position.dx,
                closeTo(layer.position.dx, .001),
                reason: reason,
              );
              expect(
                restored.position.dy,
                closeTo(layer.position.dy, .001),
                reason: reason,
              );
              expect(
                restored.width,
                closeTo(layer.width, .001),
                reason: reason,
              );
              expect(
                restored.height,
                closeTo(layer.height, .001),
                reason: reason,
              );
              if (layer.type == LayerType.image) {
                expect(cleared[i].hasImageSource, isFalse, reason: reason);
                expect(restored.imageUrl, layer.imageUrl, reason: reason);
              }
              if (layer.type == LayerType.text) {
                expect(
                  fonts,
                  contains(layer.textStyle!.fontFamily),
                  reason: reason,
                );
                expect(restored.text, layer.text, reason: reason);
                expect(
                  layer.textStyle!.fontSize,
                  greaterThanOrEqualTo(8.5),
                  reason: reason,
                );
                final style = layer.textStyle!;
                final painter = TextPainter(
                  text: TextSpan(text: layer.text, style: style),
                  textDirection: TextDirection.ltr,
                  strutStyle: StrutStyle.fromTextStyle(
                    style,
                    forceStrutHeight: true,
                  ),
                )..layout(maxWidth: layer.width);
                expect(
                  painter.height,
                  lessThanOrEqualTo(layer.height + .5),
                  reason: reason,
                );
                expect(
                  painter.computeLineMetrics().every(
                    (l) => l.width <= layer.width + .5,
                  ),
                  isTrue,
                  reason: reason,
                );
                painter.dispose();
              }
            }
            if (index > 0) {
              for (final photo in _layers(
                page,
              ).where((l) => l['type'] == 'image')) {
                for (final text in _layers(
                  page,
                ).where((l) => l['type'] == 'text')) {
                  expect(
                    _rect(
                      photo,
                      aspect.canvas,
                    ).overlaps(_rect(text, aspect.canvas)),
                    isFalse,
                    reason:
                        '$id/${aspect.name}/$index: photo obscures editable copy',
                  );
                }
                if (id == -9443) {
                  expect(
                    _rect(photo, aspect.canvas).width /
                        _rect(photo, aspect.canvas).height,
                    closeTo(1.5, .001),
                    reason: 'The entire group portrait must remain visible',
                  );
                }
              }
            }
          }
          if (id == -9451) {
            final title = _layers(
              pages[1],
            ).singleWhere((l) => '${l['id']}'.endsWith('_3_title'));
            expect(title['text'], '짧은 인사가\n긴 이야기가 돼.');
            expect(
              (title['style'] as Map)['fontSize'] as num,
              greaterThanOrEqualTo(22),
            );
          }
          expect(
            _layers(variant['cover']).where((l) => l['type'] == 'image'),
            hasLength(1),
          );
          if (id == -9443) {
            final hero = _layers(
              variant['cover'],
            ).firstWhere((l) => l['type'] == 'image');
            final box = _rect(hero, aspect.canvas);
            expect(box.width / box.height, closeTo(1.5, .001));
            for (final text in _layers(
              variant['cover'],
            ).where((l) => l['type'] == 'text')) {
              expect(
                box.overlaps(_rect(text, aspect.canvas)),
                isFalse,
                reason: 'No title or colophon may cover a friend',
              );
            }
          }
        }
      },
    );
  }
}
