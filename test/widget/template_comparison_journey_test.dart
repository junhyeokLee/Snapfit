import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/data/store_curation_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/presentation/views/public_discovery_screen.dart';
import 'package:snap_fit/features/store/presentation/views/store_screen.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/public_template_information.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_design_comparison.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_editorial_list.dart';
import 'package:snap_fit/shared/web/web_design.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

const _emitMemoryImages = bool.fromEnvironment('SELECTION_MEMORY_IMAGES');
final _memoryBoundary = GlobalKey();
final _designs = <PremiumTemplate>[
  bundledCreationTemplates.first,
  bundledCreationTemplates[1],
  publishedPremiumTemplates.first,
  publishedPremiumTemplates[1],
];

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void _memoryStage(String stage) {
  if (!_emitMemoryImages) return;
  // ignore: avoid_print
  print('SNAPFIT_SELECTION_STAGE_V1:$stage');
}

class _PrivateReadGuard {
  int attempts = 0;

  Never forbidden() {
    attempts++;
    throw StateError('Browsing and comparison must not request private data');
  }
}

Widget _host(Widget screen, _PrivateReadGuard guard, {required bool guest}) {
  final products = [
    for (final design in _designs)
      PointShopProduct(
        productKey: pointShopTemplateKey(design),
        kind: 'template',
        assetId: '${design.id}',
        title: design.title,
        pointPrice: design.isPremium ? 1800 : 0,
        isActive: true,
      ),
  ];
  return ProviderScope(
    overrides: [
      templateListProvider.overrideWith((ref) async => _designs),
      templateRepositoryProvider.overrideWith((ref) => guard.forbidden()),
      storeCurationsProvider.overrideWith((ref) async => {}),
      publicPointShopCatalogProvider.overrideWith((ref) async => products),
      pointShopRepositoryProvider.overrideWith((ref) => guard.forbidden()),
      pointShopSessionProvider.overrideWith((ref) => guard.forbidden()),
      pointShopCatalogProvider.overrideWith((ref) async {
        if (guest) return guard.forbidden();
        return products;
      }),
      ownedPointShopKeysProvider.overrideWith((ref) async {
        if (guest) return guard.forbidden();
        return <String>{};
      }),
    ],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: SnapFitWebTheme.from(ThemeData(useMaterial3: true)),
        builder: (context, child) => RepaintBoundary(
          key: _memoryBoundary,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
        ),
        home: screen,
      ),
    ),
  );
}

