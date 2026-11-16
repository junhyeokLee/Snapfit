import '../support/store_detail_loading.dart';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/domain/template_design_profile.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts;
import 'experience_detail_redesign_test.dart' show reviewApp;

PremiumTemplate get _travel => publishedCreationTemplates.firstWhere(
  (template) => template.title == '여행의 결',
);

Future<void> _open(
  WidgetTester tester, {
  Size size = const Size(320, 568),
  bool dark = false,
  double textScale = 1,
  PremiumTemplate? template,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final shown = template ?? _travel;
  final key = pointShopTemplateKey(shown);
  await tester.pumpWidget(
    reviewApp(
      Builder(
        builder: (context) => Theme(
          data: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: TemplateDetailScreen(template: shown),
          ),
        ),
      ),
      catalog: () async => [
        PointShopProduct(
          productKey: key,
          kind: 'template',
          assetId: '${shown.id}',
          title: shown.title,
          pointPrice: pointShopLaunchPrices[key]!.points,
          isActive: true,
        ),
      ],
    ),
  );
  await settleStoreDetail(tester);
}

Finder get _use => find.byKey(const ValueKey('template-detail-use'));
Finder get _pager => find.byKey(const ValueKey('template-spread-pager'));

double _spread(WidgetTester tester) =>
    tester.widget<PageView>(_pager).controller!.page!;

void main() {
  setUpAll(loadCreationFonts);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  storeDetailTestWidgets(
    'short portrait keeps the real cover readable beside an accessible CTA',
    (tester) async {
      await _open(tester);
      final cover = tester.getSize(
        find.byKey(const ValueKey('template-book-cover')).first,
      );
      // 120dp는 320dp 화면에서 표지를 식별할 최소 기준이며 배치 계산식과 독립적이다.
      expect(cover.shortestSide, greaterThanOrEqualTo(120));
      expect(_use.hitTestable(), findsOneWidget);
      expect(tester.getSize(_use).height, greaterThanOrEqualTo(48));
      expect(tester.getRect(_use).bottom, lessThanOrEqualTo(568));
      expect(tester.takeException(), isNull);
    },
  );

  storeDetailTestWidgets(
    'portrait arrows thumbnails and view switch inspect the same remembered spread',
    (tester) async {
      await _open(tester);
      expect(_spread(tester), 0);
      await tester.tap(find.byTooltip('다음 펼침면'));
      await settleStoreDetail(tester);
      expect(_spread(tester), 1);
      expect(find.text('1–2쪽').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('다음 펼침면'));
      await settleStoreDetail(tester);
      expect(_spread(tester), 2);
      await tester.tap(find.byTooltip('이전 펼침면'));
      await settleStoreDetail(tester);
      expect(_spread(tester), 1);

      final thumbnail = find.byKey(const ValueKey('template-spread-thumb-2'));
      await tester.ensureVisible(thumbnail);
      await tester.tap(thumbnail);
      await settleStoreDetail(tester);
      expect(_spread(tester), 2);
      expect(find.text('3–4쪽').hitTestable(), findsOneWidget);

      final tabs = find.byKey(const ValueKey('template-gallery-mode'));
      await tester.ensureVisible(tabs);
      await tester.tap(find.descendant(of: tabs, matching: find.text('표지')));
      await settleStoreDetail(tester);
      expect(_spread(tester), 0);
      await tester.tap(find.descendant(of: tabs, matching: find.text('내지')));
      await settleStoreDetail(tester);
      expect(_spread(tester), 2);
      expect(_use.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  storeDetailTestWidgets(
    'known document exposes actual photo and writing counts in primary specs',
    (tester) async {
      final profile = TemplateDesignProfile.of(_travel);
      expect(profile.hasKnownDocument, isTrue);
      expect(profile.photoSlotCount, isNotNull);
      expect(profile.recordPageCount, isNotNull);
      await _open(tester, size: const Size(390, 844));
      expect(find.text('사진 넣는 곳').hitTestable(), findsOneWidget);
      expect(
        find.text('${profile.photoSlotCount}곳').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('글쓰기 내지').hitTestable(), findsOneWidget);
      expect(
        find.text('${profile.recordPageCount}쪽').hitTestable(),
        findsWidgets,
      );
      expect(find.text('0종').hitTestable(), findsNothing);
      // 규격은 실제 선택 가능한 폼에 남고, 구성 정보가 구매조건을 바꾸지 않는다.
      await tester.ensureVisible(
        find.byKey(const ValueKey('template-size-selector')),
      );
      expect(
        find.byKey(const ValueKey('template-size-selector')).hitTestable(),
        findsOneWidget,
      );
      expect(_use.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    storeDetailTestWidgets(
      'short portrait long Korean text scales without overflow dark=$dark',
      (tester) async {
        final template = _travel.copyWith(
          title: '우리가 천천히 걸으며 모은 길고 다정한 여행의 모든 순간',
          subTitle: '낯선 골목과 바닷가에서 발견한 사진과 긴 문장들을 한 권에 담아요.',
        );
        await _open(tester, dark: dark, textScale: 1.8, template: template);
        expect(_use.hitTestable(), findsOneWidget);
        expect(tester.getSize(_use).height, greaterThanOrEqualTo(48));
        expect(tester.getRect(_use).bottom, lessThanOrEqualTo(568));
        await tester.tap(find.byTooltip('다음 펼침면'));
        await settleStoreDetail(tester);
        expect(_spread(tester), 1);
        await tester.ensureVisible(find.text(template.title).first);
        expect(find.text(template.title).hitTestable(), findsOneWidget);
        expect(_use.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
