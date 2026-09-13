import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../billing/data/billing_provider.dart';
import 'point_shop_repository.dart';

final pointShopRepositoryProvider = Provider<PointShopRepository>(
  (ref) => SupabasePointShopRepository(ref.watch(supabaseClientProvider)),
);

final pointShopSessionProvider = StreamProvider<String?>((ref) async* {
  final repository = ref.watch(pointShopRepositoryProvider);
  yield repository.currentUserId;
  yield* repository.authChanges;
});

final pointShopCatalogProvider = FutureProvider<List<PointShopProduct>>(
  (ref) => ref.watch(pointShopRepositoryProvider).loadCatalog(),
);

final ownedPointShopKeysProvider = FutureProvider<Set<String>>((ref) {
  ref.watch(pointShopSessionProvider);
  return ref.watch(pointShopRepositoryProvider).loadOwnedKeys();
});

/// One shared O(n) index per catalog revision, instead of a scan per badge.
final pointShopProductIndexProvider = Provider(
  (ref) => ref
      .watch(pointShopCatalogProvider)
      .whenData(
        (items) => Map<String, PointShopProduct>.unmodifiable({
          for (final item in items) item.productKey: item,
        }),
      ),
  dependencies: [pointShopCatalogProvider],
);
final pointShopOwnedProvider = Provider.autoDispose.family<bool, String>(
  (ref, key) => ref.watch(
    ownedPointShopKeysProvider.select(
      (owned) => owned.asData?.value.contains(key) ?? false,
    ),
  ),
  dependencies: [ownedPointShopKeysProvider],
);
final pointShopBadgeLabelProvider = Provider.autoDispose
    .family<String, ({String key, String freeLabel})>((ref, query) {
      if (ref.watch(pointShopOwnedProvider(query.key))) return '구매 완료';
      return ref.watch(
        pointShopProductIndexProvider.select(
          (catalog) => catalog.when(
            loading: () => '가격 확인 중',
            error: (_, __) => '가격 확인 필요',
            data: (items) {
              final product = items[query.key];
              if (product == null) return query.freeLabel;
              if (!product.isActive || product.pointPrice == null)
                return '판매 준비 중';
              return product.pointPrice == 0
                  ? query.freeLabel
                  : '${product.pointPrice}P';
            },
          ),
        ),
      );
    }, dependencies: [pointShopOwnedProvider, pointShopProductIndexProvider]);

void refreshPointShop(WidgetRef ref) {
  ref.invalidate(pointShopCatalogProvider);
  ref.invalidate(ownedPointShopKeysProvider);
  ref.invalidate(myPointBalanceProvider);
  ref.invalidate(myPointLedgerProvider);
}
