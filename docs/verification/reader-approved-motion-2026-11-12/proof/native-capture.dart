import '/tmp/snapfit-approved-canvas-reference.dart';

import 'package:book_page_flip/src/engine.dart' as engine;
import 'package:flutter/src/widgets/widget_inspector.dart'
    show WidgetInspectorService;
import 'package:snap_fit/features/album/presentation/widgets/cover/album_spine_image.dart';
import 'package:book_page_flip/book_page_flip.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/album_reader_single_page_view.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/views/album_reader_screen.dart';
import 'package:snap_fit/features/album/service/album_collaboration_session.dart';

// Fresh native captures of the existing PageEditorScreen, not a new unified
// editor implementation. The session is local and no save/gallery action runs.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/page_editor_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/page_editor_canvas.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/shared/widgets/catalog_cover_skeleton.dart';

// Reuse the complete existing backend fakes instead of inventing an editor VM
// or bypassing page/selection ownership safeguards for screenshots.
import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/page_editor_screen_golden_test.dart'
    show MockAlbumRepository, FakeStorageService, FakeAlbumPersistenceService;

const _owner = 'reader-audit-owner';
Album? _activeAlbum;

class _Albums extends MockAlbumRepository {
  @override
  Future<Album> fetchAlbum(String id) async => _activeAlbum!;
}

const _portrait = Size(390, 844);
const _landscape = Size(844, 390);
const _dpr = 2.0;
final _boundary = GlobalKey();
late List<List<LayerModel>> _pages;
late Size _sourceCanvas;
late String _title, _productKey;
late int _photoPage;

class _Binding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _Auth extends AuthViewModel {
  @override
  FutureOr<UserInfo?> build() =>
      const UserInfo(id: _owner, name: '편집 시각 점검', provider: 'email');
}

Future<void> _loadFixture() async {
  await AssetManifest.loadFromAssetBundle(rootBundle);
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in entry['fonts'] as List) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
  final template = publishedCreationTemplates.firstWhere(
    (item) => item.id == -9501,
  );
  _title = template.title;
  _productKey = pointShopTemplateKey(template);
  final data = jsonDecode(template.templateJson!) as Map<String, dynamic>;
  final metadata = data['metadata'] as Map? ?? const {};
  _sourceCanvas = Size(
    (data['designWidth'] as num? ?? metadata['designWidth'] as num? ?? 500)
        .toDouble(),
    (data['designHeight'] as num? ?? metadata['designHeight'] as num? ?? 500)
        .toDouble(),
  );
  _pages = templateDocumentPages(data)
      .take(25)
      .map(
        (page) => DataTemplateEngine.buildLayersFromJson({
          'strictLayout': true,
          'designWidth': _sourceCanvas.width,
          'designHeight': _sourceCanvas.height,
          'layers': page['layers'],
        }, _sourceCanvas),
      )
      .toList();
  expect(_pages, hasLength(25));
  _pages = _pages.take(5).toList();
  _photoPage = _pages
      .asMap()
      .entries
      .firstWhere(
        (entry) =>
            entry.key > 0 &&
            entry.value.any(
              (layer) => layer.type == LayerType.image && layer.hasImageSource,
            ),
      )
      .key;
  debugPrint(
    'UNIFIED_EDITOR_AUDIT template=${template.id} title=$_title '
    'product=$_productKey pages=${_pages.length} selectedPhotoPage=$_photoPage',
  );
}

bool _imagesReady() => find.byType(Image).evaluate().every((element) {
  final root = find.byWidget(element.widget);
  final pixels = find
      .descendant(of: root, matching: find.byType(RawImage))
      .evaluate();
  if (pixels.isNotEmpty)
    return pixels.every((pixel) => (pixel.widget as RawImage).image != null);
  // 표지는 디코딩된 RawImage를 곡면 CustomPainter로 바꿔 그린다.
  return find
      .descendant(
        of: root,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter is AlbumSpineImagePainter &&
              (widget.painter as AlbumSpineImagePainter).image.width > 0,
        ),
      )
      .evaluate()
      .isNotEmpty;
});

