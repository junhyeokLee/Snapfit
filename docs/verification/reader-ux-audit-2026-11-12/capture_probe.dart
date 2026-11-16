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
 @override Future<Album> fetchAlbum(String id) async => _activeAlbum!;
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
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in entry['fonts'] as List) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
  final template = publishedCreationTemplates.firstWhere((item) => item.id == -9501);
  _title = template.title;
  _productKey = pointShopTemplateKey(template);
  final data = jsonDecode(template.templateJson!) as Map<String, dynamic>;
  final metadata = data['metadata'] as Map? ?? const {};
  _sourceCanvas = Size(
    (data['designWidth'] as num? ?? metadata['designWidth'] as num? ?? 500).toDouble(),
    (data['designHeight'] as num? ?? metadata['designHeight'] as num? ?? 500).toDouble(),
  );
  _pages = templateDocumentPages(data).take(25).map((page) =>
    DataTemplateEngine.buildLayersFromJson({
      'strictLayout': true,
      'designWidth': _sourceCanvas.width,
      'designHeight': _sourceCanvas.height,
      'layers': page['layers'],
    }, _sourceCanvas),
  ).toList();
  expect(_pages, hasLength(25));
  _pages = _pages.take(5).toList();
  _photoPage = _pages.asMap().entries.firstWhere((entry) =>
    entry.key > 0 && entry.value.any((layer) =>
      layer.type == LayerType.image && layer.hasImageSource),
  ).key;
  debugPrint('UNIFIED_EDITOR_AUDIT template=${template.id} title=$_title '
      'product=$_productKey pages=${_pages.length} selectedPhotoPage=$_photoPage');
}

bool _imagesReady() => find.byType(Image).evaluate().every((element) {
  final pixels = find.descendant(
    of: find.byWidget(element.widget), matching: find.byType(RawImage),
  ).evaluate();
  return pixels.isNotEmpty && pixels.every((pixel) => (pixel.widget as RawImage).image != null);
});

Future<void> _settle(WidgetTester tester) async {
  var stable = 0;
  for (var frame = 0; frame < 160; frame++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump(const Duration(milliseconds: 32));
    final ready = (find.byType(AlbumReaderScreen).evaluate().isNotEmpty || find.byType(PageEditorScreen).evaluate().isNotEmpty) &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty &&
        find.byType(CatalogCoverSkeleton).evaluate().isEmpty &&
        PaintingBinding.instance.imageCache.pendingImageCount == 0 &&
        _imagesReady() && !tester.binding.hasScheduledFrame;
    stable = ready && frame >= 12 ? stable + 1 : 0;
    if (stable == 4) {
      expect(tester.takeException(), isNull);
      return;
    }
  }
  debugPrint('READER_CAPTURE readyImages=${_imagesReady()} pending=${PaintingBinding.instance.imageCache.pendingImageCount} progress=${find.byType(CircularProgressIndicator).evaluate().length} skeleton=${find.byType(CatalogCoverSkeleton).evaluate().length} scheduled=${tester.binding.hasScheduledFrame}');
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
  final container = ProviderContainer(overrides: [
    authViewModelProvider.overrideWith(_Auth.new),
    albumEditorOwnerReaderProvider.overrideWithValue(() => _owner),
    albumEditorOwnerChangesProvider.overrideWith((ref) => Stream.value(_owner)),
    albumRepositoryProvider.overrideWithValue(_Albums()),
    albumCollaborationActorProvider.overrideWithValue(_owner),
    albumEditorServiceProvider.overrideWithValue(const AlbumEditorService()),
    albumPersistenceServiceProvider.overrideWithValue(FakeAlbumPersistenceService()),
    storageServiceProvider.overrideWithValue(FakeStorageService()),
  ]);
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
  _activeAlbum = Album(id:71,userId:_owner,memberRole:'OWNER',title:_title,
    ratio:defaultCoverSize.ratio.toString(),targetPages:4,updatedAt:'2026-11-11T00:00:00Z',
    coverLayersJson:vm.exportFullAlbumLayersJson(null));
  await vm.prepareAlbumForEdit(_activeAlbum!);
  vm.loadPendingEditAlbumIfNeeded(const Size(500,500));
  expect(vm.pages.length, greaterThanOrEqualTo(5));
  final photoId = selectPhoto ? vm.pages[page].layers.firstWhere((layer) =>
    layer.type == LayerType.image && layer.hasImageSource,
  ).id : null;
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
            theme: SnapFitTheme.light().copyWith(splashFactory: NoSplash.splashFactory),
            home: AlbumReaderScreen(initialSpreadIndex: page),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);

  debugPrint('UNIFIED_EDITOR_AUDIT localId=${vm.editingAlbumId} '
      'pageId=${vm.currentPage!.id} page=$page photo=$photoId');
  return (vm: vm, photoId: photoId);
}

void _markPaint(RenderObject object) {
  object.visitChildren(_markPaint);
  if (object.attached) object.markNeedsPaint();
}

Future<void> _capture(WidgetTester tester, String name) async {
  await _settle(tester);
  for (final view in tester.binding.renderViews) {
    _markPaint(view);
  }
  await tester.pump(const Duration(milliseconds: 32));
  final directory = Platform.environment['READER_AUDIT_DIR'] ??
      const String.fromEnvironment('UNIFIED_EDITOR_AUDIT_DIR');
  if (directory.isEmpty) throw StateError('UNIFIED_EDITOR_AUDIT_DIR is required.');
  await tester.runAsync(() async {
    final boundary = _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: _dpr);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Editor audit pixels were unavailable.');
      final file = File('$directory/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
      debugPrint('UNIFIED_EDITOR_AUDIT captured ${file.path} ${image.width}x${image.height}');
    } finally {
      image.dispose();
    }
  });
}


void main(){
  _Binding();setUpAll(_loadFixture);
  testWidgets('reader cover portrait',(tester)async{
    await _mount(tester);await _capture(tester,'01-cover');
  });
  testWidgets('reader inner spread and menu',(tester)async{
    await _mount(tester,page:1);await _capture(tester,'02-spread');
    await tester.tap(find.byTooltip('앨범 메뉴'));
    await tester.pump(const Duration(milliseconds:400));
    await _capture(tester,'03-menu');
  });
  testWidgets('reader page detail',(tester)async{
    await _mount(tester,page:1);
    final spread=tester.getRect(find.byKey(const ValueKey('reader-live-spread')));
    await tester.tapAt(Offset(spread.right-spread.width/4,spread.center.dy));
    await _settle(tester);
    await _capture(tester,'05-page-detail');
  });
  testWidgets('reader inner landscape',(tester)async{
    await _mount(tester,page:1,size:_landscape);await _capture(tester,'04-landscape');
  });
}
