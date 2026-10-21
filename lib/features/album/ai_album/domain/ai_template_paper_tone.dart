import 'package:flutter/material.dart';

import 'ai_album_models.dart';
import 'ai_template_art_direction.dart';

enum AiTemplatePaperTone { original, warm, cool }

/// Adjusts only the light paper-background role. Artwork colors, text,
/// photo slots and geometry retain their original values.
AiTemplateDesign withAiTemplatePaperTone(
  AiTemplateDesign original,
  AiTemplatePaperTone tone, {
  AiTemplateDesign? current,
}) {
  if (tone == AiTemplatePaperTone.original) {
    if (current == null || identical(current, original)) return original;
    return copyAiTemplateDesign(
      current,
      pages: [
        for (final (index, page) in current.pages.indexed)
          AiTemplateDesignPage(
            background: original.pages[index].background,
            purpose: page.purpose,
            elements: page.elements,
          ),
      ],
      artDirection: original.artDirection,
    );
  }
  final elementColors = original.pages
      .expand((page) => page.elements)
      .map((element) => element.color.toARGB32())
      .toSet();
  final direction = original.artDirection;
  String hex(Color color) =>
      '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  List<String>? paletteFor(Map<int, Color> changes) {
    if (direction == null) return const [];
    final palette = <String>[];
    for (final originalHex in direction.palette) {
      final color = int.parse('FF${originalHex.substring(1)}', radix: 16);
      final replacement = changes[color];
      // A shared color still belongs to its photo/text/decoration role.
      // Only an exclusive background role can replace the original entry.
      palette.add(
        replacement != null && !elementColors.contains(color)
            ? hex(replacement)
            : originalHex,
      );
    }
    final normalized = palette.map((entry) => entry.toUpperCase()).toSet();
    if (normalized.length != palette.length) return null;
    for (final color in changes.values) {
      final changedHex = hex(color);
      if (normalized.add(changedHex)) palette.add(changedHex);
    }
    return palette.length <= 6 ? palette : null;
  }

  final replacements = <int, Color>{};
  final considered = <int>{};
  for (final page in original.pages) {
    final color = page.background;
    if (!considered.add(color.toARGB32())) continue;
    final hsv = HSVColor.fromColor(color);
    if (hsv.value < .9 || hsv.saturation > .14) continue;
    final replacement = HSVColor.fromAHSV(
      1,
      tone == AiTemplatePaperTone.warm ? 42 : 205,
      tone == AiTemplatePaperTone.warm ? .055 : .035,
      hsv.value,
    ).toColor();
    if (replacement == color) continue;
    bool readable(AiTemplateDesignPage candidate) => candidate.elements
        .where((element) => element.kind == 'text')
        .every((element) {
          final previous = _contrast(element.color, color);
          final next = _contrast(element.color, replacement);
          final required =
              element.fontSize >= 24 ||
                  (element.fontSize >= 18.66 && element.weight >= 700)
              ? 3.0
              : 4.5;
          return next >= (previous < required ? previous : required);
        });
    if (original.pages
        .where((candidate) => candidate.background == color)
        .every(readable)) {
      final candidate = {...replacements, color.toARGB32(): replacement};
      if (paletteFor(candidate) != null) {
        replacements[color.toARGB32()] = replacement;
      }
    }
  }
  if (replacements.isEmpty) return current ?? original;
  final palette = paletteFor(replacements);
  return copyAiTemplateDesign(
    current ?? original,
    pages: original.pages.indexed
        .map((entry) {
          final (index, page) = entry;
          return AiTemplateDesignPage(
            background:
                replacements[page.background.toARGB32()] ?? page.background,
            purpose: page.purpose,
            elements: (current ?? original).pages[index].elements,
          );
        })
        .toList(growable: false),
    artDirection: direction == null
        ? null
        : AiTemplateArtDirection(
            concept: direction.concept,
            rationale: direction.rationale,
            requirements: direction.requirements,
            palette: palette!,
            typography: direction.typography,
            pages: direction.pages,
          ),
  );
}

AiTemplateDesign copyAiTemplateDesign(
  AiTemplateDesign original, {
  required List<AiTemplateDesignPage> pages,
  AiTemplateArtDirection? artDirection,
}) => AiTemplateDesign(
  concept: original.concept,
  rationale: original.rationale,
  aspect: original.aspect,
  pages: pages,
  artDirection: artDirection ?? original.artDirection,
  printProduct: original.printProduct,
  layoutExpansion: original.layoutExpansion,
  version: original.version,
  compositionPlan: original.compositionPlan,
);

AlbumRecommendationDraft withAiTemplateDesign(
  AlbumRecommendationDraft draft,
  AiTemplateDesign design,
) => AlbumRecommendationDraft(
  design: design,
  draftId: draft.draftId,
  theme: draft.theme,
  title: draft.title,
  pageCount: draft.pageCount,
  templateTone: draft.templateTone,
  recommendedPhotos: draft.recommendedPhotos,
  excludedPhotos: draft.excludedPhotos,
  storySections: draft.storySections,
  summary: draft.summary,
  templateSlots: draft.templateSlots,
  curationNotes: draft.curationNotes,
  requiresUserReview: draft.requiresUserReview,
  alreadyCreatedAlbum: draft.alreadyCreatedAlbum,
  reviewCtaLabel: draft.reviewCtaLabel,
);

double _contrast(Color first, Color second) {
  final a = first.computeLuminance(), b = second.computeLuminance();
  return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
}
