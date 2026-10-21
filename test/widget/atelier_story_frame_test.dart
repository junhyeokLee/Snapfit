import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/frame_preview_photos.dart';
import 'package:snap_fit/core/templates/free_template_material_policy.dart';
import 'package:snap_fit/core/templates/studio_photo_frame_catalog.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_known_products.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/shared/widgets/atelier_story_frame.dart';
import 'package:snap_fit/shared/widgets/image_frame_style_picker.dart';
import 'package:snap_fit/shared/widgets/studio_material.dart';
import 'ai_album_start_step_test.dart' show wrapCreation;

void main() {
  test('story frames have stable previews and paid-only identities', () {
    expect(atelierStoryPhotoFrames, hasLength(4));
    expect(
      atelierStoryPhotoFrames.map((k) => framePreviewPhotos[k]).toSet(),
      hasLength(4),
    );
    for (final key in atelierStoryPhotoFrames) {
      final productKey = 'frame:$key';
      expect(studioPhotoFrames, contains(key));
      expect(imageFrameStyles.where((f) => f.key == key), hasLength(1));
      expect(
        pointShopKnownProducts.where((p) => p.productKey == productKey),
        hasLength(1),
      );
      expect(
        pointShopLaunchPrices[productKey]!.points,
        key.startsWith('storyVow') ? 400 : 300,
      );
      expect(isPendingAtelierMaterialProduct(productKey), false);
      expect(freeTemplateMaterialProductKeys, isNot(contains(productKey)));
      expect(
        freeTemplateMaterialIssues({
          'cover': {
            'layers': [
              {'type': 'image', 'frame': key},
            ],
          },
        }),
        contains(productKey),
      );
    }
    for (final aspect in CollectionAspect.values) {
      final wedding = templateVisualMaterialKeys(
        StudioEdition.velvetVowArchive.document(aspect),
      );
      final growth = templateVisualMaterialKeys(
        StudioEdition.littleExplorerBook.document(aspect),
      );
      expect(
        wedding,
        containsAll(['frame:storyVowGate', 'frame:storyVowCotton']),
      );
      expect(
        growth,
        containsAll([
          'frame:storyDiscoverySlide',
          'frame:storyDiscoveryStitch',
        ]),
      );
      expect(
        wedding
            .intersection(growth)
            .where((k) => (pointShopLaunchPrices[k]?.points ?? 0) > 0),
        isEmpty,
      );
    }
  });

  test('photo replacement and serialization keep the frame and crop', () {
    for (final key in atelierStoryPhotoFrames) {
      final original = LayerModel(
        id: key,
        type: LayerType.image,
        position: const Offset(30, 40),
        width: 320,
        height: 230,
        imageBackground: key,
        imageUrl: 'asset:${framePreviewPhotos[key]}',
        imageOffset: const Offset(16, -10),
        imageZoom: 1.2,
      );
      final replacement = original.copyWith(
        imageUrl: 'asset:assets/frame_preview/quiet_room.jpg',
      );
      final restored = LayerExportMapper.fromJson(
        LayerExportMapper.toJson(replacement, canvasSize: const Size(500, 500)),
        canvasSize: const Size(500, 500),
      );
      expect(restored.imageBackground, key);
      expect(restored.position, original.position);
      expect(restored.imageOffset, original.imageOffset);
      expect(restored.imageZoom, original.imageZoom);
      expect(restored.imageUrl, replacement.imageUrl);
    }
  });

  testWidgets('unlisted story frames are never labeled free in the editor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapCreation(
        ImageFrameStylePicker(selectedKey: null, onSelect: (_) {}),
        showShell: false,
      ),
    );
    await tester.pumpAndSettle();
    for (final key in atelierStoryPhotoFrames) {
      final tile = find.byKey(ValueKey('frame-$key'));
      expect(tile, findsOneWidget);
      expect(
        find.descendant(of: tile, matching: find.text('무료')),
        findsNothing,
      );
      expect(
        find.descendant(of: tile, matching: find.text('판매 준비 중')),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(220, 300),
    const Size(260, 260),
    const Size(320, 210),
  ]) {
    testWidgets(
      '$size: unique artwork, transparent edges and an unobscured live photograph',
      (tester) async {
        final hashes = <String>{};
        for (final style in atelierStoryPhotoFrames) {
          final key = GlobalKey();
          final opening = AtelierStoryFrame.insets(
            style,
            size,
          ).deflateRect(Offset.zero & size);
          expect(opening.width / size.width, greaterThan(.70));
          expect(opening.height / size.height, greaterThan(.70));
          expect(
            StudioMaterial.photoInsets(style, size),
            AtelierStoryFrame.insets(style, size),
          );
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: RepaintBoundary(
                  key: key,
                  child: SizedBox.fromSize(
                    size: size,
                    child: StudioMaterial(
                      style: style,
                      child: const ColoredBox(color: Color(0xFFFA00C8)),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: style);
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            expect(
              hashes.add(sha256.convert(bytes).toString()),
              true,
              reason: style,
            );
            final center = Rect.fromCenter(
              center: opening.center * 2,
              width: opening.width,
              height: opening.height,
            );
            for (var y = center.top.ceil(); y < center.bottom; y += 9) {
              for (var x = center.left.ceil(); x < center.right; x += 9) {
                final at = (y * image.width + x) * 4;
                expect(bytes.sublist(at, at + 4), [
                  250,
                  0,
                  200,
                  255,
                ], reason: '$style covers the photo at $x/$y');
              }
            }
            expect(
              bytes[3],
              lessThan(80),
              reason: '$style lost transparent exterior corners',
            );
            image.dispose();
          });
        }
      },
    );
  }
}
