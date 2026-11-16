import '../../point_shop/domain/point_shop_product.dart';
import '../../point_shop/domain/point_shop_template_key.dart';
import '../../store/domain/entities/premium_template.dart';
import '../../store/domain/store_product_discovery.dart';
import '../../store/domain/store_template_recommendations.dart';

/// Selects metadata only; artwork and account ownership do not affect discovery.
List<PremiumTemplate> selectCreationCatalog({
  required Iterable<PremiumTemplate> templates,
  required String category,
  required String price,
  required String query,
  required bool favoritesOnly,
  required Set<int> favoriteIds,
  required Map<String, PointShopProduct> products,
  required Map<String, StoreProductDiscovery> discovery,
  required DateTime now,
  Set<int> featuredIds = const {},
}) {
  final normalizedQuery = query.trim().toLowerCase();

  bool? isPaid(PremiumTemplate template) {
    final product = products[pointShopTemplateKey(template)];
    if (product == null) return template.isPremium;
    final pointPrice = product.pointPrice;
    // An existing unavailable product cannot inherit a confirmed metadata price.
    if (!product.isActive || pointPrice == null || pointPrice < 0) return null;
    return pointPrice > 0;
  }

  final candidates = templates.where((template) {
    if (category != '전체' &&
        category != storeRecommendedCategory &&
        category != '인기' &&
        template.category?.trim() != category) {
      return false;
    }
    if (favoritesOnly && !favoriteIds.contains(template.id)) return false;
    if (normalizedQuery.isNotEmpty &&
        ![
          template.title,
          template.category ?? '',
          ...?template.tags,
        ].join(' ').toLowerCase().contains(normalizedQuery)) {
      return false;
    }
    final paid = isPaid(template);
    if (price == '무료' && paid != false) return false;
    if (price == '유료' && paid != true) return false;
    if (category == storeRecommendedCategory) {
      // Unlisted premium remains readable in paid browsing, never recommended.
      final product = products[pointShopTemplateKey(template)];
      if (paid == null || (product == null && template.isPremium)) return false;
    }
    return true;
  }).toList();

  if (category == storeRecommendedCategory) {
    return recommendStoreTemplates(
      candidates,
      isPaid: (template) => isPaid(template) == true,
      featuredIds: featuredIds,
      favoriteIds: favoriteIds,
    );
  }
  return sortStoreProducts(
    candidates,
    productKey: pointShopTemplateKey,
    discovery: discovery,
    now: now,
    popularityFirst: category == '인기',
  );
}
