import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/constants/cover_theme.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/domain/entities/album_page.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_builder.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';
import 'package:snap_fit/features/album/presentation/widgets/web/web_album_workspace.dart';
import 'package:snap_fit/features/album/presentation/widgets/web/web_layer_transform_inspector.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import 'package:snap_fit/features/store/presentation/widgets/web/web_catalog_toolbar.dart';
import 'package:snap_fit/features/store/presentation/widgets/web/web_design_detail_layout.dart';
import 'package:snap_fit/shared/web/web_design.dart';
import 'package:snap_fit/features/store/presentation/views/public_discovery_screen.dart';

import '../support/web_customer_design_fixture.dart';

class _CaptureBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

/// Production compositions with one published, locally bundled photo album.
/// No account, repositories, payment SDKs, network images or writes are involved.
class _LocalAlbum {
  _LocalAlbum() {
    final collection = authoredCollections.firstWhere(
      (item) => item.id == 'wind-atlas',
    );
    title = collection.title;
    final source = collection.document(CollectionAspect.square);
    pages = [
      for (final (index, page) in templateDocumentPages(source).indexed)
        AlbumPage(
          id: 'local-design-$index',
          pageIndex: index,
          isCover: index == 0,
          layers: DataTemplateEngine.buildLayersFromJson({
            'strictLayout': true,
            'designWidth': canvas.width,
            'designHeight': canvas.height,
            'layers': page['layers'] ?? [],
          }, canvas),
        ),
    ];
    photoPage = pages.indexWhere(
      (page) =>
          page.pageIndex > 0 &&
          page.layers.any(
            (layer) => layer.type == LayerType.image && layer.hasImageSource,
          ),
    );
    if (photoPage < 0)
      throw StateError('published fixture has no photo interior');
    // A fixture cannot silently introduce external customer or stock URLs.
    for (final layer in pages.expand((page) => page.layers)) {
      for (final value in [
        layer.imageUrl,
        layer.previewUrl,
        layer.originalUrl,
        layer.textFillImageUrl,
      ]) {
        if (value?.startsWith('http') == true) {
          throw StateError('capture fixture requires bundled artwork');
        }
      }
    }
  }
  final canvas = const Size(500, 500);
  late final String title;
  late final List<AlbumPage> pages;
  late final int photoPage;
  int get innerPages => pages.length - 1;

  Widget artwork(int index) => LayoutBuilder(
    builder: (context, bounds) {
      final width = math.max(
        0.0,
        math.min(bounds.maxWidth - 24, bounds.maxHeight - 24),
      );
      return Center(
        child: SizedBox(
          width: width,
          height: width,
          child: ColoredBox(
            color: Colors.white,
            child: TemplatePageRenderer(
              layers: pages[index].layers,
              width: width,
              height: width,
              designCanvasSize: canvas,
              preserveTypography: true,
              imageDecodeWidth: 1200,
            ),
          ),
        ),
      );
    },
  );
}

class _Workspace extends ConsumerWidget {
  const _Workspace({
    required this.album,
    required this.reader,
    this.selectedNarrow = false,
  });
  final _LocalAlbum album;
  final bool reader;
  final bool selectedNarrow;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = LayerInteractionManager.preview(ref, () => album.canvas);
    final builder = LayerBuilder(preview, () => album.canvas);
    final selected = album.pages[album.photoPage].layers.firstWhere(
      (layer) => layer.type == LayerType.image,
    );
    Widget rail({bool horizontal = false}) => WebAlbumPageRail(
      pages: album.pages,
      selectedIndex: reader ? 0 : album.photoPage,
      cover: defaultCoverSize,
      theme: CoverTheme.classic,
      previewBuilder: builder,
      onSelected: (_) {},
      horizontal: horizontal,
      onAdd: reader ? null : () {},
    );
    if (reader)
      return WebAlbumReaderWorkspace(
        title: album.title,
        description: '정사각형 20 × 20cm · 소프트커버 · 내지 ${album.innerPages}쪽',
        pageLabel: '표지',
        canvas: album.artwork(0),
        pageRail: rail(),
        compactPageRail: rail(horizontal: true),
        onBack: () {},
        onEdit: () {},
        onOrder: () {},
        onNext: () {},
      );
    return WebAlbumEditorWorkspace(
      title: album.title,
      pageLabel: '내지 ${album.photoPage}쪽',
      specification: '정사각형 20 × 20cm · 소프트커버 · 내지 ${album.innerPages}쪽',
      hasUnsavedChanges: false,
      isPersisted: true,
      isSaving: false,
      onBack: () {},
      onSave: () {},
      onSaveDraft: () {},
      onUndo: () {},
      onRedo: () {},
      selectedLayerId:
          selectedNarrow || MediaQuery.sizeOf(context).width >= 1180
          ? selected.id
          : null,
      canvas: album.artwork(album.photoPage),
      pageRail: rail(),
      compactPageRail: rail(horizontal: true),
      properties: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '사진 속성',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: WebPalette.of(context).ink,
              ),
            ),
            const SizedBox(height: 16),
            WebLayerTransformInspector(
              layer: selected,
              baseSize: Size(selected.width, selected.height),
              onChanged:
                  ({
                    double? x,
                    double? y,
                    double? width,
                    double? height,
                    double? rotation,
                  }) {},
            ),
          ],
        ),
      ),
      tools: [
        for (final tool in const [
          ('사진 추가', Icons.add_photo_alternate_outlined),
          ('텍스트', Icons.text_fields),
          ('레이어', Icons.layers_outlined),
          ('레이아웃', Icons.dashboard_customize_outlined),
          ('템플릿', Icons.auto_awesome_mosaic_outlined),
          ('꾸미기', Icons.emoji_emotions_outlined),
          ('배경', Icons.palette_outlined),
        ])
          WebAlbumEditorTool(
            label: tool.$1,
            icon: tool.$2,
            onPressed: () {},
            opensProperties: false,
          ),
      ],
    );
  }
}

