import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'catalog_favorites.dart';

/// Adapter only: storage serialization, rollback, migration and device-local
/// scope remain owned by CatalogFavorites. Purchases retain account scope.
final catalogFavoritesProvider = Provider<CatalogFavorites>(
  (ref) => CatalogFavorites.instance,
);
final catalogFavoriteOrderProvider =
    NotifierProvider<CatalogFavoriteOrder, List<String>>(
      CatalogFavoriteOrder.new,
      dependencies: [catalogFavoritesProvider],
    );

class CatalogFavoriteOrder extends Notifier<List<String>> {
  @override
  List<String> build() {
    final favorites = ref.watch(catalogFavoritesProvider);
    void changed() => state = favorites.keys;
    favorites.addListener(changed);
    ref.onDispose(() => favorites.removeListener(changed));
    unawaited(favorites.load());
    return favorites.keys;
  }
}

final catalogFavoriteProvider = Provider.autoDispose.family<bool, String>(
  (ref, key) => ref.watch(
    catalogFavoriteOrderProvider.select((keys) => keys.contains(key)),
  ),
  dependencies: [catalogFavoriteOrderProvider],
);
