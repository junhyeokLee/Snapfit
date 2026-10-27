import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../billing/data/billing_provider.dart';
import '../../profile/domain/order_visibility_owner.dart';
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

final ownedPointShopKeysProvider = FutureProvider<Set<String>>((ref) async {
  ref.watch(pointShopSessionProvider);
  final owner = ref.watch(visibleOrderOwnerProvider);
  final repository = ref.watch(pointShopRepositoryProvider);
  if (owner == null || repository.currentUserId != owner) return const {};
  final keys = await repository.loadOwnedKeys();
  return ref.mounted &&
          ref.read(visibleOrderOwnerProvider) == owner &&
          repository.currentUserId == owner
      ? keys
      : const {};
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