Widget _detail(BuildContext context, _LocalAlbum album) => SnapFitWebShell(
  title: '템플릿 상세',
  section: WebSection.designs,
  child: WebDesignDetailLayout(
    preview: WebSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(child: album.artwork(0)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonal(onPressed: () {}, child: const Text('표지')),
              OutlinedButton(onPressed: () {}, child: const Text('내지')),
            ],
          ),
        ],
      ),
    ),
    action: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(album.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        const Text('길 위에서 모은 사진과 기록을 한 권의 여행 앨범으로.'),
        const SizedBox(height: 20),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text('무료')),
            Chip(label: Text('표지 + 내지')),
          ],
        ),
        const SizedBox(height: 20),
        const Text('정사각형 · 가로형\n앨범에 맞는 크기로 선택할 수 있어요.'),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add, size: 18),
          label: const Text('이 디자인으로 앨범 만들기'),
        ),
      ],
    ),
    information: const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('디자인 안내', style: TextStyle(fontWeight: FontWeight.w700)),
        SizedBox(height: 12),
        Text(
          '사진과 문구를 자유롭게 바꿀 수 있는 스냅핏 오리지널 템플릿입니다.\n\n사진은 원본을 보존하고 앨범의 비율에 맞춰 배치합니다.',
        ),
      ],
    ),
  ),
);

Widget _catalog(
  BuildContext context,
  _LocalAlbum album,
  TextEditingController search,
) => SnapFitWebShell(
  title: '템플릿·소재',
  section: WebSection.designs,
  child: ListView(
    children: [
      const WebPageHeading(
        title: '템플릿·소재',
        description: '앨범에 어울리는 디자인을 찾고 나만의 기록으로 채워보세요.',
      ),
      const SizedBox(height: 24),
      WebCatalogToolbar(
        controller: search,
        searchHint: '템플릿 이름이나 분위기로 검색',
        onSearchChanged: (_) {},
        categories: const ['전체', '여행', '일상', '가족', '웨딩'],
        category: '전체',
        onCategoryChanged: (_) {},
        price: '전체',
        onPriceChanged: (_) {},
        favoritesOnly: false,
        onFavoritesChanged: () {},
        resultLabel: '추천 디자인 3개',
        onReset: () {},
        sort: '추천순',
        onSortChanged: (_) {},
      ),
      const SizedBox(height: 24),
      LayoutBuilder(
        builder: (context, bounds) => Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            for (var i = 0; i < 3; i++)
              SizedBox(
                width: bounds.maxWidth < 600
                    ? bounds.maxWidth
                    : (bounds.maxWidth - 40) / 3,
                child: WebSurface(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(aspectRatio: 1, child: album.artwork(i)),
                      const SizedBox(height: 12),
                      Text(
                        i == 0
                            ? album.title
                            : i == 1
                            ? '낯선 거리의 기록'
                            : '함께한 여행의 순간',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text('무료 · 표지와 내지', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  ),
);

void main() {
  _CaptureBinding();
  testWidgets('export complete web redesign with local bundled artwork', (
    tester,
  ) async {
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
    final album = _LocalAlbum();
    final search = TextEditingController();
    addTearDown(search.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final viewport in [
      (name: 'desktop-light', size: const Size(1440, 1000), dark: false),
      (name: 'narrow-light', size: const Size(390, 844), dark: false),
      (name: 'desktop-dark', size: const Size(1440, 1000), dark: true),
    ]) {
      for (final screen in [
        'discovery',
        'editor',
        'editor-selected',
        'reader',
        'catalog',
        'design-detail',
        'order-history',
      ]) {
        final boundary = GlobalKey();
        await tester.pumpWidget(const SizedBox());
        tester.view.physicalSize = viewport.size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          ProviderScope(
            child: ScreenUtilInit(
              designSize: const Size(390, 844),
              minTextAdapt: true,
              builder: (_, __) => MaterialApp(
                theme: SnapFitWebTheme.from(
                  ThemeData(
                    fontFamily: 'NotoSans',
                    splashFactory: NoSplash.splashFactory,
                    brightness: viewport.dark
                        ? Brightness.dark
                        : Brightness.light,
                  ),
                ),
                home: RepaintBoundary(
                  key: boundary,
                  child: WebNavigationScope(
                    onNavigate: (_) {},
                    onNotifications: () {},
                    child: Builder(
                      builder: (context) => switch (screen) {
                        'discovery' => const PublicDiscoveryScreen(),
                        'editor' => _Workspace(album: album, reader: false),
                        'editor-selected' => _Workspace(
                          album: album,
                          reader: false,
                          selectedNarrow: true,
                        ),
                        'reader' => _Workspace(album: album, reader: true),
                        'catalog' => _catalog(context, album, search),
                        'design-detail' => _detail(context, album),
                        _ => const WebCustomerDesignFixture(),
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          for (final element in find.byType(Image).evaluate()) {
            Object? error;
            await precacheImage(
              (element.widget as Image).image,
              element,
              onError: (value, _) => error = value,
            );
            if (error != null)
              throw StateError('local image load failed: $error');
          }
        });
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$screen ${viewport.name}',
        );
        final render =
            boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await render.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            '${const String.fromEnvironment('WEB_REDESIGN_OUTPUT', defaultValue: 'output/web-full-design-2026-10-18')}/$screen-${viewport.name}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
    await tester.pumpWidget(const SizedBox());
  }, skip: !const bool.fromEnvironment('WEB_REDESIGN_CAPTURE'));
}
