import '../../../core/templates/authored_collections.dart';
import 'point_shop_product.dart';

/// Owner delegated launch pricing; server activation remains independent.
/// Opening management or registering a draft never changes a purchase quote.
const premiumVolumeLaunchPointPrice = 2500;
const conceptVolumeLaunchPointPrice = 1800;

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
    pendingPremiumVolumeForKey(key) != null ||
    pendingConceptVolumeForKey(key) != null;

String? pendingTemplateContentsLabel(String key) {
  final volume = pendingPremiumVolumeForKey(key);
  if (volume != null) return premiumVolumeContentsLabel(volume);
  if (pendingConceptVolumeForKey(key) != null) {
    return '내지 24쪽 · 표지 별도 · 세로·정사각·가로';
  }
  return null;
}

String premiumVolumeContentsLabel(PremiumVolume volume) =>
    '내지 ${volume.pageCounts.join('·')}쪽 · 표지 별도 · 세로·정사각·가로';
