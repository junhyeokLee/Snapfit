import '../../point_shop/domain/point_shop_template_key.dart';
import '../../store/data/api/template_provider.dart';
import '../../store/domain/entities/premium_template.dart';
import '../domain/social_models.dart';

/// Resolve by stable product identity, never by display title or a guessed ID.
/// A withdrawn design cannot reappear through an old public work.
PremiumTemplate? socialSourceCatalogTemplate(
  SocialTemplateSource? source,
  Iterable<PremiumTemplate> catalog,
) {
  if (source == null) return null;
  for (final template in catalog) {
    if (!isRetiredStoreTemplate(template) &&
        pointShopTemplateKey(template) == source.productKey) {
      return template;
    }
  }
  return null;
}
