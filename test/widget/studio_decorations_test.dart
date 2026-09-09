import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/studio_photo_frame_catalog.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_builder.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/decorate_sticker_tab.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/layer_manager_panel.dart';
import 'package:snap_fit/shared/widgets/studio_decoration.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import '../helpers/mock_repositories.dart';
import '../unit/album_editor_view_model_test.dart'
    show FakeAlbumPersistenceService, FakeStorageService;
import 'ai_album_start_step_test.dart' show wrapCreation, loadCreationFonts;

Future<ui.Image> capture(WidgetTester tester, Widget child) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(key: key, child: child),
      ),
    ),
  );
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return (await tester.runAsync(
    () => (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
        .toImage(),
  ))!;
}

class _Interaction extends Mock implements LayerInteractionManager {
  @override
  Widget buildInteractiveLayer({
    required LayerModel layer,
    required double baseWidth,
    required double baseHeight,
    required Widget child,
    bool isCover = false,
  }) => SizedBox(width: baseWidth, height: baseHeight, child: child);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCreationFonts);

  testWidgets('layer list shows artwork names and local material thumbnails', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final specs = [
      'studioPressedCosmos',
      'studioCotton',
      'studioCottonRag',
    ].map((id) => studioDecorationById(id)!).toList();
    final layers = specs
        .map(
          (spec) => LayerModel(
            id: spec.id,
            type: spec.assetPath == null
                ? LayerType.decoration
                : LayerType.sticker,
            position: Offset.zero,
            width: 100,
            height: 100 / spec.aspectRatio,
            imageBackground: spec.assetPath == null ? spec.id : null,
            imageUrl: spec.assetPath == null ? null : 'asset:${spec.assetPath}',
          ),
        )
        .toList();
    await tester.pumpWidget(
      ProviderScope(
        child: wrapCreation(
          Scaffold(
            body: LayerManagerPanel(
              layers: layers,
              interaction: _Interaction(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final spec in specs.reversed) {
      await tester.scrollUntilVisible(
        find.text(spec.label),
        70,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(spec.label), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is StudioDecoration && widget.spec.id == spec.id,
        ),
        findsOneWidget,
      );
    }
    for (final image in tester.widgetList<Image>(find.byType(Image))) {
      expect(image.image, isA<AssetImage>());
    }
    expect(tester.takeException(), isNull);
  });

  for (final aspect in CollectionAspect.values) {
    test(
      '${aspect.name}: insert, undo, redo, export and photo clearing preserve all new materials',
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
        vm.resetForCreate(initialCover: aspect.cover, targetPages: 2);
        final base = vm.pages.first.layers.length;
        for (var index = 0; index < studioDecorations.length; index++) {
          final spec = studioDecorations[index];
          if (spec.assetPath case final String path) {
            vm.addAssetSticker(path, aspect.canvas);
          } else {
            vm.addDecorationSticker(spec.id, aspect.canvas);
          }
          expect(vm.pages.first.layers.length, base + index + 1);
          var layer = vm.pages.first.layers.last;
          expect(
            layer.type,
            spec.assetPath == null ? LayerType.decoration : LayerType.sticker,
          );
          expect(layer.width / layer.height, closeTo(spec.aspectRatio, .0001));
          expect(layer.position.dx, greaterThanOrEqualTo(0));
          expect(layer.position.dy, greaterThanOrEqualTo(0));
          expect(
            layer.position.dx + layer.width,
            lessThan(aspect.canvas.width),
          );
          expect(
            layer.position.dy + layer.height,
            lessThan(aspect.canvas.height),
          );
          vm.undo();
          expect(vm.pages.first.layers.length, base + index);
          vm.redo();
          layer = vm.pages.first.layers.last;
          final restored = LayerExportMapper.fromJson(
            LayerExportMapper.toJson(layer, canvasSize: aspect.canvas),
            canvasSize: aspect.canvas,
          );
          expect(restored.type, layer.type);
          expect(restored.imageUrl, layer.imageUrl);
          expect(restored.imageBackground, layer.imageBackground);
          final prepared = AlbumCreationTemplate.preparePages(
            [
              [restored],
            ],
            sourceCanvas: aspect.canvas,
            cover: aspect.cover,
          ).single.single;
          expect(prepared.imageUrl, layer.imageUrl);
          expect(prepared.imageBackground, layer.imageBackground);
        }
      },
    );
  }

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'picker $size dark=$dark: new collection, categories and legacy insert',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          String? selected;
          await tester.pumpWidget(
            wrapCreation(
              Scaffold(
                body: SafeArea(
                  child: DecorateStickerTab(
                    surfaceColor: Colors.white,
                    onStickerTap: (value) => selected = value,
                  ),
                ),
              ),
              dark: dark,
            ),
          );
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('코스모스 압화'),
            120,
            maxScrolls: studioDecorations.length * 2,
            scrollable: find.descendant(
              of: find.byType(GridView),
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('코스모스 압화'));
          expect(
            selected,
            studioDecorationById('studioPressedCosmos')!.insertionValue,
          );
          await tester.tap(find.text('종이'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('코튼 페이퍼'),
            120,
            scrollable: find.descendant(
              of: find.byType(GridView),
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('코튼 페이퍼'));
          expect(
            selected,
            studioDecorationById('studioCotton')!.insertionValue,
          );
          await tester.tap(find.text('테이프'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('핀스트라이프'),
            120,
            scrollable: find.descendant(
              of: find.byType(GridView),
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('핀스트라이프'));
          expect(
            selected,
            studioDecorationById('studioWashiSage')!.insertionValue,
          );
          await tester.ensureVisible(find.text('기존 장식'));
          await tester.tap(find.text('기존 장식'));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(DecoStickerVisual).first);
          expect(selected, 'deco:stickerBlueStar@1.0');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final size in [const Size(240, 120), const Size(120, 240)]) {
    for (final frame in {
      ...studyPhotoFrames,
      ...editionPhotoFrames,
      ...keepsakePhotoFrames,
      ...atelierEditionPhotoFrames,
    }) {
      testWidgets('$size/$frame: native photo frame matches preview pixels', (
        tester,
      ) async {
        final layer = LayerModel(
          id: 'study-photo',
          type: LayerType.image,
          position: Offset.zero,
          width: size.width,
          height: size.height,
          imageUrl: 'asset:assets/snapfit_home_square.jpg',
          imageBackground: frame,
        );
        final direct = await capture(
          tester,
          LayerBuilder(_Interaction(), () => size).buildImage(layer),
        );
        final preview = await capture(
          tester,
          TemplatePageRenderer(
            layers: [layer],
            width: size.width,
            height: size.height,
            designCanvasSize: size,
            showCanvasChrome: false,
          ),
        );
        final a = (await tester.runAsync(
          () => direct.toByteData(),
        ))!.buffer.asUint8List();
        final b = (await tester.runAsync(
          () => preview.toByteData(),
        ))!.buffer.asUint8List();
        expect(a, orderedEquals(b));
        expect(a.toSet().length, greaterThan(100));
        direct.dispose();
        preview.dispose();
      });
    }
    for (final frame in [null, 'rasterCover']) {
      testWidgets(
        '$size/$frame: raster artwork fit agrees in editor and preview',
        (tester) async {
          final layer = LayerModel(
            id: 'pattern',
            type: LayerType.sticker,
            position: Offset.zero,
            width: size.width,
            height: size.height,
            imageUrl: 'asset:$proseStudyPattern',
            imageBackground: frame,
          );
          final direct = await capture(
            tester,
            LayerBuilder(_Interaction(), () => size).buildImage(layer),
          );
          final preview = await capture(
            tester,
            TemplatePageRenderer(
              layers: [layer],
              width: size.width,
              height: size.height,
              designCanvasSize: size,
              showCanvasChrome: false,
            ),
          );
          final a = (await tester.runAsync(
            () => direct.toByteData(),
          ))!.buffer.asUint8List();
          final b = (await tester.runAsync(
            () => preview.toByteData(),
          ))!.buffer.asUint8List();
          expect(a, orderedEquals(b));
          expect(a[3] == 255, frame == 'rasterCover');
          direct.dispose();
          preview.dispose();
        },
      );
    }
  }
  for (final spec in studioDecorations) {
    testWidgets(
      '${spec.id}: same artwork in picker, editor decoration and template renderer',
      (tester) async {
        final size = Size(240, 240 / spec.aspectRatio);
        final layer = LayerModel(
          id: spec.id,
          type: spec.assetPath == null
              ? LayerType.decoration
              : LayerType.sticker,
          position: Offset.zero,
          width: size.width,
          height: size.height,
          imageUrl: spec.assetPath == null ? null : 'asset:${spec.assetPath}',
          imageBackground: spec.assetPath == null ? spec.id : null,
        );
        final direct = await capture(
          tester,
          LayerBuilder(_Interaction(), () => size).buildImage(layer),
        );
        final preview = await capture(
          tester,
          TemplatePageRenderer(
            layers: [layer],
            width: size.width,
            height: size.height,
            designCanvasSize: size,
          ),
        );
        final a = await tester.runAsync(() => direct.toByteData());
        final b = await tester.runAsync(() => preview.toByteData());
        expect(a!.buffer.asUint8List(), orderedEquals(b!.buffer.asUint8List()));
        direct.dispose();
        preview.dispose();
      },
    );
  }

  test(
    'illustration assets have real alpha margins and substantial non-transparent artwork',
    () async {
      for (final spec in studioDecorations.where((s) => s.assetPath != null)) {
        final codec = await ui.instantiateImageCodec(
          await File(spec.assetPath!).readAsBytes(),
        );
        final image = (await codec.getNextFrame()).image;
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        var transparent = 0, solid = 0;
        for (var i = 3; i < bytes.length; i += 4) {
          if (bytes[i] < 8) transparent++;
          if (bytes[i] > 240) solid++;
        }
        final pixels = image.width * image.height;
        expect(transparent / pixels, greaterThan(.12));
        // The diagonal pencil intentionally has a slender silhouette.
        final minimumSolid = spec.id == 'wavePencil' ? .10 : .15;
        expect(solid / pixels, greaterThan(minimumSolid), reason: spec.id);
        expect(image.width / image.height, closeTo(spec.aspectRatio, .001));
        image.dispose();
        codec.dispose();
      }
    },
  );
}
