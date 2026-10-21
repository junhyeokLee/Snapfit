import '../../../core/templates/authored_collections.dart';
import '../../../core/templates/published_premium_templates.dart';
import 'point_shop_product.dart';
import 'point_shop_catalog_release.dart';

/// Owner delegated launch pricing; server activation remains independent.
/// Opening management or registering a draft never changes a purchase quote.
const premiumVolumeLaunchPointPrice = 2500;
const conceptVolumeLaunchPointPrice = 1800;
const atelierEditionProposedPointPrice = 2800;

final pendingStudioEditionProducts = List<PointShopProduct>.unmodifiable([
  for (final edition in StudioEdition.values.where((e) => e.premium))
    PointShopProduct(
      productKey: edition.productKey,
      kind: 'template',
      assetId: edition.id,
      title: edition.title,
      pointPrice: null,
      isActive: false,
    ),
]);

final pendingAtelierEditionProducts = List<PointShopProduct>.unmodifiable([
  for (final edition in AtelierEdition.values)
    PointShopProduct(
      productKey: edition.productKey,
      kind: 'template',
      assetId: edition.id,
      title: edition.title,
      pointPrice: null,
      isActive: false,
    ),
]);

String premiumVolumeProductKey(PremiumVolume volume) => 'template:${volume.id}';

PremiumVolume? pendingPremiumVolumeForKey(String productKey) => PremiumVolume
    .values
    .where((volume) => premiumVolumeProductKey(volume) == productKey)
    .firstOrNull;

final pendingPremiumVolumeProducts = List<PointShopProduct>.unmodifiable([
  for (final volume in PremiumVolume.values)
    PointShopProduct(
      productKey: premiumVolumeProductKey(volume),
      kind: 'template',
      assetId: volume.id,
      title: volume.title,
      pointPrice: null,
      isActive: false,
    ),
]);

ConceptVolume? pendingConceptVolumeForKey(String productKey) => ConceptVolume
    .values
    .where((volume) => 'template:${volume.id}' == productKey)
    .firstOrNull;

final pendingConceptVolumeProducts = List<PointShopProduct>.unmodifiable([
  for (final volume in ConceptVolume.values)
    PointShopProduct(
      productKey: 'template:${volume.id}',
      kind: 'template',
      assetId: volume.id,
      title: volume.title,
      pointPrice: null,
      isActive: false,
    ),
]);

bool isPendingTemplateProduct(String key) =>
    !ownerApprovedCatalogProductKeys.contains(key) &&
    (StudioEdition.values.any((e) => e.premium && e.productKey == key) ||
        AtelierEdition.values.any((e) => e.productKey == key) ||
        (pendingPremiumVolumeForKey(key) != null ||
                pendingConceptVolumeForKey(key) != null) &&
            ![
              ...premiumVolumeCatalogIds.values,
              ...conceptVolumeCatalogIds.values,
            ].any((id) => publishedPremiumProductKey(id) == key));

String? pendingTemplateContentsLabel(String key) {
  if (AtelierEdition.values.any((e) => e.productKey == key) ||
      StudioEdition.values.any((e) => e.premium && e.productKey == key)) {
    return '내지 32쪽 · 표지 별도 · 세로·정사각·가로'
        '${isPendingTemplateProduct(key) ? ' · 디자인 검수 중' : ''}';
  }
  final volume = pendingPremiumVolumeForKey(key);
  if (volume != null) return premiumVolumeContentsLabel(volume);
  if (pendingConceptVolumeForKey(key) != null) {
    return '내지 24쪽 · 표지 별도 · 세로·정사각·가로';
  }
  return null;
}

String premiumVolumeContentsLabel(PremiumVolume volume) =>
    '내지 ${volume.pageCounts.join('·')}쪽 · 표지 별도 · 세로·정사각·가로';
