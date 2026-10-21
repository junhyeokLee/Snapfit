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

Rect _rect(LayerModel layer) =>
    layer.position & Size(layer.width, layer.height);

// Map a known source face zone through the same cover fit and editable crop
// alignment used by the renderer, rather than assuming an uncropped photo.
Rect _sourceZone(LayerModel photo, Rect zone, Size sourceSize) {
  final fit = applyBoxFit(
    BoxFit.cover,
    sourceSize,
    Size(photo.width, photo.height),
  );
  final source = photo.imageAlignment.inscribe(
    fit.source,
    Offset.zero & sourceSize,
  );
  final target = Alignment.center.inscribe(fit.destination, _rect(photo));
  return Rect.fromLTRB(
    target.left + (zone.left - source.left) / source.width * target.width,
    target.top + (zone.top - source.top) / source.height * target.height,
    target.left + (zone.right - source.left) / source.width * target.width,
    target.top + (zone.bottom - source.top) / source.height * target.height,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest.whereType<Map>()) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in (entry['fonts'] as List).whereType<Map>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });

  for (final aspect in CollectionAspect.values) {
    test(
      'all 68 covers have exclusive photographs and fitting text: ${aspect.name}',
      () {
        final owners = <String, String>{};
        expect(publishedCreationTemplates, hasLength(68));
        for (final template in publishedCreationTemplates) {
          final catalog =
              jsonDecode(template.templateJson!) as Map<String, dynamic>;
          final doc = catalog['variants'][aspect.name] as Map<String, dynamic>;
          final cover = doc['cover'] as Map<String, dynamic>;
          final photographs = (cover['layers'] as List)
              .where((l) => l['type'] == 'image')
              .toList();
          expect(
            photographs,
            isNotEmpty,
            reason: '${template.title}: real cover subject',
          );
          for (final photo in photographs) {
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
        expect(
          owners.length,
          greaterThanOrEqualTo(publishedCreationTemplates.length),
        );
      },
    );
  }

  test(
    'renaming an identical photo cannot bypass the cover uniqueness rule',
    () async {
      final fingerprints = <String, Uint8List>{};
      var photographCount = 0;
      for (final template in publishedCreationTemplates) {
        final doc = jsonDecode(template.templateJson!) as Map<String, dynamic>;
        for (final photo in (doc['cover']['layers'] as List).where(
          (l) => l['type'] == 'image',
        )) {
          photographCount++;
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
      expect(fingerprints, hasLength(photographCount));
      expect(
        photographCount,
        greaterThanOrEqualTo(publishedCreationTemplates.length),
      );
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
        final doc = authoredCollections
            .singleWhere(
              (collection) => collection.id == FreeCollectionVolume.cinema.id,
            )
            .document(aspect);
        final layers = DataTemplateEngine.buildLayersFromJson(
          doc['cover'],
          aspect.canvas,
        );
        // The square original now fills each jacket. Apply its actual crop
        // before checking the photographed face zone against editable type.
        final photo = layers.singleWhere((l) => l.type == LayerType.image);
        expect(
          photo.width / photo.height,
          closeTo(aspect.canvas.aspectRatio, .00001),
        );
        expect(
          photo.width *
              photo.height /
              (aspect.canvas.width * aspect.canvas.height),
          greaterThanOrEqualTo(.8),
        );
        expect(photo.imageZoom, 1);
        final faces = _sourceZone(
          photo,
          const Rect.fromLTWH(.375, .22, .325, .30),
          const Size(1, 1),
        );
        for (final layer in layers.where((l) => l.type == LayerType.text)) {
          expect(
            _rect(layer).deflate(.5).overlaps(faces.deflate(.5)),
            false,
            reason: '${aspect.name}: ${layer.text} covers the dancing couple',
          );
        }
      }
    },
  );

  test(
    'birthday photographic crop retains the baby face in every jacket ratio',
    () {
      for (final aspect in CollectionAspect.values) {
        final doc = authoredCollections
            .singleWhere(
              (collection) => collection.id == FreeCollectionVolume.birthday.id,
            )
            .document(aspect);
        final layers = DataTemplateEngine.buildLayersFromJson(
          doc['cover'],
          aspect.canvas,
        );
        final photo = layers.singleWhere((l) => l.type == LayerType.image);
        // Convert the normalized face zone's horizontal coordinates to the
        // original 3:2 image before mapping its actual crop and alignment.
        final sourceFace = _sourceZone(
          photo,
          const Rect.fromLTWH(.215 * 1.5, .31, .115 * 1.5, .19),
          const Size(1.5, 1),
        );
        expect(sourceFace.isFinite, isTrue);
        expect(
          _rect(photo).contains(sourceFace.topLeft),
          isTrue,
          reason: '${aspect.name}: do not crop the left half of the baby face',
        );
        expect(_rect(photo).contains(sourceFace.bottomRight), isTrue);
        for (final text in layers.where((l) => l.type == LayerType.text)) {
          expect(
            _rect(text).deflate(.5).overlaps(sourceFace.deflate(.5)),
            isFalse,
            reason: '${aspect.name}: ${text.text} covers the baby face',
          );
        }
      }
    },
  );

  test('wide pet jackets place their titles below the photographed heads', () {
    for (final id in ['a-day-with-you', 'our-walking-promise']) {
      final aspect = CollectionAspect.landscape;
      final doc = authoredCollections
          .singleWhere((c) => c.id == id)
          .document(aspect);
      final title = (doc['cover']['layers'] as List).singleWhere(
        (l) => l['typographyRole'] == 'signature-title',
      );
      expect((title['y'] as num).toDouble(), greaterThan(.5), reason: id);
    }
  });

  test('dates-of-us keeps place, author and date in separate cover fields', () {
    for (final aspect in CollectionAspect.values) {
      final document = authoredCollections
          .singleWhere((collection) => collection.id == 'dates-of-us')
          .document(aspect);
      final layers = DataTemplateEngine.buildLayersFromJson(
        document['cover'],
        aspect.canvas,
      );
      final fields = layers
          .where(
            (l) =>
                l.type == LayerType.text &&
                RegExp(r'_signature_(?:place|byline|period)$').hasMatch(l.id),
          )
          .toList();
      expect(fields, hasLength(3));
      final place = fields.singleWhere(
        (l) => l.id.endsWith('_signature_place'),
      );
      expect(
        place.textStyle!.fontSize,
        greaterThanOrEqualTo(11),
        reason: '${aspect.name}: body text must retain its readable minimum',
      );
      for (var first = 0; first < fields.length; first++) {
        for (var second = first + 1; second < fields.length; second++) {
          expect(
            _rect(
              fields[first],
            ).deflate(.5).overlaps(_rect(fields[second]).deflate(.5)),
            isFalse,
            reason:
                '${aspect.name}: a collection name must not classify '
                '${fields[first].id} or ${fields[second].id} as a date',
          );
        }
      }
      final author = fields.singleWhere(
        (l) => l.id.endsWith('_signature_byline'),
      );
      final date = fields.singleWhere(
        (l) => l.id.endsWith('_signature_period'),
      );
      expect(author.position.dx, lessThan(date.position.dx));
    }
  });

  test(
    'photographic catalog jackets retain draft and saved-album source versions',
    () {
      for (final collection in baselineAuthoredCollections) {
        for (final aspect in CollectionAspect.values) {
          Map<String, dynamic> source() => switch (collection.id) {
            'lightbound' => buildLightboundWeddingDraft(aspect),
            'journey' => EditorialVolume.journey.document(aspect),
            'small-days' => EditorialVolume.smallDays.document(aspect),
            _ => throw StateError(collection.id),
          };
          final original = source();
          final unchanged = jsonEncode(original);
          final current = collection.document(aspect);
          expect(current['coverRevision'], 'open-photographic-type-2026-10-21');
          expect(current['cover']['coverRevision'], current['coverRevision']);
          expect(current['version'], (original['version'] as int) + 1);
          expect(current['cover'], isNot(original['cover']));
          for (final field in [
            'id',
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
          expect(
            afterPhoto['imageUrl'],
            collection.id == 'journey'
                ? 'asset:assets/templates/original_editorial/images/travel_cafe.png'
                : beforePhoto['imageUrl'],
            reason:
                'The public journey jacket must differ from wind-atlas; '
                'the original draft photograph stays untouched',
          );
          // Photography fills the jacket. Type is painted straight onto the
          // photo; neither a plate nor a scrim can substitute for its placement.
          final layers = DataTemplateEngine.buildLayersFromJson(
            current['cover'],
            aspect.canvas,
          );
          final photo = layers.singleWhere((l) => l.type == LayerType.image);
          expect(
            photo.width / photo.height,
            closeTo(aspect.canvas.aspectRatio, .00001),
          );
          expect(
            photo.width *
                photo.height /
                (aspect.canvas.width * aspect.canvas.height),
            greaterThanOrEqualTo(.8),
          );
          expect(photo.imageZoom, 1);
          expect(photo.imageBackground, 'none');
          expect(current['cover']['typographyPanelCoverageFraction'], 0.0);
          final photoIndex = layers.indexOf(photo);
          expect(
            layers
                .skip(photoIndex + 1)
                .where(
                  (l) => l.type != LayerType.text && l.type != LayerType.image,
                ),
            isEmpty,
          );
          for (final text in layers) {
            if (text.type != LayerType.text) continue;
            expect(text.textFillMode, 'solid', reason: text.id);
            expect(text.textStyle!.color!.a, 1, reason: text.id);
            expect(text.textStyle!.shadows, isNotEmpty, reason: text.id);
          }
          expect(jsonEncode(original), unchanged);
          expect(
            source(),
            original,
            reason:
                '${collection.id}: current-catalog work must not rewrite archived interiors',
          );
          expect(freeTemplateMaterialIssues(current), isEmpty);
        }
      }
    },
  );
}
