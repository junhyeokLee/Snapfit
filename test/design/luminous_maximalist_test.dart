import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/zine_material.dart';
import 'package:snap_fit/shared/widgets/studio_decoration.dart';

import '../widget/studio_decorations_test.dart' show capture;
import '../../tool/template_studio/luminous_materials.dart';
import '../widget/ai_album_start_step_test.dart' show loadCreationFonts;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadCreationFonts();
    for (final f in [
      ('Eulyoo', 'Eulyoo1945-Regular.ttf'),
      ('BookMyungjo', 'BookkMyungjo_Bold.ttf'),
    ]) {
      await (FontLoader(
        f.$1,
      )..addFont(rootBundle.load('assets/fonts/${f.$2}'))).load();
    }
  });
  test('candidate has original material layers and stays unpublished', () {
    for (final aspect in CollectionAspect.values) {
      final doc = buildLuminousEdition(aspect);
      expect(doc['catalogPublishable'], false);
      expect(doc['accessTier'], 'unassigned');
      expect(
        doc['assetProvenance'],
        'generated-ornaments-human-authored-layout',
      );
      for (final page in templateDocumentPages(doc).indexed) {
        final layers = page.$2['layers'] as List;
        expect(
          layers.where((l) => l['type'] == 'image').length,
          equals([1, 1, 1, 3, 1, 1, 0, 1, 1][page.$1]),
        );
        expect(layers.any((l) => l['type'] == 'text'), true);
      }
    }
    expect(zineDecorations.length, 13);
    expect(
      studioDecorations,
      containsAll([
        ...zineDecorations,
        ...luminousDecorations,
        ...travelDecorations,
      ]),
    );
    for (final s in zineDecorations) {
      expect(studioDecorationById(s.id), s);
    }
  });
  test('saved 20-page edition matches the original three documents exactly', () {
    for (final aspect in CollectionAspect.values) {
      final doc = buildTravelKeepsakeArchive(aspect);
      final saved = jsonDecode(
        File(
          'tool/template_studio/archives/travel-keepsake-20/${aspect.name}.json',
        ).readAsStringSync(),
      );
      expect(doc, saved);
      final pages = templateDocumentPages(doc);
      expect(pages.length, 21);
      expect(travelKeepsakeArchiveSpreads.length, 10);
      expect(pages.map((p) => p['role']).toSet().length, 21);
      for (final chapter in (doc['chapters'] as List).indexed) {
        expect(chapter.$2['from'], chapter.$1 * 2 + 1);
        expect(chapter.$2['to'], chapter.$1 * 2 + 2);
        expect(chapter.$2['title'], travelKeepsakeArchiveSpreads[chapter.$1]);
      }
      for (final page in pages.skip(1).indexed) {
        final n = page.$1 + 1;
        expect(page.$2['side'], n.isOdd ? 'left' : 'right');
        expect(page.$2['spreadIndex'], (n + 1) ~/ 2);
      }
      final sunset = (pages[16]['layers'] as List).singleWhere(
        (l) => (l['id'] as String).endsWith('_sunset_together'),
      );
      expect(
        sunset['w'] *
            aspect.canvas.width /
            (sunset['h'] * aspect.canvas.height),
        closeTo(7 / 6, .00001),
      );
    }
    expect(travelJournalDecorations.length, 10);
    expect(studioDecorations.toSet().length, studioDecorations.length);
  });
  test('the archived travel album retains its photos and materials', () {
    for (final aspect in CollectionAspect.values) {
      final photos = <String>{};
      final frames = <String>{};
      final compositions = <String>{};
      for (final page in templateDocumentPages(
        buildTravelKeepsakeArchive(aspect),
      ).indexed) {
        final layers = page.$2['layers'] as List;
        final slots = layers.where((l) => l['type'] == 'image').toList();
        expect(slots.length, equals(page.$1 == 0 ? 1 : 2));
        compositions.add(
          slots.map((l) => '${l['x']},${l['y']},${l['w']},${l['h']}').join('|'),
        );
        for (final slot in slots) {
          photos.add(slot['imageUrl'] as String);
          frames.add(slot['frame'] as String);
        }
        expect(
          layers.any(
            (l) =>
                l['frame'] == 'editionLace' ||
                (l['imageUrl'] ?? '').contains('luminous_bow'),
          ),
          false,
        );
        expect(
          layers
              .where((l) => l['type'] == 'text')
              .any((l) => l['style']['fontFamily'] == 'Samlip'),
          false,
        );
      }
      expect(photos.length, greaterThanOrEqualTo(17));
      expect(compositions.length, travelKeepsakeArchiveInnerPageCount + 1);
      expect(frames, containsAll(['none', 'studioTorn']));
    }
  });
  test(
    'new spreads vary silhouette, photo area, framing and material density',
    () {
      for (final aspect in CollectionAspect.values) {
        final doc = buildLuminousEdition(aspect);
        final pages = templateDocumentPages(doc);
        expect(pages.length, 9);
        expect(luminousEditionSpreads.length, 4);
        expect(doc['cover'], buildTravelKeepsakeArchive(aspect)['cover']);
        expect(pages.skip(1).map((p) => p['role']), [
          'immersive-landscape',
          'itinerary-pocket',
          'annotated-contact-strips',
          'circular-table-still-life',
          'edge-to-edge-panorama',
          'folded-personal-letter',
          'archival-portrait-mat',
          'mounted-postcard',
        ]);
        final areas = <double>[];
        final materialCounts = <int>[];
        for (final page in pages.skip(1).indexed) {
          expect(page.$2['side'], page.$1.isEven ? 'left' : 'right');
          expect(page.$2['spreadIndex'], page.$1 ~/ 2 + 1);
          final layers = page.$2['layers'] as List;
          final photos = layers.where((l) => l['type'] == 'image');
          areas.add(photos.fold<double>(0, (sum, l) => sum + l['w'] * l['h']));
          final materials = layers.where(
            (l) =>
                studioDecorationById(l['style'] is String ? l['style'] : '') !=
                    null ||
                studioDecorationByAsset(
                      (l['imageUrl'] as String?)?.replaceFirst('asset:', ''),
                    ) !=
                    null,
          );
          materialCounts.add(materials.length);
          for (final layer in materials) {
            final spec =
                studioDecorationById(
                  layer['style'] is String ? layer['style'] : '',
                ) ??
                studioDecorationByAsset(
                  (layer['imageUrl'] as String?)?.replaceFirst('asset:', ''),
                )!;
            expect(
              layer['w'] *
                  aspect.canvas.width /
                  (layer['h'] * aspect.canvas.height),
              closeTo(spec.aspectRatio, .00001),
            );
          }
        }
        expect(areas[0], greaterThan(.85));
        expect(areas[1], lessThan(.12));
        expect(areas[5], 0);
        expect(materialCounts.toSet().length, greaterThanOrEqualTo(4));
        final circle = (pages[4]['layers'] as List).singleWhere(
          (l) => l['type'] == 'image',
        );
        expect(circle['frame'], 'studioOval');
        expect(
          circle['w'] *
              aspect.canvas.width /
              (circle['h'] * aspect.canvas.height),
          closeTo(1, .00001),
        );
        expect(
          (pages[3]['layers'] as List)
              .where((l) => l['type'] == 'image')
              .map((l) => l['x'])
              .toSet()
              .length,
          1,
        );
      }
    },
  );
  test('one-photo cover and personal credits replace decorative slogans', () {
    for (final aspect in CollectionAspect.values) {
      final pages = templateDocumentPages(buildLuminousEdition(aspect));
      final cover = (pages.first['layers'] as List)
          .cast<Map<String, dynamic>>();
      final image = cover.singleWhere((l) => l['type'] == 'image');
      expect([image['x'], image['y'], image['w'], image['h']], [0, 0, 1, 1]);
      expect(image['frame'], 'none');
      expect(image['rotation'], 0);
      expect(cover.where((l) => l['type'] == 'text').map((l) => l['text']), [
        '둘만의',
        '여행',
        '서연과 지우',
        '2026. 10. 17',
      ]);
      for (final page in pages) {
        for (final layer
            in (page['layers'] as List).cast<Map<String, dynamic>>()) {
          expect(layer['fillColor'], isNot('#D83E2B'));
          expect(
            layer['style'] is Map ? layer['style']['color'] : null,
            isNot('#D83E2B'),
          );
          final text = layer['text'] as String? ?? '';
          for (final removed in ['멈춰 둔', '오후', '빛, 온도', '개인 소장본', '몇 번이고']) {
            expect(text.contains(removed), false);
          }
        }
      }
    }
  });
  test(
    'travel layers add density without adding photos or stretching materials',
    () {
      for (final aspect in CollectionAspect.values) {
        final pages = templateDocumentPages(buildTravelKeepsakeArchive(aspect));
        for (final page in pages.skip(1)) {
          final materials = (page['layers'] as List)
              .where(
                (l) =>
                    studioDecorationById(
                          l['style'] is String ? l['style'] : '',
                        ) !=
                        null ||
                    studioDecorationByAsset(
                          (l['imageUrl'] as String?)?.replaceFirst(
                            'asset:',
                            '',
                          ),
                        ) !=
                        null,
              )
              .toList();
          expect(materials.length, greaterThanOrEqualTo(8));
          for (final l in materials) {
            final spec =
                studioDecorationById(l['style'] is String ? l['style'] : '') ??
                studioDecorationByAsset(
                  (l['imageUrl'] as String?)?.replaceFirst('asset:', ''),
                )!;
            expect(
              l['w'] * aspect.canvas.width / (l['h'] * aspect.canvas.height),
              closeTo(spec.aspectRatio, .00001),
            );
          }
        }
      }
    },
  );
  testWidgets(
    'new travel artwork renders and postal cancellation has no paper background',
    (tester) async {
      for (final spec in travelDecorations) {
        final image = await capture(
          tester,
          SizedBox(
            width: 300,
            height: 300 / spec.aspectRatio,
            child: StudioDecoration(spec: spec),
          ),
        );
        final bytes = (await tester.runAsync(
          () => image.toByteData(),
        ))!.buffer.asUint8List();
        var visible = 0;
        final colors = <int>{};
        for (var i = 0; i < bytes.length; i += 4) {
          if (bytes[i + 3] > 10) visible++;
          colors.add(
            bytes[i] << 24 |
                bytes[i + 1] << 16 |
                bytes[i + 2] << 8 |
                bytes[i + 3],
          );
        }
        expect(colors.length, greaterThan(30));
        final ratio = visible / (image.width * image.height);
        expect(
          ratio,
          spec.id == 'studioPostalMark'
              ? inExclusiveRange(.015, .25)
              : greaterThan(
                  spec.id == 'travelCafeCoaster'
                      ? .6
                      : spec.id == 'travelDocumentPocket'
                      ? .7
                      : .8,
                ),
        );
        if (spec.id == 'travelDocumentPocket') {
          expect(bytes[(image.width ~/ 2) * 4 + 3], 0);
          final center =
              ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
          expect(bytes[center + 3], inExclusiveRange(100, 240));
        }
        image.dispose();
      }
    },
  );
  test(
    'six generated object cutouts preserve transparent backgrounds',
    () async {
      for (final name in [
        'zine_camera',
        'zine_heart_key',
        'zine_silver_star',
        'zine_daisy_patch',
        'zine_citrus',
        'zine_glasses',
      ]) {
        final data = await rootBundle.load('assets/sticker/studio/$name.png');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final image = (await codec.getNextFrame()).image;
        final bytes = (await image.toByteData())!.buffer.asUint8List();
        var clear = 0, visible = 0;
        for (var i = 3; i < bytes.length; i += 4) {
          if (bytes[i] == 0) clear++;
          if (bytes[i] > 220) visible++;
        }
        expect(image.width, greaterThanOrEqualTo(1200));
        expect(clear, greaterThan(image.width * image.height * .25));
        expect(visible, greaterThan(image.width * image.height * .15));
        image.dispose();
        codec.dispose();
      }
    },
  );
  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('$size: materials, favorites and enlargement are usable', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      CatalogFavorites.instance = CatalogFavorites();
      await tester.pumpWidget(const MaterialApp(home: LuminousMaterials()));
      await tester.pumpAndSettle();
      final vertical = find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first;
      Future<void> reveal(Finder target, {double delta = 250}) async {
        await tester.scrollUntilVisible(
          target,
          delta,
          scrollable: vertical,
          maxScrolls: 100,
        );
        await Scrollable.ensureVisible(tester.element(target), alignment: .5);
        await tester.pumpAndSettle();
      }

      final camera = find.byKey(const ValueKey('decoration:zineCamera'));
      await reveal(camera);
      await tester.tap(find.byTooltip('블루 포켓 카메라 즐겨찾기 추가'));
      await tester.pumpAndSettle();
      expect(CatalogFavorites.instance.contains('decoration:zineCamera'), true);
      await reveal(camera, delta: -250);
      await tester.tap(find.text('블루 포켓 카메라'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      final stayTag = find.byKey(const ValueKey('decoration:travelStayTag'));
      await reveal(stayTag);
      await tester.tap(find.byTooltip('숙소 키 태그 즐겨찾기 추가'));
      await tester.pumpAndSettle();
      expect(
        CatalogFavorites.instance.contains('decoration:travelStayTag'),
        true,
      );
      await reveal(stayTag, delta: -250);
      await tester.tap(find.text('숙소 키 태그'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is StudioDecoration && w.spec.id == 'travelStayTag',
        ),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('프레임'));
      await tester.pumpAndSettle();
      await reveal(find.text('필름 콘택트'));
      expect(find.text('필름 콘택트'), findsOneWidget);
      await tester.tap(find.text('문구'));
      await tester.pumpAndSettle();
      await reveal(find.text('같이 찍자!'));
      expect(find.text('같이 찍자!'), findsOneWidget);
      await reveal(find.text('티켓 라벨'));
      void expectTicketTextInside() {
        final label = tester.getRect(find.text('오늘의 기분 : 맑음'));
        final ticket = tester.getRect(
          find.byWidgetPredicate(
            (w) => w is ZineStationery && w.id == 'zineTicket',
          ),
        );
        expect(label.right, lessThan(ticket.left + ticket.width * .8));
        expect(label.left, greaterThan(ticket.left + ticket.width * .04));
      }

      expectTicketTextInside();
      await tester.tap(find.text('티켓 라벨'));
      await tester.pumpAndSettle();
      expectTicketTextInside();
      expect(tester.takeException(), isNull);
    });
  }
}
