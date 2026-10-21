import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/commerce/commerce_policy.dart';
import 'package:snap_fit/core/navigation/web_app_location.dart';
import 'package:snap_fit/features/commerce/data/public_print_catalog.dart';
import 'package:snap_fit/features/commerce/presentation/public_commerce_screen.dart';
import 'package:snap_fit/shared/web/web_design.dart';

// Fixtures do not access authentication, checkout or a server.
final _date = DateTime.utc(2026, 10, 19);
final _prices = PublicPrintCatalog(
  generatedAt: _date,
  items: const [
    PublicPrintPrice(
      productId: 'REDP_200_SOFT',
      pageCount: 20,
      retailPrice: 49900,
      shippingFee: 0,
      orderCodeApproved: false,
    ),
    PublicPrintPrice(
      productId: 'REDP_200X150_SOFT',
      pageCount: 20,
      retailPrice: 39900,
      shippingFee: 0,
      orderCodeApproved: true,
    ),
    PublicPrintPrice(
      productId: 'REDP_300_HARD',
      pageCount: 80,
      retailPrice: 159900,
      shippingFee: 0,
      orderCodeApproved: true,
    ),
  ],
);

Future<void> _mount(
  WidgetTester tester,
  Widget screen, {
  double width = 1440,
  ValueChanged<WebAppLocation>? onPublicNavigate,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        publicPrintCatalogProvider.overrideWith((_) async => _prices),
      ],
      child: MaterialApp(
        theme: SnapFitWebTheme.from(ThemeData()),
        home: WebNavigationScope(
          onNavigate: (_) {},
          onNotifications: () {},
          onPublicNavigate: onPublicNavigate,
          child: screen,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [390.0, 760.0, 1024.0, 1440.0]) {
    testWidgets(
      'public planned product information works without auth at $width px',
      (tester) async {
        await _mount(tester, const PrintProductsScreen(), width: width);
        expect(find.text('판매 준비 중'), findsOneWidget);
        expect(find.text('예정가 49,900원'), findsWidgets);
        expect(find.text('부가세·기본 배송비 포함 예정'), findsWidgets);
        expect(find.text('예정가 159,900원'), findsOneWidget);
        expect(find.text('제작사 접수 준비 확인 · 실물 검수 전'), findsWidgets);
        expect(find.text('결제하기'), findsNothing);
        expect(find.text('주문하기'), findsNothing);
        expect(find.byType(FilledButton), findsNothing);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('public-commerce-footer')),
          450,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('문의 junhyeoklee616@gmail.com'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'representative product updates all selectors and the exact server price',
    (tester) async {
      await _mount(tester, const PrintProductsScreen());
      await tester.scrollUntilVisible(
        find.text('이 구성 살펴보기').last,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('이 구성 살펴보기').last);
      await tester.pumpAndSettle();
      final selected = tester.widget<Text>(
        find.byKey(const ValueKey('public-selected-price')),
      );
      expect(selected.data, '예정가 159,900원');
      expect(
        find.byKey(const ValueKey('public-product-size-REDP_300_SOFT')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('public-product-cover-hard')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('public-product-pages-80')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'policy is publicly readable and links back without requesting login',
    (tester) async {
      final navigated = <WebAppLocation>[];
      await _mount(
        tester,
        const CommercePolicyScreen(kind: CommercePolicyKind.refund),
        onPublicNavigate: navigated.add,
      );
      expect(
        find.text(CommercePolicy.document(CommercePolicyKind.refund).title),
        findsWidgets,
      );
      expect(find.text(CommercePolicy.draftNotice), findsOneWidget);
      await tester.tap(find.text('인쇄 상품·가격').first);
      expect(navigated, [WebAppLocation.printProducts]);
      expect(tester.takeException(), isNull);
    },
  );
}
