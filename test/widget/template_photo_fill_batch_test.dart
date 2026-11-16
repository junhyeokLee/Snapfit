import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/data/gallery/browser_photo_asset.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';
import 'package:snap_fit/features/album/printing/print_image_header.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts, wrapCreation;

class _Photo extends Mock implements AssetEntity {}

late Uint8List _bytes;
final _captureBoundary = GlobalKey();

BrowserPhotoAsset _browser(String id) {
  final size = printEncodedImageSize(_bytes);
  return BrowserPhotoAsset.fromStored(
    ownerId: 'owner',
    id: 'browser_$id',
    name: '$id.jpg',
    width: size.width.toInt(),
    height: size.height.toInt(),
    createdAtSecond: 1,
    originalBytes: _bytes,
    previewBytes: _bytes,
    contentSha256: sha256.convert(_bytes).toString(),
  );
}

AssetEntity _native(String id, Future<File?> Function() file) {
  final photo = _Photo();
  when(() => photo.id).thenReturn(id);
  when(() => photo.width).thenReturn(800);
  when(() => photo.height).thenReturn(800);
  when(() => photo.orientation).thenReturn(0);
  when(() => photo.file).thenAnswer((_) => file());
  when(
    () => photo.thumbnailDataWithSize(const ThumbnailSize.square(150)),
  ).thenAnswer((_) async => _bytes);
  return photo;
}

LayerModel _slot(String id) => LayerModel(
  id: id,
  type: LayerType.image,
  position: const Offset(20, 25),
  width: 180,
  height: 210,
  imageBackground: 'polaroid',
);

class _Host extends StatefulWidget {
  const _Host({
    super.key,
    required this.pages,
    required this.session,
    this.enabled = true,
  });
  final List<List<LayerModel>> pages;
  final TemplatePhotoFillSession session;
  final bool enabled;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<List<LayerModel>> pages = widget.pages;
  CoverSize cover = defaultCoverSize;
  String? owner = 'owner';
  var changes = 0;

  void changeDocument() => setState(() {
    pages = [
      [for (final layer in pages.first) layer.copyWith(rotation: .25)],
      ...pages.skip(1),
    ];
  });

  void changeCover() => setState(() => cover = coverSizes[1]);
  void changeOwner() => setState(() => owner = 'other');

  @override
  Widget build(BuildContext context) => TemplatePhotoFillStep(
    pages: pages,
    cover: cover,
    session: widget.session,
    enableAutoFill: widget.enabled,
    currentOwner: () => owner,
    onChanged: (value) => setState(() {
      pages = value;
      changes++;
    }),
    onContinue: () {},
  );
}

Future<void> _waitFor(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 120; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 8)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (ready()) return;
  }
  fail('The photo-fill operation did not finish.');
}

Future<void> _paint(WidgetTester tester) async {
  await _waitFor(tester, () {
    if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty)
      return false;
    return !find.byType(Image).evaluate().any((element) {
      final pixels = find
          .descendant(
            of: find.byWidget(element.widget),
            matching: find.byType(RawImage),
          )
          .evaluate();
      return pixels.isEmpty ||
          pixels.any((pixel) => (pixel.widget as RawImage).image == null);
    });
  });
  await tester.pumpAndSettle();
}

Future<GlobalKey<_HostState>> _mount(
  WidgetTester tester, {
  required List<List<LayerModel>> pages,
  required TemplatePhotoFillSession session,
  bool enabled = true,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final host = GlobalKey<_HostState>();
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureBoundary,
      child: wrapCreation(
        _Host(key: host, pages: pages, session: session, enabled: enabled),
        textScale: textScale,
      ),
    ),
  );
  await _paint(tester);
  return host;
}