Future<void> _settle(WidgetTester tester) async {
  var stable = 0;
  for (var frame = 0; frame < 160; frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump(const Duration(milliseconds: 32));
    final ready =
        (find.byType(AlbumReaderScreen).evaluate().isNotEmpty ||
            find.byType(PageEditorScreen).evaluate().isNotEmpty) &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty &&
        find.byType(CatalogCoverSkeleton).evaluate().isEmpty &&
        PaintingBinding.instance.imageCache.pendingImageCount == 0 &&
        _imagesReady() &&
        !tester.binding.hasScheduledFrame;
    stable = ready && frame >= 12 ? stable + 1 : 0;
    if (stable == 4) {
      expect(tester.takeException(), isNull);
      return;
    }
  }
  debugPrint(
    'READER_CAPTURE readyImages=${_imagesReady()} pending=${PaintingBinding.instance.imageCache.pendingImageCount} progress=${find.byType(CircularProgressIndicator).evaluate().length} skeleton=${find.byType(CatalogCoverSkeleton).evaluate().length} scheduled=${tester.binding.hasScheduledFrame}',
  );
  expect(tester.takeException(), isNull);
  expect(PaintingBinding.instance.imageCache.pendingImageCount, 0);
  expect(find.byType(CircularProgressIndicator), findsNothing);
  expect(find.byType(CatalogCoverSkeleton), findsNothing);
  expect(_imagesReady(), isTrue);
}

Future<({AlbumEditorViewModel vm, String? photoId})> _mount(
  WidgetTester tester, {
  int page = 0,
  bool selectPhoto = false,
  Size size = _portrait,
}) async {
  tester.view.devicePixelRatio = _dpr;
  tester.view.physicalSize = Size(size.width * _dpr, size.height * _dpr);
  tester.view.padding = size.width > size.height
      ? const FakeViewPadding(left: 64, right: 96, bottom: 48)
      : const FakeViewPadding(top: 48, bottom: 68);
  tester.view.viewPadding = tester.view.padding;
  final container = ProviderContainer(
    overrides: [
      authViewModelProvider.overrideWith(_Auth.new),
      albumEditorOwnerReaderProvider.overrideWithValue(() => _owner),
      albumEditorOwnerChangesProvider.overrideWith(
        (ref) => Stream.value(_owner),
      ),
      albumRepositoryProvider.overrideWithValue(_Albums()),
      albumCollaborationActorProvider.overrideWithValue(_owner),
      albumEditorServiceProvider.overrideWithValue(const AlbumEditorService()),
      albumPersistenceServiceProvider.overrideWithValue(
        FakeAlbumPersistenceService(),
      ),
      storageServiceProvider.overrideWithValue(FakeStorageService()),
    ],
  );
  addTearDown(() async {
    // Dispose the real screen first so its editor/remote-check timers stop.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    container.dispose();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    tester.view.reset();
  });
  await container.read(authViewModelProvider.future);
  await container.read(albumEditorViewModelProvider.future);
  final vm = container.read(albumEditorViewModelProvider.notifier);
  vm.startLocalTemplateAlbum(
    albumTitle: _title,
    initialCover: defaultCoverSize,
    pages: _pages,
    templateCanvasSize: _sourceCanvas,
    sourceTemplateProductKey: _productKey,
  );
  _activeAlbum = Album(
    id: 71,
    userId: _owner,
    memberRole: 'OWNER',
    title: _title,
    ratio: defaultCoverSize.ratio.toString(),
    targetPages: 4,
    updatedAt: '2026-11-11T00:00:00Z',
    coverLayersJson: vm.exportFullAlbumLayersJson(null),
  );
  await vm.prepareAlbumForEdit(_activeAlbum!);
  vm.loadPendingEditAlbumIfNeeded(const Size(500, 500));
  expect(vm.pages.length, greaterThanOrEqualTo(5));
  final photoId = selectPhoto
      ? vm.pages[page].layers
            .firstWhere(
              (layer) => layer.type == LayerType.image && layer.hasImageSource,
            )
            .id
      : null;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: _portrait,
        minTextAdapt: true,
        builder: (_, __) => RepaintBoundary(
          key: _boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: SnapFitTheme.light().copyWith(
              splashFactory: NoSplash.splashFactory,
            ),
            home: AlbumReaderScreen(initialSpreadIndex: page),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);

  debugPrint(
    'UNIFIED_EDITOR_AUDIT localId=${vm.editingAlbumId} '
    'pageId=${vm.currentPage!.id} page=$page photo=$photoId',
  );
  return (vm: vm, photoId: photoId);
}

void _markPaint(RenderObject object) {
  object.visitChildren(_markPaint);
  if (object.attached) {
    object.markNeedsLayout();
    object.markNeedsPaint();
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  await _settle(tester);
  for (final view in tester.binding.renderViews) {
    _markPaint(view);
  }
  await tester.pump(const Duration(milliseconds: 32));
  final directory =
      Platform.environment['READER_AUDIT_DIR'] ??
      const String.fromEnvironment('UNIFIED_EDITOR_AUDIT_DIR');
  if (directory.isEmpty)
    throw StateError('UNIFIED_EDITOR_AUDIT_DIR is required.');
  await tester.runAsync(() async {
    final boundary =
        _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = (await WidgetInspectorService.instance.screenshot(
      boundary,
      width: boundary.size.width * _dpr,
      height: boundary.size.height * _dpr,
      maxPixelRatio: _dpr,
    ))!;
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null)
        throw StateError('Editor audit pixels were unavailable.');
      final file = File('$directory/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      debugPrint(
        'UNIFIED_EDITOR_AUDIT captured ${file.path} ${image.width}x${image.height}',
      );
    } finally {
      image.dispose();
    }
  });
}

