import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/studio_photo_frame_catalog.dart';
import 'package:snap_fit/core/templates/studio_word_art_catalog.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_known_products.dart';
import 'package:snap_fit/shared/widgets/atelier_edition_frame.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/image_frame_style_picker.dart';
import 'package:snap_fit/shared/widgets/studio_decoration.dart';
import 'package:snap_fit/shared/widgets/studio_material.dart';
import 'package:snap_fit/shared/widgets/studio_word_art_preview.dart';
import 'ai_album_start_step_test.dart' show loadCreationFonts;
import 'studio_decorations_test.dart' show capture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadCreationFonts();
    for (final entry in {
      'RiaSans': 'RiaSans-Bold.ttf',
      'Yeongwol': 'YeongwolTTF.ttf',
      'BookMyungjo': 'BookkMyungjo_Bold.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load('assets/fonts/${entry.value}'))).load();
    }
  });
  test(
    '36 independent materials retain stable favorites and unpriced product identities',
    () {
      expect(atelierEditionPhotoFrames, hasLength(12));
      expect(atelierCompositionDecorations, hasLength(8));
      expect(atelierWordArts, hasLength(16));
      final keys = [
        ...atelierEditionPhotoFrames.map((s) => 'frame:$s'),
        ...atelierCompositionDecorations.map((s) => 'sticker:${s.id}'),
        ...atelierWordArts.map((s) => s.productKey),
      ];
      expect(keys.toSet(), hasLength(36));
      for (final key in keys) {
        final product = pointShopKnownProducts.singleWhere(
          (p) => p.productKey == key,
        );
        expect(product.pointPrice, isNull);
        expect(product.isActive, false);
      }
      for (final art in atelierWordArts) {
        expect(
          CatalogFavoriteKeys.decoration(art.insertionValue),
          art.favoriteKey,
        );
        final layers = art.previewLayers();
        expect(layers.map((l) => l.id).toSet(), hasLength(layers.length));
        expect(
          layers.where((l) => l.type == LayerType.text).length,
          greaterThanOrEqualTo(3),
        );
        expect(
          layers.where((l) => l.type == LayerType.text).map((l) => l.text),
          contains(art.text),
        );
        for (final layer in layers.where(
          (l) => l.type == LayerType.decoration,
        )) {
          expect(
            studioDecorations.any((s) => s.id == layer.imageBackground),
            true,
          );
        }
      }
    },
  );

  for (final s in [
    const Size(350, 500),
    const Size(500, 500),
    const Size(600, 400),
  ]) {
    test('frame geometry and all editable text fit at $s', () {
      for (final style in atelierEditionPhotoFrames) {
        final inset = StudioMaterial.photoInsets(style, s);
        expect(StudioMaterial.photoInsets(style, s * 2), inset * 2);
        final inner = inset.deflateRect(Offset.zero & s);
        expect(inner.width, greaterThan(s.width * .60));
        expect(inner.height, greaterThan(s.height * .60));
        final a = AtelierEditionFrame.aperture(style, inner.size);
        final b = AtelierEditionFrame.aperture(style, inner.size * 2);
        for (var x = 1; x < 10; x++) {
          for (var y = 1; y < 10; y++) {
            final p = Offset(inner.width * x / 10, inner.height * y / 10);
            expect(a.contains(p), b.contains(p * 2));
          }
        }
      }
      for (final art in atelierWordArts) {
        final layers = art.buildLayers(s);
        final texts = layers.where((l) => l.type == LayerType.text).toList();
        for (final layer in layers) {
          expect(layer.position.dx, greaterThanOrEqualTo(0));
          expect(layer.position.dy, greaterThanOrEqualTo(0));
          expect(layer.position.dx + layer.width, lessThanOrEqualTo(s.width));
          expect(layer.position.dy + layer.height, lessThanOrEqualTo(s.height));
        }
        for (final layer in texts) {
          final measure = TextPainter(
            text: TextSpan(text: layer.text, style: layer.textStyle),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: layer.width);
          expect(
            measure.height,
            lessThanOrEqualTo(layer.height + 1),
            reason: '${art.id}: ${layer.text}',
          );
          measure.dispose();
          for (final other in texts.where((l) => l.id != layer.id)) {
            final a = layer.position & Size(layer.width, layer.height);
            final b = other.position & Size(other.width, other.height);
            expect(
              a.deflate(.5).overlaps(b.deflate(.5)),
              false,
              reason: '${art.id}: ${layer.text} / ${other.text}',
            );
          }
        }
      }
    });
  }

  testWidgets('render every new material and export contact sheets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1440));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final groups = <String, List<({String id, String label, Widget view})>>{
      'frames': [
        for (final s in atelierEditionFrameStyles)
          (
            id: s.key,
            label: s.label,
            view: StudioMaterial(
              style: s.key,
              child: Image.asset(
                'assets/templates/original_editorial/images/petal_evening.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
      ],
      'lettering': [
        for (final art in atelierWordArts)
          (id: art.id, label: art.label, view: StudioWordArtPreview(art: art)),
      ],
      'papers': [
        for (final s in atelierCompositionDecorations)
          (
            id: s.id,
            label: s.label,
            view: Center(
              child: AspectRatio(
                aspectRatio: s.aspectRatio,
                child: StudioDecoration(spec: s),
              ),
            ),
          ),
      ],
    };
    const export = bool.fromEnvironment('EXPORT_MATERIALS');
    final out = Directory('output/materials/atelier-36');
    if (export) out.createSync(recursive: true);
    Future<void> save(ui.Image image, String name) async {
      if (export) {
        await tester.runAsync(() async {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '${out.path}/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        });
      }
      image.dispose();
    }

    for (final entry in groups.entries) {
      for (final item in entry.value) {
        final image = await capture(
          tester,
          SizedBox(
            width: 500,
            height: 500,
            child: ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: item.view,
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: item.id);
        await save(image, item.id);
      }
      final rows = (entry.value.length / 4).ceil();
      final image = await capture(
        tester,
        SizedBox(
          width: 1440,
          height: rows * 340,
          child: ColoredBox(
            color: Colors.white,
            child: Wrap(
              children: [
                for (final item in entry.value)
                  SizedBox(
                    width: 360,
                    height: 340,
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          Expanded(child: item.view),
                          const SizedBox(height: 12),
                          Text(
                            item.label,
                            style: const TextStyle(
                              fontFamily: 'NotoSans',
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await save(image, entry.key);
      expect(tester.takeException(), isNull);
    }
  });
}
