import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/navigation/web_app_location.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/store/presentation/views/public_discovery_screen.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/public_template_information.dart';
import 'package:snap_fit/shared/web/web_design.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  Widget app(
    Widget child,
    List<WebAppLocation> requests, {
    bool failPrices = false,
  }) => ProviderScope(
    overrides: [
      pointShopRepositoryProvider.overrideWith(
        (_) => throw StateError(
          'Guest previews must not request accounts or ownership',
        ),
      ),
      publicPointShopCatalogProvider.overrideWith((_) async {
        if (failPrices) throw StateError('public catalog offline');
        return [
          PointShopProduct(
            productKey: pointShopTemplateKey(publishedCreationTemplates.first),
            kind: 'template',
            assetId: 'published-fixture',
            title: 'Public price fixture',
            pointPrice: 1800,
            isActive: true,
          ),
          PointShopProduct(
            productKey: 'sticker:${studioDecorations.first.id}',
            kind: 'sticker',
            assetId: studioDecorations.first.id,
            title: 'Public material fixture',
            pointPrice: 200,
            isActive: true,
          ),
        ];
      }),
      ownedPointShopKeysProvider.overrideWith(
        (_) => throw StateError('Guests must not read individual ownership'),
      ),
    ],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: SnapFitWebTheme.from(ThemeData()),
        builder: (_, child) => WebNavigationScope(
          onNavigate: (_) {},
          onNotifications: () {},
          onPublicNavigate: requests.add,
          child: child!,
        ),
        home: child,
      ),
    ),
  );

  testWidgets(
    'public browsing sends canonical preview and login destinations to the router',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <WebAppLocation>[];
      await tester.pumpWidget(
        app(const PublicDiscoveryScreen(catalogOnly: true), requests),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('discovery-login')));
      expect(requests.removeLast(), WebAppLocation.login);
      final template = publishedCreationTemplates.first;
      final preview = find.byKey(ValueKey('discovery-template-${template.id}'));
      await tester.ensureVisible(preview);
      await tester.tap(preview);
      expect(
        requests.single,
        WebAppLocation(WebAppPage.template, '${template.id}'),
      );
      expect(tester.takeException(), isNull);
    },
    skip: !kIsWeb,
  );

  testWidgets(
    'guest detail shows the public price and requests login before ownership',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <WebAppLocation>[];
      await tester.pumpWidget(
        app(
          TemplateDetailScreen(
            template: publishedCreationTemplates.first,
            guestPreview: true,
          ),
          requests,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CatalogFavoriteButton), findsNothing);
      expect(find.text('1,800P'), findsWidgets);
      expect(find.text('디자인 이용 안내'), findsOneWidget);
      expect(find.byTooltip('알림'), findsNothing);
      expect(
        find.byKey(const ValueKey('web-primary-navigation')),
        findsNothing,
      );
      final use = find.byKey(const ValueKey('template-detail-use'));
      await tester.ensureVisible(use);
      await tester.tap(use);
      expect(requests, [WebAppLocation.login]);
      expect(tester.takeException(), isNull);
    },
    skip: !kIsWeb,
  );

  testWidgets(
    'guest can continue to login when the public price lookup fails',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <WebAppLocation>[];
      await tester.pumpWidget(
        app(
          TemplateDetailScreen(
            template: publishedCreationTemplates.first,
            guestPreview: true,
          ),
          requests,
          failPrices: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('가격을 확인하지 못했어요'), findsWidgets);
      expect(find.text('가격 다시 확인'), findsOneWidget);
      final use = find.byKey(const ValueKey('template-detail-use'));
      await tester.ensureVisible(use);
      await tester.tap(use);
      expect(requests, [WebAppLocation.login]);
      expect(tester.takeException(), isNull);
    },
    skip: !kIsWeb,
  );

  testWidgets(
    'guest materials remain public, read only and return to the same template',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <WebAppLocation>[];
      final template = publishedCreationTemplates.first.copyWith(
        pageCount: 1,
        templateJson: jsonEncode({
          'designWidth': 500,
          'designHeight': 500,
          'pages': [
            {
              'layers': [
                {
                  'id': 'public-material',
                  'type': 'decoration',
                  'style': studioDecorations.first.id,
                  'x': 100,
                  'y': 100,
                  'width': 100,
                  'height': 100,
                },
              ],
            },
          ],
        }),
      );
      await tester.pumpWidget(
        app(
          TemplateDetailScreen(template: template, guestPreview: true),
          requests,
        ),
      );
      await tester.pumpAndSettle();
      final materials = find.widgetWithText(TextButton, '전체 보기');
      await tester.ensureVisible(materials);
      await tester.tap(materials);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('template-material-list')),
        findsOneWidget,
      );
      expect(find.byTooltip('알림'), findsNothing);
      expect(
        find.byKey(const ValueKey('web-primary-navigation')),
        findsNothing,
      );
      expect(find.text('200P'), findsOneWidget);
      expect(find.textContaining('로그인 후 보유 여부와 최종 이용 조건'), findsOneWidget);
      final row = find.byKey(
        ValueKey('template-material-row-sticker:${studioDecorations.first.id}'),
      );
      expect(tester.widget<InkWell>(row).onTap, isNull);
      await tester.tap(find.text('템플릿으로'));
      await tester.pumpAndSettle();
      expect(find.byType(TemplateDetailScreen), findsOneWidget);
      expect(
        tester
            .widget<TemplateDetailScreen>(find.byType(TemplateDetailScreen))
            .template
            .id,
        template.id,
      );
      expect(requests, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !kIsWeb,
  );
}
