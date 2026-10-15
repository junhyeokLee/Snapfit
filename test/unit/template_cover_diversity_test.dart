import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/free_template_material_policy.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import '../widget/ai_album_start_step_test.dart' show loadCreationFonts;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadCreationFonts();
    for (final f in [
      ('Eulyoo', 'Eulyoo1945-Regular.ttf'),
      ('BookMyungjo', 'BookkMyungjo_Bold.ttf'),
      ('Cormorant Garamond', 'Cormorant-Regular.ttf'),
    ]) {
      await (FontLoader(
        f.$1,
      )..addFont(rootBundle.load('assets/fonts/${f.$2}'))).load();
    }
  });

  for (final aspect in CollectionAspect.values) {
    test(
      'all 51 covers have exclusive photographs and fitting text: ${aspect.name}',
      () {
        final owners = <String, String>{};
        for (final template in publishedCreationTemplates) {
          final catalog =
              jsonDecode(template.templateJson!) as Map<String, dynamic>;
          final doc = catalog['variants'][aspect.name] as Map<String, dynamic>;
          final cover = doc['cover'] as Map<String, dynamic>;
          for (final photo in (cover['layers'] as List).where(
            (l) => l['type'] == 'image',
          )) {
            final path = photo['imageUrl'] as String;
            expect(path.startsWith('asset:'), true);
            expect(
              owners.containsKey(path),
              false,
              reason: '$path reused by ${owners[path]} and ${template.title}',
            );
            owners[path] = template.title;
            expect(File(path.substring(6)).existsSync(), true);
          }
          if (!template.isPremium)
            expect(freeTemplateMaterialIssues(doc), isEmpty);
          final layers = DataTemplateEngine.buildLayersFromJson(
            cover,
            aspect.canvas,
          );
          for (final layer in layers) {
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
            if (layer.type != LayerType.text) continue;
            final painter = TextPainter(
              textDirection: TextDirection.ltr,
              text: TextSpan(text: layer.text, style: layer.textStyle),
              strutStyle: StrutStyle.fromTextStyle(
                layer.textStyle!,
                forceStrutHeight: true,
              ),
            )..layout(maxWidth: layer.width);
            expect(
              painter.height,
              lessThanOrEqualTo(layer.height + .5),
              reason: '${template.title}: ${layer.text}',
            );
            painter.dispose();
            for (final other in layers.where(
              (l) => l.type == LayerType.text && l.id != layer.id,
            )) {
              expect(
                rect
                    .deflate(.7)
                    .overlaps(
                      (other.position & Size(other.width, other.height))
                          .deflate(.7),
                    ),
                false,
                reason:
                    '${template.title}: ${layer.text} overlaps ${other.text}',
              );
            }
          }
        }
        expect(owners, hasLength(57));
      },
    );
  }

  test(
    'renaming an identical photo cannot bypass the cover uniqueness rule',
    () async {
      final fingerprints = <String, Uint8List>{};
      for (final template in publishedCreationTemplates) {
        final doc = jsonDecode(template.templateJson!) as Map<String, dynamic>;
        for (final photo in (doc['cover']['layers'] as List).where(
          (l) => l['type'] == 'image',
        )) {
          final path = (photo['imageUrl'] as String).substring(6);
          final codec = await ui.instantiateImageCodec(
            File(path).readAsBytesSync(),
            targetWidth: 32,
            targetHeight: 32,
          );
          final image = (await codec.getNextFrame()).image;
          final pixels = (await image.toByteData())!.buffer.asUint8List();
          for (final prior in fingerprints.entries) {
            var difference = 0;
            for (var i = 0; i < pixels.length; i += 4) {
              for (var channel = 0; channel < 3; channel++)
                difference += (pixels[i + channel] - prior.value[i + channel])
                    .abs();
            }
            final mean = difference / (pixels.length / 4 * 3);
            expect(
              mean,
              greaterThan(2),
              reason:
                  '${template.title}: $path is visually identical to ${prior.key}',
            );
          }
          fingerprints[path] = pixels;
          image.dispose();
          codec.dispose();
        }
      }
      expect(fingerprints, hasLength(57));
    },
  );

  test(
    'premium cover refinement changes no interior, identity, price or archived artwork',
    () {
      for (final volume in PremiumVolume.values) {
        for (final aspect in CollectionAspect.values) {
          for (final count in volume.pageCounts) {
            final before = volume.document(
              aspect,
              innerPages: count,
              refineCover: false,
            );
            final after = volume.document(aspect, innerPages: count);
            expect(after['coverRevision'], catalogCoverRevision);
            expect(after['coverReview'], 'pending-visual-approval');
            for (final key in [
              'id',
              'editionId',
              'innerPageCount',
              'pages',
              'chapters',
              'accessTier',
              'releaseGates',
            ])
              expect(after[key], before[key], reason: '${volume.id}: $key');
            expect(after['cover'], isNot(before['cover']));
            expect(
              volume.document(aspect, innerPages: count, refineCover: false),
              before,
            );
          }
        }
      }
    },
  );

  test('travel cover keeps the existing editable title, names and date', () {
    const copy = LuminousCopy(
      first: '우리만의',
      second: '여름',
      third: ' 여행',
      names: '민지와 수현',
      date: '2027. 07. 09',
    );
    for (final aspect in CollectionAspect.values) {
      final document = PremiumVolume.travel.document(aspect, travelCopy: copy);
      final texts = (document['cover']['layers'] as List)
          .where((l) => l['type'] == 'text')
          .map((l) => l['text']);
      expect(texts, contains('우리만의 여름 여행'));
      expect(texts, contains(copy.names));
      expect(texts, contains(copy.date));
    }
  });

  test(
    'evening wedding cover type leaves the photographed faces clear in every ratio',
    () {
      for (final aspect in CollectionAspect.values) {
        final doc = FreeCollectionVolume.cinema.document(aspect);
        final layers = DataTemplateEngine.buildLayersFromJson(
          doc['cover'],
          aspect.canvas,
        );
        // Face zone measured from the square source and its centered wide crop.
        final faces = Rect.fromLTWH(
          aspect.canvas.width * .375,
          aspect.canvas.height *
              (aspect == CollectionAspect.landscape ? .12 : .22),
          aspect.canvas.width * .325,
          aspect.canvas.height * .30,
        );
        for (final layer in layers.where((l) => l.type == LayerType.text)) {
          expect(
            (layer.position & Size(layer.width, layer.height)).overlaps(faces),
            false,
            reason: '${aspect.name}: ${layer.text} covers the dancing couple',
          );
        }
      }
    },
  );

  test(
    'catalog baseline covers improve without changing draft or saved interiors',
    () {
      for (final collection in baselineAuthoredCollections) {
        for (final aspect in CollectionAspect.values) {
          final original = switch (collection.id) {
            'lightbound' => buildLightboundWeddingDraft(aspect),
            'journey' => EditorialVolume.journey.document(aspect),
            'small-days' => EditorialVolume.smallDays.document(aspect),
            _ => throw StateError(collection.id),
          };
          final unchanged = jsonEncode(original);
          final current = collection.document(aspect);
          expect(current['coverRevision'], baselineCoverRevision);
          expect(current['version'], (original['version'] as int) + 1);
          expect(current['cover'], isNot(original['cover']));
          for (final field in [
            'id',
            'pages',
            'innerPageCount',
            'chapters',
            'accessTier',
          ]) {
            expect(
              current[field],
              original[field],
              reason: '${collection.id}: $field',
            );
          }
          final beforePhoto = (original['cover']['layers'] as List).singleWhere(
            (l) => l['type'] == 'image',
          );
          final afterPhoto = (current['cover']['layers'] as List).singleWhere(
            (l) => l['type'] == 'image',
          );
          expect(afterPhoto['imageUrl'], beforePhoto['imageUrl']);
          expect(
            afterPhoto['w'] * afterPhoto['h'],
            greaterThan(beforePhoto['w'] * beforePhoto['h']),
          );
          expect(jsonEncode(original), unchanged);
          expect(freeTemplateMaterialIssues(current), isEmpty);
        }
      }
    },
  );
}
