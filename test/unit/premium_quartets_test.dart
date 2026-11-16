import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/premium_quartet_frame_catalog.dart';
import 'package:snap_fit/core/templates/template_catalog_categories.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_catalog_release.dart';
import 'package:snap_fit/shared/widgets/premium_quartet_frame.dart';
import 'package:snap_fit/shared/widgets/premium_quartet_stationery.dart';
import 'package:snap_fit/shared/widgets/studio_material.dart';
import '../../tool/template_studio/export_price_application.dart';

Rect _rawBounds(Map raw) => Rect.fromLTWH(
  (raw['x'] as num).toDouble(),
  (raw['y'] as num).toDouble(),
  (raw['w'] as num).toDouble(),
  (raw['h'] as num).toDouble(),
);

void _pathContainsRect(Path outer, Rect inner, String reason) {
  for (var n = 0; n <= 32; n++) {
    final x = inner.left + inner.width * n / 32;
    final y = inner.top + inner.height * n / 32;
    for (final point in [
      Offset(x, inner.top),
      Offset(x, inner.bottom),
      Offset(inner.left, y),
      Offset(inner.right, y),
    ]) {
      expect(outer.contains(point), isTrue, reason: '$reason/$point');
    }
  }
}

void _withinCanvas(Rect bounds, Size size, String reason) {
  expect(bounds.left, greaterThanOrEqualTo(-.1), reason: reason);
  expect(bounds.top, greaterThanOrEqualTo(-.1), reason: reason);
  expect(bounds.right, lessThanOrEqualTo(size.width + .1), reason: reason);
  expect(bounds.bottom, lessThanOrEqualTo(size.height + .1), reason: reason);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final needed = {
      'NotoSans',
      'BookMyungjo',
      'Poppins',
      ...premiumQuartetSpecsById.values.expand(
        (s) => [s.font, s.secondaryFont],
      ),
    };
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final row in manifest.cast<Map>()) {
      if (!needed.contains(row['family'])) continue;
      final loader = FontLoader(row['family'] as String);
      for (final face in (row['fonts'] as List).cast<Map>()) {
        loader.addFont(rootBundle.load(face['asset'] as String));
      }
      await loader.load();
      needed.remove(row['family']);
    }
    expect(needed, isEmpty, reason: 'Designed typefaces must be bundled.');
  });

  test(
    '44 independent paid books add four concepts to each existing topic',
    () {
      expect(premiumQuartetEditions, hasLength(44));
      expect(premiumQuartetSpecsById, hasLength(44));
      expect(premiumQuartetEditions.map((e) => e.catalogId).toSet(), {
        for (var id = -9801; id >= -9844; id--) id,
      });
      expect(premiumQuartetSpecsById.values.map((s) => s.style).toSet(), {
        for (var n = 0; n < 44; n++) n,
      });
      for (final topic in templateTopicOrder) {
        expect(
          premiumQuartetEditions.where((e) => e.category == topic),
          hasLength(4),
        );
      }
      final oldPhotos = storyEditions
          .where((e) => e.qualityRevision != premiumQuartetRevision)
          .expand((e) => e.photoAssets)
          .toSet();
      final photos = <String>{}, kits = <String>{}, sequences = <String>{};
      for (final book in premiumQuartetEditions) {
        final spec = premiumQuartetSpecsById[book.id]!;
        expect(book.isPremium, isTrue);
        expect(book.exclusivePhotography, isTrue);
        expect(book.innerPages, 32);
        expect(book.chapters, hasLength(16));
        expect(book.notes, hasLength(16));
        expect(book.chapters.toSet(), hasLength(16));
        expect(book.notes.toSet(), hasLength(16));
        expect(book.spreadOrder, hasLength(16));
        expect(book.spreadOrder.toSet(), hasLength(16));
        expect(
          sequences.add(jsonEncode(book.spreadOrder)),
          isTrue,
          reason: book.id,
        );
        expect(book.spreadOrder, containsAll([3, 9, 19, 29, 31]));
        expect(spec.cards, hasLength(4));
        expect(spec.cards.map((c) => c.first).toSet(), hasLength(4));
        expect(
          PremiumQuartetStationery.supportedMotifs,
          contains(spec.motifCode),
        );
        expect(spec.paperKinds.toSet(), hasLength(2));
        expect(book.photoFrames, hasLength(2));
        expect(book.photoAssets, hasLength(6));
        expect(
          book.photoAssets.toSet().intersection(oldPhotos),
          isEmpty,
          reason: book.id,
        );
        for (final photo in book.photoAssets)
          expect(photos.add(photo), isTrue, reason: photo);
        expect(book.includedMaterialKeys.toSet(), hasLength(8));
        for (final key in book.includedMaterialKeys)
          expect(kits.add(key), isTrue, reason: key);
        expect(pointShopLaunchPrices[book.productKey]?.points, 2500);
      }
      expect(photos, hasLength(264));
      expect(kits, hasLength(352));
      expect(
        premiumQuartetSpecsById.values.map((s) => s.motifCode).toSet(),
        hasLength(44),
      );
    },
  );

  test(
    'native mounts and paper cuts preserve every photo and record perimeter',
    () {
      expect(premiumQuartetFrames, hasLength(88));
      expect(premiumQuartetFrames.map((f) => f.kind).toSet(), {
        for (var n = 0; n < 16; n++) n,
      });
      for (final size in const [
        Size(48, 48),
        Size(500, 500),
        Size(600, 400),
        Size(400, 600),
        Size(200, 1000),
      ]) {
        for (final frame in premiumQuartetFrames) {
          final aperture = PremiumQuartetFrame.insets(
            frame.id,
            size,
          ).deflateRect(Offset.zero & size);
          expect(aperture.width, greaterThan(0), reason: frame.id);
          expect(aperture.height, greaterThan(0), reason: frame.id);
          final outer = PremiumQuartetFrame.outer(frame.id, size);
          _pathContainsRect(outer, aperture, '${frame.id}/$size');
          _withinCanvas(outer.getBounds(), size, '${frame.id}/$size');
        }
        for (var kind = 0; kind < 16; kind++) {
          final outer = PremiumQuartetStationery.paperOuter(kind, size);
          _pathContainsRect(
            outer,
            PremiumQuartetStationery.recordTextBounds(size),
            'paper$kind/$size',
          );
          _withinCanvas(outer.getBounds(), size, 'paper$kind/$size');
        }
      }
    },
  );

  test('all book and eight kit prices are active release rows', () {
    final rows = {
      for (final row in pointShopPriceApplicationRows())
        row['product_key']: row,
    };
    for (final book in premiumQuartetEditions) {
      for (final key in [book.productKey, ...book.includedMaterialKeys]) {
        expect(rows[key], isNotNull, reason: key);
        expect(rows[key]!['point_price'], greaterThan(0), reason: key);
        expect(rows[key]!['is_active'], isTrue, reason: key);
        expect(ownerApprovedCatalogProductKeys, contains(key));
      }
    }
  });

  for (final book in premiumQuartetEditions) {
    for (final aspect in CollectionAspect.printable) {
      test(
        '${book.id}/${aspect.name}: all eight materials, natural type and whole photos',
        () {
          final document = storyEditionDocument(book, aspect);
          final pages = templateDocumentPages(document);
          expect(pages, hasLength(33));
          expect(document['chapters'], hasLength(16));
          expect(document['catalogPublishable'], isTrue);
          expect(document['innerPageCount'], 32);
          expect(
            templateVisualMaterialKeys(document),
            book.includedMaterialKeys.toSet(),
          );
          final cardRoles = <String>{},
              usedPhotos = <String>{},
              ids = <String>{};
          for (final page in pages) {
            final rawLayers = (page['layers'] as List).cast<Map>();
            final paperRects = <Rect>[
              for (final raw in rawLayers)
                if (raw['style'] == '${book.id}-paper' ||
                    raw['style'] == '${book.id}-vellum')
                  _rawBounds(raw),
            ];
            for (final raw in rawLayers) {
              if (raw['premiumCardRole'] case final String role)
                cardRoles.add(role);
              if (raw['premiumTextRegion'] case final List region) {
                final area = Rect.fromLTWH(
                  (region[0] as num).toDouble(),
                  (region[1] as num).toDouble(),
                  (region[2] as num).toDouble(),
                  (region[3] as num).toDouble(),
                );
                final actual = _rawBounds(raw);
                expect(
                  area.inflate(.002).contains(actual.topLeft),
                  isTrue,
                  reason: '${book.id}/${raw['text']}',
                );
                expect(
                  area.inflate(.002).contains(actual.bottomRight),
                  isTrue,
                  reason: '${book.id}/${raw['text']}',
                );
                for (final paper in paperRects.where(actual.overlaps)) {
                  final safe = Rect.fromLTWH(
                    paper.left + paper.width * .14,
                    paper.top + paper.height * .18,
                    paper.width * .72,
                    paper.height * .62,
                  ).inflate(.002);
                  expect(
                    safe.contains(actual.topLeft),
                    isTrue,
                    reason:
                        '${book.id}/${raw['text']} outside paper writing area',
                  );
                  expect(
                    safe.contains(actual.bottomRight),
                    isTrue,
                    reason:
                        '${book.id}/${raw['text']} outside paper writing area',
                  );
                }
              }
              if (raw['type'] != 'image') continue;
              final asset = raw['imageUrl'] ?? raw['asset'];
              if (asset is String)
                usedPhotos.add(asset.replaceFirst('asset:', ''));
              final size = Size(
                (raw['w'] as num).toDouble() * aspect.canvas.width,
                (raw['h'] as num).toDouble() * aspect.canvas.height,
              );
              final aperture = StudioMaterial.photoInsets(
                raw['frame'] as String? ?? 'none',
                size,
              ).deflateRect(Offset.zero & size);
              expect(
                aperture.width / aperture.height,
                closeTo(1.5, .00001),
                reason: '${book.id}/${raw['frame']}',
              );
              expect(raw['imageOffsetRatio'], isNull);
              expect(raw['premiumFullSourcePhoto'], isTrue);
            }
            final layers = DataTemplateEngine.buildLayersFromJson(
              page,
              aspect.canvas,
            );
            for (final layer in layers) {
              expect(ids.add(layer.id), isTrue, reason: layer.id);
              _withinCanvas(
                layer.position & Size(layer.width, layer.height),
                aspect.canvas,
                layer.id,
              );
              if (layer.type != LayerType.text) continue;
              final painter = TextPainter(
                text: TextSpan(text: layer.text, style: layer.textStyle),
                textDirection: TextDirection.ltr,
                textAlign: layer.textAlign ?? TextAlign.left,
              )..layout(maxWidth: layer.width);
              expect(
                painter.height,
                lessThanOrEqualTo(layer.height + 1.25),
                reason: '${book.id}/${layer.text}',
              );
              expect(
                painter.computeLineMetrics().every(
                  (line) => line.width <= layer.width + 1.25,
                ),
                isTrue,
                reason: '${book.id}/${layer.text}',
              );
              final raw = rawLayers
                  .where((r) => r['id'] == layer.id)
                  .firstOrNull;
              final metrics = painter.computeLineMetrics();
              if (raw?['editorialTextRole'] == 'body' &&
                  raw?['premiumMaxLines'] == null &&
                  !(layer.text ?? '').contains('\n') &&
                  metrics.length > 1) {
                expect(
                  metrics.last.width,
                  greaterThanOrEqualTo(layer.textStyle!.fontSize! * 1.99),
                  reason:
                      '${book.id}/${layer.text}: no isolated trailing glyph',
                );
              }
              painter.dispose();
            }
          }
          expect(cardRoles, {
            'observation',
            'conditions',
            'reflection',
            'next-plan',
          });
          expect(usedPhotos, containsAll(book.photoAssets));
        },
      );
    }
  }
}
