// 실제 카탈로그와 상세 화면을 사용하되 계정·구매·운영 요청은 모의값으로 격리한다.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/store_detail_gallery.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

import '/Users/devsheep/SnapFit/SnapFit/test/support/store_detail_loading.dart';
import '/Users/devsheep/SnapFit/SnapFit/test/widget/experience_detail_redesign_test.dart'
    show reviewApp;
import 'capture_support.dart';

Future<void> _ready(WidgetTester tester) async {
  await settleStoreDetail(tester);
  for (final element in find.byType(Image).evaluate()) {
    unawaited(precacheImage((element.widget as Image).image, element));
  }
  // 이미지 완료 콜백도 가짜 프레임 시계가 필요하므로 IO와 pump를 번갈아 진행한다.
  var stableFrames = 0;
  for (var frame = 0; frame < 120; frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 32));
    final ready = PaintingBinding.instance.imageCache.pendingImageCount == 0 &&
        !tester.binding.hasScheduledFrame;
    stableFrames = ready && frame >= 8 ? stableFrames + 1 : 0;
    if (stableFrames >= 3) return;
  }
  fail('Store artwork did not settle within the bounded frame budget.');
}

void main() {
  setUpAll(() async {
    await auditFonts();
    // 표지 레터링까지 실제 판매 폰트로 보며 대체 글꼴의 인상을 배제한다.
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

  for (final (size, suffix) in [
    (const Size(390, 844), '390'),
    (const Size(320, 568), '320'),
    (const Size(844, 390), 'landscape'),
  ]) {
    storeDetailTestWidgets('store current real template $suffix', (tester) async {
      auditViewport(tester, size: size);
      final template = publishedCreationTemplates.firstWhere(
        (template) => template.title == '여행의 결',
      );
      final key = pointShopTemplateKey(template);
      final price = pointShopLaunchPrices[key]!.points;
      await tester.pumpWidget(
        reviewApp(
          auditFrame(TemplateDetailScreen(template: template)),
          catalog: () async => [
            PointShopProduct(
              productKey: key,
              kind: 'template',
              assetId: '${template.id}',
              title: template.title,
              pointPrice: price,
              isActive: true,
            ),
          ],
        ),
      );
      await _ready(tester);
      expect(find.byKey(const ValueKey('template-detail-use')).hitTestable(),
          findsOneWidget);
      debugPrint('VISUAL_COVER_$suffix ${tester.getSize(find.byKey(const ValueKey('template-book-cover')).first).shortestSide}');
      await auditCapture(tester, 'store-detail-$suffix');

      if (suffix == '390') {
        final tabs = find.byKey(const ValueKey('template-gallery-mode'));
        expect(tester.widget<StoreGalleryTabs>(tabs).selected, 0);
        await tester.tap(find.descendant(of: tabs, matching: find.text('내지')));
        await _ready(tester);
        await auditCapture(tester, 'store-detail-390-interior');

        final information =
            find.byKey(const ValueKey('template-gallery-information'));
        await tester.ensureVisible(information);
        await tester.tap(find.text('디자인 구성 · 사진과 글'));
        await _ready(tester);
        await tester.ensureVisible(
          find.byKey(const ValueKey('template-purchase-overview')),
        );
        await auditCapture(tester, 'store-detail-390-information');
      }
    });
  }
}
