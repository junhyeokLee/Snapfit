import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';
import 'package:snap_fit/core/templates/free_template_material_policy.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/shared/widgets/studio_material.dart';
import 'package:flutter/painting.dart';
import '../../tool/template_studio/export_price_application.dart';
import 'story_editions_test.dart' show loadStoryFonts;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadStoryFonts);

  test(
    'five group journals and five personal training books are discoverable and priced',
    () {
      final club = activityStoryEditions
          .where((e) => e.category == '동아리')
          .toList();
      final sport = activityStoryEditions
          .where((e) => e.category == '스포츠·도전')
          .toList();
      expect(club, hasLength(5));
      expect(sport, hasLength(5));
      expect(club.map((e) => e.activity).toSet(), {
        StoryActivity.running,
        StoryActivity.climbing,
        StoryActivity.golf,
        StoryActivity.badminton,
        StoryActivity.cycling,
      });
      expect(sport.map((e) => e.activity).toSet(), {
        StoryActivity.running,
        StoryActivity.climbing,
        StoryActivity.golf,
        StoryActivity.tennis,
        StoryActivity.swimming,
      });
      final rows = pointShopPriceApplicationRows();
      for (final e in activityStoryEditions) {
        final store = publishedCreationTemplates.singleWhere(
          (t) => t.id == e.catalogId,
        );
        expect(pointShopTemplateKey(store), e.productKey);
        expect(store.tags, containsAll(e.discoveryTags));
        expect(e.photoAssets.toSet(), hasLength(5));
        expect(e.notes.toSet(), hasLength(12));
        final product = rows.singleWhere(
          (r) => r['product_key'] == e.productKey,
        );
        expect(product['point_price'], 1800);
        expect(product['is_active'], true);
        for (final entry in e.materialKeys.indexed) {
          final material = rows.singleWhere(
            (r) => r['product_key'] == entry.$2,
          );
          expect(material['is_active'], true);
          expect(material['point_price'], [100, 200, 300][entry.$1]);
        }
        expect(e.photoFrames.toSet(), hasLength(2));
        for (final frame in e.photoFrames) {
          final key = 'frame:$frame';
          expect(freeTemplateMaterialProductKeys, contains(key));
          final product = rows.singleWhere((r) => r['product_key'] == key);
          expect(product['point_price'], 0);
          expect(product['is_active'], true);
        }
        for (final path in e.photoAssets) expect(File(path).existsSync(), true);
      }
    },
  );

  for (final aspect in CollectionAspect.printable) {
    test(
      '${aspect.name}: group members, editable records and personal training remain distinct',
      () {
        final coverSignatures = <String>{};
        for (final e in activityStoryEditions) {
          final d = storyEditionDocument(e, aspect);
          final pages = templateDocumentPages(d);
          final club = e.category == '동아리';
          expect(pages, hasLength(25));
          expect(d['activity'], e.activity!.name);
          expect(d['publicationStatus'], 'bundled');
          expect(
            d['activityFormat'],
            club ? 'group-journal' : 'personal-training',
          );
          expect(templateVisualMaterialKeys(d), containsAll(e.materialKeys));
          expect(
            templateVisualMaterialKeys(d),
            e.includedMaterialKeys.toSet(),
            reason: 'Declare every applied frame and material accurately',
          );
          expect(d['includedMaterialKeys'], e.includedMaterialKeys);
          coverSignatures.add(
            jsonEncode(
              (pages.first['layers'] as List)
                  .map((l) => [l['type'], l['x'], l['y'], l['w'], l['h']])
                  .toList(),
            ),
          );
          final roster = pages
              .where((p) => p['role'] == 'story-2')
              .expand((p) => (p['layers'] as List).cast<Map>())
              .toList();
          expect(
            roster.where((l) => l['text'] == '이름을 입력해 주세요'),
            hasLength(e.memberSlots),
          );
          if (club) expect(e.memberSlots, inInclusiveRange(4, 6));
          final all = pages.expand((p) => (p['layers'] as List).cast<Map>());
          expect(all.where((l) => l['text'] == '날짜 · 장소'), hasLength(4));
          final photos = all.where((l) => l['type'] == 'image').toList();
          final mounted = photos.where((l) => l['frame'] != 'none').toList();
          expect(mounted.map((l) => l['frame']).toSet(), e.photoFrames.toSet());
          expect(mounted.length, greaterThanOrEqualTo(4));
          expect(
            photos.where((l) => l['frame'] == 'none').length,
            greaterThanOrEqualTo(4),
            reason: 'Keep large photographs and framed details in balance',
          );
          for (final l in photos.where(
            (l) => l['activityPhotoComposition'] != null,
          )) {
            final size = Size(
              (l['w'] as num) * aspect.canvas.width,
              (l['h'] as num) * aspect.canvas.height,
            );
            final insets = StudioMaterial.photoInsets(
              l['frame'] as String,
              size,
            );
            expect(
              (size.width - insets.horizontal) /
                  (size.height - insets.vertical),
              closeTo(1.5, .000001),
              reason: '${e.id}: preserve the whole photograph inside its mount',
            );
          }
          final paperPage = pages.singleWhere(
            (p) => p['role'] == 'story-6' && p['side'] == 'right',
          );
          final paperLayers = (paperPage['layers'] as List).cast<Map>();
          final paper = paperLayers.singleWhere((l) => l['style'] == e.paperId);
          final picture = paperLayers.singleWhere((l) => l['type'] == 'image');
          expect((paper['z'] as num), lessThan(picture['z'] as num));
          Rect bounds(Map l) => Rect.fromLTWH(
            (l['x'] as num).toDouble(),
            (l['y'] as num).toDouble(),
            (l['w'] as num).toDouble(),
            (l['h'] as num).toDouble(),
          );
          expect(bounds(paper).contains(bounds(picture).topLeft), true);
          expect(bounds(paper).contains(bounds(picture).bottomRight), true);
          for (final l in all) {
            if (l['type'] == 'text' || l['type'] == 'image')
              expect(l['templateContent'], true);
            if (club && l['type'] == 'image') {
              expect(l['activityPhotoComposition'], 'whole-source-3:2');
            }
          }
          if (club && aspect.isLandscape) {
            final group = (pages.first['layers'] as List).firstWhere(
              (l) => l['type'] == 'image',
            );
            expect(
              group['w'],
              greaterThanOrEqualTo(.59),
              reason: 'Do not shrink a team to a thumbnail in wide books',
            );
          }
        }
        expect(coverSignatures, hasLength(10));
      },
    );
  }
}
