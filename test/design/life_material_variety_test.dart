import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';

void main() {
  test(
    'editorial redesign preserves covers and chapters but rebuilds inner layouts',
    () {
      for (final volume in lifeConceptVolumes) {
        for (final aspect in CollectionAspect.values) {
          final baseline =
              jsonDecode(
                    File(
                      'tool/template_studio/archives/life-material-variety/${volume.id}/${aspect.name}.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>;
          final current = volume.document(aspect);
          expect(current['cover'], baseline['cover']);
          expect(current['chapters'], baseline['chapters']);
          final before = templateDocumentPages(baseline);
          final after = templateDocumentPages(current);
          expect(after.length, before.length);
          expect(current['version'], volume.contentRevision);
          var changedPhotoLayouts = 0;
          for (var i = 0; i < before.length; i++) {
            for (final key in ['name', 'role', 'side', 'spreadIndex']) {
              expect(after[i][key], before[i][key]);
            }
            final oldLayers = before[i]['layers'] as List;
            final newLayers = after[i]['layers'] as List;
            String photoGeometry(List layers) => jsonEncode([
              for (final l in layers.where((l) => l['type'] == 'image'))
                [l['x'], l['y'], l['w'], l['h'], l['frame']],
            ]);
            if (i > 0 && photoGeometry(newLayers) != photoGeometry(oldLayers)) {
              changedPhotoLayouts++;
            }
            for (final id in after[i]['photoOverlayTextIds'] ?? <String>[]) {
              final n = newLayers.indexWhere((l) => l['id'] == id);
              expect(n, greaterThan(0));
              expect(newLayers[n]['type'], 'text');
              final backing = newLayers[n - 1];
              expect(backing['type'], 'decoration');
              expect(backing['fillColor'], isNotNull);
              expect(backing['opacity'] ?? 1, 1);
            }
          }
          expect(
            changedPhotoLayouts,
            greaterThanOrEqualTo(18),
            reason: volume.id,
          );
        }
      }
    },
  );

  test(
    'decorations are curated, repeat at most twice, and remain available to edit',
    () {
      for (final volume in lifeConceptVolumes) {
        final counts = <String, int>{};
        for (final page in templateDocumentPages(
          volume.document(CollectionAspect.square),
        )) {
          for (final layer in page['layers'] as List) {
            if (layer['type'] == 'image') continue;
            final style = layer['style'];
            final asset = (layer['imageUrl'] as String?)?.replaceFirst(
              'asset:',
              '',
            );
            final spec =
                studioDecorationById(style is String ? style : '') ??
                studioDecorationByAsset(asset);
            if (spec == null) continue;
            counts.update(spec.id, (n) => n + 1, ifAbsent: () => 1);
          }
        }
        expect(counts[volume.signatureMaterial], 2, reason: volume.id);
        for (final entry in counts.entries) {
          expect(
            entry.value,
            lessThanOrEqualTo(2),
            reason: '${volume.id}: ${entry.key} repeated',
          );
        }
      }
      expect(lifeVarietyCutouts.length + lifeVarietyPapers.length, 12);
      for (final spec in [...lifeVarietyCutouts, ...lifeVarietyPapers]) {
        expect(studioDecorationById(spec.id), spec);
      }
    },
  );

  test('shared-seasons refinement leaves the other life collections intact', () {
    for (final volume in lifeConceptVolumes.where(
      (v) => v != ConceptVolume.sharedSeasons,
    )) {
      for (final aspect in CollectionAspect.values) {
        final baseline = jsonDecode(
          File(
            'tool/template_studio/archives/life-editorial-2/${volume.id}/${aspect.name}.json',
          ).readAsStringSync(),
        );
        baseline['accessTier'] = 'premium';
        baseline['releaseGates']['price'] = 'launch-price-set-sale-held';
        expect(volume.document(aspect), baseline);
      }
    }
  });

  test('shared-seasons removes floating objects and opaque photo labels', () {
    for (final aspect in CollectionAspect.values) {
      final pages = templateDocumentPages(
        ConceptVolume.sharedSeasons.document(aspect),
      );
      final baseline =
          jsonDecode(
                File(
                  'tool/template_studio/archives/life-editorial-2/shared-seasons/${aspect.name}.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(pages.first, templateDocumentPages(baseline).first);
      expect(ConceptVolume.sharedSeasons.contentRevision, 3);
      final opening = pages[1]['layers'] as List;
      final branch = opening.singleWhere(
        (l) => l['imageUrl'] == 'asset:assets/sticker/studio/olive_press.png',
      );
      final caption = opening.singleWhere(
        (l) => l['text'] == '너와 나, 그리고 우리의 매일.',
      );
      expect(
        (branch['y'] as num) + (branch['h'] as num),
        lessThan((caption['y'] as num) - .04),
      );
      for (final page in pages.skip(1)) {
        expect(page['photoOverlayTextIds'], isNull);
        final layers = page['layers'] as List;
        for (final forbidden in [
          'life_house_key.png',
          'life_slippers.png',
          'life_vase.png',
          'material_clip.png',
        ]) {
          expect(jsonEncode(layers), isNot(contains(forbidden)));
        }
        expect(layers.where((l) => l['type'] == 'text'), isNotEmpty);
      }
    }
  });
}
