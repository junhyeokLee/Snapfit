import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/navigation/web_app_location.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/public_template_information.dart';
import 'package:snap_fit/shared/web/web_design.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  final design = publishedPremiumTemplates.firstWhere(
    (item) => item.id == -9522,
  );
  Finder key(String value) => find.byKey(ValueKey(value));

  Widget host(List<WebAppLocation> destinations, {double scale = 1}) =>
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          pointShopRepositoryProvider.overrideWith(
            (_) => throw StateError('Guest browsing must remain public'),
          ),
          ownedPointShopKeysProvider.overrideWith(
            (_) => throw StateError('Guest browsing must not read ownership'),
          ),
          publicPointShopCatalogProvider.overrideWith(
            (_) async => [
              PointShopProduct(
                productKey: pointShopTemplateKey(design),
                kind: 'template',
                assetId: '${design.id}',
                title: design.title,
                pointPrice: 2800,
                isActive: true,
              ),
            ],
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            theme: SnapFitWebTheme.from(ThemeData(useMaterial3: true)),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: WebNavigationScope(
                onNavigate: (_) {},
                onNotifications: () {},
                onPublicNavigate: destinations.add,
                child: child!,
              ),
            ),
            home: TemplateDetailScreen(template: design, guestPreview: true),
          ),
        ),
      );

  void viewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'mobile artwork fits the actual spread and use action stays visible after scrolling',
    (tester) async {
      viewport(tester, const Size(390, 844));
      final destinations = <WebAppLocation>[];
      await tester.pumpWidget(host(destinations));
      await tester.pumpAndSettle();
      final action = key('template-detail-use');
      expect(action, findsOneWidget);
      expect(action.hitTestable(), findsOneWidget);
      final coverHeight = tester.getSize(key('template-detail-stage')).height;
      await tester.tap(find.byTooltip('다음 펼침면'));
      await tester.pumpAndSettle();
      final innerHeight = tester.getSize(key('template-detail-stage')).height;
      expect(innerHeight, lessThan(coverHeight * .65));
      expect(find.text('1–2쪽'), findsOneWidget);
      final actionBefore = tester.getRect(action);
      await tester.drag(
        key('web-design-detail-stacked'),
        const Offset(0, -1200),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(action), actionBefore);
      expect(action.hitTestable(), findsOneWidget);
      expect(find.text('2,800P'), findsWidgets);
      final detailScroll = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: key('web-design-detail-stacked'),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      detailScroll.jumpTo(detailScroll.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(key('template-spread-pager'), findsNothing);
      detailScroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageView>(key('template-spread-pager')).controller!.page,
        closeTo(1, .001),
      );
      expect(find.text('1–2쪽'), findsOneWidget);
      expect(tester.getSize(key('template-detail-stage')).height, innerHeight);
      expect(tester.getRect(action), actionBefore);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(destinations, [WebAppLocation.login]);
      expect(tester.takeException(), isNull);
    },
    skip: !kIsWeb,
  );

  testWidgets(
    'scrolling away retains a late spread and its selected thumbnail',
    (tester) async {
      viewport(tester, const Size(390, 844));
      await tester.pumpWidget(host(<WebAppLocation>[]));
      await tester.pumpAndSettle();
      final thumbnail = key('template-spread-thumb-14');
      // Drag the rail itself. ensureVisible also scrolls the outer vertical
      // viewport, which does not represent a user's horizontal thumbnail drag.
      for (
        var drag = 0;
        drag < 20 && thumbnail.hitTestable().evaluate().isEmpty;
        drag++
      ) {
        await tester.drag(key('template-spread-list'), const Offset(-200, 0));
        await tester.pumpAndSettle();
      }
      expect(thumbnail.hitTestable(), findsOneWidget);
      await tester.tap(thumbnail);
      await tester.pumpAndSettle();
      expect(find.text('27–28쪽'), findsOneWidget);
      final scroll = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: key('web-design-detail-stacked'),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(key('template-spread-pager'), findsNothing);
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageView>(key('template-spread-pager')).controller!.page,
        closeTo(14, .001),
      );
      expect(find.text('27–28쪽'), findsOneWidget);
      expect(thumbnail.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    skip: !kIsWeb,
  );

  for (final sample in [
    (const Size(320, 568), 2.0),
    (const Size(844, 390), 1.0),
    (const Size(1440, 1000), 1.0),
  ]) {
    testWidgets(
      'detail use action remains unique and reachable at ${sample.$1} text ${sample.$2}',
      (tester) async {
        viewport(tester, sample.$1);
        final destinations = <WebAppLocation>[];
        await tester.pumpWidget(host(destinations, scale: sample.$2));
        await tester.pumpAndSettle();
        final action = key('template-detail-use');
        expect(tester.takeException(), isNull);
        expect(action, findsOneWidget);
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(action.hitTestable(), findsOneWidget);
        final rect = tester.getRect(action);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(sample.$1.width));
        expect(rect.bottom, lessThanOrEqualTo(sample.$1.height));
        expect(
          key('web-design-detail-bottom-action'),
          sample.$1.width == 1440 ? findsNothing : findsOneWidget,
        );
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(destinations, [WebAppLocation.login]);
        expect(tester.takeException(), isNull);
      },
      skip: !kIsWeb,
    );
  }
}
