import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/shared/widgets/catalog_cover_skeleton.dart';
import 'package:snap_fit/shared/widgets/catalog_skeleton_shimmer.dart';
import 'package:snap_fit/shared/widgets/snapfit_shimmer.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/data/store_curation_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/presentation/views/store_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/public_template_information.dart';

import '../support/catalog_preview_loading.dart';

const _cover = SizedBox.square(dimension: 160, child: CatalogCoverSkeleton());

Widget _host({
  Widget child = _cover,
  bool active = true,
  bool reduced = false,
  bool dark = false,
}) => MaterialApp(
  theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
  themeAnimationDuration: Duration.zero,
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(800, 600),
      disableAnimations: reduced,
    ),
    child: TickerMode(
      enabled: active,
      child: CatalogSkeletonShimmer(
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  ),
);

Future<Uint8List> _pixels(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
) async {
  return (await tester.runAsync(() async {
    final image =
        await (boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage();
    try {
      if (const bool.fromEnvironment('SHIMMER_QA')) {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('output/store-shimmer-qa/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png!.buffer.asUint8List());
      }
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return Uint8List.fromList(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }))!;
}

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'paper sheen visibly moves without rebuilding children, dark=$dark',
      (tester) async {
        final boundary = GlobalKey();
        var builds = 0;
        await tester.pumpWidget(
          _host(
            dark: dark,
            child: RepaintBoundary(
              key: boundary,
              child: Builder(
                builder: (_) {
                  builds++;
                  return _cover;
                },
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 30));
        final before = await _pixels(
          tester,
          boundary,
          '${dark ? 'dark' : 'light'}-before',
        );
        final initialBuilds = builds;
        await tester.pump(const Duration(milliseconds: 450));
        final after = await _pixels(
          tester,
          boundary,
          '${dark ? 'dark' : 'light'}-sweep',
        );
        expect(before.length, after.length);
        expect(
          List.generate(
            before.length,
            (i) => before[i] != after[i],
          ).any((v) => v),
          isTrue,
        );
        expect(builds, initialBuilds);
        expect(find.byType(ShaderMask), findsNothing);
        expect(tester.binding.transientCallbackCount, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'multiple placeholders share one clock and completed covers release it',
    (tester) async {
      await tester.pumpWidget(
        _host(
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [_cover, _cover, _cover],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 1);
      await tester.pumpWidget(_host(child: const Text('Loaded')));
      await tester.pumpAndSettle();
      expect(find.byType(CatalogCoverSkeleton), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(_host());
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets(
    'hidden tabs, reduced motion and background stop and resume the clock',
    (tester) async {
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      await tester.pumpWidget(_host());
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(_host(active: false));
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(_host(reduced: true));
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(_host());
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'both scroll axes must be idle; cached offscreen placeholders stop',
    (tester) async {
      final vertical = ScrollController();
      final horizontal = ScrollController();
      addTearDown(vertical.dispose);
      addTearDown(horizontal.dispose);
      await tester.pumpWidget(
        _host(
          child: ListView(
            controller: vertical,
            cacheExtent: 2000,
            children: [
              SizedBox(
                height: 180,
                child: ListView(
                  controller: horizontal,
                  scrollDirection: Axis.horizontal,
                  children: const [_cover, SizedBox(width: 1800)],
                ),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      );
      expect(tester.hasRunningAnimations, isTrue);
      vertical.position.isScrollingNotifier.value = true;
      horizontal.position.isScrollingNotifier.value = true;
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      vertical.position.isScrollingNotifier.value = false;
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      horizontal.position.isScrollingNotifier.value = false;
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      vertical.jumpTo(1000);
      await tester.pumpAndSettle();
      expect(
        find.byType(CatalogCoverSkeleton, skipOffstage: false),
        findsOneWidget,
      );
      expect(tester.hasRunningAnimations, isFalse);
      vertical.jumpTo(0);
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'full loading skeleton pauses during scroll and resumes after settling',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scroll,
              child: const SnapFitShimmerTemplateTileGrid(rows: 3),
            ),
          ),
        ),
      );
      expect(tester.hasRunningAnimations, isTrue);
      scroll.position.isScrollingNotifier.value = true;
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      scroll.position.isScrollingNotifier.value = false;
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets(
    'store cover shines while native preview is pending and stops on completion',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      CatalogFavorites.instance = CatalogFavorites();
      await CatalogFavorites.instance.load();
      addTearDown(() => CatalogFavorites.instance.dispose());
      const source =
          '{"designWidth":500,"designHeight":500,"pages":[{"layers":[{"id":"loaded-cover","type":"text","text":"Our photos","x":0.1,"y":0.1,"width":0.8,"height":0.2,"fontSize":24}]}]}';
      final template = PremiumTemplate(
        id: 8877001,
        title: 'Loading cover',
        category: '일상',
        coverImageUrl: '',
        previewImages: const [],
        pageCount: 1,
        userCount: 0,
        documentBuilder: () {
          // Production loads exported documents in the worker. This controlled
          // slow custom document lets the real store show its pending artwork.
          sleep(const Duration(milliseconds: 180));
          return source;
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mockTemplateList(() => [template]),
            storeCurationsProvider.overrideWith((_) async => {}),
            pointShopCatalogProvider.overrideWith(
              (_) async => [
                PointShopProduct(
                  productKey: pointShopTemplateKey(template),
                  kind: 'template',
                  assetId: '${template.id}',
                  title: template.title,
                  pointPrice: 0,
                  isActive: true,
                ),
              ],
            ),
            publicPointShopCatalogProvider.overrideWith((_) async => []),
            ownedPointShopKeysProvider.overrideWith((_) async => <String>{}),
            pointShopRepositoryProvider.overrideWith(
              (_) => throw StateError('No commerce request'),
            ),
          ],
          child: MaterialApp(
            theme: SnapFitTheme.light(),
            themeAnimationDuration: Duration.zero,
            home: const StoreScreen(embedded: true),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CatalogCoverSkeleton), findsOneWidget);
      expect(tester.binding.transientCallbackCount, greaterThan(1));
      await loadCatalogPreview(tester, template);
      await tester.pumpAndSettle();
      expect(find.byType(CatalogCoverSkeleton), findsNothing);
      // Riverpod 3.2 keeps one idle scope callback (scheduleNewFrame: false).
      // Only that callback remains; no shimmer ticker requests another frame.
      expect(tester.binding.transientCallbackCount, 1);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