Future<void> _capturePreview(WidgetTester tester) async {
  if (kIsWeb) return;
  if (kIsWeb) return;
  const definedDirectory = String.fromEnvironment('PHOTO_FILL_CAPTURE_DIR');
  final directory = definedDirectory.isNotEmpty
      ? definedDirectory
      : Platform.environment['PHOTO_FILL_CAPTURE_DIR'];
  if (directory == null || directory.isEmpty) return;
  await _paint(tester);
  await tester.runAsync(() async {
    final boundary =
        _captureBoundary.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final pixels = await image.toByteData(format: ui.ImageByteFormat.png);
      if (pixels == null)
        throw StateError('Photo-fill preview capture failed.');
      final file = File('$directory/photo-fill-preview-native.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(pixels.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('fill-auto-fill')));
  await _waitFor(
    tester,
    () => find
        .byKey(const ValueKey('photo-fill-batch-preview'))
        .evaluate()
        .isNotEmpty,
  );
  await _paint(tester);
}

bool _ready(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.byKey(const ValueKey('fill-auto-fill')))
        .onPressed !=
    null;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final exceptionReporter = reportTestException;
  setUpAll(() {
    reportTestException = (details, description) {
      // ignore: avoid_print
      print('Batch failure: ${details.exceptionAsString()}');
      exceptionReporter(details, description);
    };
  });
  tearDownAll(() => reportTestException = exceptionReporter);
  setUpAll(() async {
    if (!kIsWeb) await loadCreationFonts();
    _bytes = kIsWeb
        ? base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
          )
        : (await rootBundle.load(
            'assets/frame_preview/alpine_lake.jpg',
          )).buffer.asUint8List();
  });

  testWidgets(
    'preview cancellation is inert and applying is one complete undo and redo',
    (tester) async {
      final a = _browser('a'), b = _browser('b'), c = _browser('c');
      final existing = _slot('kept').copyWith(
        asset: _browser('kept'),
        imageZoom: 1.6,
        imageOffset: const Offset(4, -9),
      );
      final caption = LayerModel(
        id: 'caption',
        type: LayerType.text,
        text: '내 문구',
        position: const Offset(25, 300),
      );
      final session = TemplatePhotoFillSession()
        ..pendingPhotos.addAll([a, b, c])
        ..selectedPhoto = c
        ..selectedSlot = (page: 1, id: 'second')
        ..page = 1;
      final host = await _mount(
        tester,
        session: session,
        pages: [
          [existing, caption],
          [
            _slot(
              'first',
            ).copyWith(position: const Offset(24, 65), width: 215, height: 290),
            _slot('second').copyWith(
              position: const Offset(265, 110),
              width: 215,
              height: 290,
            ),
          ],
        ],
      );
      await _open(tester);
      final preview = tester.widget<TemplatePageRenderer>(
        find.byKey(const ValueKey('photo-fill-batch-page-1')),
      );
      expect(preview.layers[0].asset, same(a));
      expect(preview.layers[1].asset, same(b));
      expect(host.currentState!.changes, 0);
      expect(host.currentState!.pages[1][0].asset, isNull);
      await _capturePreview(tester);
      await tester.tap(find.byKey(const ValueKey('photo-fill-batch-cancel')));
      await _paint(tester);
      expect(host.currentState!.changes, 0);
      expect(session.pendingPhotos, [a, b, c]);
      expect(session.selectedPhoto, same(c));
      expect(session.selectedSlot, (page: 1, id: 'second'));
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('photo-fill-batch-apply')));
      await _paint(tester);
      expect(host.currentState!.changes, 1);
      expect(host.currentState!.pages[1][0].asset, same(a));
      expect(host.currentState!.pages[1][1].asset, same(b));
      expect(host.currentState!.pages[0], [existing, caption]);
      expect(session.pendingPhotos, [c]);
      expect(session.selectedPhoto, same(c));
      expect(session.selectedSlot, (page: 1, id: 'first'));
      await tester.tap(find.byKey(const ValueKey('photo-fill-undo')));
      await _paint(tester);
      expect(host.currentState!.pages[1][0].asset, isNull);
      expect(host.currentState!.pages[1][1].asset, isNull);
      expect(session.pendingPhotos, [a, b, c]);
      expect(session.selectedPhoto, same(c));
      expect(session.selectedSlot, (page: 1, id: 'second'));
      expect(session.page, 1);
      await tester.tap(find.byKey(const ValueKey('photo-fill-redo')));
      await _paint(tester);
      expect(host.currentState!.pages[1][0].asset, same(a));
      expect(host.currentState!.pages[1][1].asset, same(b));
      expect(session.pendingPhotos, [c]);
      expect(existing.imageZoom, 1.6);
      expect(existing.imageOffset, const Offset(4, -9));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a short selection fills only its first empty slot', (
    tester,
  ) async {
    final photo = _browser('one');
    final session = TemplatePhotoFillSession()
      ..pendingPhotos.add(photo)
      ..selectedPhoto = photo;
    final host = await _mount(
      tester,
      pages: [
        [_slot('cover')],
        [_slot('inner')],
      ],
      session: session,
    );
    await _open(tester);
    expect(find.textContaining('빈 칸 1개는'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('photo-fill-batch-apply')));
    await _paint(tester);
    expect(host.currentState!.pages[0].single.asset, same(photo));
    expect(host.currentState!.pages[1].single.asset, isNull);
    expect(session.pendingPhotos, isEmpty);
    expect(session.selectedPhoto, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one unavailable original rejects the entire proposed batch', (
    tester,
  ) async {
    final good = _browser('good');
    final missing = _native('missing', () async => null);
    final session = TemplatePhotoFillSession()
      ..pendingPhotos.addAll([good, missing])
      ..selectedPhoto = good;
    final host = await _mount(
      tester,
      pages: [
        [_slot('cover')],
        [_slot('inner')],
      ],
      session: session,
    );
    await tester.tap(find.byKey(const ValueKey('fill-auto-fill')));
    await _waitFor(tester, () => _ready(tester));
    expect(host.currentState!.changes, 0);
    expect(
      host.currentState!.pages.expand((p) => p).every((l) => l.asset == null),
      isTrue,
    );
    expect(session.pendingPhotos, [good, missing]);
    expect(
      find.byKey(const ValueKey('photo-fill-batch-preview')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  }, skip: kIsWeb);

  for (final change in ['document', 'cover', 'owner']) {
    testWidgets('a $change change while preparing rejects the proposal', (
      tester,
    ) async {
      final pending = Completer<File?>();
      final photo = _native('pending', () => pending.future);
      final session = TemplatePhotoFillSession()
        ..pendingPhotos.add(photo)
        ..selectedPhoto = photo;
      final host = await _mount(
        tester,
        pages: [
          [_slot('cover')],
        ],
        session: session,
      );
      await tester.tap(find.byKey(const ValueKey('fill-auto-fill')));
      await tester.pump();
      switch (change) {
        case 'document':
          host.currentState!.changeDocument();
        case 'cover':
          host.currentState!.changeCover();
        case 'owner':
          host.currentState!.changeOwner();
      }
      await tester.pump();
      pending.complete(null);
      await _waitFor(tester, () => _ready(tester));
      expect(host.currentState!.changes, 0);
      expect(host.currentState!.pages.single.single.asset, isNull);
      expect(session.pendingPhotos, [photo]);
      expect(
        find.byKey(const ValueKey('photo-fill-batch-preview')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    }, skip: kIsWeb);
  }

  testWidgets('switching owner closes the owned preview without applying it', (
    tester,
  ) async {
    final photo = _browser('private');
    final session = TemplatePhotoFillSession()
      ..pendingPhotos.add(photo)
      ..selectedPhoto = photo;
    final host = await _mount(
      tester,
      pages: [
        [_slot('cover')],
      ],
      session: session,
    );
    await _open(tester);
    host.currentState!.changeOwner();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('photo-fill-batch-preview')),
      findsNothing,
    );
    expect(host.currentState!.changes, 0);
    expect(host.currentState!.pages.single.single.asset, isNull);
    expect(session.pendingPhotos, [photo]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI and other non opted-in flows keep their existing controls', (
    tester,
  ) async {
    final photo = _browser('selected');
    final session = TemplatePhotoFillSession()
      ..pendingPhotos.add(photo)
      ..selectedPhoto = photo;
    await _mount(
      tester,
      pages: [
        [_slot('cover')],
      ],
      session: session,
      enabled: false,
    );
    expect(find.byKey(const ValueKey('fill-auto-fill')), findsNothing);
    expect(find.byKey(const ValueKey('fill-add-photos')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('batch preview stays usable at $size and larger text', (
      tester,
    ) async {
      final photo = _browser('preview');
      final session = TemplatePhotoFillSession()
        ..pendingPhotos.add(photo)
        ..selectedPhoto = photo;
      await _mount(
        tester,
        pages: [
          [_slot('cover')],
        ],
        session: session,
        size: size,
        textScale: 1.5,
      );
      await _open(tester);
      expect(
        find.byKey(const ValueKey('photo-fill-batch-apply')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('photo-fill-batch-cancel')));
      await _paint(tester);
    });
  }

  testWidgets(
    'prepared native files are restored by the same undo and redo transaction',
    (tester) async {
      final photo = _native(
        'local',
        () async => File('assets/frame_preview/alpine_lake.jpg'),
      );
      final session = TemplatePhotoFillSession()
        ..pendingPhotos.add(photo)
        ..selectedPhoto = photo;
      final host = await _mount(
        tester,
        pages: [
          [_slot('cover')],
        ],
        session: session,
      );
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('photo-fill-batch-apply')));
      await _paint(tester);
      Iterable<TemplatePageRenderer> renderers() =>
          tester.widgetList(find.byType(TemplatePageRenderer));
      expect(
        renderers().any(
          (renderer) => renderer.localFiles?.containsKey('cover') == true,
        ),
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('photo-fill-undo')));
      await _paint(tester);
      expect(host.currentState!.pages.single.single.asset, isNull);
      expect(
        renderers().every((renderer) => renderer.localFiles?.isEmpty != false),
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('photo-fill-redo')));
      await _paint(tester);
      expect(
        renderers().any(
          (renderer) => renderer.localFiles?.containsKey('cover') == true,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
    skip: kIsWeb,
  );
}
