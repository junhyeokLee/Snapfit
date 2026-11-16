import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/frame_preview_photos.dart';
import 'package:snap_fit/core/templates/premium_quartet_frame_catalog.dart';
import 'package:snap_fit/core/templates/story_edition_catalog.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/point_shop/domain/premium_volume_registration.dart';
import 'package:snap_fit/features/store/data/api/material_provider.dart';
import 'package:snap_fit/features/store/presentation/widgets/material_preview_composition.dart';
import 'package:snap_fit/shared/widgets/image_frame_style_picker.dart';

void main() {
  test('new paid kit metadata is complete before any server overlay', () {
    final materials = {
      for (final item in bundledMaterials) item.productKey: item,
    };
    for (final book in premiumQuartetEditions) {
      expect(publishedCreationTemplateById(book.catalogId)?.pageCount, 32);
      final contents = pendingTemplateContentsLabel(book.productKey);
      expect(contents, contains('내지 32쪽'), reason: book.id);
      expect(contents, contains('전용 소재 8종'), reason: book.id);
      for (final key in book.includedMaterialKeys) {
        final material = materials[key];
        expect(material, isNotNull, reason: key);
        expect(
          material!.isPremium,
          isTrue,
          reason: '$key must reach the paid filter immediately',
        );
        expect(
          material.collection,
          book.title,
          reason: '$key must be searchable by its book title',
        );
      }
      for (final suffix in [
        'paper',
        'vellum',
        'motif',
        'keepsake',
        'caption',
      ]) {
        expect(storyEditionForMaterial('${book.id}-$suffix'), same(book));
      }
      expect(storyEditionForMaterial(book.id), same(book));
    }
    for (final book in storyEditions.where((e) => !e.isPremium)) {
      for (final key in book.materialKeys) {
        expect(materials[key]!.isPremium, isFalse, reason: '$key remains free');
      }
    }
  });

  test('both papers and both phrases preview their own book photography', () {
    for (final book in premiumQuartetEditions) {
      for (final suffix in [
        'paper',
        'vellum',
        'motif',
        'keepsake',
        '',
        'caption',
      ]) {
        final phrase = suffix.isEmpty || suffix == 'caption';
        final key = phrase
            ? 'phrase:collage-${book.id}${suffix.isEmpty ? '' : '-caption'}'
            : 'sticker:${book.id}-$suffix';
        for (var index = 0; index < 2; index++) {
          final preview = MaterialPreviewComposition.forProduct(
            key,
            phrase ? '문구' : '소재',
            photoIndex: index,
          );
          expect(preview.photoAsset, book.photoAssets[index], reason: key);
          expect(preview.caption, book.title, reason: key);
          expect(
            preview.photoRect!.width / preview.photoRect!.height,
            closeTo(1.5, .000001),
            reason: '$key preserves the full landscape sample',
          );
          expect(preview.materialRect.width, greaterThan(0));
          expect(preview.materialRect.height, greaterThan(0));
          if (suffix == 'paper' || suffix == 'vellum') {
            expect(
              preview.placement,
              MaterialPreviewPlacement.backing,
              reason: key,
            );
            expect(
              preview.materialRect.width / preview.materialRect.height,
              closeTo(1.25, .000001),
            );
          } else if (phrase) {
            expect(
              preview.placement,
              MaterialPreviewPlacement.lettering,
              reason: key,
            );
            expect(preview.letteringSourceSize, isNotNull, reason: key);
            expect(
              preview.materialRect.width / preview.materialRect.height,
              closeTo(preview.letteringSourceSize!.aspectRatio, .000001),
            );
          } else {
            expect(
              preview.placement,
              MaterialPreviewPlacement.accent,
              reason: key,
            );
            expect(
              preview.materialRect.width / preview.materialRect.height,
              closeTo(1, .000001),
            );
          }
        }
      }
    }
  });

  test(
    'every new mount has a matching picker entry and its own source photo',
    () {
      final frames = premiumQuartetEditions
          .expand((e) => e.photoFrames)
          .toSet();
      expect(premiumQuartetFramesById.keys.toSet(), frames);
      expect(premiumQuartetFrameBookIds.keys.toSet(), frames);
      for (final book in premiumQuartetEditions) {
        final sources = <String>{};
        for (var index = 0; index < book.photoFrames.length; index++) {
          final frame = book.photoFrames[index];
          expect(
            imageFrameStyles.where((style) => style.key == frame),
            hasLength(1),
          );
          expect(premiumQuartetFrameBookIds[frame], book.id);
          expect(
            framePreviewPhotos[frame],
            book.photoAssets[index == 0 ? 1 : 4],
          );
          expect(sources.add(framePreviewPhotos[frame]!), isTrue);
        }
      }
    },
  );

  testWidgets(
    'all new store frames keep the entire sample photo at both sizes',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final frame in premiumQuartetFramesById.keys) {
        for (final size in [const Size(96, 96), const Size(600, 680)]) {
          Size? aperture;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox.fromSize(
                    size: size,
                    child: ImageFramePreview(
                      style: imageFrameStyles.singleWhere(
                        (s) => s.key == frame,
                      ),
                      child: LayoutBuilder(
                        builder: (_, constraints) {
                          aperture = constraints.biggest;
                          return const SizedBox.expand();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: frame);
          expect(aperture, isNotNull, reason: frame);
          expect(aperture!.aspectRatio, closeTo(1.5, .000001), reason: frame);
        }
      }
    },
  );
}
