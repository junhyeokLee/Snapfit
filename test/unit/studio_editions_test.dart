import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/free_template_material_policy.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/point_shop/domain/premium_volume_registration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font
        in jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
  });

  for (final edition in StudioEdition.values) {
    for (final aspect in CollectionAspect.values) {
      test(
        '${edition.id}/${aspect.name}: complete editable, fitted and tier-safe book',
        () {
          final doc = edition.document(aspect);
          final pages = templateDocumentPages(doc);
          expect(pages.length, edition.innerPageCount + 1);
          expect(doc['chapters'], hasLength(edition.innerPageCount ~/ 2));
          final ids = <String>{}, arrangements = <String>{};
          final papers = <String>{}, photoAssets = <String>{};
          for (final entry in pages.indexed) {
            final page = entry.$2;
            if (entry.$1 > 0) {
              papers.add((page['layers'] as List).first['fillColor'] as String);
            }
            final layers = DataTemplateEngine.buildLayersFromJson(
              page,
              aspect.canvas,
            );
            expect(layers.length, (page['layers'] as List).length);
            for (final layer in layers) {
              expect(ids.add(layer.id), true, reason: layer.id);
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
              if (layer.imageUrl case final String url
                  when url.startsWith('asset:')) {
                expect(File(url.substring(6)).existsSync(), true, reason: url);
              }
              if (layer.type == LayerType.text) {
                final text = TextPainter(
                  textDirection: TextDirection.ltr,
                  text: TextSpan(text: layer.text, style: layer.textStyle),
                  strutStyle: StrutStyle.fromTextStyle(
                    layer.textStyle!,
                    forceStrutHeight: true,
                  ),
                )..layout(maxWidth: layer.width);
                expect(
                  text.height,
                  lessThanOrEqualTo(layer.height + .5),
                  reason: '${layer.id}: ${layer.text}',
                );
                final source = (page['layers'] as List).cast<Map>().singleWhere(
                  (raw) => raw['id'] == layer.id,
                );
                if (source['typographyRole'] == 'milestone-note') {
                  final material = layers.singleWhere(
                    (l) => l.id == source['materialContentOf'],
                  );
                  final paper =
                      material.position & Size(material.width, material.height);
                  expect(paper.contains(rect.topLeft), true, reason: layer.id);
                  expect(
                    rect.right,
                    lessThanOrEqualTo(paper.right + .1),
                    reason: layer.id,
                  );
                  expect(
                    rect.bottom,
                    lessThanOrEqualTo(paper.bottom + .1),
                    reason: layer.id,
                  );
                  expect(
                    text.computeLineMetrics().length,
                    lessThanOrEqualTo(layer.text!.split('\n').length),
                    reason:
                        'Do not break an authored note into orphaned syllables.',
                  );
                  expect(
                    layer.textStyle!.fontSize,
                    greaterThanOrEqualTo(aspect.canvas.shortestSide * .017),
                    reason: layer.id,
                  );
                }
                text.dispose();
              } else if (layer.type == LayerType.image) {
                photoAssets.add(layer.imageUrl!);
                final changed = layer.copyWith(
                  imageUrl: 'asset:assets/frame_preview/quiet_room.jpg',
                );
                final saved = LayerExportMapper.toJson(
                  changed,
                  canvasSize: aspect.canvas,
                );
                final restored = LayerExportMapper.fromJson(
                  saved,
                  canvasSize: aspect.canvas,
                );
                expect(restored.imageBackground, layer.imageBackground);
                expect(restored.position, layer.position);
                expect(
                  restored.imageUrl,
                  'asset:assets/frame_preview/quiet_room.jpg',
                );
              }
            }
            if (entry.$1.isOdd) {
              final pair = pages.skip(entry.$1).take(2);
              arrangements.add(
                jsonEncode([
                  for (final p in pair)
                    [
                      for (final l in (p['layers'] as List).cast<Map>().where(
                        (l) => l['type'] == 'image',
                      ))
                        [
                          for (final key in ['x', 'y', 'w', 'h'])
                            ((l[key] as num) * 50).round(),
                        ],
                    ],
                ]),
              );
            }
          }
          expect(arrangements, hasLength(edition.innerPageCount ~/ 2));
          final keys = templateVisualMaterialKeys(doc);
          if (edition.premium) {
            expect(papers.length, greaterThanOrEqualTo(10));
            if (edition == StudioEdition.cityAfterglow)
              expect(
                photoAssets.where(
                  (asset) =>
                      asset.contains('road_window') ||
                      asset.contains('city_skyline'),
                ),
                isEmpty,
                reason: 'Keep the evening-city photo sequence coherent.',
              );
            expect(
              keys
                  .where((key) => (pointShopLaunchPrices[key]?.points ?? 0) > 0)
                  .length,
              greaterThanOrEqualTo(8),
            );
            expect(isPendingTemplateProduct(edition.productKey), false);
            expect(pointShopLaunchPrices[edition.productKey]!.points, 2800);
          } else {
            expect(
              freeTemplateMaterialIssues(edition.catalogDocument()),
              isEmpty,
            );
            for (final key in keys) {
              expect(pointShopLaunchPrices[key]?.points, 0, reason: key);
            }
            expect(pointShopLaunchPrices[edition.productKey]!.points, 0);
          }
          final item = publishedCreationTemplates.singleWhere(
            (t) => t.id == edition.catalogId,
          );
          expect(pointShopTemplateKey(item), edition.productKey);
          expect(item.isPremium, edition.premium);
          expect(item.pageCount, edition.innerPageCount);
        },
      );
    }
  }

  test('new concepts have distinct layouts and separate paid material kits', () {
    final repeatedLayouts = <String>[];
    Set<String> paidKeys(StudioEdition edition) => templateVisualMaterialKeys(
      edition.document(CollectionAspect.square),
    ).where((key) => (pointShopLaunchPrices[key]?.points ?? 0) > 0).toSet();
    expect(
      paidKeys(
        StudioEdition.summerKeepsakeBox,
      ).intersection(paidKeys(StudioEdition.cityAfterglow)),
      isEmpty,
      reason: 'The summer concept must not reuse the night-city paid kit.',
    );
    for (final previous in [
      StudioEdition.cityAfterglow,
      StudioEdition.summerKeepsakeBox,
    ]) {
      expect(
        paidKeys(
          StudioEdition.companionJournal,
        ).intersection(paidKeys(previous)),
        isEmpty,
        reason: 'The companion magazine needs its own material kit.',
      );
    }
    for (final aspect in CollectionAspect.values) {
      final signatures = <String, String>{};
      for (final edition in StudioEdition.values) {
        final pages = templateDocumentPages(
          edition.document(aspect),
        ).skip(1).toList();
        for (var i = 0; i < pages.length; i += 2) {
          final signature = jsonEncode([
            for (final page in pages.skip(i).take(2))
              [
                for (final layer in (page['layers'] as List).cast<Map>().where(
                  (l) => l['type'] == 'image',
                ))
                  [
                    for (final key in ['x', 'y', 'w', 'h'])
                      ((layer[key] as num) * 50).round(),
                  ],
              ],
          ]);
          if ((edition.familyEdition ||
                  edition.petEdition ||
                  edition.milestoneEdition) &&
              signatures.containsKey(signature)) {
            repeatedLayouts.add(
              '${edition.id}/${aspect.name}/${i + 1}: repeats ${signatures[signature]}',
            );
          }
          signatures[signature] = '${edition.id}/${i + 1}';
        }
      }
      for (final edition in [
        StudioEdition.summerKeepsakeBox,
        StudioEdition.companionJournal,
        StudioEdition.velvetVowArchive,
        StudioEdition.littleExplorerBook,
      ]) {
        final usage = <String, int>{};
        for (final page in templateDocumentPages(
          edition.document(aspect),
        ).skip(1)) {
          for (final key in templateVisualMaterialKeys({'cover': page})) {
            if ((pointShopLaunchPrices[key]?.points ?? 0) > 0) {
              usage.update(key, (n) => n + 1, ifAbsent: () => 1);
            }
          }
          final raw = (page['layers'] as List).cast<Map>();
          final layers = DataTemplateEngine.buildLayersFromJson(
            page,
            aspect.canvas,
          );
          for (final layer in layers.where(
            (l) => raw.any(
              (r) =>
                  r['id'] == l.id &&
                  [
                    'family-caption',
                    'pet-caption',
                    'milestone-caption',
                  ].contains(r['typographyRole']),
            ),
          )) {
            expect(
              layer.textStyle!.fontSize,
              greaterThanOrEqualTo(aspect.canvas.shortestSide * .02),
            );
          }
        }
        for (final material in usage.entries) {
          expect(material.value, lessThanOrEqualTo(5), reason: material.key);
        }
      }
    }
    expect(repeatedLayouts, isEmpty);
  });
}