BookFlipController _book(WidgetTester tester) =>
    tester.widget<BookFlip>(find.byType(BookFlip)).controller!;

Future<void> _frame(WidgetTester tester, String name) async {
  // 애니메이션을 진행시키지 않고 실제 네이티브 렌더 트리를 캡처한다.
  for (final view in tester.binding.renderViews) {
    _markPaint(view);
  }
  await tester.pump();
  final directory = Platform.environment['READER_AUDIT_DIR']!;
  await tester.runAsync(() async {
    final boundary =
        _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = (await WidgetInspectorService.instance.screenshot(
      boundary,
      width: boundary.size.width * _dpr,
      height: boundary.size.height * _dpr,
      maxPixelRatio: _dpr,
    ))!;
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$directory/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  });
}

engine.FlipScene _scene(WidgetTester tester) =>
    (tester.widget(
          find.byElementPredicate(
            (element) =>
                element is RenderObjectElement &&
                element.renderObject is engine.RenderBookCanvas,
          ),
        ) as dynamic).scene
        as engine.FlipScene;

Future<void> _exportAtlas(WidgetTester tester) async {
  final scene = _scene(tester);
  final directory = Platform.environment['READER_AUDIT_DIR']!;
  await tester.runAsync(() async {
    final out = Directory('$directory/reference');
    await out.create(recursive: true);
    for (var index = 2; index <= 5; index++) {
      final recorder = ui.PictureRecorder();
      final c = Canvas(recorder);
      c.drawImageRect(
        scene.atlas!,
        Rect.fromLTWH(
          (index % scene.atlasCols * scene.cellW).toDouble(),
          (index ~/ scene.atlasCols * scene.cellH).toDouble(),
          scene.cellW.toDouble(),
          scene.cellH.toDouble(),
        ),
        Rect.fromLTWH(0, 0, scene.cellW.toDouble(), scene.cellH.toDouble()),
        Paint()..filterQuality = FilterQuality.none,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(scene.cellW, scene.cellH);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('${out.path}/page-${index - 1}.png').writeAsBytes(
          bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
      } finally {
        image.dispose();
        picture.dispose();
      }
    }
    await File('${out.path}/manifest.json').writeAsString(
      jsonEncode({
        'viewport': {
          'top': tester
              .getRect(find.byKey(const ValueKey('reader-page-viewport')))
              .top,
          'width': tester
              .getRect(find.byKey(const ValueKey('reader-page-viewport')))
              .width,
          'height': tester
              .getRect(find.byKey(const ValueKey('reader-page-viewport')))
              .height,
          'dpr': _dpr,
        },
        'pageWidth': scene.w / 2,
        'pageHeight': scene.h,
        'pad': 28,
        'cellWidth': scene.cellW,
        'cellW': scene.cellW,
        'cellHeight': scene.cellH,
        'cellH': scene.cellH,
      }),
    );
  });
}

Future<void> _engineFrame(WidgetTester tester, String name) async {
  final element = find
      .byElementPredicate(
        (element) =>
            element is RenderObjectElement &&
            element.renderObject is engine.RenderBookCanvas,
      )
      .evaluate()
      .single;
  final scene = _scene(tester);
  await tester.runAsync(() async {
    final image = (await WidgetInspectorService.instance.screenshot(
      element.renderObject!,
      width: scene.w + 56,
      height: scene.h + 56,
      maxPixelRatio: 1,
      margin: 28,
    ))!;
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(
        '${Platform.environment['READER_AUDIT_DIR']}/reference/$name.png',
      );
      await file.writeAsBytes(
        bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  });
}

Future<void> _referenceFrames(WidgetTester tester) async {
  await tester.runAsync(() async {
    final directory = Platform.environment['READER_AUDIT_DIR']!;
    final generated = await Process.run('node', [
      '/tmp/generate-approved-canvas-ops.cjs',
      '$directory/reference/manifest.json',
      '$directory/reference/commands.json',
    ]);
    if (generated.exitCode != 0)
      throw StateError(
        'Reference command extraction failed: ${generated.stderr}',
      );
    final document = jsonDecode(
      await File('$directory/reference/commands.json').readAsString(),
    ) as Map;
    final scene = _scene(tester);
    final images = <ui.Image>[];
    try {
      for (var i = 1; i <= 4; i++) {
        final codec = await ui.instantiateImageCodec(
          await File('$directory/reference/page-$i.png').readAsBytes(),
        );
        final frame = await codec.getNextFrame();
        images.add(frame.image);
        codec.dispose();
      }
      for (final frame in document['frames'] as List) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..translate(28 + scene.w / 2, 28);
        paintApprovedCanvasReference(canvas, frame['ops'] as List, images);
        final picture = recorder.endRecording();
        final image = await picture.toImage(
          (scene.w + 56).round(),
          (scene.h + 56).round(),
        );
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final label = ((frame['progress'] as num) * 100)
              .round()
              .toString()
              .padLeft(3, '0');
          await File('$directory/reference/html-$label.png').writeAsBytes(
            bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          );
        } finally {
          image.dispose();
          picture.dispose();
        }
      }
    } finally {
      for (final image in images) {
        image.dispose();
      }
    }
  });
}

