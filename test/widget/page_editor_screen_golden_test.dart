import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/api/storage_service.dart';
import 'package:snap_fit/features/album/data/dto/request/create_album_request.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/repositories/album_repository.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/page_editor_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/editor_bottom_menu.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/edit_cover.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/layer_manager_panel.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'package:snap_fit/features/album/service/album_persistence_service.dart';

class MockAlbumRepository extends Mock implements AlbumRepository {}

class FakeStorageService implements StorageService {
  @override
  Future<String?> uploadProfileImage(File file, String userId) async => null;

  @override
  Future<String?> uploadFile(File file, String path) async => null;

  @override
  Future<UploadedUrls> uploadImageVariants(
    AssetEntity asset, {
    int previewMaxDimension = 1600,
  }) async => const UploadedUrls();

  @override
  Future<UploadedUrls> uploadCoverVariants(
    Uint8List pngBytes, {
    int originalMaxDimension = 4096,
    int previewMaxDimension = 1024,
  }) async => const UploadedUrls();
}

class FakeAlbumPersistenceService implements AlbumPersistenceService {
  @override
  Future<void> performBackgroundUpload({
    required int albumId,
    required Size canvasSize,
    required List<LayerModel> currentLayers,
    required Uint8List? coverImageBytes,
    required String themeLabel,
    required String title,
    required double coverRatio,
    required int targetPages,
    bool swallowErrors = true,
    void Function(int completed, int total)? onProgress,
  }) async {}

  @override
  Future<bool> pollAlbumCreation(int albumId) async => false;
}

Future<void> _loadGoldenFonts() async {
  final korean = FontLoader('Noto Sans KR')
    ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/NotoSansKR-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Bold.ttf'));
  await korean.load();

  final materialIcons = FontLoader('MaterialIcons')
    ..addFont(
      File(
        '/opt/data/flutter-sdk-release/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes().then(ByteData.sublistView),
    );
  await materialIcons.load();
}

List<Override> _editorOverrides() {
  final mockRepo = MockAlbumRepository();
  return [
    albumRepositoryProvider.overrideWithValue(mockRepo),
    albumEditorServiceProvider.overrideWithValue(const AlbumEditorService()),
    albumPersistenceServiceProvider.overrideWithValue(
      FakeAlbumPersistenceService(),
    ),
    storageServiceProvider.overrideWithValue(FakeStorageService()),
  ];
}

class _EditorGoldenBoot extends ConsumerStatefulWidget {
  const _EditorGoldenBoot();

  @override
  ConsumerState<_EditorGoldenBoot> createState() => _EditorGoldenBootState();
}

class _EditorGoldenBootState extends ConsumerState<_EditorGoldenBoot> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(albumEditorViewModelProvider.future);
      if (!mounted) return;
      final cover = coverSizes.firstWhere(
        (item) => item.name == '세로형',
        orElse: () => coverSizes.first,
      );
      ref
          .read(albumEditorViewModelProvider.notifier)
          .startLocalTemplateAlbum(
            albumTitle: '편집 작업대 골든',
            initialCover: cover,
            pages: [
              [
                LayerModel(
                  id: 'cover-title-layer',
                  type: LayerType.text,
                  text: '제주 가족 여행',
                  position: const Offset(54, 84),
                  width: 260,
                  height: 72,
                  textStyle: const TextStyle(
                    color: Colors.black87,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                LayerModel(
                  id: 'cover-photo-slot',
                  type: LayerType.decoration,
                  position: const Offset(70, 190),
                  width: 230,
                  height: 230,
                  decorationFillColor: '#EAFBFD',
                  decorationBorderColor: '#16BFD0',
                  decorationBorderWidth: 3,
                  decorationCornerRadius: 24,
                ),
              ],
              const [],
            ],
          );
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return const PageEditorScreen();
  }
}

Widget _wrapEditor() {
  return ProviderScope(
    overrides: _editorOverrides(),
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (_, __) => MaterialApp(
        theme: ThemeData(fontFamily: 'Noto Sans KR'),
        home: const _EditorGoldenBoot(),
      ),
    ),
  );
}

Future<void> _pumpEditorToEntryMotion(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_wrapEditor());
  for (var i = 0; i < 12; i += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    if (find.byKey(const Key('pageEditorCanvasReveal')).evaluate().isNotEmpty) {
      return;
    }
  }
}

double _firstOpacityUnder(WidgetTester tester, Key key) {
  return tester
      .widgetList<Opacity>(
        find.descendant(of: find.byKey(key), matching: find.byType(Opacity)),
      )
      .first
      .opacity;
}

