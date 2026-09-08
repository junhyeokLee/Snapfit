import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/studio_word_art_catalog.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_builder.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/decorate_panel.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/studio_word_art_preview.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import '../helpers/mock_repositories.dart';
import '../unit/album_editor_view_model_test.dart'
    show FakeAlbumPersistenceService, FakeStorageService;
import '../unit/catalog_favorites_test.dart' show MemoryFavoritesStorage;
import 'ai_album_start_step_test.dart' show wrapCreation, loadCreationFonts;
import 'studio_decorations_test.dart' show capture;

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
  late CatalogFavorites previous;
  setUpAll(() async {
    await loadCreationFonts();
    for (final font in {
      'RiaSans': 'RiaSans-Bold.ttf',
      'Yeongwol': 'YeongwolTTF.ttf',
      'Samlip': 'samlip-regular.ttf',
      'BookMyungjo': 'BookkMyungjo_Bold.ttf',
    }.entries) {
      await (FontLoader(
        font.key,
      )..addFont(rootBundle.load('assets/fonts/${font.value}'))).load();
    }
  });
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

  for (final aspect in CollectionAspect.values) {
    test(
      '${aspect.name}: all word art inserts atomically, stays editable and roundtrips',
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
        for (final art in studioWordArts) {
          vm.resetForCreate(initialCover: aspect.cover, targetPages: 2);
          vm.updatePageLayers([], recordHistory: false);
          vm.addWordArt(art, aspect.canvas);
          final inserted = [...vm.pages.first.layers];
          expect(inserted.length, art.previewLayers().length);
          for (final layer in inserted) {
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
            final saved = LayerExportMapper.fromJson(
              LayerExportMapper.toJson(layer, canvasSize: aspect.canvas),
              canvasSize: aspect.canvas,
            );
            expect(saved.type, layer.type);
            expect(saved.textFillMode, layer.textFillMode);
            expect(saved.imageBackground, layer.imageBackground);
            if (layer.type == LayerType.text) {
              expect(saved.text, art.text);
              expect(saved.textStyle!.fontFamily, layer.textStyle!.fontFamily);
              final painter = TextPainter(
                text: TextSpan(text: layer.text, style: layer.textStyle),
                textDirection: TextDirection.ltr,
              )..layout(maxWidth: layer.width);
              expect(
                painter.height,
                lessThanOrEqualTo(layer.height + 1),
                reason: art.id,
              );
              painter.dispose();
            }
          }
          vm.undo();
          expect(vm.pages.first.layers, isEmpty);
          vm.redo();
          expect(
            vm.pages.first.layers.map((l) => l.id),
            inserted.map((l) => l.id),
          );
          final text = vm.pages.first.layers.singleWhere(
            (l) => l.type == LayerType.text,
          );
          vm.updateLayer(text.copyWith(text: '나의 기록'));
          expect(
            vm.pages.first.layers.singleWhere((l) => l.id == text.id).text,
            '나의 기록',
          );
          vm.addWordArt(art, aspect.canvas);
          final ids = vm.pages.first.layers.map((l) => l.id).toList();
          expect(ids.toSet().length, ids.length);
        }
      },
    );
  }

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets(
      '$size: real decorate panel inserts new art and preserves favorite identities',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final gates = <String>[];
        var closed = 0;
        await tester.pumpWidget(
          wrapCreation(
            ProviderScope(
              overrides: [
                albumEditorViewModelProvider.overrideWith(
                  AlbumEditorViewModel.new,
                ),
                albumRepositoryProvider.overrideWithValue(
                  MockAlbumRepository(),
                ),
                albumEditorServiceProvider.overrideWithValue(
                  const AlbumEditorService(),
                ),
                albumPersistenceServiceProvider.overrideWithValue(
                  FakeAlbumPersistenceService(),
                ),
                storageServiceProvider.overrideWithValue(FakeStorageService()),
              ],
              child: DecoratePanel(
                mode: DecorateSheetMode.sticker,
                onClose: () => closed++,
              ),
            ),
            pointShopGate:
                (context, ref, {required productKey, required title}) async {
                  gates.add(productKey);
                  return true;
                },
          ),
        );
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(DecoratePanel)),
        );
        await container.read(albumEditorViewModelProvider.future);
        final vm = container.read(albumEditorViewModelProvider.notifier);
        vm.resetForCreate(targetPages: 2);
        vm.updatePageLayers([], recordHistory: false);
        await tester.ensureVisible(find.text('블루 포켓 카메라'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('블루 포켓 카메라'));
        await tester.pumpAndSettle();
        expect(vm.pages.first.layers.last.type, LayerType.sticker);
        expect(gates, ['sticker:zineCamera']);
        await tester.ensureVisible(find.text('꾸민 문구'));
        await tester.tap(find.text('꾸민 문구'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('볼드 컷아웃 즐겨찾기 추가'));
        await tester.pumpAndSettle();
        expect(
          CatalogFavorites.instance.contains(studioWordArts.first.favoriteKey),
          true,
        );
        expect(
          CatalogFavoriteKeys.decoration(studioWordArts.first.insertionValue),
          studioWordArts.first.favoriteKey,
        );
        await tester.ensureVisible(find.text('볼드 컷아웃'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('볼드 컷아웃'));
        await tester.pumpAndSettle();
        expect(gates.last, 'phrase:collage-bold-cut');
        expect(closed, 2);
        expect(vm.pages.first.layers.last.textFillMode, 'papercut');
        vm.undo();
        expect(vm.pages.first.layers.length, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('word art contact sheet uses real document renderer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final image = await capture(
      tester,
      ColoredBox(
        color: const Color(0xFFF1F2F5),
        child: SizedBox(
          width: 1080,
          height: 900,
          child: Wrap(
            children: [
              for (final art in studioWordArts)
                SizedBox(
                  width: 360,
                  height: 300,
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Expanded(child: StudioWordArtPreview(art: art)),
                        Text(
                          art.label,
                          style: const TextStyle(
                            fontFamily: 'NotoSans',
                            fontSize: 16,
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
    await tester.runAsync(() async {
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final file = File('output/template-studio/editor-word-art.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes.buffer.asUint8List());
    });
    image.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor and saved preview keep the lettering on its stationery', (
    tester,
  ) async {
    const size = Size(500, 650);
    for (final art in studioWordArts) {
      final layers = art.buildLayers(size);
      final text = layers.singleWhere((l) => l.type == LayerType.text);
      final builder = LayerBuilder(_Interaction(), () => size);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox.fromSize(
              size: size,
              child: Stack(
                children: [
                  for (final layer in layers)
                    Positioned(
                      left: layer.position.dx,
                      top: layer.position.dy,
                      child: layer.type == LayerType.text
                          ? builder.buildText(layer)
                          : builder.buildImage(layer),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final native = tester.getRect(find.text(art.text));
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: TemplatePageRenderer(
              layers: layers,
              width: size.width,
              height: size.height,
              designCanvasSize: size,
              preserveTypography: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final preview = tester.getRect(find.text(art.text));
      expect(
        (native.center - preview.center).distance,
        lessThan(2),
        reason: art.id,
      );
      final painter = TextPainter(
        text: TextSpan(text: text.text, style: text.textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      expect(
        painter.width + 36,
        lessThanOrEqualTo(text.width + 1),
        reason: '${art.id} editor frame padding',
      );
      painter.dispose();
      expect(tester.takeException(), isNull);
    }
  });
}
