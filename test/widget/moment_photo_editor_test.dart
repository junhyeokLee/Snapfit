import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/page_editor_canvas.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/photo_crop_sheet.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/editor_context_dock.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/decorate_panel.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/decorate_sticker_tab.dart';
import 'package:snap_fit/features/album/presentation/widgets/web/web_album_workspace.dart';
import 'package:snap_fit/features/album/presentation/widgets/web/web_editor_tool_dialog.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_design.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_format.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/views/moment_photo_editor_screen.dart';

import '../helpers/load_moment_capture_fonts.dart';
import '../helpers/mock_repositories.dart';
import '../unit/album_editor_view_model_test.dart'
    show FakeAlbumPersistenceService, FakeStorageService;
import '../unit/browser_photo_import_test.dart' show browserPhotoFixture;
import 'photo_crop_sheet_test.dart' show waitForCropPhoto;

class _Moments extends Fake implements MomentsRepository {
  String? owner = 'owner';
  final changes = StreamController<String?>.broadcast(sync: true);
  @override
  String? get currentUserId => owner;
  @override
  Stream<String?> get authChanges => changes.stream;
}

class MomentPhotoEditorFixture {
  final moments = _Moments();
  late ProviderContainer container;
  late BuildContext context;
  Future<MomentPhotoDesign?>? result;
  MomentPhotoEditorFixture({MomentUpload? upload})
    : upload =
          upload ??
          MomentUpload(
            id: 'photo-upload',
            filename: 'selected.png',
            bytes: browserPhotoFixture(width: 48, height: 60),
          );
  final MomentUpload upload;

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
    bool dark = false,
    GlobalKey? captureKey,
    ThemeData? theme,
    bool useWebWorkspace = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        momentsRepositoryProvider.overrideWithValue(moments),
        pointShopCatalogProvider.overrideWith((_) async => []),
        ownedPointShopKeysProvider.overrideWith((_) async => <String>{}),
        albumRepositoryProvider.overrideWithValue(MockAlbumRepository()),
        albumEditorServiceProvider.overrideWithValue(
          const AlbumEditorService(),
        ),
        albumPersistenceServiceProvider.overrideWithValue(
          FakeAlbumPersistenceService(),
        ),
        storageServiceProvider.overrideWithValue(FakeStorageService()),
        albumEditorOwnerReaderProvider.overrideWithValue(() => moments.owner),
        albumEditorOwnerChangesProvider.overrideWith(
          (_) => const Stream.empty(),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await moments.changes.close();
    });
    await container.read(albumEditorViewModelProvider.future);
    final vm = container.read(albumEditorViewModelProvider.notifier);
    vm.startSinglePageDraft(
      layers: [
        LayerModel(
          id: 'existing-album-text',
          type: LayerType.text,
          position: const Offset(10, 20),
          text: '저장하지 않은 내 앨범',
          textStyle: const TextStyle(fontFamily: 'NotoSans'),
        ),
      ],
      canvasSize: const Size(500, 500),
    );
    vm.addDecorationSticker('stickerLeafGreen', const Size(500, 500));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme ?? (dark ? SnapFitTheme.dark() : SnapFitTheme.light()),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: captureKey == null
                ? child!
                : RepaintBoundary(key: captureKey, child: child!),
          ),
          home: Builder(
            builder: (value) {
              context = value;
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => result = openMomentPhotoEditor(
                      context,
                      upload: upload,
                      useWebWorkspace: useWebWorkspace,
                    ),
                    child: const Text('사진 꾸미기 열기'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('사진 꾸미기 열기'));
    // Native image codecs finish outside the widget test's fake clock.
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(PageEditorCanvas).evaluate().isNotEmpty &&
          find
              .descendant(
                of: find.byType(PageEditorCanvas),
                matching: find.byType(RawImage),
              )
              .evaluate()
              .any((e) => (e.widget as RawImage).image != null)) {
        await tester.pumpAndSettle();
        return;
      }
    }
    fail(
      'The editable photo did not become ready. '
      'canvas=${find.byType(PageEditorCanvas).evaluate().length}, '
      'retry=${find.text('꾸미기 다시 열기').evaluate().length}, '
      'images=${tester.widgetList<Image>(find.byType(Image)).map((image) => image.image).toList()}',
    );
  }
}