Future<void> _pumpEditor(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_wrapEditor());
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    registerFallbackValue(
      const CreateAlbumRequest(
        ratio: '1:1',
        coverLayersJson: '{}',
        coverImageUrl: '',
        coverThumbnailUrl: '',
      ),
    );
    await _loadGoldenFonts();
  });

  testWidgets(
    'page editor 390 viewport keeps canvas and command dock separated',
    (tester) async {
      await _pumpEditor(tester);

      expect(find.text('표지 다듬기'), findsOneWidget);
      expect(find.byType(EditCover), findsOneWidget);
      expect(find.byType(EditorBottomMenu), findsOneWidget);
      expect(find.text('템플릿'), findsOneWidget);
      expect(find.text('레이어'), findsOneWidget);

      final canvasBottom = tester.getBottomLeft(find.byType(EditCover)).dy;
      final dockTop = tester.getTopLeft(find.byType(EditorBottomMenu)).dy;
      expect(canvasBottom, lessThan(dockTop));
    },
  );

  testWidgets(
    'page editor first entry stages canvas selector and dock motion',
    (tester) async {
      await _pumpEditor(tester);

      expect(find.byKey(const Key('pageEditorCanvasReveal')), findsOneWidget);
      expect(find.byKey(const Key('pageEditorSelectorReveal')), findsOneWidget);
      expect(find.byKey(const Key('pageEditorDockReveal')), findsOneWidget);
    },
  );

  testWidgets(
    'page editor entry motion exposes staggered middle frame behavior',
    (tester) async {
      await _pumpEditorToEntryMotion(tester);
      await tester.pump(const Duration(milliseconds: 96));

      final canvasOpacity = _firstOpacityUnder(
        tester,
        const Key('pageEditorCanvasReveal'),
      );
      final selectorOpacity = _firstOpacityUnder(
        tester,
        const Key('pageEditorSelectorReveal'),
      );
      final dockOpacity = _firstOpacityUnder(
        tester,
        const Key('pageEditorDockReveal'),
      );

      expect(canvasOpacity, greaterThan(0));
      expect(canvasOpacity, lessThan(1));
      expect(selectorOpacity, greaterThan(0));
      expect(selectorOpacity, lessThan(canvasOpacity));
      expect(dockOpacity, lessThan(canvasOpacity));
    },
  );

  testWidgets('page selector triggers dimensional page-turn reveal on canvas', (
    tester,
  ) async {
    await _pumpEditor(tester);

    await tester.tap(find.text('1쪽'));
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byKey(const Key('pageEditorPageTurnReveal')), findsOneWidget);
    expect(find.byKey(const Key('pageSelectorSelectionGlow')), findsOneWidget);
    final opacity = tester
        .widget<Opacity>(find.byKey(const Key('pageEditorPageTurnOpacity')))
        .opacity;
    expect(opacity, greaterThanOrEqualTo(0.18));
    expect(opacity, lessThan(1));
    expect(
      find.byKey(const Key('pageEditorPageEdgeHighlight')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 240));
    final settlingScale = tester
        .widget<Transform>(find.byKey(const Key('pageEditorPageSettleScale')))
        .transform
        .storage[0];
    expect(settlingScale, greaterThan(1));

    await tester.pumpAndSettle();
    expect(find.text('1페이지 꾸미기'), findsOneWidget);
  });

  testWidgets(
    'editor tool opens inline atelier panel without modal route jump',
    (tester) async {
      await _pumpEditor(tester);

      await tester.tap(find.text('레이어'));
      await tester.pump(const Duration(milliseconds: 180));

      expect(find.byKey(const Key('editorAtelierPanel')), findsOneWidget);
      expect(find.byType(LayerManagerPanel), findsOneWidget);
      expect(find.byType(EditorBottomMenu), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);

      final panelBottom = tester
          .getBottomLeft(find.byKey(const Key('editorAtelierPanel')))
          .dy;
      final dockTop = tester.getTopLeft(find.byType(EditorBottomMenu)).dy;
      expect(panelBottom, lessThanOrEqualTo(dockTop + 1));
    },
  );

  testWidgets(
    'page editor full workspace golden captures canvas dock and layer sheet',
    (tester) async {
      await _pumpEditor(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PageEditorScreen),
        matchesGoldenFile('goldens/page_editor_workspace_390x844.png'),
      );

      await tester.tap(find.text('레이어'));
      await tester.pumpAndSettle();

      expect(find.byType(LayerManagerPanel), findsOneWidget);
      expect(find.textContaining('항목을 탭하면'), findsOneWidget);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/page_editor_layer_panel_390x844.png'),
      );
    },
  );
}
