import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

import '../fixtures/ai_template_design_fixture.dart';
import 'ai_album_start_step_test.dart' show loadCreationFonts, wrapCreation;
import 'photo_crop_sheet_test.dart' show waitForCropPhoto;

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _Photo extends Mock implements AssetEntity {}

late Map<String, List<int>> _thumbnails;

AssetEntity _photo(String id, {String image = 'alpine_lake'}) {
  final photo = _Photo();
  when(() => photo.id).thenReturn(id);
  // These history fixtures model photos whose EXIF dimensions are unavailable.
  when(() => photo.width).thenReturn(0);
  when(() => photo.height).thenReturn(0);
  when(() => photo.orientation).thenReturn(0);
  when(
    () => photo.file,
  ).thenAnswer((_) async => File('assets/frame_preview/$image.jpg'));
  when(
    () => photo.thumbnailDataWithSize(const ThumbnailSize.square(150)),
  ).thenAnswer((_) async => Uint8List.fromList(_thumbnails[image]!));
  return photo;
}

class _Host extends StatefulWidget {
  const _Host({
    super.key,
    this.pages,
    this.pickPhotos,
    this.pickPhoto,
    this.session,
  });
  final List<List<LayerModel>>? pages;
  final Future<List<AssetEntity>?> Function()? pickPhotos;
  final Future<AssetEntity?> Function()? pickPhoto;
  final TemplatePhotoFillSession? session;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<List<LayerModel>> pages = widget.pages ?? _designPages();
  int changes = 0;
  bool visible = true;
  void detach() => setState(() => visible = false);
  void attach({List<LayerModel>? cover}) => setState(() {
    if (cover != null) {
      pages = [cover, ...pages.skip(1)];
      widget.session!.updateCover(cover);
    }
    visible = true;
  });

  void replacePages(List<List<LayerModel>> value) =>
      setState(() => pages = value);

  @override
  Widget build(BuildContext context) => !visible
      ? const SizedBox()
      : TemplatePhotoFillStep(
          session: widget.session,
          pages: pages,
          cover: templateDesignDraft().design!.coverSize,
          onChanged: (value) => setState(() {
            pages = value;
            changes++;
          }),
          onContinue: () {},
          pickPhoto: widget.pickPhoto,
          pickPhotos: widget.pickPhotos,
        );
}

List<List<LayerModel>> _designPages() {
  final design = templateDesignDraft().design!;
  return design.buildLayers(targetSize: coverCanvasBaseSize(design.coverSize));
}

LayerModel _slot(String id, {AssetEntity? photo}) => LayerModel(
  id: id,
  type: LayerType.image,
  position: const Offset(40, 40),
  width: 180,
  height: 240,
  imageBackground: 'archSoft',
  asset: photo,
);

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = size.width > size.height
      ? const FakeViewPadding(left: 44, right: 24, bottom: 24)
      : const FakeViewPadding(top: 24, bottom: 24);
  tester.view.viewPadding = tester.view.padding;
  addTearDown(tester.view.reset);
}

Future<void> _paint(WidgetTester tester) async {
  await tester.pump();
  for (var attempt = 0; attempt < 100; attempt++) {
    final loading = find.byType(Image).evaluate().any((element) {
      final pixels = find
          .descendant(
            of: find.byWidget(element.widget),
            matching: find.byType(RawImage),
          )
          .evaluate();
      return pixels.isEmpty ||
          pixels.any((pixel) => (pixel.widget as RawImage).image == null);
    });
    if (!loading) {
      await tester.pumpAndSettle();
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  fail('Photo fill preview did not finish decoding');
}

Future<void> _boot(
  WidgetTester tester,
  GlobalKey<_HostState> host, {
  List<List<LayerModel>>? pages,
  Future<List<AssetEntity>?> Function()? pickPhotos,
  Future<AssetEntity?> Function()? pickPhoto,
  bool dark = false,
  double textScale = 1,
  GlobalKey? capture,
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: capture,
      child: wrapCreation(
        _Host(
          key: host,
          pages: pages,
          pickPhoto: pickPhoto,
          pickPhotos: pickPhotos,
        ),
        dark: dark,
        textScale: textScale,
      ),
    ),
  );
  await _paint(tester);
}

Future<void> _tapSlot(WidgetTester tester, String id) async {
  final renderer = tester
      .widgetList<TemplatePageRenderer>(find.byType(TemplatePageRenderer))
      .firstWhere(
        (view) =>
            view.onLayerTap != null &&
            view.layers.any((layer) => layer.id == id),
      );
  renderer.onLayerTap!(id);
  await _paint(tester);
}

Future<void> _undo(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('photo-fill-undo')));
  await _paint(tester);
}