Future<void> _openStickers(WidgetTester tester) async {
  await tester.tap(find.text('더보기'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('꾸미기'));
  await tester.pumpAndSettle();
  expect(find.byType(DecoratePanel), findsOneWidget);
  expect(find.byType(DecorateStickerTab), findsOneWidget);
}

Future<void> _captureFormat(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  boundary.markNeedsPaint();
  await tester.pump();
  await tester.runAsync(() async {
    const output = String.fromEnvironment('MOMENT_FORMAT_REVIEW_OUTPUT');
    if (output.isEmpty) throw StateError('External review directory required');
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$output/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  setUpAll(loadMomentCaptureFonts);

  testWidgets('record format dialog and canvas visual proof at 390', (
    tester,
  ) async {
    final photo = await rootBundle.load(
      'assets/templates/jeju_travel/images/figma_small/jeju_sunset.jpg',
    );
    final fixture = MomentPhotoEditorFixture(
      upload: MomentUpload(
        id: 'format-review',
        filename: 'jeju-sunset.jpg',
        bytes: photo.buffer.asUint8List(
          photo.offsetInBytes,
          photo.lengthInBytes,
        ),
      ),
    );
    final key = GlobalKey();
    await fixture.mount(tester, captureKey: key);
    await fixture.open(tester);
    await tester.tap(find.byKey(const ValueKey('moment-editor-format')));
    await tester.pumpAndSettle();
    await _captureFormat(tester, key, 'record-format-picker-390-light');
    await tester.tap(
      find.byKey(ValueKey('print-size-${coverSizes[1].productId}')),
    );
    await tester.pumpAndSettle();
    await _captureFormat(tester, key, 'record-editor-20x15-390-light');
    await tester.tap(find.byKey(const ValueKey('moment-photo-design-apply')));
    await tester.pumpAndSettle();
    expect(
      (await fixture.result!)!.canvasSize,
      coverCanvasBaseSize(coverSizes[1]),
    );
    expect(tester.takeException(), isNull);
  }, skip: !const bool.fromEnvironment('EXPORT_MOMENT_FORMAT_REVIEW'));

  for (final web in [false, true]) {
    testWidgets(
      'official record formats preserve the photo through repeated choices web=$web',
      (tester) async {
        final fixture = MomentPhotoEditorFixture();
        await fixture.mount(
          tester,
          size: web ? const Size(1280, 900) : const Size(320, 568),
          scale: web ? 1 : 2,
          useWebWorkspace: web,
        );
        await fixture.open(tester);
        final scope = ProviderScope.containerOf(
          tester.element(find.byType(MomentPhotoEditorScreen)),
        );
        final vm = scope.read(albumEditorViewModelProvider.notifier);
        final initialCanvas = coverCanvasBaseSize(defaultCoverSize);
        expect(
          tester
              .widget<PageEditorCanvas>(find.byType(PageEditorCanvas))
              .logicalCanvasSize,
          initialCanvas,
        );
        final original = MomentPhotoDesign.fromLayers(
          canvasSize: initialCanvas,
          backgroundColor: Colors.white,
          layers: vm.layers,
          photoSource: momentPhotoOriginalSource,
        );
        for (final cover in [...coverSizes, defaultCoverSize]) {
          await tester.tap(find.byKey(const ValueKey('moment-editor-format')));
          await tester.pumpAndSettle();
          final option = find.byKey(ValueKey('print-size-${cover.productId}'));
          await tester.ensureVisible(option);
          await tester.tap(option);
          await tester.pumpAndSettle();
          final expected = resizeMomentPhotoDesign(original, cover);
          final canvas = tester.widget<PageEditorCanvas>(
            find.byType(PageEditorCanvas),
          );
          expect(canvas.logicalCanvasSize, coverCanvasBaseSize(cover));
          final photo = vm.layers.single;
          final target = expected
              .layersForPhoto(momentPhotoOriginalSource)
              .single;
          expect(photo.width, closeTo(target.width, .001));
          expect(photo.height, closeTo(target.height, .001));
          expect(photo.position.dx, closeTo(target.position.dx, .001));
          expect(photo.position.dy, closeTo(target.position.dy, .001));
          expect(photo.imageZoom, 1);
          expect(tester.takeException(), isNull);
        }
        final before = vm.layers.single;
        vm.updateLayer(
          before.copyWith(imageZoom: 1.5, imageOffset: const Offset(7, -3)),
        );
        vm.addTextLayer(
          '계속 남기는 문구',
          canvasSize: initialCanvas,
          style: const TextStyle(fontSize: 20, fontFamily: 'NotoSans'),
          mode: TextStyleType.none,
        );
        await tester.pumpAndSettle();
        Map<String, dynamic> editedSnapshot() => MomentPhotoDesign.fromLayers(
          canvasSize: initialCanvas,
          backgroundColor: Colors.white,
          layers: vm.layers,
          photoSource: momentPhotoOriginalSource,
        ).toJson();
        final edited = editedSnapshot();
        await tester.tap(find.byKey(const ValueKey('moment-editor-format')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(ValueKey('print-size-${coverSizes[1].productId}')),
        );
        await tester.pumpAndSettle();
        expect(vm.layers, hasLength(2));
        await tester.tap(find.byTooltip(web ? '실행 취소 (Ctrl/⌘ Z)' : '되돌리기'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<PageEditorCanvas>(find.byType(PageEditorCanvas))
              .logicalCanvasSize,
          initialCanvas,
        );
        expect(editedSnapshot(), edited);
        await tester.tap(
          find.byTooltip(web ? '다시 실행 (Ctrl/⌘ Shift Z)' : '다시하기'),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<PageEditorCanvas>(find.byType(PageEditorCanvas))
              .logicalCanvasSize,
          coverCanvasBaseSize(coverSizes[1]),
        );
        expect(vm.layers.first.imageZoom, 1.5);
        final apply = web
            ? find.text('적용').first
            : find.byKey(const ValueKey('moment-photo-design-apply'));
        await tester.tap(apply);
        await tester.pumpAndSettle();
        expect(
          (await fixture.result!)!.canvasSize,
          coverCanvasBaseSize(coverSizes[1]),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'applying a decorated photo preserves the separate album draft and undo history',
    (tester) async {
      final fixture = MomentPhotoEditorFixture();
      await fixture.mount(tester);
      final parent = fixture.container.read(
        albumEditorViewModelProvider.notifier,
      );
      final before = parent.exportFullAlbumLayersJson(null);
      final session = parent.editSessionIdentity;
      final canUndo = fixture.container
          .read(albumEditorViewModelProvider)
          .value!
          .canUndo;
      await fixture.open(tester);
      await _openStickers(tester);
      await tester.tap(find.byKey(const ValueKey('deco:stickerHeartRed@0.9')));
      await tester.pumpAndSettle();
      final editorScope = ProviderScope.containerOf(
        tester.element(find.byType(MomentPhotoEditorScreen)),
      );
      expect(
        editorScope.read(albumEditorViewModelProvider.notifier).layers,
        hasLength(2),
      );
      await tester.tap(find.byTooltip('되돌리기'));
      await tester.pumpAndSettle();
      expect(
        editorScope.read(albumEditorViewModelProvider.notifier).layers,
        hasLength(1),
      );
      await tester.tap(find.byTooltip('다시하기'));
      await tester.pumpAndSettle();
      expect(
        editorScope.read(albumEditorViewModelProvider.notifier).layers,
        hasLength(2),
      );
      await tester.tap(find.byKey(const ValueKey('moment-photo-design-apply')));
      await tester.pumpAndSettle();
      final result = await fixture.result!;
      expect(result, isNotNull);
      final layers = result!.toJson()['layers'] as List;
      expect(layers, hasLength(2));
      expect(
        layers.any(
          (raw) =>
              (raw['payload'] as Map)['imageBackground'] == 'stickerHeartRed',
        ),
        isTrue,
      );
      expect(jsonEncode(result.toJson()), contains(momentPhotoOriginalSource));
      expect(jsonEncode(result.toJson()), isNot(contains('feed caption')));
      expect(parent.exportFullAlbumLayersJson(null), before);
      expect(parent.editSessionIdentity, same(session));
      expect(
        fixture.container.read(albumEditorViewModelProvider).value!.canUndo,
        canUndo,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'discarding photo decoration leaves the original upload and album untouched',
    (tester) async {
      final fixture = MomentPhotoEditorFixture();
      await fixture.mount(tester);
      final bytes = List<int>.of(fixture.upload.bytes);
      await fixture.open(tester);
      await _openStickers(tester);
      await tester.tap(find.byKey(const ValueKey('deco:stickerBlueStar@1.0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('꾸미기 닫기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('계속 꾸미기'));
      await tester.pumpAndSettle();
      expect(find.byType(MomentPhotoEditorScreen), findsOneWidget);
      await tester.tap(find.byTooltip('꾸미기 닫기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('적용하지 않고 나가기'));
      await tester.pumpAndSettle();
      expect(await fixture.result!, isNull);
      expect(fixture.upload.bytes, bytes);
      expect(fixture.upload.design, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account change closes the photo editor and its open sticker sheet without returning artwork',
    (tester) async {
      final fixture = MomentPhotoEditorFixture();
      await fixture.mount(tester);
      await fixture.open(tester);
      await _openStickers(tester);
      fixture.moments.owner = 'another-owner';
      fixture.moments.changes.add('another-owner');
      await tester.pumpAndSettle();
      expect(await fixture.result!, isNull);
      expect(find.byType(MomentPhotoEditorScreen), findsNothing);
      expect(find.byType(DecoratePanel), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('one-photo tools stay usable at 320px dark large text', (
    tester,
  ) async {
    final fixture = MomentPhotoEditorFixture();
    await fixture.mount(
      tester,
      size: const Size(320, 568),
      scale: 1.8,
      dark: true,
    );
    await fixture.open(tester);
    final canvas = tester.getSize(find.byType(PageEditorCanvas));
    expect(canvas.width, greaterThan(100));
    expect(canvas.height, greaterThan(100));
    expect(
      find.byKey(const ValueKey('moment-photo-design-apply')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('moment-photo-design-apply')));
    await tester.pumpAndSettle();
    expect(await fixture.result!, isNotNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'shared photo controls protect the original while keeping opacity and history',
    (tester) async {
      final fixture = MomentPhotoEditorFixture();
      await fixture.mount(tester);
      await fixture.open(tester);
      final dock = tester.widget<EditorContextDock>(
        find.byType(EditorContextDock),
      );
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(MomentPhotoEditorScreen)),
      );
      final vm = scope.read(albumEditorViewModelProvider.notifier);
      dock.interaction.setSelectedLayer(vm.layers.single.id);
      await tester.pumpAndSettle();
      expect(find.text('사진 바꾸기'), findsOneWidget);
      expect(find.text('자르기·구도'), findsOneWidget);
      expect(find.text('사진 꾸미기'), findsOneWidget);
      dock.interaction.deleteSelected();
      expect(vm.layers, hasLength(1));
      await tester.tap(find.text('더보기'));
      await tester.pumpAndSettle();
      expect(find.text('삭제'), findsNothing);
      expect(find.textContaining('원본은 유지돼요'), findsOneWidget);
      tester.widget<Slider>(find.byType(Slider)).onChanged!(.45);
      await tester.pumpAndSettle();
      expect(vm.layers.single.opacity, .45);
      await tester.tap(find.byTooltip('편집 도구 닫기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('되돌리기'));
      await tester.pumpAndSettle();
      expect(vm.layers.single.opacity, 1);
      await tester.tap(find.byKey(const ValueKey('moment-photo-design-apply')));
      await tester.pumpAndSettle();
      expect(await fixture.result!, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account change dismisses the shared details sheet with its editor',
    (tester) async {
      final fixture = MomentPhotoEditorFixture();
      await fixture.mount(tester);
      await fixture.open(tester);
      await tester.tap(find.text('더보기'));
      await tester.pumpAndSettle();
      fixture.moments.owner = 'another-owner';
      fixture.moments.changes.add('another-owner');
      await tester.pumpAndSettle();
      expect(await fixture.result!, isNull);
      expect(find.byKey(const ValueKey('editor-more-sheet')), findsNothing);
      expect(find.byType(MomentPhotoEditorScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'web photos reuse the album workspace and selector with explicit one-photo limits',
    (tester) async {
      final fixture = MomentPhotoEditorFixture();
      await fixture.mount(
        tester,
        size: const Size(1280, 900),
        useWebWorkspace: true,
      );
      await fixture.open(tester);
      expect(find.byType(WebAlbumEditorWorkspace), findsOneWidget);
      expect(find.byType(EditorContextDock), findsNothing);
      await tester.tap(find.text('템플릿'));
      await tester.pumpAndSettle();
      expect(find.byType(WebEditorToolDialog), findsOneWidget);
      expect(find.text('앨범에서 배치하기'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('web-editor-tool-tab-sticker')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DecoratePanel), findsOneWidget);
      expect(
        find.byKey(const ValueKey('deco:stickerRibbonBlue@1.0')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('deco:stickerBlueStar@1.0')));
      await tester.pumpAndSettle();
      expect(find.byType(WebEditorToolDialog), findsNothing);
      final workspace = tester.widget<WebAlbumEditorWorkspace>(
        find.byType(WebAlbumEditorWorkspace),
      );
      expect(workspace.saveActionLabel, '적용');
      expect(workspace.saveStatusLabel, '아직 적용하지 않은 꾸미기');
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(MomentPhotoEditorScreen)),
      );
      final vm = scope.read(albumEditorViewModelProvider.notifier);
      final before = vm.layers.last.position;
      await tester.tap(find.byKey(const ValueKey('web-layer-advanced-toggle')));
      await tester.pumpAndSettle();
      final x = find.byKey(const ValueKey('web-layer-x'));
      await tester.enterText(x, '2500');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(x).decoration!.errorText,
        '-1651.2~1651.2 px 범위예요.',
      );
      expect(vm.layers.last.position, before);
      await tester.tap(find.text('적용'));
      await tester.pumpAndSettle();
      expect((await fixture.result!)!.toJson()['layers'], hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
  for (final web in [false, true]) {
    testWidgets(
      'existing 1000px artwork keeps its canvas, crop preview and saved coordinates web=$web',
      (tester) async {
        const size = Size(1000, 1250);
        final design = MomentPhotoDesign.fromLayers(
          canvasSize: size,
          backgroundColor: Colors.white,
          photoSource: momentPhotoOriginalSource,
          layers: [
            LayerModel(
              id: 'large-original',
              type: LayerType.image,
              position: Offset.zero,
              width: 1000,
              height: 1250,
              imageUrl: momentPhotoOriginalSource,
              originalUrl: momentPhotoOriginalSource,
              previewUrl: momentPhotoOriginalSource,
            ),
            LayerModel(
              id: 'large-text',
              type: LayerType.text,
              position: const Offset(620, 900),
              width: 240,
              height: 120,
              zIndex: 1,
              text: '다시 열린 기록',
              textStyle: const TextStyle(
                fontFamily: 'NotoSans',
                fontSize: 42,
                color: Colors.white,
              ),
            ),
          ],
        );
        final fixture = MomentPhotoEditorFixture(
          upload: MomentUpload(
            id: 'existing-design',
            filename: 'existing.png',
            bytes: browserPhotoFixture(width: 48, height: 60),
            design: design,
          ),
        );
        await fixture.mount(
          tester,
          size: web ? const Size(1280, 900) : const Size(390, 844),
          useWebWorkspace: web,
        );
        await fixture.open(tester);
        final canvas = tester.widget<PageEditorCanvas>(
          find.byType(PageEditorCanvas),
        );
        expect(canvas.logicalCanvasSize, size);
        expect(tester.getSize(find.byKey(canvas.canvasKey)), size);
        if (web) {
          final workspace = tester.widget<WebAlbumEditorWorkspace>(
            find.byType(WebAlbumEditorWorkspace),
          );
          expect(
            (workspace.pageRail as WebAlbumPageRail).logicalCanvasSize,
            size,
          );
        }
        canvas.interaction.setSelectedLayer('large-original');
        await tester.pumpAndSettle();
        if (web) {
          await tester.tap(
            find.byKey(const ValueKey('web-layer-advanced-toggle')),
          );
          await tester.pumpAndSettle();
          expect(find.textContaining('페이지 가로 1000'), findsOneWidget);
        }
        await tester.tap(find.text('자르기·구도'));
        await waitForCropPhoto(tester);
        expect(
          tester
              .widget<PhotoCropSheet>(find.byType(PhotoCropSheet))
              .pageContext!
              .canvasSize,
          size,
        );
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('적용'));
        await tester.pumpAndSettle();
        final result = (await fixture.result!)!;
        expect(result.canvasSize, size);
        final restored = result.layersForPhoto(momentPhotoOriginalSource);
        expect(restored.first.width, 1000);
        expect(restored.first.height, 1250);
        expect(restored.last.position, const Offset(620, 900));
        expect(restored.last.textStyle!.fontSize, 42);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
