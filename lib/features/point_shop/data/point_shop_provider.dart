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

void refreshPointShop(WidgetRef ref) {
  ref.invalidate(pointShopCatalogProvider);
  ref.invalidate(ownedPointShopKeysProvider);
  ref.invalidate(myPointBalanceProvider);
  ref.invalidate(myPointLedgerProvider);
}

class PointShopPurchaseCoordinator {
  bool busy = false;
}

final pointShopPurchaseCoordinatorProvider = Provider(
  (ref) => PointShopPurchaseCoordinator(),
);
