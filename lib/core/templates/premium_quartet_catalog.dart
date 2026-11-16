part of 'story_edition_catalog.dart';

const premiumQuartetRevision = '2026-11-03-premium-quartets-32p';

/// Small metadata only. Books and bitmaps are materialized one at a time.
class PremiumQuartetSpec {
  const PremiumQuartetSpec({
    required this.id,
    required this.title,
    required this.category,
    required this.style,
    required this.motifCode,
    required this.ink,
    required this.tint,
    required this.accent,
    required this.paperAccent,
    required this.paperKinds,
    required this.headline,
    required this.tagline,
    required this.font,
    required this.secondaryFont,
    required this.cards,
    required this.phrase2,
  });
  final String id, title, category, motifCode, ink, tint, accent, paperAccent;
  final String headline, tagline, font, secondaryFont, phrase2;
  final int style;
  final List<int> paperKinds;
  final List<List<String>> cards;
}

PremiumQuartetSpec? premiumQuartetSpecForMaterial(String id) {
  for (final suffix in const [
    '-paper',
    '-vellum',
    '-motif',
    '-keepsake',
    '-caption',
  ]) {
    if (id.endsWith(suffix)) {
      final result =
          premiumQuartetSpecsById[id.substring(0, id.length - suffix.length)];
      if (result != null) return result;
    }
  }
  return premiumQuartetSpecsById[id];
}

StoryEdition? storyEditionForMaterial(String id) =>
    storyMaterialsById[id] ??
    storyEditionsById[id] ??
    storyEditionsById[premiumQuartetSpecForMaterial(id)?.id];
