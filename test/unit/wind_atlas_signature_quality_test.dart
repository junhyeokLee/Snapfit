import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/free_template_material_policy.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';

const _signaturePageIndices = {0, 3, 4, 7, 8, 13, 14};
Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}

String _digest(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(_canonical(value)))).toString();
Map<String, String> _fingerprints(CollectionAspect aspect) {
  final pages = templateDocumentPages(buildWindAtlas(aspect));
  return {
    'protectedInner': _digest([
      for (var i = 1; i < pages.length; i++)
        if (!_signaturePageIndices.contains(i)) pages[i],
    ]),
    'botanical': _digest(
      buildWindAtlas(aspect, cover: WindAtlasCover.botanical)['cover'],
    ),
    'photographic': _digest(
      buildWindAtlas(aspect, cover: WindAtlasCover.photographic)['cover'],
    ),
    'originalSignature': _digest([
      for (final i in _signaturePageIndices) pages[i],
    ]),
  };
}

// Recorded from the shipping factory before the signature changes. These are
// document hashes, not artwork snapshots; no image/document export is involved.
const _originalFingerprints = {
  'portrait': {
    'protectedInner':
        '739adffadb5dd48cd44125ea714857ee67b086601167bda5f1fa95d28d3611ee',
    'botanical':
        'f2fa324394b01e090ae63e62a1316971a5dc2ef9ad62b5aa8d37b1d6baf8ae31',
    'photographic':
        'd7d88d45504c05bbc3687ac727e43b083892c25681a325a3ff293d5d0698d5ce',
    'originalSignature':
        '09c6eaba0321f22961f510bb34884f7b22e85e781a500c2e11e77568462e813c',
  },
  'square': {
    'protectedInner':
        '3347d1f3ae27899afe677bef7361a2009d21a6a8fc1be20b01be5b6133fb4700',
    'botanical':
        'e7204607487f642c1fbb806ae3ff447c6455b55631663ad94e50d3f58a7a1177',
    'photographic':
        'b8130316a88390e7cbfecc70fa62df60d16985399833852d86228c3c62128c1a',
    'originalSignature':
        '3b771f3f1284c47f36ce3cec662306086c67d4d78467175757a2932fad426a5c',
  },
  'landscape': {
    'protectedInner':
        'f7f37ec4ba1c6930bbfd386468a53748b7ef94c2bbf7d41912dfd8d72a9c677a',
    'botanical':
        '948af834d9bab0e6c37f31fa0072b7dc35739dd40f4dc1483a78ec454f8c97c3',
    'photographic':
        '3784e0da5e4b34cdc3bd8e8d5ceee78cd1ef2d11e897f861c2b175aa5f03c770',
    'originalSignature':
        'bc3a11d2a1e2ec4398fb0a14ee8ed45063b0a4914ac93af7933ed3502c9259df',
  },
};

List<List<LayerModel>> _layers(
  CollectionAspect aspect, {
  EditorialCopy copy = windAtlasCopy,
  WindAtlasCover cover = WindAtlasCover.illustrated,
}) => [
  for (final page in templateDocumentPages(
    buildWindAtlas(aspect, cover: cover, copy: copy),
  ))
    DataTemplateEngine.buildLayersFromJson(page, aspect.canvas),
];

List<String> _textIssues(List<List<LayerModel>> pages) {
  final issues = <String>[];
  for (final layer
      in pages
          .expand((page) => page)
          .where((layer) => layer.type == LayerType.text)) {
    final painter = TextPainter(
      text: TextSpan(text: layer.text, style: layer.textStyle),
      textDirection: TextDirection.ltr,
      strutStyle: StrutStyle.fromTextStyle(
        layer.textStyle!,
        forceStrutHeight: true,
      ),
    )..layout(maxWidth: layer.width);
    if (painter.height > layer.height + .5 ||
        painter.computeLineMetrics().any(
          (line) => line.width > layer.width + .5,
        )) {
      issues.add('${layer.id}: text exceeds its editable box');
    }
    painter.dispose();
  }
  return issues;
}

