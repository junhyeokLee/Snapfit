import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:book_page_flip/book_page_flip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/constants/snapfit_colors.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/providers/home_ui_state_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/album_reader_screen.dart';
import 'package:snap_fit/features/album/presentation/views/home_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_catalog_cover.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_bottom_navigation_bar.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/presentation/views/material_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/views/store_screen.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/shared/widgets/album_stage_style.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/experience_form_style.dart';
import 'package:snap_fit/shared/widgets/studio_decoration.dart';

import '../helpers/fake_album.dart';
import 'ai_album_start_step_test.dart' show loadCreationFonts;
import 'auth_gate_test.dart' show FakeHomeViewModel;
import 'my_page_screen_test.dart' show FakeAuthViewModel;
import 'page_editor_screen_golden_test.dart'
    show MockAlbumRepository, FakeStorageService, FakeAlbumPersistenceService;

class _ProductionPaintBinding extends AutomatedTestWidgetsFlutterBinding {
  // Include the real shadow blur in native screenshots, not golden-test silhouettes.
  @override
  bool get disableShadows => false;
}

Widget _app(Widget child, ValueNotifier<bool> dark, {GlobalKey? captureKey}) =>
    ProviderScope(
      overrides: [
        templateListProvider.overrideWith(
          (ref) async => publishedCreationTemplates,
        ),
        pointShopCatalogProvider.overrideWith(
          (ref) async => [
            for (final entry in pointShopLaunchPrices.entries)
              PointShopProduct(
                productKey: entry.key,
                kind: entry.key.split(':').first,
                assetId: entry.key.split(':').last,
                title: entry.key,
                pointPrice: entry.value.points,
                isActive: true,
              ),
          ],
        ),
        ownedPointShopKeysProvider.overrideWith((ref) async => <String>{}),
        authViewModelProvider.overrideWith(
          () => FakeAuthViewModel(
            const UserInfo(id: 'qa', name: '스냅핏', provider: 'kakao'),
          ),
        ),
        homeViewModelProvider.overrideWith(
          () => FakeHomeViewModel([
            fakeAlbum(id: 1, ratio: '0.75', updatedAt: '2026-10-08'),
            fakeAlbum(id: 2, ratio: '1', updatedAt: '2026-10-07'),
            fakeAlbum(id: 3, ratio: '1.333333', updatedAt: '2026-10-06'),
          ]),
        ),
        notificationUnreadCountProvider.overrideWith((ref) async => 0),
        albumRepositoryProvider.overrideWithValue(MockAlbumRepository()),
        storageServiceProvider.overrideWithValue(FakeStorageService()),
        albumPersistenceServiceProvider.overrideWithValue(
          FakeAlbumPersistenceService(),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => ValueListenableBuilder<bool>(
          valueListenable: dark,
          builder: (_, isDark, __) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: SnapFitTheme.light(),
            darkTheme: SnapFitTheme.dark(),
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            builder: (context, body) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: RepaintBoundary(key: captureKey, child: body!),
            ),
            home: child,
          ),
        ),
      ),
    );

Future<void> _paint(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1000));
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _save(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('THEME_STORE_HOME_QA')) return;
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('output/theme-store-home-qa/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

class _ReaderBoot extends ConsumerStatefulWidget {
  const _ReaderBoot();
  @override
  ConsumerState<_ReaderBoot> createState() => _ReaderBootState();
}

class _ReaderBootState extends ConsumerState<_ReaderBoot> {
  bool _ready = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(albumEditorViewModelProvider.future);
      if (!mounted) return;
      ref
          .read(albumEditorViewModelProvider.notifier)
          .startLocalTemplateAlbum(
            albumTitle: '우리의 순간',
            initialCover: defaultCoverSize,
            templateCanvasSize: const Size(500, 500),
            pages: [
              for (final photo in [
                'portrait',
                'square',
                'landscape',
                'portrait',
                'square',
              ])
                [
                  LayerModel(
                    id: 'photo-$photo',
                    type: LayerType.image,
                    position: const Offset(20, 20),
                    width: 460,
                    height: 400,
                    imageUrl: 'asset:assets/snapfit_home_$photo.jpg',
                  ),
                ],
            ],
          );
      setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) => _ready
      ? const AlbumReaderScreen(initialSpreadIndex: 1)
      : const SizedBox();
}