void _viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _publicScroll() => find
    .descendant(
      of: find.byKey(const ValueKey('public-discovery-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _publicSearch(WidgetTester tester, String query) async {
  tester.state<ScrollableState>(_publicScroll()).position.jumpTo(0);
  await tester.pumpAndSettle();
  final search = find.byKey(const ValueKey('discovery-search'));
  await tester.ensureVisible(search);
  await tester.enterText(search, query);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

Future<void> _publicCompare(WidgetTester tester, PremiumTemplate design) async {
  await _publicSearch(tester, design.title);
  final button = find.byKey(ValueKey('discovery-compare-${design.id}'));
  await tester.scrollUntilVisible(button, 180, scrollable: _publicScroll());
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  expect(button.hitTestable(), findsOneWidget);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _memoryImage(WidgetTester tester, String id) async {
  if (!_emitMemoryImages) return;
  for (var attempt = 0; attempt < 60; attempt++) {
    final artwork = tester.widgetList<RawImage>(find.byType(RawImage));
    if (artwork.isNotEmpty && artwork.every((image) => image.image != null)) {
      break;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  final artwork = tester.widgetList<RawImage>(find.byType(RawImage));
  expect(artwork, isNotEmpty);
  expect(
    artwork.every((image) => image.image != null),
    isTrue,
    reason: 'RAM checks must include decoded photo artwork: $id',
  );
  await tester.pump();
  await tester.runAsync(() async {
    // Rasterization and PNG conversion are engine work. Keep both outside the
    // widget test's fake clock, and do all widget pumping above this callback.
    final boundary =
        _memoryBoundary.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      // Opt-in RAM protocol only. No image or preview file is written.
      // ignore: avoid_print
      print(
        'SNAPFIT_MEMORY_IMAGE_V1:${jsonEncode({'id': id, 'mimeType': 'image/png', 'width': image.width, 'height': image.height, 'base64': base64Encode(bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes))})}',
      );
    } finally {
      image.dispose();
    }
  });
  _memoryStage('captured:$id');
}

void main() {
  _PaintBinding();
  setUpAll(() async {
    // Bundled typography is verified by the native RAM run. Browser tests
    // exercise navigation and state without the web test FontLoader deadlock.
    if (kIsWeb) return;
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final raw in manifest.whereType<Map>()) {
      final loader = FontLoader(raw['family'] as String);
      for (final font in (raw['fonts'] as List).whereType<Map>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
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

  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets('public comparison journey preserves selection at $size', (
      tester,
    ) async {
      _viewport(tester, size);
      final guard = _PrivateReadGuard();
      await tester.pumpWidget(
        _host(
          const PublicDiscoveryScreen(catalogOnly: true),
          guard,
          guest: true,
        ),
      );
      await tester.pumpAndSettle();

      for (var index = 0; index < 3; index++) {
        await _publicCompare(tester, _designs[index]);
        expect(find.byType(TemplateDetailScreen), findsNothing);
        expect(find.text('비교할 디자인 ${index + 1}/3'), findsOneWidget);
      }
      await Scrollable.ensureVisible(
        tester.element(
          find.byKey(ValueKey('discovery-template-${_designs[2].id}')),
        ),
        alignment: 0,
      );
      await tester.pumpAndSettle();
      await _memoryImage(tester, 'public-selected-three-${size.width.toInt()}');
      await _publicCompare(tester, _designs[3]);
      _memoryStage('fourth-selection-checked:${size.width.toInt()}');
      expect(
        find.text(TemplateDesignComparisonSelection.limitMessage),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('comparison-selected-${_designs[3].id}')),
        findsNothing,
      );
      expect(find.text('비교할 디자인 3/3'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      _memoryStage('limit-message-dismissed:${size.width.toInt()}');

      // Neither search nor subject filtering owns the comparison selection.
      await _publicSearch(tester, '찾을수없는비교검색');
      for (final design in _designs.take(3)) {
        expect(
          find.byKey(ValueKey('comparison-selected-${design.id}')),
          findsOneWidget,
        );
      }
      await _publicSearch(tester, '');
      final topic = find.widgetWithText(ChoiceChip, '여행');
      await tester.ensureVisible(topic);
      await tester.pumpAndSettle();
      await tester.tap(topic);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(topic).selected, isTrue);
      expect(find.text('비교할 디자인 3/3'), findsOneWidget);
      _memoryStage('filters-preserved-selection:${size.width.toInt()}');

      final open = find.byKey(const ValueKey('template-comparison-open'));
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.byType(TemplateDesignComparisonView), findsOneWidget);
      expect(find.byType(TemplateDetailScreen), findsNothing);
      await _memoryImage(tester, 'comparison-top-${size.width.toInt()}');

      final remove = find.byKey(
        ValueKey('comparison-remove-${_designs.first.id}'),
      );
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('comparison-remove-${_designs.first.id}')),
        findsNothing,
      );
      // The offstage catalog updates immediately, while comparison is open.
      expect(
        find.byKey(
          ValueKey('comparison-selected-${_designs.first.id}'),
          skipOffstage: false,
        ),
        findsNothing,
      );
      expect(find.text('비교할 디자인 2/3', skipOffstage: false), findsOneWidget);

      final detail = find.byKey(ValueKey('comparison-open-${_designs[1].id}'));
      await tester.ensureVisible(detail);
      await tester.pumpAndSettle();
      await _memoryImage(tester, 'comparison-facts-${size.width.toInt()}');
      await tester.tap(detail);
      await tester.pumpAndSettle();
      expect(find.byType(TemplateDesignComparisonView), findsNothing);
      final detailScreen = tester.widget<TemplateDetailScreen>(
        find.byType(TemplateDetailScreen),
      );
      expect(detailScreen.template.id, _designs[1].id);
      expect(detailScreen.guestPreview, isTrue);
      expect(guard.attempts, 0);
      _memoryStage('guest-detail-opened:${size.width.toInt()}');
      Navigator.of(tester.element(find.byType(TemplateDetailScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.text('비교할 디자인 2/3'), findsOneWidget);

      final clear = find.byKey(const ValueKey('template-comparison-clear'));
      await tester.ensureVisible(clear);
      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('template-comparison-tray')),
        findsNothing,
      );
      expect(guard.attempts, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final editorial in [false, true]) {
    testWidgets('signed store comparison opens from editorial=$editorial', (
      tester,
    ) async {
      _viewport(tester, const Size(390, 844));
      final guard = _PrivateReadGuard();
      await tester.pumpWidget(
        _host(
          StoreScreen(editorial: editorial, embedded: true),
          guard,
          guest: false,
        ),
      );
      await tester.pumpAndSettle();
      final scroll = find
          .descendant(
            of: find.byType(StoreScreen),
            matching: find.byType(CustomScrollView),
          )
          .first;
      final scrollable = find
          .descendant(of: scroll, matching: find.byType(Scrollable))
          .first;
      for (var index = 0; index < 2; index++) {
        final button = find.byKey(
          ValueKey('compare-template-${_designs[index].id}'),
        );
        await tester.scrollUntilVisible(button, 180, scrollable: scrollable);
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        if (editorial)
          expect(find.byType(TemplateEditorialList), findsOneWidget);
        expect(button.hitTestable(), findsOneWidget);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(TemplateDetailScreen), findsNothing);
      }
      expect(find.text('비교할 디자인 2/3'), findsOneWidget);
      final open = find.byKey(const ValueKey('template-comparison-open'));
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.byType(TemplateDesignComparisonView), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('comparison-view-clear')));
      await tester.pumpAndSettle();
      expect(find.text('비교할 디자인을 다시 골라 주세요.'), findsOneWidget);
      await tester.tap(find.byTooltip('비교 닫기'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('template-comparison-tray')),
        findsNothing,
      );
      expect(guard.attempts, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
