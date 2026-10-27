import 'authored_collections.dart';

/// Stable catalog identities. Never derive these IDs from enum ordering.
const premiumVolumeCatalogIds = {
  PremiumVolume.wedding: -9501,
  PremiumVolume.travel: -9502,
  PremiumVolume.daily: -9503,
  PremiumVolume.baby: -9504,
  PremiumVolume.family: -9505,
  PremiumVolume.couple: -9506,
  PremiumVolume.pet: -9507,
};

const conceptVolumeCatalogIds = {
  ConceptVolume.silkVows: -9511,
  ConceptVolume.shoreDays: -9512,
  ConceptVolume.readingRoom: -9513,
  ConceptVolume.firstWardrobe: -9514,
  ConceptVolume.sundayPicnic: -9515,
  ConceptVolume.sharedSeasons: -9516,
  ConceptVolume.littleCompanion: -9517,
};

final atelierEditionCatalogIds = {
  for (final edition in AtelierEdition.values) edition: edition.catalogId,
};

// Metadata only: indexing must never evaluate a template's lazy document.
// These IDs are fixed and unique across the published catalog.
final _premiumProductKeys = <int, String>{
  for (final edition in storyEditions.where((e) => e.isPremium))
    edition.catalogId: edition.productKey,
  for (final edition in StudioEdition.values.where((e) => e.premium))
    edition.catalogId: edition.productKey,
  for (final edition in AtelierEdition.values)
    edition.catalogId: edition.productKey,
  for (final entry in premiumVolumeCatalogIds.entries)
    entry.value: 'template:${entry.key.id}',
  for (final entry in conceptVolumeCatalogIds.entries)
    entry.value: 'template:${entry.key.id}',
};

String? publishedPremiumProductKey(int catalogId) =>
    _premiumProductKeys[catalogId];

PremiumVolume? publishedPremiumVolume(int catalogId) => premiumVolumeCatalogIds
    .entries
    .where((entry) => entry.value == catalogId)
    .firstOrNull
    ?.key;

Map<String, dynamic> premiumCatalogDocument(
  PremiumVolume volume, {
  int? innerPages,
}) => {
  ...refinePaidCatalogDocument(
    volume.id,
    CollectionAspect.square,
    volume.document(CollectionAspect.square, innerPages: innerPages),
  ),
  'variants': {
    for (final aspect in CollectionAspect.printable)
      aspect.name: refinePaidCatalogDocument(
        volume.id,
        aspect,
        volume.document(aspect, innerPages: innerPages),
      ),
  },
};

Map<String, dynamic> conceptCatalogDocument(ConceptVolume volume) => {
  ...refinePaidCatalogDocument(
    volume.id,
    CollectionAspect.square,
    volume.document(CollectionAspect.square),
  ),
  'variants': {
    for (final aspect in CollectionAspect.printable)
      aspect.name: refinePaidCatalogDocument(
        volume.id,
        aspect,
        volume.document(aspect),
      ),
  },
};