Future<void> _redo(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('photo-fill-redo')));
  await _paint(tester);
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('EDITOR_FLOW_QA')) return;
  await _paint(tester);
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('output/editor-flow-qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  _PaintBinding();
  setUpAll(() async {
    await loadCreationFonts();
    _thumbnails = {
      for (final name in ['alpine_lake', 'forest_trail', 'ocean_shore'])
        name: await File('assets/frame_preview/$name.jpg').readAsBytes(),
    };
  });

  testWidgets(
    'detaching photo fill preserves tray, selected page and undo, without undoing a later cover edit',
    (tester) async {
      _size(tester, const Size(390, 844));
      final host = GlobalKey<_HostState>();
      final session = TemplatePhotoFillSession();
      final a = _photo('lake'), b = _photo('forest', image: 'forest_trail');
      await tester.pumpWidget(
        wrapCreation(
          _Host(
            key: host,
            session: session,
            pages: [
              [_slot('cover')],
              [_slot('inner')],
            ],
            pickPhotos: () async => [a, b],
          ),
        ),
      );
      await _paint(tester);
      await tester.tap(find.text('사진 추가'));
      await _paint(tester);
      await tester.tap(find.byKey(const ValueKey('fill-page-1')));
      await _paint(tester);
      await _tapSlot(tester, 'inner');
      expect(host.currentState!.pages[1].single.asset!.id, 'lake');
      host.currentState!.detach();
      await tester.pumpAndSettle();
      expect(find.byType(TemplatePhotoFillStep), findsNothing);
      final editedCover = [_slot('cover').copyWith(imageZoom: 2)];
      host.currentState!.attach(cover: editedCover);
      await _paint(tester);
      expect(session.page, 1);
      expect(find.byKey(const ValueKey('tray-photo-forest')), findsOneWidget);
      expect(session.selectedPhoto!.id, 'forest');
      expect(session.selectedSlot, (page: 1, id: 'inner'));
      await _undo(tester);
      expect(host.currentState!.pages[1].single.asset, isNull);
      expect(host.currentState!.pages[0].single.imageZoom, 2);
      expect(find.byKey(const ValueKey('tray-photo-lake')), findsOneWidget);
      await _redo(tester);
      expect(host.currentState!.pages[1].single.asset!.id, 'lake');
      expect(host.currentState!.pages[0].single.imageZoom, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a design reset clears the old workspace even while the widget stays mounted',
    (tester) async {
      _size(tester, const Size(390, 844));
      final host = GlobalKey<_HostState>(),
          session = TemplatePhotoFillSession();
      await tester.pumpWidget(
        wrapCreation(
          _Host(
            key: host,
            session: session,
            pages: [
              [_slot('cover')],
            ],
            pickPhotos: () async => [_photo('lake')],
          ),
        ),
      );
      await _paint(tester);
      await tester.tap(find.text('사진 추가'));
      await _paint(tester);
      session.reset();
      host.currentState!.replacePages([
        [_slot('new')],
      ]);
      await _paint(tester);
      expect(find.byKey(const ValueKey('photo-fill-tray')), findsNothing);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('photo-fill-undo')))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'photo fill history restores crop, slots and unused photos $size dark=$dark',
        (tester) async {
          _size(tester, size);
          final host = GlobalKey<_HostState>(), capture = GlobalKey();
          final a = _photo('lake'),
              b = _photo('forest', image: 'forest_trail'),
              c = _photo('sea', image: 'ocean_shore');
          await _boot(
            tester,
            host,
            pickPhotos: () async => [a, b, c],
            dark: dark,
            capture: capture,
          );
          final original = host.currentState!.pages[0].firstWhere(
            (layer) => layer.type == LayerType.image,
          );
          await tester.tap(find.text('사진 추가'));
          await _paint(tester);
          expect(host.currentState!.changes, 0);
          await _undo(tester);
          expect(find.byKey(const ValueKey('photo-fill-tray')), findsNothing);
          await _redo(tester);
          expect(find.byKey(const ValueKey('tray-photo-lake')), findsOneWidget);
          await _tapSlot(tester, original.id);
          expect(host.currentState!.changes, 1);
          expect(find.byKey(const ValueKey('tray-photo-lake')), findsNothing);
          await tester.tap(find.byTooltip('사진 구도 조정'));
          await waitForCropPhoto(tester);
          await tester.tap(find.byTooltip('사진 확대'));
          await tester.drag(
            find.byKey(const ValueKey('photo-crop-preview')),
            const Offset(24, -20),
          );
          await tester.tap(find.byKey(const ValueKey('photo-crop-apply')));
          await _paint(tester);
          LayerModel current() => host.currentState!.pages[0].firstWhere(
            (layer) => layer.id == original.id,
          );
          File shownPhoto() => tester
              .widgetList<TemplatePageRenderer>(
                find.byType(TemplatePageRenderer),
              )
              .firstWhere(
                (view) =>
                    view.onLayerTap != null &&
                    view.layers.any((layer) => layer.id == original.id),
              )
              .localFiles![original.id]!;
          final cropped = current();
          expect(cropped.imageZoom, closeTo(1.1, .001));
          expect(cropped.imageOffset, isNot(Offset.zero));
          await _undo(tester);
          expect(current().asset, same(a));
          expect(current().imageZoom, 1);
          await _redo(tester);
          expect(current().imageOffset, cropped.imageOffset);
          await tester.tap(find.byKey(const ValueKey('tray-photo-forest')));
          await tester.tap(find.byTooltip('사진 교체'));
          await _paint(tester);
          expect(current().asset, same(b));
          expect(shownPhoto().path, 'assets/frame_preview/forest_trail.jpg');
          expect(current().imageZoom, 1);
          expect(current().imageOffset, isNull);
          expect(find.byKey(const ValueKey('tray-photo-lake')), findsOneWidget);
          expect(current().width, original.width);
          expect(current().imageBackground, original.imageBackground);
          await _undo(tester);
          expect(current().asset, same(a));
          expect(shownPhoto().path, 'assets/frame_preview/alpine_lake.jpg');
          expect(current().imageOffset, cropped.imageOffset);
          expect(
            find.byKey(const ValueKey('tray-photo-forest')),
            findsOneWidget,
          );
          expect(find.byKey(const ValueKey('tray-photo-lake')), findsNothing);
          await _redo(tester);
          expect(shownPhoto().path, 'assets/frame_preview/forest_trail.jpg');
          final preview = tester
              .widgetList<TemplatePageRenderer>(
                find.byType(TemplatePageRenderer),
              )
              .firstWhere((view) => view.onLayerTap != null);
          expect(preview.height, greaterThan(size.width == 320 ? 100 : 140));
          await _capture(
            tester,
            capture,
            'photo-history-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
          );
          await tester.tap(find.byTooltip('사진 제거'));
          await _paint(tester);
          expect(current().asset, isNull);
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('tray-photo-forest')),
            70,
            scrollable: find
                .descendant(
                  of: find.byKey(const ValueKey('photo-fill-tray')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(
            find.byKey(const ValueKey('tray-photo-forest')),
            findsOneWidget,
          );
          await _undo(tester);
          expect(current().asset, same(b));
          expect(find.byKey(const ValueKey('tray-photo-forest')), findsNothing);
          await _redo(tester);
          expect(current().asset, isNull);
          await _undo(tester);
          expect(host.currentState!.changes, 11);
          final beforeRotation = current();
          tester.view.physicalSize = size.width > size.height
              ? const Size(390, 844)
              : const Size(844, 390);
          await _paint(tester);
          expect(current(), same(beforeRotation));
          expect(
            tester
                .widget<IconButton>(
                  find.byKey(const ValueKey('photo-fill-undo')),
                )
                .onPressed,
            isNotNull,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('next empty visits all slots on a page before wrapping $size', (
      tester,
    ) async {
      _size(tester, size);
      final host = GlobalKey<_HostState>();
      await _boot(
        tester,
        host,
        pages: [
          [_slot('cover')],
          [_slot('one'), _slot('two')],
          [_slot('three')],
        ],
        pickPhoto: () async => null,
      );
      for (final id in ['cover', 'one', 'two', 'three', 'cover']) {
        await tester.tap(find.byKey(const ValueKey('fill-next-empty')));
        await _paint(tester);
        final selected = tester
            .widgetList<TemplatePageRenderer>(find.byType(TemplatePageRenderer))
            .where((view) => view.selectedLayerId != null)
            .single;
        expect(selected.selectedLayerId, id);
      }
      expect(host.currentState!.changes, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'batch duplicates and tray exclusion are undoable without changing pages',
    (tester) async {
      _size(tester, const Size(390, 844));
      final host = GlobalKey<_HostState>();
      final a = _photo('a'), duplicate = _photo('a'), b = _photo('b');
      await _boot(tester, host, pickPhotos: () async => [a, duplicate, b]);
      await tester.tap(find.text('사진 추가'));
      await _paint(tester);
      expect(find.byKey(const ValueKey('tray-photo-a')), findsOneWidget);
      await tester.tap(find.text('사진 추가'));
      await _paint(tester);
      await _undo(tester);
      expect(find.byKey(const ValueKey('photo-fill-tray')), findsNothing);
      await _redo(tester);
      await tester.tap(find.byTooltip('선택한 사진 제외'));
      await _paint(tester);
      expect(find.byKey(const ValueKey('tray-photo-a')), findsNothing);
      await _undo(tester);
      expect(find.byKey(const ValueKey('tray-photo-a')), findsOneWidget);
      expect(host.currentState!.changes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unavailable photo stays in the tray and retry creates one undo step',
    (tester) async {
      _size(tester, const Size(390, 844));
      final host = GlobalKey<_HostState>(), photo = _photo('retry');
      var requests = 0;
      when(() => photo.file).thenAnswer(
        (_) async => ++requests == 1
            ? null
            : File('assets/frame_preview/alpine_lake.jpg'),
      );
      await _boot(
        tester,
        host,
        pages: [
          [_slot('cover')],
        ],
        pickPhotos: () async => [photo],
      );
      await tester.tap(find.text('사진 추가'));
      await _paint(tester);
      await _tapSlot(tester, 'cover');
      expect(host.currentState!.pages[0][0].asset, isNull);
      expect(find.byKey(const ValueKey('tray-photo-retry')), findsOneWidget);
      expect(find.text('사진을 가져오지 못했어요. 다시 선택해주세요.'), findsOneWidget);
      await _tapSlot(tester, 'cover');
      expect(host.currentState!.pages[0][0].asset, same(photo));
      expect(requests, 2);
      await _undo(tester);
      expect(host.currentState!.pages[0][0].asset, isNull);
      expect(find.byKey(const ValueKey('tray-photo-retry')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final phase in ['gallery', 'file', 'crop']) {
    testWidgets(
      'external template change rejects stale $phase work and clears history',
      (tester) async {
        _size(tester, const Size(390, 844));
        final host = GlobalKey<_HostState>(), photo = _photo('new');
        final pick = Completer<AssetEntity?>(), file = Completer<File?>();
        if (phase == 'file')
          when(() => photo.file).thenAnswer((_) => file.future);
        await _boot(
          tester,
          host,
          pages: [
            [_slot('cover')],
          ],
          pickPhoto: phase == 'gallery' ? () => pick.future : null,
          pickPhotos: phase != 'gallery' ? () async => [photo] : null,
        );
        if (phase == 'gallery') {
          await _tapSlot(tester, 'cover');
        } else {
          await tester.tap(find.text('사진 추가'));
          await _paint(tester);
          await _tapSlot(tester, 'cover');
          if (phase == 'crop') {
            await tester.tap(find.byTooltip('사진 구도 조정'));
            await waitForCropPhoto(tester);
            await tester.tap(find.byTooltip('사진 확대'));
          }
        }
        final changed = host.currentState!.pages[0][0].copyWith(
          width: 290,
          rotation: .1,
        );
        host.currentState!.replacePages([
          [changed],
        ]);
        await tester.pump();
        if (phase == 'gallery') pick.complete(photo);
        if (phase == 'file')
          file.complete(File('assets/frame_preview/alpine_lake.jpg'));
        if (phase == 'crop')
          await tester.tap(find.byKey(const ValueKey('photo-crop-apply')));
        await _paint(tester);
        expect(host.currentState!.pages[0][0], same(changed));
        expect(find.text('페이지가 변경됐어요. 사진을 다시 선택해주세요.'), findsOneWidget);
        expect(
          tester
              .widget<IconButton>(find.byKey(const ValueKey('photo-fill-undo')))
              .onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'removing a page while its file loads cannot attach it to another slot',
    (tester) async {
      _size(tester, const Size(390, 844));
      final host = GlobalKey<_HostState>(), photo = _photo('old');
      final file = Completer<File?>();
      when(() => photo.file).thenAnswer((_) => file.future);
      await _boot(
        tester,
        host,
        pages: [
          [_slot('cover')],
          [_slot('removed', photo: photo)],
        ],
        pickPhotos: () async => null,
      );
      host.currentState!.replacePages([
        [_slot('cover')],
      ]);
      await tester.pump();
      file.complete(File('assets/frame_preview/alpine_lake.jpg'));
      await _paint(tester);
      expect(host.currentState!.pages.single.single.asset, isNull);
      expect(find.byKey(const ValueKey('fill-page-1')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'undo restores the old bitmap even if its initial file load completed during replacement',
    (tester) async {
      _size(tester, const Size(390, 844));
      final host = GlobalKey<_HostState>();
      final old = _photo('old'),
          replacement = _photo('new', image: 'forest_trail');
      final loading = Completer<File?>();
      when(() => old.file).thenAnswer((_) => loading.future);
      await _boot(
        tester,
        host,
        pages: [
          [_slot('cover', photo: old)],
        ],
        pickPhoto: () async => replacement,
      );
      await _tapSlot(tester, 'cover');
      await tester.tap(find.byTooltip('사진 교체'));
      await _paint(tester);
      loading.complete(File('assets/frame_preview/alpine_lake.jpg'));
      await _paint(tester);
      await _undo(tester);
      final preview = tester
          .widgetList<TemplatePageRenderer>(find.byType(TemplatePageRenderer))
          .firstWhere((view) => view.onLayerTap != null);
      expect(host.currentState!.pages[0][0].asset, same(old));
      expect(
        preview.localFiles!['cover']!.path,
        'assets/frame_preview/alpine_lake.jpg',
      );
      await _redo(tester);
      final replaced = tester
          .widgetList<TemplatePageRenderer>(find.byType(TemplatePageRenderer))
          .firstWhere((view) => view.onLayerTap != null);
      expect(
        replaced.localFiles!['cover']!.path,
        'assets/frame_preview/forest_trail.jpg',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('photo history is bounded to the last 30 changes', (
    tester,
  ) async {
    _size(tester, const Size(390, 844));
    final host = GlobalKey<_HostState>();
    var index = 0;
    await _boot(
      tester,
      host,
      pickPhotos: () async => [_photo('photo-${index++}')],
    );
    for (var i = 0; i < 31; i++) {
      await tester.tap(find.text('사진 추가'));
      await _paint(tester);
    }
    for (var i = 0; i < 30; i++) {
      await _undo(tester);
    }
    expect(
      tester
          .widget<ListView>(find.byKey(const ValueKey('photo-fill-tray')))
          .semanticChildCount,
      1,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('photo-fill-undo')))
          .onPressed,
      isNull,
    );
    expect(host.currentState!.changes, 0);
    await _redo(tester);
    expect(
      tester
          .widget<ListView>(find.byKey(const ValueKey('photo-fill-tray')))
          .semanticChildCount,
      2,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unchanged crop makes no history entry and a new edit invalidates redo',
    (tester) async {
      _size(tester, const Size(390, 844));
      final host = GlobalKey<_HostState>(), photo = _photo('new');
      await _boot(
        tester,
        host,
        pages: [
          [_slot('cover')],
        ],
        pickPhotos: () async => [photo],
      );
      await tester.tap(find.text('사진 추가'));
      await _paint(tester);
      await _tapSlot(tester, 'cover');
      await tester.tap(find.byTooltip('사진 구도 조정'));
      await waitForCropPhoto(tester);
      await tester.tap(find.byKey(const ValueKey('photo-crop-apply')));
      await _paint(tester);
      expect(host.currentState!.changes, 1);
      await _undo(tester);
      expect(host.currentState!.pages[0][0].asset, isNull);
      await _tapSlot(tester, 'cover');
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('photo-fill-redo')))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('photo history controls and continue fit large text $size', (
      tester,
    ) async {
      _size(tester, size);
      final host = GlobalKey<_HostState>();
      await _boot(
        tester,
        host,
        pages: [
          [_slot('cover')],
        ],
        pickPhotos: () async => [_photo('new')],
        textScale: 1.6,
      );
      await tester.tap(find.text('사진 추가'));
      await _paint(tester);
      final undo = tester.getRect(
        find.byKey(const ValueKey('photo-fill-undo')),
      );
      final footer = tester.getRect(find.widgetWithText(TextButton, '나중에 채우기'));
      expect(undo.width, greaterThanOrEqualTo(44));
      expect(footer.bottom, lessThanOrEqualTo(size.height - 24));
      expect(tester.takeException(), isNull);
    });
  }
}
