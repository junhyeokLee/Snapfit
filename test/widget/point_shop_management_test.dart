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
      expect(find.text('템플릿 · 650P · 판매 중'), findsOneWidget);
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
