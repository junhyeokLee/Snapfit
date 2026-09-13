import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/catalog_favorites.dart';
import 'package:snap_fit/core/templates/catalog_favorites_provider.dart';
import 'package:snap_fit/core/templates/catalog_favorite_keys.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/presentation/providers/store_catalog_provider.dart';
import '../unit/catalog_favorites_test.dart' show MemoryFavoritesStorage;

void main() {
  test(
    'derived catalog memoizes query and preserves topic/search/latest save ordering',
    () async {
      final favorites = CatalogFavorites(storage: MemoryFavoritesStorage());
      await favorites.load();
      final c = ProviderContainer(
        overrides: [
          catalogFavoritesProvider.overrideWithValue(favorites),
          templateListProvider.overrideWith(
            (ref) async => bundledCreationTemplates,
          ),
        ],
      );
      addTearDown(c.dispose);
      addTearDown(favorites.dispose);
      await c.read(templateListProvider.future);
      final q = (query: '', category: '전체', favoritesOnly: false);
      final subscription = c.listen(storeCatalogProvider(q), (_, __) {});
      addTearDown(subscription.close);
      final all = c.read(storeCatalogProvider(q)).requireValue;
      expect(all.filtered.length, bundledCreationTemplates.length);
      expect(
        identical(all, c.read(storeCatalogProvider(q)).requireValue),
        isTrue,
      );
      final first = bundledCreationTemplates.first;
      final second = bundledCreationTemplates[1];
      await favorites.toggle(CatalogFavoriteKeys.template(first.id));
      await favorites.toggle(CatalogFavoriteKeys.template(second.id));
      await c.pump();
      expect(
        c
            .read(storeCatalogProvider(q))
            .requireValue
            .filtered
            .take(2)
            .map((t) => t.id),
        [second.id, first.id],
      );
      final search = c
          .read(
            storeCatalogProvider((
              query: first.title.toUpperCase(),
              category: 'missing',
              favoritesOnly: false,
            )),
          )
          .requireValue;
      expect(search.category, '전체');
      expect(search.filtered.map((t) => t.id), [first.id]);
      final only = c
          .read(
            storeCatalogProvider((
              query: '',
              category: '전체',
              favoritesOnly: true,
            )),
          )
          .requireValue;
      expect(only.filtered.map((t) => t.id), [second.id, first.id]);
    },
  );
}
