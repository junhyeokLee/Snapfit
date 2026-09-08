import 'dart:io';
import 'package:snap_fit/core/templates/studio_photo_frame_catalog.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/data/album_creation_catalog_provider.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';

import 'ai_album_start_step_test.dart' show wrapCreation, loadCreationFonts;

class _Photo extends Mock implements AssetEntity {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCreationFonts);

  test(
    'creation catalog excludes all other products after remote refresh',
    () async {
      final remote = bundledCreationTemplates.first.copyWith(
        id: 786,
        title: 'Remote product',
        isPremium: true,
      );
      final container = ProviderContainer(
        overrides: [
          templateListProvider.overrideWith((ref) async => [remote]),
        ],
      );
      addTearDown(container.dispose);
      final events = <List<PremiumTemplate>>[];
      final subscription = container.listen(albumCreationCatalogProvider, (
        _,
        next,
      ) {
        next.whenData(events.add);
      }, fireImmediately: true);
      addTearDown(subscription.close);
      await container.read(albumCreationCatalogProvider.future);
      for (var i = 0; i < 100 && events.length < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(
        events.first.map((t) => t.id),
        bundledCreationTemplates.map((t) => t.id),
      );
      expect(events.length, greaterThanOrEqualTo(2));
      expect(events.last.any((t) => t.id == 786), false);
      for (final items in events) {
        expect(
          items.map((t) => t.id),
          bundledCreationTemplates.map((t) => t.id),
        );
      }
    },
  );

  for (final template in bundledCreationTemplates) {
    for (final size in [const Size(390, 844), const Size(844, 390)]) {
      testWidgets(
        '${template.title} at $size: offline preview selects all five physical sizes',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          AlbumCreationTemplate? result;
          await tester.pumpWidget(
            ProviderScope(
              child: wrapCreation(
                Builder(
                  builder: (context) => TextButton(
                    onPressed: () async {
                      result = await Navigator.push<AlbumCreationTemplate>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TemplateDetailScreen(
                            template: template,
                            selectForCreation: true,
                          ),
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.text(template.title),
            ),
            findsOneWidget,
          );
          await tester.tap(find.text('이 디자인 선택'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(result, isNotNull);
          expect(result!.isPremium, false);
          expect(result!.preserveTypography, true);
          expect(result!.pages.length, template.pageCount + 1);
          expect(
            template.pageCount,
            template.id == windAtlasBundledId ? 32 : 24,
          );
          expect(
            result!.variants.keys,
            unorderedEquals([
              'REDP_200_SOFT',
              'REDP_200X150_SOFT',
              'REDP_250X200_SOFT',
              'REDP_250_SOFT',
              'REDP_300_SOFT',
            ]),
          );
          expect(
            result!.variantCanvasSizes.keys,
            unorderedEquals(result!.variants.keys),
          );
          expect(result!.pagesCanvasSize, coverCanvasBaseSize(result!.cover));
          for (final cover in coverSizes) {
            expect(
              result!.variantCanvasSizes[cover.productId],
              coverCanvasBaseSize(cover),
            );
          }
          for (final pages in result!.variants.values) {
            expect(pages.length, template.pageCount + 1);
            final photos = pages
                .expand((p) => p)
                .where((l) => l.type == LayerType.image);
            expect(
              photos.every(
                (l) =>
                    l.imageUrl == null &&
                    (l.imageBackground == 'none' ||
                        studioPhotoFrames.contains(l.imageBackground)),
              ),
              true,
            );
          }
          // Same orientation must still retain three distinct physical canvases.
          // Every layer grows uniformly, including ornaments and photo masks.
          final small = result!.variants['REDP_200_SOFT']!;
          for (final larger in [
            ('REDP_250_SOFT', 1.25),
            ('REDP_300_SOFT', 1.5),
          ]) {
            final pages = result!.variants[larger.$1]!;
            for (var page = 0; page < small.length; page++) {
              expect(pages[page].length, small[page].length);
              for (var index = 0; index < small[page].length; index++) {
                final original = small[page][index];
                final scaled = pages[page][index];
                expect(scaled.id, original.id);
                expect(
                  scaled.width,
                  closeTo(original.width * larger.$2, .0001),
                );
                expect(
                  scaled.height,
                  closeTo(original.height * larger.$2, .0001),
                );
                expect(
                  scaled.position.dx,
                  closeTo(original.position.dx * larger.$2, .0001),
                );
                expect(
                  scaled.position.dy,
                  closeTo(original.position.dy * larger.$2, .0001),
                );
                expect(scaled.rotation, original.rotation);
                expect(scaled.imageBackground, original.imageBackground);
              }
            }
          }
        },
      );
    }
  }

  for (final collection in authoredCollections) {
    testWidgets(
      '${collection.title}: actual photo picker preserves mask, ornaments and geometry',
      (tester) async {
        const aspect = CollectionAspect.square;
        var pages = AlbumCreationTemplate.preparePages(
          templateDocumentPages(collection.document(aspect))
              .map(
                (p) => DataTemplateEngine.buildLayersFromJson(p, aspect.canvas),
              )
              .toList(),
          sourceCanvas: aspect.canvas,
          cover: aspect.cover,
        );
        final photoPage = pages.indexWhere(
          (page) => page.any((l) => l.type == LayerType.image),
        );
        expect(photoPage, greaterThanOrEqualTo(0));
        final originals = pages[photoPage];
        final slot = originals.firstWhere((l) => l.type == LayerType.image);
        final photo = _Photo();
        when(
          () => photo.file,
        ).thenAnswer((_) async => File('assets/snapfit_home_square.jpg'));
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          ProviderScope(
            child: wrapCreation(
              StatefulBuilder(
                builder: (context, setState) => TemplatePhotoFillStep(
                  pages: pages,
                  cover: aspect.cover,
                  preserveTypography: true,
                  onChanged: (value) => setState(() => pages = value),
                  onContinue: () {},
                  pickPhoto: () async => photo,
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('사진 추가'));
        await tester.pumpAndSettle();
        final filled = pages[photoPage].singleWhere((l) => l.id == slot.id);
        expect(filled.asset, same(photo));
        expect(filled.imageBackground, slot.imageBackground);
        expect(filled.position, slot.position);
        expect(filled.width, slot.width);
        expect(filled.height, slot.height);
        expect(filled.rotation, slot.rotation);
        for (var i = 0; i < originals.length; i++) {
          if (originals[i].id != slot.id)
            expect(pages[photoPage][i], same(originals[i]));
        }
        await tester.binding.setSurfaceSize(const Size(844, 390));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          pages[photoPage].singleWhere((l) => l.id == slot.id).asset,
          same(photo),
        );
      },
    );
  }
}
