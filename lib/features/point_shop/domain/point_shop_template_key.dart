import '../../../core/templates/authored_collections.dart';
import '../../store/domain/entities/premium_template.dart';

/// Authored designs keep one product identity across the store, creation flow,
/// editor and every aspect ratio. The negative catalog ID is a presentation ID.
String pointShopAuthoredTemplateKey(AuthoredCollection collection) =>
    'template:${collection.id}';

String pointShopTemplateKey(PremiumTemplate template) {
  for (final collection in [
    ...authoredCollections,
    ...retiredAuthoredCollections,
  ]) {
    if (collection.bundledId == template.id) {
      return pointShopAuthoredTemplateKey(collection);
    }
  }
  return 'template:server-${template.id}';
}
