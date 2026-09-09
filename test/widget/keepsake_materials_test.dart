import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/studio_photo_frame_catalog.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_known_products.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/image_frame_style_picker.dart';
import 'package:snap_fit/shared/widgets/keepsake_photo_frame.dart';
import 'package:snap_fit/shared/widgets/studio_decoration.dart';
import 'package:snap_fit/shared/widgets/studio_material.dart';
import '../../tool/template_studio/luminous_materials.dart';
import '../unit/catalog_favorites_test.dart' show MemoryFavoritesStorage;
import 'ai_album_start_step_test.dart' show loadCreationFonts;
import 'studio_decorations_test.dart' show capture;

const _photo = 'assets/templates/original_editorial/images/petal_evening.png';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCreationFonts);
  late CatalogFavorites previous;
  setUp(() async {
    previous = CatalogFavorites.instance;
    CatalogFavorites.instance = CatalogFavorites(
      storage: MemoryFavoritesStorage(),
    );
    await CatalogFavorites.instance.load();
  });
  tearDown(() {
    CatalogFavorites.instance.dispose();
    CatalogFavorites.instance = previous;
  });

  test(
    '28 new materials have unique catalog, favorites and price identities',
    () {
      expect(keepsakeDecorations.length + keepsakePhotoFrames.length, 28);
      expect(
        keepsakeDecorations.where((s) => s.assetPath != null),
        hasLength(8),
      );
      expect(
        keepsakeDecorations.where((s) => s.assetPath == null),
        hasLength(14),
      );
      expect(keepsakeDecorations.map((s) => s.id).toSet(), hasLength(22));
      expect(
        keepsakeDecorations.map((s) => s.collection).toSet(),
        containsAll(keepsakeMaterialCollections),
      );
      for (final s in keepsakeDecorations) {
        expect(
          CatalogFavoriteKeys.decoration(s.insertionValue),
          'decoration:${s.id}',
        );
        final product = pointShopKnownProducts.singleWhere(
          (p) => p.productKey == 'sticker:${s.id}',
        );
        expect(product.pointPrice, isNull);
        expect(product.isActive, false);
        if (s.assetPath != null) expect(File(s.assetPath!).existsSync(), true);
      }
      for (final key in keepsakePhotoFrames) {
        expect(
          imageFrameStyles.singleWhere((s) => s.key == key).label,
          matches(RegExp('[가-힣]')),
        );
        expect(
          pointShopKnownProducts.any((p) => p.productKey == 'frame:$key'),
          true,
        );
      }
    },
  );

  test(
    'inventory resolves only used materials across variants, without grants',
    () {
      final doc = <String, dynamic>{
        'cover': {
          'layers': [
            {'type': 'image', 'frame': 'materialLaceMount'},
            {'type': 'image', 'imageUrl': 'asset:assets/templates/sample.png'},
          ],
        },
        'pages': [
          {
            'layers': [
              {'type': 'decoration', 'style': 'materialMonthDial'},
              {
                'type': 'sticker',
                'imageUrl': 'asset:assets/sticker/studio/material_lace.png',
              },
              {'type': 'text', 'text': 'materialRose'},
            ],
          },
        ],
        'variants': {
          'landscape': {
            'pages': [
              {
                'layers': [
                  {'type': 'image', 'imageBackground': 'materialLinenOval'},
                  {
                    'type': 'decoration',
                    'imageBackground': 'materialBlindEmboss',
                  },
                ],
              },
            ],
          },
        },
      };
      expect(templateVisualMaterialKeys(doc), {
        'frame:materialLaceMount',
        'sticker:materialLace',
        'sticker:materialMonthDial',
        'frame:materialLinenOval',
        'sticker:materialLinen',
        'sticker:materialBlindEmboss',
      });
      expect(
        () => templateVisualMaterialKeys(doc).add('other'),
        throwsUnsupportedError,
      );
    },
  );

  for (final size in [
    const Size(350, 500),
    const Size(500, 500),
    const Size(600, 400),
  ]) {
    test('materials fit and frame openings scale at $size', () {
      for (final s in keepsakeDecorations) {
        final fitted = s.fittedSize(size);
        expect(fitted.width, lessThanOrEqualTo(size.width * .88 + .01));
        expect(fitted.height, lessThanOrEqualTo(size.height * .88 + .01));
        expect(fitted.aspectRatio, closeTo(s.aspectRatio, .001));
      }
      for (final key in keepsakePhotoFrames) {
        final inset = StudioMaterial.photoInsets(key, size);
        expect(StudioMaterial.photoInsets(key, size * 2), inset * 2);
        final opening = inset.deflateRect(Offset.zero & size);
        expect(opening.width, greaterThan(size.width * .65));
        expect(opening.height, greaterThan(size.height * .65));
        final p = KeepsakePhotoFrame.aperture(key, opening.size);
        final q = KeepsakePhotoFrame.aperture(key, opening.size * 2);
        for (var x = 1; x < 10; x++) {
          for (var y = 1; y < 10; y++) {
            final point = Offset(
              opening.width * x / 10,
              opening.height * y / 10,
            );
            expect(p.contains(point), q.contains(point * 2));
          }
        }
      }
    });
  }

  testWidgets(
    'all new materials render native artwork and export a review sheet',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final items = <({String id, String label, Widget art})>[
        for (final s in keepsakeDecorations)
          (
            id: s.id,
            label: s.label,
            art: AspectRatio(
              aspectRatio: s.aspectRatio,
              child: StudioDecoration(spec: s),
            ),
          ),
        for (final key in keepsakePhotoFrames)
          (
            id: key,
            label: imageFrameStyles.singleWhere((s) => s.key == key).label,
            art: StudioMaterial(
              style: key,
              child: Image.asset(_photo, fit: BoxFit.cover),
            ),
          ),
      ];
      const export = bool.fromEnvironment('EXPORT_MATERIALS');
      final output = Directory('output/materials/keepsake-28');
      if (export) output.createSync(recursive: true);
      for (final item in items) {
        final image = await capture(
          tester,
          SizedBox(
            width: 360,
            height: 360,
            child: ColoredBox(
              color: const Color(0xFFF2F3F1),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(child: item.art),
              ),
            ),
          ),
        );
        final data = await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        final bytes = data!.buffer.asUint8List();
        final colors = <int>{};
        for (var i = 0; i < bytes.length; i += 4 * 101) {
          colors.add(bytes[i] << 16 | bytes[i + 1] << 8 | bytes[i + 2]);
        }
        expect(colors.length, greaterThan(12), reason: item.id);
        if (export)
          File('${output.path}/${item.id}.png').writeAsBytesSync(
            (await tester.runAsync(
              () => image.toByteData(format: ui.ImageByteFormat.png),
            ))!.buffer.asUint8List(),
          );
        image.dispose();
      }
      final sheet = await capture(
        tester,
        SizedBox(
          width: 1400,
          height: 960,
          child: ColoredBox(
            color: Colors.white,
            child: GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 7,
              childAspectRatio: 200 / 235,
              padding: const EdgeInsets.all(10),
              children: [
                for (final item in items)
                  Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Center(child: item.art),
                        ),
                      ),
                      SizedBox(
                        height: 28,
                        child: Text(
                          item.label,
                          style: const TextStyle(
                            fontFamily: 'NotoSans',
                            color: Color(0xFF29302F),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
      if (export)
        File('${output.path}/contact.png').writeAsBytesSync(
          (await tester.runAsync(
            () => sheet.toByteData(format: ui.ImageByteFormat.png),
          ))!.buffer.asUint8List(),
        );
      sheet.dispose();
    },
  );

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('new material gallery filters, bookmarks, and opens at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: LuminousMaterials(newOnly: true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('재료 라이브러리 83'), findsOneWidget);
      await tester.tap(find.text('스티커·종이'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('서약의 아틀리에'));
      await tester.pumpAndSettle();
      expect(find.text('자수 레이스 코너'), findsOneWidget);
      expect(find.text('해변에서 주운 조개'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('favorite-decoration:materialLace')),
      );
      await tester.pumpAndSettle();
      expect(
        CatalogFavorites.instance.contains('decoration:materialLace'),
        true,
      );
      await tester.tap(find.text('자수 레이스 코너'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('프레임'));
      await tester.pumpAndSettle();
      expect(find.text('세 겹 단차 액자'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final entry in keepsakeFrameAssets.entries) {
    testWidgets(
      '${entry.key} uses predecoded material during print rendering',
      (tester) async {
        final image = (await tester.runAsync(() async {
          final codec = await ui.instantiateImageCodec(
            await File(entry.value).readAsBytes(),
          );
          final image = (await codec.getNextFrame()).image;
          codec.dispose();
          return image;
        }))!;
        final rendered = await capture(
          tester,
          SizedBox(
            width: 240,
            height: 320,
            child: StudioMaterial(
              style: entry.key,
              printImages: {'asset:${entry.value}': image},
              child: const ColoredBox(color: Colors.red),
            ),
          ),
        );
        expect(find.byType(RawImage), findsOneWidget);
        expect(find.byType(Image), findsNothing);
        await tester.pumpWidget(const SizedBox());
        rendered.dispose();
        image.dispose();
      },
    );
  }
}
