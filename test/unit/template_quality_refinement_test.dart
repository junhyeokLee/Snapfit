import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/free_template_material_policy.dart';
import 'package:snap_fit/core/templates/published_premium_templates.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';

void main() {
  test('free editorial refinement remains free in every size', () {
    expect(FreeCollectionVolume.values, hasLength(32));
    for (final volume in FreeCollectionVolume.values) {
      for (final aspect in CollectionAspect.values) {
        final doc = volume.document(aspect);
        expect(doc['version'], 4);
        expect(doc['qualityRevision'], 'editorial-free-2026-10-07');
        expect(doc['accessTier'], 'free');
        expect(doc['innerPageCount'], 24);
        expect(doc['chapters'], hasLength(12));
        expect(freeTemplateMaterialIssues(doc), isEmpty, reason: volume.id);
        expect(pointShopLaunchPrices['template:${volume.id}']!.points, 0);
        final inner = doc['pages'] as List;
        expect(
          inner.any((p) => jsonEncode(p['layers']).contains('quality_photo_')),
          true,
          reason: '${volume.id} must include the new photo compositions',
        );
      }
    }
  });

  test(
    'paid refinement preserves identity, chapter navigation and pricing',
    () {
      final covers = <String>{};
      for (final volume in ConceptVolume.values) {
        final price = pointShopLaunchPrices['template:${volume.id}']!.points;
        expect(price, 1800);
        expect(
          publishedPremiumProductKey(conceptVolumeCatalogIds[volume]!),
          'template:${volume.id}',
        );
        for (final aspect in CollectionAspect.values) {
          final baseline = volume.document(aspect, refineQuality: false);
          final original = jsonEncode(baseline);
          final refined = volume.document(aspect);
          expect(jsonEncode(baseline), original);
          expect(refined['qualityRevision'], conceptQualityRevision);
          expect(refined['qualityReview'], 'pending-visual-approval');
          expect(refined['version'], volume.contentRevision + 1);
          for (final field in [
            'id',
            'collectionId',
            'editionId',
            'innerPageCount',
            'chapters',
            'accessTier',
            'releaseGates',
          ]) {
            expect(refined[field], baseline[field], reason: '$volume / $field');
          }
          final before = templateDocumentPages(baseline);
          final after = templateDocumentPages(refined);
          expect(after, hasLength(25));
          for (var i = 0; i < after.length; i++) {
            for (final field in ['name', 'role', 'side', 'spreadIndex']) {
              expect(after[i][field], before[i][field]);
            }
          }
          expect(after.first['layers'], isNot(before.first['layers']));
          expect(after[1]['layers'], isNot(before[1]['layers']));
          expect(after[2]['layers'], isNot(before[2]['layers']));
          expect(
            after
                .expand((p) => p['layers'] as List)
                .where(
                  (l) => l['type'] == 'image' && l['frame'] == 'studioOvalMat',
                ),
            isEmpty,
            reason: 'Oval photographs must not sit on a detached square mat',
          );
          expect(
            templateVisualMaterialKeys(refined),
            contains('sticker:${volume.signatureMaterial}'),
          );
          for (final key in templateVisualMaterialKeys(
            refined,
          ).difference(templateVisualMaterialKeys(baseline))) {
            expect(pointShopLaunchPrices.containsKey(key), true, reason: key);
          }
          if (aspect == CollectionAspect.square) {
            expect(covers.add(jsonEncode(after.first['layers'])), true);
          }
          expect(
            volume.document(aspect, refineQuality: false),
            baseline,
            reason: 'Refinement cannot mutate an archived edition',
          );
        }
      }
    },
  );
}
