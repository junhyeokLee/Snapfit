import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/free_template_material_policy.dart';
import 'package:snap_fit/core/templates/studio_photo_frame_catalog.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/shared/widgets/atelier_signature_frame.dart';
import 'package:snap_fit/shared/widgets/image_frame_style_picker.dart';
import 'package:snap_fit/shared/widgets/studio_material.dart';
import 'ai_album_start_step_test.dart' show wrapCreation;

void main() {
  testWidgets('an unlisted paid signature never advertises itself as free', (
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
    final tile = find.byKey(const ValueKey('frame-signatureVowPocket'));
    expect(tile, findsOneWidget);
    expect(
      find.descendant(of: tile, matching: find.text('판매 준비 중')),
      findsOneWidget,
    );
    expect(find.descendant(of: tile, matching: find.text('무료')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test(
    'signature frames are registered paid proposals, never free-book assets',
    () {
      expect(atelierSignaturePhotoFrames, hasLength(7));
      for (final key in atelierSignaturePhotoFrames) {
        expect(studioPhotoFrames, contains(key));
        expect(imageFrameStyles.where((s) => s.key == key), hasLength(1));
        expect(pointShopLaunchPrices['frame:$key']?.points, 400);
        expect(isPendingAtelierMaterialProduct('frame:$key'), false);
        expect(freeTemplateMaterialProductKeys, isNot(contains('frame:$key')));
      }
      for (final aspect in CollectionAspect.values) {
        for (final free in authoredCollections) {
          expect(freeTemplateMaterialIssues(free.document(aspect)), isEmpty);
        }
        final used = <String>{};
        for (final edition in AtelierEdition.values) {
          final doc = edition.document(aspect);
          final signatures = templateVisualMaterialKeys(
            doc,
          ).where((key) => key.startsWith('frame:signature'));
          expect(signatures, hasLength(1), reason: edition.id);
          used.addAll(signatures);
          final titles = [
            for (final page in templateDocumentPages(doc).skip(1))
              for (final layer in (page['layers'] as List).cast<Map>())
                if (layer['typographyRole'] == 'signature-title') layer,
          ];
          expect(titles.length, greaterThanOrEqualTo(12));
          expect(titles.every((t) => t['typographyStyle'] == edition.id), true);
        }
        expect(
          used,
          atelierSignaturePhotoFrames.map((s) => 'frame:$s').toSet(),
        );
      }
    },
  );

  test('photo replacement and saved roundtrip retain signature structure', () {
    for (final key in atelierSignaturePhotoFrames) {
      final original = LayerModel(
        id: 'replace-$key',
        type: LayerType.image,
        position: const Offset(20, 30),
        width: 260,
        height: 200,
        imageBackground: key,
        imageUrl: 'asset:assets/templates/atelier_editions_2026/slow-rail.png',
      );
      final replaced = original.copyWith(
        imageUrl:
            'asset:assets/templates/jeju_travel/images/approved_stock/road_window.jpg',
      );
      final restored = LayerExportMapper.fromJson(
        LayerExportMapper.toJson(replaced, canvasSize: const Size(500, 500)),
        canvasSize: const Size(500, 500),
      );
      expect(restored.imageBackground, key);
      expect(restored.imageUrl, replaced.imageUrl);
      expect(restored.position, original.position);
      expect(restored.width, original.width);
      expect(restored.height, original.height);
    }
  });

  for (final size in [
    const Size(220, 300),
    const Size(260, 260),
    const Size(320, 210),
  ]) {
    testWidgets(
      '$size: all signature frames preserve a clear photo center and distinct artwork',
      (tester) async {
        final hashes = <String>{};
        for (final style in atelierSignaturePhotoFrames) {
          final key = GlobalKey();
          final opening = AtelierSignatureFrame.insets(
            style,
            size,
          ).deflateRect(Offset.zero & size);
          expect(opening.width / size.width, greaterThan(.65));
          expect(opening.height / size.height, greaterThan(.65));
          expect(
            StudioMaterial.photoInsets(style, size),
            AtelierSignatureFrame.insets(style, size),
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
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            expect(
              hashes.add(sha256.convert(bytes).toString()),
              true,
              reason: style,
            );
            final center = Rect.fromCenter(
              center: opening.center,
              width: opening.width * .60,
              height: opening.height * .60,
            );
            for (var y = center.top.ceil(); y < center.bottom; y += 7) {
              for (var x = center.left.ceil(); x < center.right; x += 7) {
                final offset = (y * image.width + x) * 4;
                expect(bytes.sublist(offset, offset + 4), [
                  250,
                  0,
                  200,
                  255,
                ], reason: '$style photo obscured at $x/$y');
              }
            }
            image.dispose();
          });
        }
      },
    );
  }
}
