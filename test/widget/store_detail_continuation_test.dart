import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/supabase/supabase_provider.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_cover_frame.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_access.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/views/template_full_screen_view.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts;

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

final _template = publishedCreationTemplates.firstWhere(
  (item) => item.id == -9501,
);
final _productKey = pointShopTemplateKey(_template);

PointShopProduct _product({int? price = 400, bool active = true}) =>
    PointShopProduct(
      productKey: _productKey,
      kind: 'template',
      assetId: _productKey.split(':').last,
      title: _template.title,
      pointPrice: price,
      isActive: active,
    );

void main() {
  _PaintBinding();
  final boundary = GlobalKey();
  final navigator = GlobalKey<NavigatorState>();
  final accessRequests = <String>[];

  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    await loadCreationFonts();
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
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
    accessRequests.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(() {
    CatalogFavorites.instance.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Finder key(String name) => find.byKey(ValueKey(name));
  Finder action() => key('template-detail-use');
  Finder viewer() => find.byType(TemplateFullScreenView);
  Finder viewerPager() =>
      find.descendant(of: viewer(), matching: find.byType(PageView));
  Finder detailPager() => key('template-spread-pager');
  Finder selector() => key('template-size-selector');

  void metrics(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = size.width > size.height
        ? const FakeViewPadding(left: 32, right: 48, bottom: 24)
        : const FakeViewPadding(top: 24, bottom: 34);
  }

  void reset(WidgetTester tester) {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
  }

  Future<void> paint(WidgetTester tester, {bool pending = false}) async {
    if (pending) {
      await tester.pump(const Duration(milliseconds: 350));
    } else {
      await tester.pumpAndSettle();
    }
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    if (pending) {
      await tester.pump(const Duration(milliseconds: 100));
    } else {
      await tester.pumpAndSettle();
    }
  }

  Future<void> tap(
    WidgetTester tester,
    Finder finder, {
    bool pending = false,
  }) async {
    await tester.ensureVisible(finder);
    if (pending) {
      await tester.pump(const Duration(milliseconds: 100));
    } else {
      await tester.pumpAndSettle();
    }
    await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
    if (pending) {
      await tester.pump(const Duration(milliseconds: 100));
    } else {
      await tester.pumpAndSettle();
    }
    await tester.tap(finder);
    await paint(tester, pending: pending);
  }

  Future<void> mount(
    WidgetTester tester, {
    PremiumTemplate? template,
    Future<List<PointShopProduct>> Function()? catalog,
    Set<String> owned = const {},
    bool dark = false,
    double scale = 1.3,
    bool pending = false,
  }) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, __) => null,
        overrides: [
          pointShopCatalogProvider.overrideWith(
            (_) => catalog?.call() ?? Future.value([_product()]),
          ),
          ownedPointShopKeysProvider.overrideWith((_) async => owned),
          pointShopAccessGateProvider.overrideWithValue((
            context,
            ref, {
            required productKey,
            required title,
          }) async {
            accessRequests.add(productKey);
            return false;
          }),
          pointShopRepositoryProvider.overrideWith(
            (_) => throw StateError(
              'Real purchase and ownership requests are forbidden in design QA.',
            ),
          ),
          supabaseClientProvider.overrideWith(
            (_) => throw StateError(
              'Real backend access is forbidden in design QA.',
            ),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            navigatorKey: navigator,
            debugShowCheckedModeBanner: false,
            theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(key: boundary, child: child!),
            ),
            home: TemplateDetailScreen(template: template ?? _template),
          ),
        ),
      ),
    );
    await paint(tester, pending: pending);
  }

  void safe(WidgetTester tester, Finder finder, Size size) {
    final priceText = find.descendant(
      of: key('template-detail-price'),
      matching: find.byType(Text),
    );
    expect(priceText, findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(priceText).didExceedMaxLines,
      false,
    );
    final rect = tester.getRect(finder);
    final wide = size.width > size.height;
    expect(rect.width, greaterThanOrEqualTo(44));
    expect(rect.height, greaterThanOrEqualTo(44));
    expect(rect.left, greaterThanOrEqualTo(wide ? 32 : 0));
    expect(rect.right, lessThanOrEqualTo(size.width - (wide ? 48 : 0)));
    expect(rect.top, greaterThanOrEqualTo(wide ? 0 : 24));
    expect(rect.bottom, lessThanOrEqualTo(size.height - (wide ? 24 : 34) + 1));
    expect(finder.hitTestable(), findsOneWidget);
  }

  void label(WidgetTester tester, String text, {required bool enabled}) {
    expect(
      find.descendant(of: action(), matching: find.text(text)),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(action()).onPressed != null, enabled);
  }

  Future<void> capture(
    WidgetTester tester,
    String name,
    Size size,
    bool dark, {
    bool pending = false,
  }) async {
    await paint(tester, pending: pending);
    expect(tester.takeException(), isNull, reason: name);
    if (!const bool.fromEnvironment('STORE_DETAIL_QA')) return;
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(
        'output/all-screens-qa/store-detail-flow-$name-'
        '${size.width.toInt()}-${dark ? 'dark' : 'light'}'
        '${const String.fromEnvironment('DESIGN_SYSTEM_REVISION')}.png',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> selectVariant(WidgetTester tester, String text) async {
    await tester.ensureVisible(selector());
    await tester.pumpAndSettle();
    await tap(
      tester,
      find.descendant(of: selector(), matching: find.text(text)),
    );
  }

  void restored(WidgetTester tester, int page) {
    final spread = page == 0 ? 0 : (page + 1) ~/ 2;
    expect(
      tester.widget<PageView>(detailPager()).controller!.page,
      closeTo(spread.toDouble(), .001),
    );
    final left = spread == 0 ? 0 : spread * 2 - 1;
    if (left > 0) {
      expect(find.byKey(ValueKey('template-book-spread-$left')), findsWidgets);
    }
    expect(key('template-spread-thumb-$spread').hitTestable(), findsOneWidget);
  }

  const cases = [
    (size: Size(320, 568), dark: false, state: 'paid'),
    (size: Size(320, 568), dark: true, state: 'missing'),
    (size: Size(390, 844), dark: false, state: 'free'),
    (size: Size(390, 844), dark: true, state: 'owned'),
    (size: Size(648, 320), dark: false, state: 'inactive'),
    (size: Size(648, 320), dark: true, state: 'unknown-price'),
    (size: Size(844, 390), dark: false, state: 'retry'),
    (size: Size(844, 390), dark: true, state: 'paid'),
  ];
  for (final scenario in cases) {
    testWidgets(
      'template detail ${scenario.state} restores its inspected spread ${scenario.size} dark=${scenario.dark}',
      (tester) async {
        reset(tester);
        metrics(tester, scenario.size);
        final original = _template.templateJson;
        final pending = scenario.state == 'owned'
            ? Completer<List<PointShopProduct>>()
            : null;
        var catalogReads = 0;
        await mount(
          tester,
          dark: scenario.dark,
          owned: scenario.state == 'owned' ? {_productKey} : {},
          pending: pending != null,
          catalog: () async {
            catalogReads++;
            if (pending != null) return pending.future;
            if (scenario.state == 'retry' && catalogReads == 1) {
              throw StateError('fixture offline');
            }
            return switch (scenario.state) {
              'missing' => [],
              'inactive' => [_product(active: false)],
              'unknown-price' => [_product(price: null)],
              'free' => [_product(price: 0)],
              _ => [_product()],
            };
          },
        );
        final unavailable = [
          'missing',
          'inactive',
          'unknown-price',
        ].contains(scenario.state);
        label(
          tester,
          unavailable
              ? '판매 준비 중'
              : scenario.state == 'retry'
              ? '가격 다시 확인'
              : '이 디자인으로 시작',
          enabled: !unavailable,
        );
        safe(tester, action(), scenario.size);
        final stage = key('template-detail-stage');
        final cover = tester.widget<HomeCoverFrame>(
          find
              .descendant(of: stage, matching: find.byType(HomeCoverFrame))
              .first,
        );
        expect(cover.showBookDepth, true);
        expect(cover.bindingArtwork, isNotNull);
        if (scenario.state == 'free') expect(find.text('무료'), findsWidgets);
        if (scenario.state == 'owned') expect(find.text('구매 완료'), findsWidgets);
        await capture(
          tester,
          scenario.state,
          scenario.size,
          scenario.dark,
          pending: pending != null,
        );
        if (pending != null) {
          pending.complete([]);
          await paint(tester);
          label(tester, '이 디자인으로 시작', enabled: true);
        }
        if (scenario.state == 'retry') {
          await tap(tester, action());
          expect(catalogReads, 2);
          label(tester, '이 디자인으로 시작', enabled: true);
        }
        final variant = scenario.dark ? 'portrait' : 'landscape';
        await selectVariant(tester, scenario.dark ? '세로형' : '가로형');
        await tap(tester, find.byTooltip('전체 미리보기'));
        expect(viewer(), findsOneWidget);
        final pages = tester
            .widget<TemplateFullScreenView>(viewer())
            .parsedPages
            .length;
        expect(pages, greaterThan(6));
        await tester.drag(viewerPager(), Offset(-scenario.size.width * .8, 0));
        await paint(tester);
        tester.widget<PageView>(viewerPager()).controller!.jumpToPage(5);
        await paint(tester);
        expect(find.text('6 / $pages'), findsOneWidget);
        final rotated = scenario.size.width > scenario.size.height
            ? const Size(390, 844)
            : const Size(844, 390);
        metrics(tester, rotated);
        await paint(tester);
        expect(find.text('6 / $pages'), findsOneWidget);
        if (scenario.dark) {
          await tester.binding.handlePopRoute();
          await paint(tester);
        } else {
          await tap(tester, find.byTooltip('닫기'));
        }
        expect(viewer(), findsNothing);
        restored(tester, 5);
        expect(find.text('5–6쪽'), findsOneWidget);
        expect(tester.widget<SegmentedButton<String>>(selector()).selected, {
          variant,
        });
        safe(tester, action(), rotated);
        if ((scenario.size.width == 390 && !scenario.dark) ||
            (scenario.size.width == 844 && scenario.dark)) {
          await capture(tester, 'restored-spread', rotated, scenario.dark);
        }
        expect(accessRequests, isEmpty);
        expect(_template.templateJson, original);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scenario in [
    (size: const Size(320, 568), dark: true),
    (size: const Size(648, 320), dark: false),
  ]) {
    testWidgets(
      'large text keeps template access and returned spread reachable ${scenario.size}',
      (tester) async {
        reset(tester);
        metrics(tester, scenario.size);
        await mount(tester, dark: scenario.dark, scale: 1.8);
        safe(tester, action(), scenario.size);
        label(tester, '이 디자인으로 시작', enabled: true);
        await capture(tester, 'large-text', scenario.size, scenario.dark);
        await tap(tester, find.byTooltip('다음 펼침면'));
        await tap(tester, find.byTooltip('전체 미리보기'));
        tester.widget<PageView>(viewerPager()).controller!.jumpToPage(4);
        await paint(tester);
        await tester.binding.handlePopRoute();
        await paint(tester);
        restored(tester, 4);
        safe(tester, action(), scenario.size);
        expect(find.text('3–4쪽'), findsOneWidget);
        expect(accessRequests, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'price loading and retry never grant access while ready free paid and owned paths still ask the gate',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      final pending = Completer<List<PointShopProduct>>();
      var reads = 0;
      await mount(
        tester,
        pending: true,
        catalog: () {
          if (++reads == 1) return pending.future;
          return Future.value([_product()]);
        },
      );
      label(tester, '가격 확인 중', enabled: false);
      await capture(
        tester,
        'price-loading',
        const Size(390, 844),
        false,
        pending: true,
      );
      pending.completeError(StateError('fixture offline'));
      await paint(tester);
      label(tester, '가격 다시 확인', enabled: true);
      await capture(tester, 'price-error', const Size(390, 844), false);
      await tap(tester, action());
      expect(reads, 2);
      expect(accessRequests, isEmpty);
      label(tester, '이 디자인으로 시작', enabled: true);
      for (final mode in ['free', 'paid', 'owned', 'published-free']) {
        final template = mode == 'published-free'
            ? publishedCreationTemplates.firstWhere((item) => !item.isPremium)
            : _template;
        await mount(
          tester,
          template: template,
          owned: mode == 'owned' ? {_productKey} : {},
          catalog: () async {
            if (mode == 'owned') throw StateError('fixture catalog offline');
            if (mode == 'published-free') return [];
            return [_product(price: mode == 'free' ? 0 : 400)];
          },
        );
        label(tester, '이 디자인으로 시작', enabled: true);
        final previous = accessRequests.length;
        // The premium detail stays busy while its edition sheet is open.
        // Advance that real modal flow before waiting for animations to settle.
        await tap(tester, action(), pending: true);
        if (key('template-edition-continue').evaluate().isNotEmpty) {
          expect(key('template-edition-sheet'), findsOneWidget);
          expect(tester.widget<FilledButton>(action()).onPressed, isNull);
          expect(accessRequests, hasLength(previous));
          await tester.ensureVisible(key('template-edition-continue'));
          await Scrollable.ensureVisible(
            tester.element(key('template-edition-continue')),
            alignment: .5,
          );
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            key('template-edition-continue').hitTestable(),
            findsOneWidget,
          );
          await tap(tester, key('template-edition-continue'), pending: true);
        }
        await paint(tester);
        expect(accessRequests, hasLength(previous + 1), reason: mode);
        expect(accessRequests.last, pointShopTemplateKey(template));
        expect(find.byType(TemplateDetailScreen), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'full preview ignores invalid stale covered and changed-variant callbacks',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      await mount(tester, dark: true);
      await tap(tester, find.byTooltip('전체 미리보기'));
      final firstViewer = tester.widget<TemplateFullScreenView>(viewer());
      tester.widget<PageView>(viewerPager()).controller!.jumpToPage(5);
      await paint(tester);
      firstViewer.onPageChanged!(-1);
      firstViewer.onPageChanged!(firstViewer.parsedPages.length);
      await tap(tester, find.byTooltip('닫기'));
      restored(tester, 5);

      final changeVariant = tester
          .widget<SegmentedButton<String>>(selector())
          .onSelectionChanged!;
      await tap(tester, find.byTooltip('전체 미리보기'));
      final staleViewer = tester.widget<TemplateFullScreenView>(viewer());
      changeVariant({'portrait'});
      staleViewer.onPageChanged!(9);
      await paint(tester);
      await tap(tester, find.byTooltip('닫기'));
      expect(tester.widget<SegmentedButton<String>>(selector()).selected, {
        'portrait',
      });
      restored(tester, 5);
      staleViewer.onPageChanged!(1);
      await paint(tester);
      restored(tester, 5);

      await tap(tester, find.byTooltip('전체 미리보기'));
      final coveredViewer = tester.widget<TemplateFullScreenView>(viewer());
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('별도 화면')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      coveredViewer.onPageChanged!(11);
      navigator.currentState!.pop();
      await paint(tester);
      await tap(tester, find.byTooltip('닫기'));
      restored(tester, 5);

      await tap(tester, find.byTooltip('전체 미리보기'));
      final count = tester
          .widget<TemplateFullScreenView>(viewer())
          .parsedPages
          .length;
      tester.widget<PageView>(viewerPager()).controller!.jumpToPage(count - 1);
      await paint(tester);
      metrics(tester, const Size(844, 390));
      await capture(tester, 'last-page', const Size(844, 390), true);
      await tester.binding.handlePopRoute();
      await paint(tester);
      restored(tester, count - 1);
      safe(tester, action(), const Size(844, 390));
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byTooltip('다음 펼침면'),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await capture(tester, 'last-spread', const Size(844, 390), true);
      expect(accessRequests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
