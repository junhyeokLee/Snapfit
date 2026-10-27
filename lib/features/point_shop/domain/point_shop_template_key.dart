import '../../../core/templates/authored_collections.dart';
import '../../../core/templates/published_premium_templates.dart';
import '../../store/domain/entities/premium_template.dart';

/// Authored designs keep one product identity across the store, creation flow,
/// editor and every aspect ratio. The negative catalog ID is a presentation ID.
String pointShopAuthoredTemplateKey(AuthoredCollection collection) =>
    'template:${collection.id}';

final _freeStoryProductKeys = <int, String>{
  for (final edition in storyEditions.where((e) => !e.isPremium))
    edition.catalogId: edition.productKey,
};

final _authoredProductKeys = <int, String>{
  for (final collection in retiredAuthoredCollections)
    collection.bundledId: pointShopAuthoredTemplateKey(collection),
  for (final collection in authoredCollections)
    collection.bundledId: pointShopAuthoredTemplateKey(collection),
};

// A bounded index of fixed IDs avoids repeated scans/temporary lists during
// filtering and tile builds. Arbitrary server IDs are never added to the cache.
String pointShopTemplateKey(PremiumTemplate template) =>
    _freeStoryProductKeys[template.id] ??
    publishedPremiumProductKey(template.id) ??
    _authoredProductKeys[template.id] ??
    'template:server-${template.id}';
