import 'studio_decoration_catalog.dart';
import 'template_document_pages.dart';
import 'template_visual_material_inventory.dart';

const freeTemplateMaterialPolicyRevision = 'free-materials-2026-10-07';

/// Deliberate free starter kit. A missing price is not a free classification.
/// These keys must remain 0P; changing a tier requires a new material identity.
const freeTemplateMaterialProductKeys = {
  'frame:studioArch',
  'frame:studioCapsule',
  'frame:studioDeckle',
  'frame:studioDoubleMat',
  'frame:studioFilm',
  'frame:studioGallery',
  'frame:studioInstant',
  'frame:studioOval',
  'frame:studioOvalMat',
  'frame:studioPhotoCorners',
  'frame:studioPostage',
  'frame:studioPostcard',
  'frame:studioRounded',
  'frame:studioScallop',
  'frame:studioSticker',
  'frame:studioTicket',
  'frame:studioWave',
  'frame:studyArchWindow',
  'frame:studyFloatMount',
  'frame:studyNotchedMat',
  'sticker:studioBlushPaper',
  'sticker:studioBotanicalStamp',
  'sticker:studioCottonRag',
  'sticker:studioPressedCosmos',
  'sticker:studioSageRibbon',
  'sticker:studioWashiIndigo',
  'sticker:studioWashiRose',
  'sticker:studioWashiSage',
  'sticker:materialBlindEmboss',
  'sticker:materialVellumBand',
  'sticker:materialTransitPunch',
  'sticker:materialIndexTabs',
  'sticker:materialScallopNote',
  'sticker:materialCrossStitchBand',
  'sticker:materialWalkLedger',
  'sticker:atelierTitlePlate',
  'sticker:atelierPostalBand',
  'sticker:atelierGridLeaf',
  'sticker:atelierColorSlips',
  'sticker:atelierCornerBrackets',
};

// Free collection artwork that is not sold as an independent shop product.
// Exact paths, not directory prefixes, keep new paid artwork out by default.
const freeTemplateArtworkPaths = {
  'asset:assets/templates/premium_wind_atlas/coast_watercolor.png',
  'asset:assets/templates/premium_wind_atlas/lemon_botanical.png',
  'asset:assets/templates/prose_study/woodcut_endpaper.png',
  'asset:assets/templates/prose_study/woodcut_ink.png',
};

/// Publication validation, not an ownership grant. Saved customer albums are
/// never rewritten or reclassified by this rule.
Set<String> freeTemplateMaterialIssues(Map<String, dynamic> document) {
  final issues = <String>{
    ...templateVisualMaterialKeys(
      document,
    ).difference(freeTemplateMaterialProductKeys),
  };
  final byValue = {
    for (final spec in studioDecorations) spec.insertionValue: spec,
  };
  final byId = {for (final spec in studioDecorations) spec.id: spec};
  void inspect(Map<String, dynamic> data) {
    for (final page in templateDocumentPages(data)) {
      for (final layer
          in (page['layers'] as List? ?? const []).whereType<Map>()) {
        final type = layer['type']?.toString().toLowerCase();
        final image = layer['imageUrl']?.toString();
        final background = layer['imageBackground'];
        final style = background ?? layer['style'];
        // A sold decoration must not be disguised as an ordinary photo slot.
        final material = byValue[image] ?? byId[style];
        if (material != null) {
          final key = 'sticker:${material.id}';
          if (!freeTemplateMaterialProductKeys.contains(key)) issues.add(key);
        } else if (type == 'sticker' || type == 'decoration') {
          if (image != null && !freeTemplateArtworkPaths.contains(image)) {
            issues.add('unreviewed-artwork:$image');
          }
          if (style != null &&
              style is! Map &&
              !photoCoverShadeStyles.contains(style)) {
            issues.add('unreviewed-decoration:$style');
          }
        }
        if (type == 'image') {
          final frame = background ?? layer['frame'];
          if (frame != null &&
              frame != '' &&
              frame != 'none' &&
              !freeTemplateMaterialProductKeys.contains('frame:$frame')) {
            issues.add('frame:$frame');
          }
        }
        final fill = layer['textFillImageUrl'];
        if (fill != null && !freeTemplateArtworkPaths.contains(fill)) {
          issues.add('unreviewed-text-fill:$fill');
        }
        final wordArt = layer['wordArtId'];
        if (wordArt != null &&
            !freeTemplateMaterialProductKeys.contains(
              'phrase:collage-$wordArt',
            )) {
          issues.add('phrase:collage-$wordArt');
        }
      }
    }
    final variants = data['variants'];
    if (variants is Map) {
      for (final variant in variants.values.whereType<Map>()) {
        inspect(Map<String, dynamic>.from(variant));
      }
    }
  }

  inspect(document);
  return Set.unmodifiable(issues);
}

void validateFreeTemplateMaterials(Map<String, dynamic> document) {
  final issues = freeTemplateMaterialIssues(document);
  if (issues.isNotEmpty) {
    throw StateError(
      'free_template_material_policy:${document['id']}: '
      '${issues.join(', ')}',
    );
  }
}
