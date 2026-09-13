import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/studio_photo_frame_catalog.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'package:snap_fit/shared/widgets/image_frame_style_picker.dart';
import 'package:snap_fit/shared/widgets/studio_material.dart';
import 'package:snap_fit/shared/widgets/study_photo_frame.dart';
import '../helpers/mock_repositories.dart';
import '../unit/album_editor_view_model_test.dart'
    show FakeAlbumPersistenceService, FakeStorageService, MockAssetEntity;
import 'ai_album_start_step_test.dart' show wrapCreation, loadCreationFonts;
import 'studio_decorations_test.dart' show capture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCreationFonts);

  test('prose and approved edition mounts are selectable', () {
    expect(StudioMaterial.photoStyles, containsAll(studyPhotoFrames));
    expect(
      imageFrameStyles.map((s) => s.key).toSet(),
      containsAll(studyPhotoFrames),
    );
    expect(
      imageFrameStyles
          .map((s) => s.key)
          .toSet()
          .intersection(editionPhotoFrames),
      containsAll(editionPhotoFrames),
    );
    for (final aspect in CollectionAspect.values) {
      final size = aspect.canvas;
      for (final style in studyPhotoFrames) {
        final inset = StudyPhotoFrame.photoInsets(style, size);
        final window = inset.deflateRect(Offset.zero & size);
        expect(window.width, greaterThan(size.width * .8));
        expect(window.height, greaterThan(size.height * .8));
        expect(StudyPhotoFrame.photoInsets(style, size * 2), inset * 2);
        final path = StudyPhotoFrame.windowPath(style, window.size);
        final doubled = StudyPhotoFrame.windowPath(style, window.size * 2);
        expect(path.getBounds().left, closeTo(0, .001));
        expect(path.getBounds().top, closeTo(0, .001));
        expect(path.getBounds().right, closeTo(window.width, .001));
        expect(path.getBounds().bottom, closeTo(window.height, .001));
        expect(path.contains(window.size.center(Offset.zero)), true);
        for (var x = 0; x <= 30; x++) {
          for (var y = 0; y <= 30; y++) {
            final point = Offset(window.width * x / 30, window.height * y / 30);
            expect(path.contains(point), doubled.contains(point * 2));
          }
        }
      }
    }
  });

  test(
    'eight Korean frame entries remain compatible with archived documents',
    () {
      expect(StudioMaterial.newPhotoStyles.length, 8);
      expect(
        imageFrameStyles.map((s) => s.key).toSet().length,
        imageFrameStyles.length,
      );
      for (final key in StudioMaterial.newPhotoStyles) {
        expect(
          imageFrameStyles.singleWhere((s) => s.key == key).label,
          matches(RegExp(r'^[가-힣 ]+$')),
        );
      }
      for (final aspect in CollectionAspect.values) {
        final used = retiredAuthoredCollections
            .expand((c) => templateDocumentPages(c.document(aspect)))
            .expand((page) => page['layers'] as List)
            .map((layer) => (layer as Map)['frame'])
            .toSet();
        expect(used, containsAll(StudioMaterial.newPhotoStyles));
      }
    },
  );

  for (final aspect in CollectionAspect.values) {
    final size = aspect.canvas;
    test(
      '${aspect.name}: paths fit saved bounds and scale without changing contour',
      () {
        for (final key in StudioMaterial.newPhotoStyles) {
          final path = StudioMaterialClipper(key).getClip(size);
          final twice = StudioMaterialClipper(key).getClip(size * 2);
          final bounds = path.getBounds();
          expect(bounds.left, greaterThanOrEqualTo(-.01));
          expect(bounds.top, greaterThanOrEqualTo(-.01));
          expect(bounds.right, lessThanOrEqualTo(size.width + .01));
          expect(bounds.bottom, lessThanOrEqualTo(size.height + .01));
          expect(path.contains(size.center(Offset.zero)), isTrue);
          for (var x = 0; x <= 40; x++) {
            for (var y = 0; y <= 40; y++) {
              final p = Offset(size.width * x / 40, size.height * y / 40);
              expect(
                path.contains(p),
                twice.contains(p * 2),
                reason: '$key at $p',
              );
            }
          }
          final inset = StudioMaterial.photoInsets(key, size);
          expect(
            inset.deflateRect(Offset.zero & size).width,
            greaterThan(size.width * .7),
          );
          expect(
            inset.deflateRect(Offset.zero & size).height,
            greaterThan(size.height * .7),
          );
        }
      },
    );

    test(
      '${aspect.name}: frame changes, photo replacement, undo and save retain crop and geometry',
      () async {
        final container = ProviderContainer(
          overrides: [
            albumRepositoryProvider.overrideWithValue(MockAlbumRepository()),
            albumEditorServiceProvider.overrideWithValue(
              const AlbumEditorService(),
            ),
            albumPersistenceServiceProvider.overrideWithValue(
              FakeAlbumPersistenceService(),
            ),
            storageServiceProvider.overrideWithValue(FakeStorageService()),
          ],
        );
        addTearDown(container.dispose);
        await container.read(albumEditorViewModelProvider.future);
        final vm = container.read(albumEditorViewModelProvider.notifier);
        final asset = MockAssetEntity();
        for (final key in StudioMaterial.photoStyles) {
          vm.resetForCreate(initialCover: aspect.cover, targetPages: 2);
          final original = LayerModel(
            id: 'photo',
            type: LayerType.image,
            position: const Offset(30, 40),
            width: size.width * .6,
            height: size.height * .6,
            imageOffset: const Offset(8, -12),
            rotation: -.04,
            imageUrl: 'asset:assets/snapfit_home_square.jpg',
            imageBackground: 'studioOval',
          );
          vm.updatePageLayers([original], recordHistory: false);
          vm.updateImageFrame(original.id, key);
          expect(vm.pages.first.layers.single.imageBackground, key);
          vm.undo();
          expect(vm.pages.first.layers.single.imageBackground, 'studioOval');
          vm.redo();
          expect(vm.pages.first.layers.single.imageBackground, key);
          final saved = LayerExportMapper.fromJson(
            LayerExportMapper.toJson(
              vm.pages.first.layers.single,
              canvasSize: size,
            ),
            canvasSize: size,
          );
          expect(saved.imageBackground, key);
          expect(saved.imageOffset, original.imageOffset);
          expect(saved.rotation, original.rotation);
          await vm.updateSlotImage(original.id, asset);
          final replaced = vm.pages.first.layers.single;
          expect(replaced.asset, same(asset));
          expect(replaced.imageUrl, isNull);
          expect(replaced.imageBackground, key);
          expect(replaced.imageOffset, original.imageOffset);
          expect(replaced.width, original.width);
          expect(replaced.height, original.height);
          expect(replaced.position, original.position);
          vm.undo();
          expect(vm.pages.first.layers.single.imageUrl, original.imageUrl);
          expect(vm.pages.first.layers.single.imageBackground, key);
        }
      },
    );
  }

  test(
    'photo offset scales with the image slot and older documents stay compatible',
    () {
      const size = Size(400, 600);
      final layer = LayerModel(
        id: 'crop',
        type: LayerType.image,
        position: Offset.zero,
        width: 200,
        height: 300,
        imageOffset: const Offset(20, -30),
      );
      final json = LayerExportMapper.toJson(layer, canvasSize: size);
      final restored = LayerExportMapper.fromJson(json, canvasSize: size * 2);
      expect(restored.imageOffset, const Offset(40, -60));
      final payload = json['payload'] as Map<String, dynamic>;
      payload.remove('imageOffsetRatio');
      expect(
        LayerExportMapper.fromJson(json, canvasSize: size).imageOffset,
        isNull,
      );
      for (final invalid in [
        'invalid',
        {'x': '20', 'y': -30},
        {'x': double.nan, 'y': 0},
      ]) {
        payload['imageOffsetRatio'] = invalid;
        expect(
          LayerExportMapper.fromJson(json, canvasSize: size).imageOffset,
          isNull,
        );
      }
    },
  );

  testWidgets(
    'film perforations and ticket notches are transparent, paper borders are matte',
    (tester) async {
      for (final size in [const Size(240, 300), const Size(300, 240)]) {
        for (final key in [
          'studioFilm',
          'studioTicket',
          'studioGallery',
          'studioInstant',
        ]) {
          final image = await capture(
            tester,
            SizedBox.fromSize(
              size: size,
              child: StudioMaterial(
                style: key,
                child: const ColoredBox(color: Color(0xFFFF0000)),
              ),
            ),
          );
          final bytes = (await tester.runAsync(
            () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
          ))!;
          int channel(double x, double y, int c) =>
              bytes.getUint8((y.floor() * image.width + x.floor()) * 4 + c);
          expect(channel(size.width / 2, size.height / 2, 0), 255);
          if (key == 'studioFilm') {
            final horizontal = size.width > size.height;
            final x = horizontal ? size.width * .065 : size.width * .052;
            final y = horizontal ? size.height * .052 : size.height * .065;
            expect(channel(x, y, 3), 0);
          } else if (key == 'studioTicket') {
            expect(channel(2, size.height / 2, 3), 0);
          } else {
            expect(channel(size.width / 2, 4, 1), 255);
            expect(channel(size.width / 2, 4, 3), 255);
          }
          image.dispose();
        }
      }
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets(
      '$size: picker fits safe areas, selects last frame and cancels without changes',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        tester.view.padding = FakeViewPadding(
          bottom: 24 * tester.view.devicePixelRatio,
          right: size.width > size.height
              ? 32 * tester.view.devicePixelRatio
              : 0,
        );
        addTearDown(tester.view.resetPadding);
        String? selected;
        await tester.pumpWidget(
          wrapCreation(
            Builder(
              builder: (context) => Center(
                child: IconButton(
                  tooltip: '프레임 열기',
                  icon: const Icon(Icons.crop),
                  onPressed: () async {
                    selected = await ImageFrameStylePicker.show(
                      context,
                      currentKey: 'studioOval',
                      photoBuilder: (_) => const ColoredBox(color: Colors.red),
                      photoAspectRatio: 1.4,
                    );
                  },
                ),
              ),
            ),
            textScale: 1.6,
          ),
        );
        await tester.tap(find.byTooltip('프레임 열기'));
        await tester.pumpAndSettle();
        final item = find.byKey(const ValueKey('frame-studioFilm'));
        await tester.scrollUntilVisible(
          item,
          140,
          scrollable: find.descendant(
            of: find.byType(GridView),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        await Scrollable.ensureVisible(tester.element(item), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(item);
        await tester.pumpAndSettle();
        expect(selected, 'studioFilm');
        await tester.tap(find.byTooltip('프레임 열기'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('닫기'));
        await tester.pumpAndSettle();
        expect(selected, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
