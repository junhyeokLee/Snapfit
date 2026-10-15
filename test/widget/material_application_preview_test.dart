import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/studio_phrase_catalog.dart';
import 'package:snap_fit/core/templates/studio_word_art_catalog.dart';
import 'package:snap_fit/features/store/presentation/widgets/material_application_preview.dart';
import 'package:snap_fit/features/store/presentation/widgets/material_preview_composition.dart';
import 'package:snap_fit/shared/widgets/studio_decoration.dart';
import 'package:snap_fit/shared/widgets/studio_word_art_preview.dart';

String typeOf(StudioDecorationSpec spec) =>
    spec.category == StudioDecorationCategory.paper ? '종이' : '스티커';

void main() {
  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in manifest) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
  });

  test(
    'every decoration keeps its aspect, visible boundaries and caption space',
    () {
      final bounds = (Offset.zero & MaterialPreviewComposition.canvas).inflate(
        .001,
      );
      final photos = <String>{};
      for (final spec in studioDecorations) {
        final plan = MaterialPreviewComposition.forProduct(
          'sticker:${spec.id}',
          typeOf(spec),
        );
        final material = plan.materialRect;
        expect(
          material.width / material.height,
          closeTo(spec.aspectRatio, .00001),
          reason: spec.id,
        );
        for (final rect in [
          material,
          plan.photoRect,
          plan.captionRect,
          plan.sampleTextRect,
        ].whereType<Rect>()) {
          expect(rect.width > 0 && rect.height > 0, isTrue, reason: spec.id);
          expect(
            bounds.contains(rect.topLeft) && bounds.contains(rect.bottomRight),
            isTrue,
            reason: spec.id,
          );
        }
        if (plan.captionRect != null) {
          expect(
            material.overlaps(plan.captionRect!),
            isFalse,
            reason: spec.id,
          );
        }
        final photo = plan.photoRect!;
        if (plan.placement == MaterialPreviewPlacement.card ||
            plan.placement == MaterialPreviewPlacement.band) {
          expect(material.overlaps(photo), isFalse, reason: spec.id);
          expect(plan.materialBelowPhoto, isFalse, reason: spec.id);
        }
        if (plan.materialBelowPhoto) {
          final covered = material.intersect(photo);
          expect(
            covered.width * covered.height / (material.width * material.height),
            lessThan(.35),
            reason: spec.id,
          );
        }
        if (plan.sampleTextRect != null) {
          expect(
            material.contains(plan.sampleTextRect!.topLeft),
            isTrue,
            reason: spec.id,
          );
          expect(
            material.contains(plan.sampleTextRect!.bottomRight),
            isTrue,
            reason: spec.id,
          );
        }
        expect(
          File(plan.photoAsset!).existsSync(),
          isTrue,
          reason: plan.photoAsset,
        );
        photos.add(plan.photoAsset!);
        final next = MaterialPreviewComposition.forProduct(
          'sticker:${spec.id}',
          typeOf(spec),
          photoIndex: 1,
        );
        expect(next.photoAsset, isNot(plan.photoAsset), reason: spec.id);
        expect(next.materialRect, material, reason: spec.id);
      }
      expect(photos.length, greaterThanOrEqualTo(30));
    },
  );

  test(
    'reported cards have dedicated, uncovered compositions and contextual photos',
    () {
      for (final entry in {
        'lifeCompanionTab': 'pet_walk.png',
        'lifeWardrobeLabel': 'growth_keepsakes.png',
        'materialBlindEmboss': 'petal_couple.png',
      }.entries) {
        final plan = MaterialPreviewComposition.forProduct(
          'sticker:${entry.key}',
          '종이',
        );
        expect(plan.placement, MaterialPreviewPlacement.card);
        expect(plan.photoAsset, endsWith(entry.value));
        expect(plan.sampleText, isNotNull);
        expect(plan.photoRect!.overlaps(plan.materialRect), isFalse);
      }
    },
  );

  test('lettering uses its own source proportions and relevant photograph', () {
    for (final art in studioWordArts) {
      final plan = MaterialPreviewComposition.forProduct(art.productKey, '문구');
      expect(
        plan.materialRect.width / plan.materialRect.height,
        closeTo(art.sourceSize.aspectRatio, .00001),
      );
      expect(plan.materialRect.overlaps(plan.photoRect!), isFalse);
      expect(File(plan.photoAsset!).existsSync(), isTrue);
    }
    for (final phrase in studioPhrases) {
      final plan = MaterialPreviewComposition.forProduct(
        'phrase:${phrase.id}',
        '문구',
      );
      if (phrase.category == '웨딩')
        expect(plan.photoAsset, contains(RegExp('petal_|lightbound_')));
      if (phrase.category == '성장·육아')
        expect(plan.photoAsset, contains('growth_'));
      if (phrase.category == '반려동물') expect(plan.photoAsset, contains('pet_'));
    }
  });

  test(
    'translucent papers stay visible and curated photos keep their subject',
    () {
      for (final id in [
        'materialVellumBand',
        'travelDocumentPocket',
        'travelPhotoSleeve',
        'studioVellum',
      ]) {
        final spec = studioDecorationById(id)!;
        final plan = MaterialPreviewComposition.forProduct(
          'sticker:$id',
          typeOf(spec),
        );
        expect(plan.paperColor.computeLuminance(), lessThan(.75), reason: id);
      }
      final growth = MaterialPreviewComposition.forProduct(
        'sticker:materialScallopNote',
        '종이',
      );
      expect(growth.photoAlignment.x, lessThan(0));
      for (var i = 0; i < 4; i++) {
        final letter = MaterialPreviewComposition.forProduct(
          'phrase:collage-atelier-postcard',
          '문구',
          photoIndex: i,
        );
        expect(letter.photoAsset, contains(RegExp('daily_desk|daily_book')));
      }
    },
  );

  testWidgets(
    'all decoration and word-art application examples render without overlap overflow',
    (tester) async {
      tester.view.physicalSize = const Size(960, 1170);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const first = [
        'lifeCompanionTab',
        'lifeWardrobeLabel',
        'materialBlindEmboss',
      ];
      final specs = [
        for (final id in first) studioDecorationById(id)!,
        ...studioDecorations.where((s) => !first.contains(s.id)),
      ];
      final cases = <({String key, String type, String title, Widget child})>[
        for (final spec in specs)
          (
            key: 'sticker:${spec.id}',
            type: typeOf(spec),
            title: spec.label,
            child: StudioDecoration(spec: spec, imageDecodeWidth: 768),
          ),
        for (final art in studioWordArts)
          (
            key: art.productKey,
            type: '문구',
            title: art.label,
            child: StudioWordArtPreview(art: art),
          ),
        for (final phrase in studioPhrases)
          (
            key: 'phrase:${phrase.id}',
            type: '문구',
            title: phrase.text.replaceAll('\n', ' '),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                phrase.text,
                style: phrase.lettering.style,
                textAlign: phrase.alignment,
              ),
            ),
          ),
      ];
      for (var offset = 0; offset < cases.length; offset += 9) {
        final batch = cases.skip(offset).take(9).toList();
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                key: boundary,
                child: ColoredBox(
                  color: Colors.white,
                  child: GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 320 / 378,
                    padding: const EdgeInsets.all(10),
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final item in batch)
                        Column(
                          children: [
                            Expanded(
                              child: MaterialApplicationPreview(
                                productKey: item.key,
                                type: item.type,
                                material: item.child,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 32,
                              child: Text(
                                item.title,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: const TextStyle(
                                  fontFamily: 'NotoSans',
                                  fontSize: 13,
                                  color: Color(0xFF283D36),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: batch.map((item) => item.key).join(', '),
        );
        expect(
          find.byKey(const ValueKey('application-material')),
          findsNWidgets(batch.length),
        );
        if (const bool.fromEnvironment('MATERIAL_APPLICATION_QA')) {
          await tester.runAsync(() async {
            for (final element in find.byType(Image).evaluate()) {
              await precacheImage((element.widget as Image).image, element);
            }
          });
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            Directory(
              'output/material-application-qa',
            ).createSync(recursive: true);
            File(
              'output/material-application-qa/batch-$offset.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
    },
  );
}