void main() {
  _ProductionPaintBinding();
  setUpAll(() async {
    await loadCreationFonts();
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in manifest) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(648, 320),
    const Size(740, 360),
    const Size(844, 390),
  ]) {
    for (final isDark in [false, true]) {
      testWidgets('native home, store and detail themes $size dark=$isDark', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = size.width > size.height
            ? const FakeViewPadding(left: 44, right: 24, bottom: 24)
            : const FakeViewPadding(top: 24, bottom: 24);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        final dark = ValueNotifier(isDark);
        addTearDown(dark.dispose);
        final key = GlobalKey();
        final suffix = '${size.width.toInt()}-${isDark ? 'dark' : 'light'}';
        await tester.pumpWidget(
          _app(const HomeScreen(), dark, captureKey: key),
        );
        await _paint(tester);
        final context = tester.element(find.byType(HomeScreen));
        expect(
          Theme.of(context).brightness,
          isDark ? Brightness.dark : Brightness.light,
        );
        final nav = tester.widget<Material>(
          find.byKey(const ValueKey('home-navigation-surface')),
        );
        expect(nav.color, SnapFitColors.backgroundOf(context));
        expect(
          AlbumStageStyle.overlay(context).systemNavigationBarIconBrightness,
          isDark ? Brightness.light : Brightness.dark,
        );
        final stage = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('home-album-stage-background')),
        );
        expect(
          (stage.decoration as BoxDecoration).gradient!.colors.first,
          AlbumStageStyle.top(context),
        );
        await _save(tester, key, 'home-$suffix');
        await tester.tap(
          find.descendant(
            of: find.byType(HomeBottomNavigationBar),
            matching: find.text('스토어'),
          ),
        );
        await _paint(tester);
        expect(find.byType(StoreScreen), findsOneWidget);
        final storeScaffold = tester.widget<Scaffold>(
          find
              .descendant(
                of: find.byType(StoreScreen),
                matching: find.byType(Scaffold),
              )
              .first,
        );
        expect(
          storeScaffold.backgroundColor,
          SnapFitColors.backgroundOf(context),
        );
        final firstTitle = publishedCreationTemplates.first.title;
        expect(
          tester.widget<Text>(find.text(firstTitle).first).style!.color,
          ExperienceFormStyle.ink(context),
        );
        await _save(tester, key, 'store-$suffix');
        await tester.tap(find.text('꾸밈소재').first);
        await _paint(tester);
        await _save(tester, key, 'materials-$suffix');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());

        final spec = studioDecorations.first;
        await tester.pumpWidget(
          _app(
            MaterialDetailScreen(
              productKey: 'sticker:${spec.id}',
              favoriteKey: CatalogFavoriteKeys.decoration(spec.insertionValue),
              title: spec.label,
              type: '스티커',
              preview: (_) => StudioDecoration(spec: spec),
            ),
            dark,
            captureKey: key,
          ),
        );
        await _paint(tester);
        final detailContext = tester.element(find.byType(MaterialDetailScreen));
        expect(
          tester.widget<Text>(find.text(spec.label).first).style!.color,
          ExperienceFormStyle.ink(detailContext),
        );
        await _save(tester, key, 'material-detail-$suffix');
        await tester.tap(find.byTooltip('소재 크게 보기'));
        await _paint(tester);
        expect(
          tester.widget<AppBar>(find.byType(AppBar).last).backgroundColor,
          SnapFitColors.backgroundOf(detailContext),
        );
        await _save(tester, key, 'material-zoom-$suffix');
        await tester.pumpWidget(const SizedBox());

        final template = publishedCreationTemplates.firstWhere(
          (item) => item.isPremium,
        );
        await tester.pumpWidget(
          _app(TemplateDetailScreen(template: template), dark, captureKey: key),
        );
        await _paint(tester);
        final templateContext = tester.element(
          find.byType(TemplateDetailScreen),
        );
        expect(
          tester.widget<Text>(find.text(template.title).last).style!.color,
          ExperienceFormStyle.ink(templateContext),
        );
        await _save(tester, key, 'template-detail-$suffix');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());

        await tester.pumpWidget(
          _app(const _ReaderBoot(), dark, captureKey: key),
        );
        await _paint(tester);
        for (var n = 0; n < 100; n++) {
          if (find.byType(BookFlip).evaluate().isNotEmpty &&
              tester
                  .widget<BookFlip>(find.byType(BookFlip))
                  .controller!
                  .isReady)
            break;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(find.byType(BookFlip), findsOneWidget);
        final readerContext = tester.element(find.byType(AlbumReaderScreen));
        expect(
          tester
              .widget<Scaffold>(
                find
                    .descendant(
                      of: find.byType(AlbumReaderScreen),
                      matching: find.byType(Scaffold),
                    )
                    .first,
              )
              .backgroundColor,
          AlbumStageStyle.top(readerContext),
        );
        await _save(tester, key, 'reader-$suffix');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets(
    'switching theme keeps navigation, store filters, scroll and artwork',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dark = ValueNotifier(false);
      addTearDown(dark.dispose);
      await tester.pumpWidget(_app(const HomeScreen(), dark));
      await _paint(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(HomeBottomNavigationBar),
          matching: find.text('스토어'),
        ),
      );
      await _paint(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<String>),
          matching: find.text('무료'),
        ),
      );
      await _paint(tester);
      final storeState = tester.state(find.byType(StoreScreen));
      final scroll = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      scroll.jumpTo(200);
      await _paint(tester);
      dark.value = true;
      await _paint(tester);
      expect(tester.state(find.byType(StoreScreen)), same(storeState));
      expect(scroll.offset, 200);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      expect(container.read(homeUiStateProvider).bottomNavIndex, 2);
      scroll.jumpTo(0);
      await _paint(tester);
      expect(
        tester
            .widget<SegmentedButton<String>>(
              find.byType(SegmentedButton<String>),
            )
            .selected,
        {'무료'},
      );
      expect(
        tester
            .widget<Material>(
              find.byKey(const ValueKey('home-navigation-surface')),
            )
            .color,
        SnapFitColors.deepCharcoal,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'cover photograph and print colours are identical in both themes',
    (tester) async {
      final dark = ValueNotifier(false);
      addTearDown(dark.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 200,
                  height: 250,
                  child: CreationCatalogCover(
                    template: publishedCreationTemplates.first,
                    useThumbnail: true,
                  ),
                ),
              ),
            ),
          ),
          dark,
        ),
      );
      await _paint(tester);
      Future<List<int>> pixels() async => (await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData();
        image.dispose();
        return bytes!.buffer.asUint8List().toList();
      }))!;
      final before = await pixels();
      dark.value = true;
      await _paint(tester);
      expect(await pixels(), before);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