Rect _paintBounds(LayerModel layer) {
  final angle = layer.rotation * math.pi / 180;
  final width =
      layer.width * math.cos(angle).abs() +
      layer.height * math.sin(angle).abs();
  final height =
      layer.width * math.sin(angle).abs() +
      layer.height * math.cos(angle).abs();
  return Rect.fromCenter(
    center: layer.position + Offset(layer.width / 2, layer.height / 2),
    width: width,
    height: height,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (kIsWeb)
      return; // Web verifies structure; native uses bundled font metrics.
    for (final raw
        in jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List) {
      final loader = FontLoader(raw['family'] as String);
      for (final font in raw['fonts'] as List) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });

  test(
    'signature remains the same free 32-page product in every published variant',
    () {
      final template = bundledCreationTemplates.singleWhere(
        (item) => item.id == windAtlasBundledId,
      );
      final collection = authoredCollections.singleWhere(
        (item) => item.id == windAtlasId,
      );
      expect(template.id, -9304);
      expect(template.isPremium, isFalse);
      expect(template.pageCount, 32);
      expect(pointShopTemplateKey(template), 'template:wind-atlas');
      expect(pointShopRequiresFreePrice('template:wind-atlas'), isTrue);
      expect(pointShopLaunchPrices['template:wind-atlas']!.points, 0);
      final catalog = jsonDecode(template.templateJson!) as Map;
      expect(
        (catalog['variants'] as Map).keys,
        unorderedEquals(CollectionAspect.values.map((aspect) => aspect.name)),
      );
      for (final aspect in CollectionAspect.values) {
        final document = buildWindAtlas(aspect);
        expect(document['id'], 'snapfit_premium_wind_atlas_${aspect.name}');
        expect(document['collectionId'], 'wind-atlas');
        expect(document['accessTier'], 'free');
        expect(document['publicationStatus'], 'bundled');
        expect(document['aiGenerated'], isFalse);
        expect(document['innerPageCount'], 32);
        expect(document['pages'], hasLength(32));
        expect(templateDocumentPages(document), hasLength(33));
        expect(collection.chapters, windAtlasSpreads);
        expect(catalog['variants'][aspect.name], collection.document(aspect));
        final chapters = (document['chapters'] as List).cast<Map>();
        for (final chapter in chapters.indexed) {
          expect(chapter.$2['title'], windAtlasSpreads[chapter.$1]);
          expect(chapter.$2['from'], chapter.$1 * 2 + 1);
          expect(chapter.$2['to'], chapter.$1 * 2 + 2);
        }
      }
    },
  );

  test('journal keeps source paragraphs and wraps complete Korean words', () {
    for (final aspect in CollectionAspect.values) {
      final raw = templateDocumentPages(buildWindAtlas(aspect))[14];
      final journal = (raw['layers'] as List).cast<Map>().singleWhere(
        (layer) => (layer['id'] as String).endsWith('_archive_journal'),
      );
      final text = journal['text'] as String;
      expect(journal['editorialSourceText'], windAtlasCopy.note);
      expect(
        text.split(RegExp(r'\s+')),
        windAtlasCopy.note.split(RegExp(r'\s+')),
        reason: 'Layout breaks must preserve every word and its order.',
      );
      expect(
        '\n\n'.allMatches(text).length,
        '\n\n'.allMatches(windAtlasCopy.note).length,
      );
      final layer = DataTemplateEngine.buildLayersFromJson(
        raw,
        aspect.canvas,
      ).singleWhere((layer) => layer.id.endsWith('_archive_journal'));
      for (final line in text.split('\n').where((line) => line.isNotEmpty)) {
        expect(line.runes.length, greaterThan(2), reason: line);
        final painter = TextPainter(
          text: TextSpan(text: line, style: layer.textStyle),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: layer.width);
        expect(painter.computeLineMetrics(), hasLength(1), reason: line);
        painter.dispose();
      }
    }
  });

  for (final aspect in CollectionAspect.values) {
    test(
      '${aspect.name}: unchanged 26 pages and two alternate covers retain their original document content',
      () {
        final current = _fingerprints(aspect);
        final original = _originalFingerprints[aspect.name]!;
        for (final key in ['protectedInner', 'botanical', 'photographic']) {
          expect(
            current[key],
            original[key],
            reason: '${aspect.name}/$key changed outside the signature scope',
          );
        }
        expect(
          current['originalSignature'],
          isNot(original['originalSignature']),
          reason: 'The selected artwork must contain the new signature design.',
        );
        final pages = templateDocumentPages(buildWindAtlas(aspect));
        expect([
          for (var i = 1; i < pages.length; i++)
            if (!_signaturePageIndices.contains(i)) i,
        ], hasLength(26));
      },
    );

    test(
      '${aspect.name}: every cover and page remains fitted, editable and safe to save',
      () {
        for (final cover in WindAtlasCover.values) {
          final document = buildWindAtlas(aspect, cover: cover);
          final pages = _layers(aspect, cover: cover);
          expect(freeTemplateMaterialIssues(document), isEmpty);
          expect(
            _textIssues(pages),
            isEmpty,
            reason: '${aspect.name}/${cover.name}',
          );
          final seen = <String>{};
          for (final (index, page) in pages.indexed) {
            final cleared = AlbumCreationTemplate.preparePages(
              [page],
              sourceCanvas: aspect.canvas,
              cover: aspect.cover,
            ).single;
            for (final (layerIndex, layer) in page.indexed) {
              expect(seen.add(layer.id), isTrue, reason: layer.id);
              final rect = layer.position & Size(layer.width, layer.height);
              expect(rect.isFinite, isTrue, reason: layer.id);
              expect(rect.width, greaterThan(0), reason: layer.id);
              expect(rect.height, greaterThan(0), reason: layer.id);
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
              if (_signaturePageIndices.contains(index) &&
                  (layer.type == LayerType.image ||
                      layer.type == LayerType.text)) {
                final painted = _paintBounds(layer);
                expect(
                  painted.left,
                  greaterThanOrEqualTo(-.1),
                  reason: layer.id,
                );
                expect(
                  painted.top,
                  greaterThanOrEqualTo(-.1),
                  reason: layer.id,
                );
                expect(
                  painted.right,
                  lessThanOrEqualTo(aspect.canvas.width + .1),
                  reason: layer.id,
                );
                expect(
                  painted.bottom,
                  lessThanOrEqualTo(aspect.canvas.height + .1),
                  reason: layer.id,
                );
              }
              final saved = LayerExportMapper.fromJson(
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
              expect(saved.id, layer.id);
              expect(saved.type, layer.type);
              expect(saved.imageBackground, layer.imageBackground);
              expect(saved.text, layer.text);
              expect(saved.position.dx, closeTo(layer.position.dx, .000001));
              expect(saved.position.dy, closeTo(layer.position.dy, .000001));
              expect(saved.width, closeTo(layer.width, .000001));
              expect(saved.height, closeTo(layer.height, .000001));
              expect(saved.rotation, layer.rotation);
              if (layer.type == LayerType.text) {
                expect(
                  saved.textStyle!.fontFamily,
                  layer.textStyle!.fontFamily,
                );
                expect(
                  saved.textStyle!.fontSize,
                  closeTo(layer.textStyle!.fontSize!, .000001),
                );
                final edited = layer.copyWith(text: '우리의 여행');
                final restored = LayerExportMapper.fromJson(
                  LayerExportMapper.toJson(
                    edited,
                    canvasSize: aspect.canvas,
                    isCover: index == 0,
                  ),
                  canvasSize: aspect.canvas,
                  isCover: index == 0,
                );
                expect(restored.text, '우리의 여행');
                expect(restored.id, layer.id);
                expect(
                  restored.textStyle!.fontFamily,
                  layer.textStyle!.fontFamily,
                );
              }
              if (layer.type == LayerType.image) {
                expect(cleared[layerIndex].hasImageSource, isFalse);
                final replacement = cleared[layerIndex].copyWith(
                  imageUrl: 'asset:assets/snapfit_home_square.jpg',
                );
                final restored = LayerExportMapper.fromJson(
                  LayerExportMapper.toJson(
                    replacement,
                    canvasSize: aspect.canvas,
                    isCover: index == 0,
                  ),
                  canvasSize: aspect.canvas,
                  isCover: index == 0,
                );
                expect(
                  restored.imageUrl,
                  'asset:assets/snapfit_home_square.jpg',
                );
                expect(restored.imageBackground, layer.imageBackground);
                if (index > 0) {
                  expect(
                    index.isOdd ? rect.right : rect.left,
                    index.isOdd
                        ? lessThanOrEqualTo(aspect.canvas.width * .88 + .1)
                        : greaterThanOrEqualTo(aspect.canvas.width * .12 - .1),
                    reason: '${layer.id}: binding inset',
                  );
                }
              }
              if (layer.type == LayerType.sticker)
                expect(cleared[layerIndex].imageUrl, layer.imageUrl);
            }
          }
          for (final pair in [(3, 4), (7, 8), (13, 14)]) {
            final layers = [...pages[pair.$1], ...pages[pair.$2]];
            expect(
              layers.where((layer) => layer.type == LayerType.image),
              isNotEmpty,
            );
            expect(
              layers.where((layer) => layer.type == LayerType.text),
              isNotEmpty,
            );
          }
        }
      },
    );

    test(
      '${aspect.name}: signature body, labels and headings retain readable size and contrast',
      () {
        final document = buildWindAtlas(aspect);
        final rawPages = templateDocumentPages(document);
        final pages = _layers(aspect);
        for (final index in _signaturePageIndices) {
          final prefix = '${windAtlasId}_${aspect.name}_${index}_';
          final layers = pages[index];
          final paper = layers.firstWhere(
            (layer) => layer.id == '${prefix}paper',
          );
          final background = Color(
            int.parse(
              'FF${paper.decorationFillColor!.replaceFirst('#', '')}',
              radix: 16,
            ),
          );
          final rawById = {
            for (final raw in rawPages[index]['layers'] as List) raw['id']: raw,
          };
          for (final layer in layers.where(
            (layer) => layer.type == LayerType.text,
          )) {
            final size = layer.textStyle!.fontSize!;
            final role = rawById[layer.id]['typographyRole'];
            expect(
              role,
              anyOf('body', 'caption', 'signature-title'),
              reason: layer.id,
            );
            expect(
              rawById[layer.id]['typographyMinFontSize'],
              greaterThanOrEqualTo(role == 'caption' ? 8.5 : 11),
              reason: layer.id,
            );
            expect(
              size,
              greaterThanOrEqualTo(8.5),
              reason: '${layer.id}: readable information floor',
            );
            if (role == 'body') {
              expect(
                size,
                greaterThanOrEqualTo(11),
                reason: '${layer.id}: body text floor',
              );
            }
            if (role == 'signature-title') {
              expect(layer.textStyle!.fontFamily, 'Eulyoo', reason: layer.id);
              expect(
                size,
                greaterThanOrEqualTo(18),
                reason: '${layer.id}: title hierarchy',
              );
            }
            final ink = layer.textStyle!.color!;
            final a = ink.computeLuminance();
            final b = background.computeLuminance();
            final contrast = (math.max(a, b) + .05) / (math.min(a, b) + .05);
            expect(
              contrast,
              greaterThanOrEqualTo(4.5),
              reason: '${layer.id}: readable text against its paper',
            );
          }
        }
      },
    );

    test(
      '${aspect.name}: longer personal copy remains real editable text with bundled-font preflight',
      () {
        const copy = EditorialCopy(
          place: '초여름의 작은 마을에서 보낸 시간',
          period: '2026년 6월 12일 ~ 6월 18일',
          byline: '수연과 지후의 기록',
          note: '함께한 순간을 오래 기억하고 싶다.',
        );
        for (final cover in WindAtlasCover.values) {
          final pages = _layers(aspect, cover: cover, copy: copy);
          expect(
            _textIssues(pages),
            isEmpty,
            reason: '${aspect.name}/${cover.name}',
          );
          final content = pages
              .expand((p) => p)
              .where((layer) => layer.type == LayerType.text)
              .map((layer) => layer.text)
              .join(' ')
              .replaceAll(RegExp(r'\s+'), ' ');
          for (final value in [
            copy.place,
            copy.period,
            copy.byline,
            copy.note,
          ]) {
            expect(content, contains(value.replaceAll(RegExp(r'\s+'), ' ')));
          }
        }
        final tooLong = EditorialCopy(
          place: '여행',
          period: '2026',
          byline: '수연',
          note: List.filled(40, '기록').join('\n'),
        );
        expect(
          _textIssues(_layers(aspect, copy: tooLong)),
          isNotEmpty,
          reason:
              'Unbounded copy must still be detected instead of silently clipped.',
        );
      },
    );
  }
}