void main() {
  _Binding();
  setUpAll(_loadFixture);
  testWidgets('native reader single-page and leaf evidence', (tester) async {
    await _mount(tester, page: 1);
    await _capture(tester, '01-left-page');
    final controller = _book(tester);
    expect(controller.currentSpread, 1);
    await tester.tap(find.byTooltip('다음 페이지'));
    await _settle(tester);
    expect(controller.currentSpread, 1);
    await _capture(tester, '02-right-page');
    await _frame(tester, 'frames/000');
    await tester.tap(find.byTooltip('다음 페이지'));
    // 전환의 각 중간 프레임을 실제 BookFlip 렌더러에서 기록한다.
    for (var frame = 1; frame <= 36; frame++) {
      await tester.pump(const Duration(milliseconds: 33));
      await _frame(tester, 'frames/${frame.toString().padLeft(3, '0')}');
      if (frame == 9) await _frame(tester, '03-leaf-in-flight');
    }
    await _settle(tester);
    expect(controller.currentSpread, 2);
    expect(
      tester
          .widget<AlbumReaderSinglePageView>(
            find.byType(AlbumReaderSinglePageView),
          )
          .requestedFocusPageIndex,
      3,
    );
    await _capture(tester, '04-next-left-page');
    await _capture(tester, '05-page-list');
    await tester.tap(find.byTooltip('앨범 메뉴'));
    await _settle(tester);
    await _capture(tester, '06-menu');
  });
  testWidgets('native reader cover evidence', (tester) async {
    await _mount(tester);
    await _capture(tester, '07-cover');
  });
  testWidgets('native reader landscape evidence', (tester) async {
    await _mount(tester, page: 1, size: _landscape);
    await _capture(tester, '08-landscape');
  });
  testWidgets('native reader exact approved leaf frames', (tester) async {
    await _mount(tester, page: 1);
    await tester.tap(find.byTooltip('다음 페이지'));
    await _settle(tester);
    await _exportAtlas(tester);
    await _referenceFrames(tester);
    final viewport = tester.getRect(
      find.byKey(const ValueKey('reader-page-viewport')),
    );
    final gesture = await tester.startGesture(
      Offset(viewport.right - 40, viewport.center.dy),
    );
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    final scene = _scene(tester);
    for (final progress in [0.0, .25, .5, .75, 1.0]) {
      _book(tester).dragToDistance(
        localPosition: Offset(scene.w * .75, scene.h / 2),
        direction: FlipDirection.forward,
        distance: scene.w / 2 * progress,
      );
      await tester.pump();
      final label = (progress * 100).round().toString().padLeft(3, '0');
      await _frame(tester, 'progress/forward-$label');
      await _engineFrame(tester, 'native-$label');
      expect(_book(tester).flipProgress, closeTo(progress, .00001));
    }
    await gesture.up();
    await _settle(tester);
    expect(_book(tester).currentSpread, 2);
  });
  testWidgets('native reader cover opens and closes with approved motion', (
    tester,
  ) async {
    await _mount(tester);
    await _frame(tester, 'cover-frames/000');
    var frameIndex = 1;
    for (final next in [true, false]) {
      await tester.tap(find.byTooltip(next ? '다음 페이지' : '이전 페이지'));
      await tester.pump();
      await tester.pump();
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 33));
        await _frame(
          tester,
          'cover-frames/${frameIndex.toString().padLeft(3, '0')}',
        );
        frameIndex++;
      }
      await _settle(tester);
      expect(_book(tester).currentSpread, next ? 1 : 0);
      await _capture(tester, next ? '09-cover-opened' : '10-cover-closed');
    }
  });
}
