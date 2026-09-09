import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_repository.dart';
import 'package:snap_fit/features/profile/presentation/views/admin_point_shop_management_screen.dart';
import 'package:snap_fit/features/profile/presentation/widgets/my_point_balance_card.dart';

class FakeShop extends PointShopRepository {
  final List<PointShopProduct> saved = [];
  bool failSave = false;
  int catalogReads = 0;
  @override
  String? get currentUserId => 'admin-user';
  @override
  Stream<String?> get authChanges => const Stream.empty();
  @override
  Future<List<PointShopProduct>> loadCatalog() async {
    catalogReads++;
    return List.of(saved);
  }

  @override
  Future<Set<String>> loadOwnedKeys() async => {};
  @override
  Future<void> saveProduct(PointShopProduct product) async {
    if (failSave) throw StateError('offline');
    saved.add(product);
  }

  @override
  Future<PointShopAccess> getAccess(String key) => throw UnimplementedError();
  @override
  Future<PointShopPurchase> purchase(String key, int expectedPrice) =>
      throw UnimplementedError();
}

Widget admin(FakeShop repository, {bool allowed = true}) => ProviderScope(
  overrides: [
    pointShopAdminAccessProvider.overrideWithValue(allowed),
    pointShopRepositoryProvider.overrideWithValue(repository),
  ],
  child: const MaterialApp(home: AdminPointShopManagementScreen()),
);

