import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/free_template_material_policy.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/premium_volume_registration.dart';
import 'package:snap_fit/features/store/data/api/material_provider.dart';
import '../../tool/template_studio/export_price_application.dart';
import 'story_editions_test.dart' show loadStoryFonts;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadStoryFonts);

  test(
    'club category delivers five free and five paid identities with matching material tiers',
    () {
      expect(clubStoryEditions, hasLength(10));
      expect(clubStoryEditions.where((e) => e.isPremium), hasLength(5));
      expect(clubStoryEditions.where((e) => !e.isPremium), hasLength(5));
      final rows = pointShopPriceApplicationRows();
      for (final e in clubStoryEditions) {
        expect(e.category, '동아리');
        expect(
          (e.isPremium ? publishedPremiumTemplates : bundledCreationTemplates)
              .where((t) => t.id == e.catalogId),
          hasLength(1),
        );
        for (final key in [e.productKey, ...e.materialKeys]) {
          expect(pointShopRequiresFreePrice(key), !e.isPremium, reason: key);
          final row = rows.singleWhere((r) => r['product_key'] == key);
          expect(
            row['is_active'],
            true,
            reason:
                'All current club kits are approved; their tiers stay distinct',
          );
          expect(row['point_price'], e.isPremium ? greaterThan(0) : 0);
        }
        for (final key in e.materialKeys) {
          expect(
            bundledMaterials.singleWhere((m) => m.productKey == key).isPremium,
            e.isPremium,
          );
        }
        expect(isPendingTemplateProduct(e.productKey), false);
      }
    },
  );

  for (final aspect in CollectionAspect.printable) {
    test(
      '${aspect.name}: distinct covers and usable editable club activity pages',
      () {
        final coverCompositions = <String>{};
        for (final e in clubStoryEditions) {
          final document = storyEditionDocument(e, aspect);
          final pages = templateDocumentPages(document);
          expect(pages, hasLength(25));
          expect(document['qualityRevision'], clubStoryEditionRevision);
          if (!e.isPremium)
            expect(freeTemplateMaterialIssues(document), isEmpty);
          if (e.coverStyle == 18 ||
              (e.coverStyle == 10 && aspect == CollectionAspect.portrait)) {
            final photo = DataTemplateEngine.buildLayersFromJson(
              pages.first,
              aspect.canvas,
            ).firstWhere((l) => l.type == LayerType.image);
            expect(
              photo.width / photo.height,
              closeTo(1, .00001),
              reason:
                  'Keep every member in these edge-to-edge group photographs',
            );
          }
          coverCompositions.add(
            jsonEncode([
              for (final layer in (pages.first['layers'] as List).cast<Map>())
                [layer['type'], layer['x'], layer['y'], layer['w'], layer['h']],
            ]),
          );
          if (aspect.isLandscape &&
              const {11, 13, 17, 18}.contains(e.coverStyle)) {
            final mainPhoto = DataTemplateEngine.buildLayersFromJson(
              pages.first,
              aspect.canvas,
            ).firstWhere((l) => l.type == LayerType.image);
            expect(
              mainPhoto.width / mainPhoto.height,
              lessThan(1.2),
              reason:
                  'The wide jacket must retain the group, instruments and movement',
            );
          }
          final people = pages.where((p) => p['role'] == 'story-2');
          final peopleText = people
              .expand((p) => (p['layers'] as List).cast<Map>())
              .where((l) => l['type'] == 'text')
              .map((l) => l['text']);
          expect(peopleText.where((t) => t == '이름을 입력해 주세요'), hasLength(3));
          final schedule = pages.where((p) => p['role'] == 'story-8');
          final fields = schedule
              .expand((p) => (p['layers'] as List).cast<Map>())
              .where((l) => l['text'] == '날짜 · 장소')
              .toList();
          expect(fields, hasLength(e.isPremium ? 4 : 3));
          expect(
            fields.every((l) => l['templateContent'] == true),
            true,
            reason: 'Empty date labels and samples must not complete an album',
          );
          final credits = pages
              .where((p) => p['role'] == 'story-10')
              .expand((p) => (p['layers'] as List).cast<Map>())
              .where((l) => l['type'] == 'text');
          expect(
            credits.any(
              (l) => (l['text'] as String).contains(
                e.isPremium ? '도움을 준 사람들' : '사진 설명',
              ),
            ),
            true,
          );
        }
        expect(
          coverCompositions,
          hasLength(10),
          reason: 'Do not simply recolor one club cover',
        );
      },
    );
  }
}
