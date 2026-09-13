import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/templates/catalog_favorites_provider.dart';
import '../../../../core/templates/catalog_favorite_keys.dart';
import '../../../../core/templates/template_catalog_categories.dart';
import '../../data/api/template_provider.dart';
import '../../domain/entities/premium_template.dart';

typedef StoreCatalogQuery = ({
  String query,
  String category,
  bool favoritesOnly,
});

class StoreCatalog {
  const StoreCatalog({
    required this.templates,
    required this.filtered,
    required this.categories,
    required this.category,
  });
  final List<PremiumTemplate> templates, filtered;
  final List<String> categories;
  final String category;
}

/// Auto-disposal bounds search history; immutable result is reused on UI rebuild.
final storeCatalogProvider = Provider.autoDispose
    .family<AsyncValue<StoreCatalog>, StoreCatalogQuery>((ref, request) {
      final keys = ref.watch(catalogFavoriteOrderProvider);
      final rank = {for (var i = 0; i < keys.length; i++) keys[i]: i};
      return ref.watch(templateListProvider).whenData((templates) {
        final categories = [
          '전체',
          ...orderedTemplateTopics(
            templates.map((t) => (t.category ?? '').trim()),
          ),
        ];
        final category = categories.contains(request.category)
            ? request.category
            : '전체';
        final query = request.query.trim().toLowerCase();
        final indexed = templates.indexed.where((entry) {
          final t = entry.$2;
          if (request.favoritesOnly &&
              !rank.containsKey(CatalogFavoriteKeys.template(t.id)))
            return false;
          if (category != '전체' && (t.category ?? '').trim() != category)
            return false;
          return query.isEmpty ||
              [
                t.title,
                t.subTitle ?? '',
                t.description ?? '',
                (t.category ?? '').trim(),
                (t.tags ?? const <String>[]).join(' '),
              ].join(' ').toLowerCase().contains(query);
        }).toList();
        indexed.sort((a, b) {
          final order =
              (rank[CatalogFavoriteKeys.template(a.$2.id)] ?? keys.length)
                  .compareTo(
                    rank[CatalogFavoriteKeys.template(b.$2.id)] ?? keys.length,
                  );
          return order == 0 ? a.$1.compareTo(b.$1) : order;
        });
        return StoreCatalog(
          templates: templates,
          filtered: List.unmodifiable(indexed.map((e) => e.$2)),
          categories: List.unmodifiable(categories),
          category: category,
        );
      });
    }, dependencies: [catalogFavoriteOrderProvider, templateListProvider]);
