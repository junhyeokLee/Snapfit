@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/gallery/browser_gallery_repository.dart';
import 'package:snap_fit/features/album/data/gallery/browser_photo_asset.dart';
import 'package:snap_fit/features/album/data/gallery/browser_photo_files.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/photo_crop_sheet.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_book_artwork.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import 'package:snap_fit/shared/widgets/browser_photo_selection_sheet.dart';
import 'package:snap_fit/shared/widgets/gallery_thumb_tile.dart';

import '../unit/browser_photo_import_test.dart' show browserPhotoFixture;
import 'ai_album_start_step_test.dart' show wrapCreation;
import 'photo_crop_sheet_test.dart' show waitForCropPhoto;

class _Host extends StatefulWidget {
  const _Host({super.key, required this.fixedPhoto});
  final BrowserPhotoAsset fixedPhoto;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final session = TemplatePhotoFillSession();
  final canvas = coverCanvasBaseSize(defaultCoverSize);
  late List<List<LayerModel>> pages = [
    [
      LayerModel(
        id: 'cover-photo',
        type: LayerType.image,
        position: Offset.zero,
        width: canvas.width,
        height: canvas.height,
        imageBackground: 'none',
      ),
      LayerModel(
        id: 'fixed-cover-photo',
        type: LayerType.image,
        position: Offset(24, canvas.height - 104),
        width: 80,
        height: 80,
        imageBackground: 'none',
        asset: widget.fixedPhoto,
        imageZoom: 1.25,
        imageOffset: const Offset(12, -8),
        zIndex: 1,
      ),
      LayerModel(
        id: 'cover-title',
        type: LayerType.text,
        position: const Offset(24, 24),
        width: canvas.width - 48,
        height: 48,
        text: '오래 기억할 우리의 여행',
        textStyle: const TextStyle(fontFamily: 'NotoSans', fontSize: 22),
        zIndex: 2,
      ),
    ],
    [
      LayerModel(
        id: 'interior-photo',
        type: LayerType.image,
        position: const Offset(40, 40),
        width: canvas.width - 80,
        height: canvas.height - 80,
        imageBackground: 'none',
      ),
    ],
  ];
  int changes = 0;

  LayerModel get coverPhoto =>
      pages.first.firstWhere((layer) => layer.id == 'cover-photo');

  @override
  Widget build(BuildContext context) => TemplatePhotoFillStep(
    session: session,
    pages: pages,
    cover: defaultCoverSize,
    onChanged: (value) => setState(() {
      pages = value;
      changes++;
    }),
    onContinue: () {},
    // Exercise the production browser multi-select route, not picker callbacks.
  );
}

Finder _visibleCover() => find.descendant(
  of: find.byType(TemplateBookArtwork),
  matching: find.byType(TemplatePageRenderer),
);

