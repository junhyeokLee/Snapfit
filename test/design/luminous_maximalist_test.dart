import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/zine_material.dart';
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
          page.$1 == 0 ? equals(1) : greaterThanOrEqualTo(5),
        );
        expect(layers.any((l) => l['type'] == 'text'), true);
      }
    }
    expect(zineDecorations.length, 13);
    expect(
      studioDecorations,
      containsAll([...zineDecorations, ...luminousDecorations]),
    );
    for (final s in zineDecorations) {
      expect(studioDecorationById(s.id), s);
    }
  });
  test('three art-direction proofs have distinct photo compositions', () {
    for (final aspect in CollectionAspect.values) {
      final photos = <String>{};
      final frames = <String>{};
      final compositions = <String>{};
      for (final page in templateDocumentPages(
        buildLuminousEdition(aspect),
      ).indexed) {
        final layers = page.$2['layers'] as List;
        final slots = layers.where((l) => l['type'] == 'image').toList();
        expect(
          slots.length,
          page.$1 == 0 ? equals(1) : greaterThanOrEqualTo(5),
        );
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
      expect(photos.length, greaterThanOrEqualTo(9));
      expect(compositions.length, luminousEditionInnerPageCount + 1);
      expect(frames, containsAll(['none', 'studioTorn']));
    }
  });
  test('one-photo cover and personal credits replace decorative slogans', () {
    for (final aspect in CollectionAspect.values) {
      final pages = templateDocumentPages(buildLuminousEdition(aspect));
      final cover = (pages.first['layers'] as List)
          .cast<Map<String, dynamic>>();
      final image = cover.singleWhere((l) => l['type'] == 'image');
      expect(image['w'], greaterThan(.90));
      expect(image['h'], greaterThan(.70));
      expect(image['frame'], 'none');
      expect(image['rotation'], 0);
      expect(cover.where((l) => l['type'] == 'text').map((l) => l['text']), [
        '겹쳐진',
        '순간',
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
      await tester.tap(find.byTooltip('블루 포켓 카메라 즐겨찾기 추가'));
      await tester.pumpAndSettle();
      expect(CatalogFavorites.instance.contains('decoration:zineCamera'), true);
      await tester.ensureVisible(find.text('블루 포켓 카메라'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('블루 포켓 카메라'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('프레임'));
      await tester.pumpAndSettle();
      expect(find.text('필름 콘택트'), findsOneWidget);
      await tester.tap(find.text('문구'));
      await tester.pumpAndSettle();
      expect(find.text('같이 찍자!'), findsOneWidget);
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
      await tester.ensureVisible(find.text('티켓 라벨'));
      await tester.tap(find.text('티켓 라벨'));
      await tester.pumpAndSettle();
      expectTicketTextInside();
      expect(tester.takeException(), isNull);
    });
  }
}
