import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/catalog_favorites.dart';
import 'package:snap_fit/core/templates/catalog_favorites_provider.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_repository.dart';
import '../unit/catalog_favorites_test.dart' show MemoryFavoritesStorage;

void main() {
  test(
    'favorite key selectors suppress unrelated saves; rollback/latest-save persist',
    () async {
      final storage = MemoryFavoritesStorage();
      final favorites = CatalogFavorites(storage: storage);
      await favorites.load();
      final c = ProviderContainer(
        overrides: [catalogFavoritesProvider.overrideWithValue(favorites)],
      );
      addTearDown(c.dispose);
      addTearDown(favorites.dispose);
      var changes = 0;
      c.listen(catalogFavoriteProvider('a'), (_, __) => changes++);
      await favorites.toggle('b');
      await c.pump();
      expect(changes, 0);
      await favorites.toggle('a');
      await c.pump();
      expect(changes, 1);
      expect(c.read(catalogFavoriteOrderProvider), ['a', 'b']);
      await favorites.toggle('b');
      await favorites.toggle('b');
      await c.pump();
      expect(c.read(catalogFavoriteOrderProvider), ['b', 'a']);
      expect(changes, 1);
    },
  );
  test('price and owned selectors do not notify unrelated badges', () async {
    var products = [
      for (final key in ['a', 'b'])
        PointShopProduct(
          productKey: key,
          kind: 'sticker',
          assetId: key,
          title: key,
          pointPrice: 20,
          isActive: true,
        ),
    ];
    var owned = <String>{};
    final c = ProviderContainer(
      overrides: [
        pointShopCatalogProvider.overrideWith((ref) async => products),
        ownedPointShopKeysProvider.overrideWith((ref) async => owned),
      ],
    );
    addTearDown(c.dispose);
    var changes = 0;
    final provider = pointShopBadgeLabelProvider((key: 'a', freeLabel: '무료'));
    c.listen(provider, (_, __) => changes++);
    await c.read(pointShopCatalogProvider.future);
    await c.read(ownedPointShopKeysProvider.future);
    await c.pump();
    expect(c.read(provider), '20P');
    changes = 0;
    owned = {'b'};
    c.invalidate(ownedPointShopKeysProvider);
    await c.read(ownedPointShopKeysProvider.future);
    await c.pump();
    expect(changes, 0);
    products = [
      products.first,
      PointShopProduct(
        productKey: 'b',
        kind: 'sticker',
        assetId: 'b',
        title: 'b',
        pointPrice: 40,
        isActive: true,
      ),
    ];
    c.invalidate(pointShopCatalogProvider);
    await c.read(pointShopCatalogProvider.future);
    await c.pump();
    expect(changes, 0);
    owned = {'a', 'b'};
    c.invalidate(ownedPointShopKeysProvider);
    await c.read(ownedPointShopKeysProvider.future);
    await c.pump();
    expect(c.read(provider), '구매 완료');
    changes = 0;
    owned = {'a'};
    c.invalidate(ownedPointShopKeysProvider);
    c.read(ownedPointShopKeysProvider);
    await c.pump();
    await c.read(ownedPointShopKeysProvider.future);
    await c.pump();
    expect(
      changes,
      0,
      reason: 'unrelated ownership refresh must not flicker a',
    );
  });
}