void main() {
  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('launch price dialog stays reachable at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeShop();
      await tester.pumpWidget(admin(repository));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, '상품 찾기'),
        'vow-keepsake',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('point-shop-admin-template:vow-keepsake')),
      );
      await tester.pumpAndSettle();
      final dialog = tester.getRect(find.byType(AlertDialog));
      expect(dialog.top, greaterThanOrEqualTo(0));
      expect(dialog.bottom, lessThanOrEqualTo(size.height));
      expect(dialog.right, lessThanOrEqualTo(size.width));
      await tester.ensureVisible(
        find.byKey(const ValueKey('point-shop-use-launch-price')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('point-shop-use-launch-price')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('point-shop-price')))
            .controller!
            .text,
        '2500',
      );
      expect(repository.saved, isEmpty);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'launch price input never writes on open or overwrites a configured price',
    (tester) async {
      final repository = FakeShop()
        ..saved.add(
          const PointShopProduct(
            productKey: 'sticker:materialRose',
            kind: 'sticker',
            assetId: 'materialRose',
            title: '간직한 장미',
            pointPrice: 350,
            isActive: true,
          ),
        );
      await tester.pumpWidget(admin(repository));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, '상품 찾기'),
        'materialRose',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('350P · 판매 중'), findsOneWidget);
      expect(find.textContaining('출시 책정가 300P'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('point-shop-admin-sticker:materialRose')),
      );
      await tester.pumpAndSettle();
      String price() => tester
          .widget<TextField>(find.byKey(const ValueKey('point-shop-price')))
          .controller!
          .text;
      expect(price(), '350');
      expect(repository.saved, hasLength(1));
      await tester.tap(
        find.byKey(const ValueKey('point-shop-use-launch-price')),
      );
      await tester.pumpAndSettle();
      expect(price(), '300');
      expect(repository.saved, hasLength(1));
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(repository.saved, hasLength(1));
      expect(repository.saved.single.pointPrice, 350);
    },
  );

  testWidgets(
    'free material launch price is explicit zero; cancel keeps current free fallback',
    (tester) async {
      final repository = FakeShop();
      await tester.pumpWidget(admin(repository));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, '상품 찾기'),
        'materialIndexTabs',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('point-shop-admin-sticker:materialIndexTabs'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('point-shop-price')))
            .controller!
            .text,
        isEmpty,
      );
      await tester.tap(
        find.byKey(const ValueKey('point-shop-use-launch-price')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('point-shop-price')))
            .controller!
            .text,
        '0',
      );
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        false,
      );
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(repository.saved, isEmpty);
    },
  );

  testWidgets('premium draft can save a price but cannot start sales', (
    tester,
  ) async {
    final repository = FakeShop();
    await tester.pumpWidget(admin(repository));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '상품 찾기'),
      'vow-keepsake',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('가격 미설정 · 출시 대기'), findsOneWidget);
    expect(find.textContaining('내지 24·32쪽'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('point-shop-admin-template:vow-keepsake')),
    );
    await tester.pumpAndSettle();
    expect(find.text('현재 무료로 제공 중이며 저장된 가격이 없습니다.'), findsNothing);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNull,
    );
    expect(repository.saved, isEmpty);
    await tester.tap(find.byKey(const ValueKey('point-shop-use-launch-price')));
    await tester.pumpAndSettle();
    expect(repository.saved, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.productKey, 'template:vow-keepsake');
    expect(repository.saved.single.pointPrice, 2500);
    expect(repository.saved.single.isActive, false);
    expect(find.textContaining('2500P · 출시 대기'), findsOneWidget);
  });

  testWidgets('concept draft saves 1800P without enabling sales', (
    tester,
  ) async {
    final repository = FakeShop();
    await tester.pumpWidget(admin(repository));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '상품 찾기'),
      'shared-seasons',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('가격 미설정 · 출시 대기'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('point-shop-admin-template:shared-seasons')),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('point-shop-use-launch-price')));
    await tester.pumpAndSettle();
    expect(repository.saved, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(repository.saved.single.pointPrice, 1800);
    expect(repository.saved.single.isActive, false);
    expect(find.textContaining('1800P · 출시 대기'), findsOneWidget);
  });

  testWidgets('non-admin cannot load or edit the price catalog', (
    tester,
  ) async {
    final repository = FakeShop();
    await tester.pumpWidget(admin(repository, allowed: false));
    await tester.pumpAndSettle();
    expect(find.text('상품 가격을 변경할 관리자 권한이 필요합니다.'), findsOneWidget);
    expect(repository.catalogReads, 0);
    expect(repository.saved, isEmpty);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets(
    'admin opens without choosing prices and explicitly saves one known product',
    (tester) async {
      final repository = FakeShop();
      await tester.pumpWidget(admin(repository));
      await tester.pumpAndSettle();
      expect(repository.saved, isEmpty);
      expect(find.textContaining('현재 무료 · 가격 미설정'), findsWidgets);
      await tester.tap(
        find.byKey(const ValueKey('point-shop-admin-template:lightbound')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.tap(find.widgetWithText(FilledButton, '저장'));
      await tester.pumpAndSettle();
      expect(repository.saved, isEmpty);
      expect(find.text('판매할 가격을 0 이상의 정수 포인트로 입력해 주세요.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('point-shop-price')),
        '650',
      );
      await tester.tap(find.widgetWithText(FilledButton, '저장'));
      await tester.pumpAndSettle();
      expect(repository.saved, hasLength(1));
      expect(repository.saved.single.productKey, 'template:lightbound');
      expect(repository.saved.single.assetId, 'lightbound');
      expect(repository.saved.single.pointPrice, 650);
      expect(repository.saved.single.isActive, isTrue);
      expect(find.textContaining('템플릿 · 650P · 판매 중'), findsOneWidget);
      expect(find.textContaining('출시 책정가 0P'), findsWidgets);
    },
  );

  testWidgets('failed admin save keeps the entered price and permits retry', (
    tester,
  ) async {
    final repository = FakeShop()..failSave = true;
    await tester.pumpWidget(admin(repository));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('point-shop-admin-template:lightbound')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('point-shop-price')),
      '300',
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(repository.saved, isEmpty);
    expect(find.text('저장하지 못했습니다. 관리자 권한과 연결 상태를 확인해 주세요.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('point-shop-price')))
          .controller!
          .text,
      '300',
    );
    repository.failSave = false;
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(repository.saved.single.pointPrice, 300);
  });

  testWidgets(
    'MyPage point card shows balance and opens the existing recharge action',
    (tester) async {
      var charges = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [myPointBalanceProvider.overrideWith((ref) async => 2750)],
          child: MaterialApp(
            home: Scaffold(body: MyPointBalanceCard(onCharge: () => charges++)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2750P'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('my-point-charge')));
      expect(charges, 1);
    },
  );

  testWidgets(
    'MyPage point card retries a failed balance read without showing a made-up balance',
    (tester) async {
      var reads = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myPointBalanceProvider.overrideWith((ref) async {
              if (++reads == 1) throw StateError('offline');
              return -200;
            }),
          ],
          child: MaterialApp(
            home: Scaffold(body: MyPointBalanceCard(onCharge: () {})),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0P'), findsNothing);
      await tester.tap(find.text('잔액 다시 확인'));
      await tester.pumpAndSettle();
      expect(find.text('-200P'), findsOneWidget);
    },
  );
}
