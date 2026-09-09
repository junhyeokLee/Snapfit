import '../../../core/templates/authored_collections.dart';
import '../../../core/templates/studio_decoration_catalog.dart';
import '../../../core/templates/studio_phrase_catalog.dart';
import '../../../core/templates/studio_word_art_catalog.dart';
import '../../../shared/widgets/image_frame_style_picker.dart';
import 'point_shop_product.dart';
import 'point_shop_template_key.dart';
import 'premium_volume_registration.dart';

/// Public assets and explicitly registered drafts available to administrators.
/// Opening this list never persists prices or publishes candidate artwork.
final pointShopKnownProducts = List<PointShopProduct>.unmodifiable([
  for (final collection in authoredCollections)
    PointShopProduct(
      productKey: pointShopAuthoredTemplateKey(collection),
      kind: 'template',
      assetId: collection.id,
      title: collection.title,
      pointPrice: null,
      isActive: false,
    ),
  ...pendingPremiumVolumeProducts,
  ...pendingConceptVolumeProducts,
  for (final decoration in studioDecorations)
    PointShopProduct(
      productKey: 'sticker:${decoration.id}',
      kind: 'sticker',
      assetId: decoration.id,
      title: decoration.label,
      pointPrice: null,
      isActive: false,
    ),
  for (final phrase in studioPhrases)
    PointShopProduct(
      productKey: 'phrase:${phrase.id}',
      kind: 'phrase',
      assetId: phrase.id,
      title: phrase.text.replaceAll('\n', ' '),
      pointPrice: null,
      isActive: false,
    ),
  for (final frame in imageFrameStyles.where((frame) => frame.key.isNotEmpty))
    PointShopProduct(
      productKey: 'frame:${frame.key}',
      kind: 'frame',
      assetId: frame.key,
      title: frame.label,
      pointPrice: null,
      isActive: false,
    ),
  for (final art in studioWordArts)
    PointShopProduct(
      productKey: art.productKey,
      kind: 'phrase',
      assetId: 'collage-${art.id}',
      title: art.label,
      pointPrice: null,
      isActive: false,
    ),
]);