Future<void> _settlePhotos(WidgetTester tester) async {
  // Browser thumbnail codecs complete on the real event loop. Repeated fake
  // frames alone keep their progress indicators animating indefinitely.
  await tester.pump(const Duration(milliseconds: 400));
  for (var attempt = 0; attempt < 150; attempt++) {
    final thumbnailsReady = find
        .byType(GalleryThumbTile)
        .evaluate()
        .every(
          (element) => find
              .descendant(
                of: find.byWidget(element.widget),
                matching: find.byType(RawImage),
              )
              .evaluate()
              .any((pixels) => (pixels.widget as RawImage).image != null),
        );
    final imagesReady = find
        .byType(Image)
        .evaluate()
        .every(
          (element) => find
              .descendant(
                of: find.byWidget(element.widget),
                matching: find.byType(RawImage),
              )
              .evaluate()
              .any((pixels) => (pixels.widget as RawImage).image != null),
        );
    if (thumbnailsReady &&
        imagesReady &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      await tester.pumpAndSettle();
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  fail('Browser gallery and tray photographs did not finish decoding.');
}

Future<void> _tapCover(WidgetTester tester) async {
  await tester.tapAt(tester.getRect(_visibleCover()).center);
  await _settlePhotos(tester);
}

Future<void> _history(WidgetTester tester, String action) async {
  await tester.tap(find.byKey(ValueKey('photo-fill-$action')));
  await _settlePhotos(tester);
}

void main() {
  for (final size in [const Size(390, 844), const Size(1000, 800)]) {
    testWidgets(
      'web cover accepts actual gallery tray taps, crop and undo $size',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final originals = <Uint8List>[
          browserPhotoFixture(width: 40, height: 40),
          browserPhotoFixture(width: 60, height: 120),
        ];
        final repository = BrowserGalleryRepository(
          currentOwner: () => 'cover-owner',
        );
        await tester.runAsync(
          () => repository.importFiles([
            for (var i = 0; i < originals.length; i++)
              BrowserPhotoFile(
                name: 'cover-$i.png',
                size: originals[i].length,
                readBytes: () async => originals[i],
              ),
          ]),
        );
        final photos = repository.photos;
        expect(photos.length, 2);
        final fixedOriginal = browserPhotoFixture(width: 40, height: 60);
        final fixedAsset = await tester.runAsync(
          () => BrowserPhotoAsset.fromBytes(
            ownerId: 'cover-owner',
            name: 'already-placed.png',
            bytes: fixedOriginal,
          ),
        );
        final host = GlobalKey<_HostState>();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              galleryRepositoryProvider.overrideWithValue(repository),
              visibleOrderOwnerProvider.overrideWith((ref) => 'cover-owner'),
            ],
            child: wrapCreation(_Host(key: host, fixedPhoto: fixedAsset!)),
          ),
        );
        await _settlePhotos(tester);
        final originalSlot = host.currentState!.coverPhoto;
        final fixedPhoto = host.currentState!.pages.first.firstWhere(
          (layer) => layer.id == 'fixed-cover-photo',
        );
        final title = host.currentState!.pages.first.firstWhere(
          (layer) => layer.id == 'cover-title',
        );

        await tester.tap(find.byKey(const ValueKey('fill-add-photos')));
        await _settlePhotos(tester);
        expect(find.byType(BrowserPhotoSelectionSheet), findsOneWidget);
        expect(
          tester
              .widget<BrowserPhotoSelectionSheet>(
                find.byType(BrowserPhotoSelectionSheet),
              )
              .maxSelection,
          100,
        );
        for (final photo in photos) {
          await tester.tap(find.byKey(ValueKey('browser-photo-${photo.id}')));
        }
        await _settlePhotos(tester);
        await tester.tap(
          find.byKey(const ValueKey('confirm-browser-photo-selection')),
        );
        await _settlePhotos(tester);
        expect(find.byType(BrowserPhotoSelectionSheet), findsNothing);
        expect(host.currentState!.changes, 0);
        expect(host.currentState!.session.pendingPhotos, photos);

        // This real hit test failed when flat web covers were treated like the
        // native book's noninteractive binding duplicate.
        await _tapCover(tester);
        expect(host.currentState!.coverPhoto.asset, same(photos[0]));
        expect(host.currentState!.changes, 1);
        expect(
          tester.widget<TemplatePageRenderer>(_visibleCover()).selectedLayerId,
          originalSlot.id,
        );
        expect(find.byTooltip('사진 구도 조정'), findsOneWidget);
        expect(host.currentState!.pages[1].single.hasImageSource, isFalse);

        await tester.tap(find.byTooltip('사진 선택 해제'));
        await _settlePhotos(tester);
        expect(find.byTooltip('사진 교체'), findsNothing);
        await _tapCover(tester);
        expect(find.byTooltip('사진 교체'), findsOneWidget);
        expect(host.currentState!.changes, 1);

        await tester.tap(find.byKey(ValueKey('tray-photo-${photos[1].id}')));
        await tester.tap(find.byTooltip('사진 교체'));
        await waitForCropPhoto(tester);
        final replacementReview = tester.widget<PhotoCropSheet>(
          find.byType(PhotoCropSheet),
        );
        expect(replacementReview.title, '표지 사진 구도');
        expect(replacementReview.layer.asset, same(photos[1]));
        expect(replacementReview.pageContext, isNotNull);
        expect(host.currentState!.coverPhoto.asset, same(photos[0]));
        await tester.tap(find.byKey(const ValueKey('photo-crop-apply')));
        await _settlePhotos(tester);
        expect(host.currentState!.coverPhoto.asset, same(photos[1]));
        expect(host.currentState!.session.pendingPhotos, [photos[0]]);
        await _history(tester, 'undo');
        expect(host.currentState!.coverPhoto.asset, same(photos[0]));
        expect(host.currentState!.session.pendingPhotos, [photos[1]]);
        await _history(tester, 'redo');
        expect(host.currentState!.coverPhoto.asset, same(photos[1]));

        await tester.tap(find.byTooltip('사진 구도 조정'));
        await waitForCropPhoto(tester);
        expect(find.byType(PhotoCropSheet), findsOneWidget);
        await tester.tap(find.byTooltip('사진 확대'));
        await _settlePhotos(tester);
        await tester.tap(find.byKey(const ValueKey('photo-crop-anchor-0')));
        await _settlePhotos(tester);
        final cropSheet = find.byType(PhotoCropSheet);
        final photoDraft = tester
            .widget<TemplatePageRenderer>(
              find.descendant(
                of: cropSheet,
                matching: find.byType(TemplatePageRenderer),
              ),
            )
            .layers
            .single;
        await tester.tap(
          find.byKey(const ValueKey('photo-crop-context-toggle')),
        );
        await _settlePhotos(tester);
        final pageContext = find.byKey(
          const ValueKey('photo-crop-page-context'),
        );
        expect(pageContext, findsOneWidget);
        final paper = find.descendant(
          of: pageContext,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ColoredBox &&
                widget.color == Colors.white &&
                widget.child is TemplatePageRenderer,
          ),
        );
        expect(paper, findsOneWidget);
        final pageRenderer = tester.widget<TemplatePageRenderer>(
          find.descendant(
            of: paper,
            matching: find.byType(TemplatePageRenderer),
          ),
        );
        final pageDraft = pageRenderer.layers.firstWhere(
          (layer) => layer.id == originalSlot.id,
        );
        expect(pageDraft.asset, same(photos[1]));
        expect(pageDraft.imageZoom, photoDraft.imageZoom);
        expect(pageDraft.imageOffset, photoDraft.imageOffset);
        expect(
          pageRenderer.layers.firstWhere((layer) => layer.id == fixedPhoto.id),
          same(fixedPhoto),
        );
        expect(
          pageRenderer.layers.firstWhere((layer) => layer.id == title.id),
          same(title),
        );
        expect(
          find.descendant(of: pageContext, matching: find.text(title.text!)),
          findsOneWidget,
        );
        expect(host.currentState!.coverPhoto.imageZoom, 1);
        expect(host.currentState!.coverPhoto.imageOffset, isNull);
        await tester.tap(
          find.byKey(const ValueKey('photo-crop-context-toggle')),
        );
        await _settlePhotos(tester);
        expect(pageContext, findsNothing);
        final restoredDraft = tester
            .widget<TemplatePageRenderer>(
              find.descendant(
                of: cropSheet,
                matching: find.byType(TemplatePageRenderer),
              ),
            )
            .layers
            .single;
        expect(restoredDraft.imageZoom, photoDraft.imageZoom);
        expect(restoredDraft.imageOffset, photoDraft.imageOffset);
        await tester.tap(find.byKey(const ValueKey('photo-crop-apply')));
        await _settlePhotos(tester);
        final cropped = host.currentState!.coverPhoto;
        expect(cropped.imageZoom, closeTo(1.1, .001));
        expect(cropped.imageOffset, isNot(Offset.zero));
        expect(cropped.asset, same(photos[1]));
        expect(cropped.position, originalSlot.position);
        expect(cropped.width, originalSlot.width);
        expect(cropped.height, originalSlot.height);
        expect(cropped.imageBackground, originalSlot.imageBackground);

        await _history(tester, 'undo');
        expect(host.currentState!.coverPhoto.asset, same(photos[1]));
        expect(host.currentState!.coverPhoto.imageZoom, 1);
        expect(host.currentState!.coverPhoto.imageOffset, isNull);
        await _history(tester, 'redo');
        expect(host.currentState!.coverPhoto.imageOffset, cropped.imageOffset);
        expect(host.currentState!.coverPhoto.imageZoom, cropped.imageZoom);
        expect(
          host.currentState!.pages.first.firstWhere(
            (layer) => layer.id == fixedPhoto.id,
          ),
          same(fixedPhoto),
        );
        expect(
          host.currentState!.pages.first.firstWhere(
            (layer) => layer.id == title.id,
          ),
          same(title),
        );
        for (var i = 0; i < photos.length; i++) {
          expect(photos[i], isA<BrowserPhotoAsset>());
          expect(photos[i].originalBytes, orderedEquals(originals[i]));
        }
        expect(fixedAsset.originalBytes, orderedEquals(fixedOriginal));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
