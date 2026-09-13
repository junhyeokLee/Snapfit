import 'dart:convert';
import '../../../core/templates/authored_collections.dart';
import '../../../core/templates/template_document_pages.dart';
import '../../store/domain/entities/premium_template.dart';

/// Negative IDs identify published artwork bundled with the app.
/// Point-shop configuration determines its price independently.
final bundledCreationTemplates = List<PremiumTemplate>.unmodifiable([
  for (var i = 0; i < authoredCollections.length; i++)
    PremiumTemplate(
      id: authoredCollections[i].bundledId,
      title: authoredCollections[i].title,
      subTitle: authoredCollections[i].subtitle,
      description: authoredCollections[i].subtitle,
      category: authoredCollections[i].category,
      coverImageUrl: '',
      previewImages: const [],
      pageCount: authoredCollections[i].innerPageCount,
      userCount: 0,
      isNew: true,
      isPremium: false,
      tags: ['SnapFit Original', '직접 디자인', ...authoredCollections[i].styleTags],
      templateJson: jsonEncode(authoredCollections[i].catalogDocument()),
    ),
]);

bool isBundledCreationTemplate(PremiumTemplate template) =>
    isPublishedCreationTemplate(template) ||
    retiredAuthoredCollections.any((local) => local.bundledId == template.id);

bool isPublishedCreationTemplate(PremiumTemplate template) =>
    bundledCreationTemplates.any((local) => local.id == template.id);

final _publishedPhotoCounts = {
  for (final template in bundledCreationTemplates)
    template.id:
        templateDocumentPages(
          jsonDecode(template.templateJson!) as Map<String, dynamic>,
        ).fold<int>(
          0,
          (count, page) =>
              count +
              (page['layers'] as List)
                  .where(
                    (layer) =>
                        layer['type'].toString().toLowerCase() == 'image',
                  )
                  .length,
        ),
};

int? publishedTemplatePhotoCount(PremiumTemplate template) =>
    _publishedPhotoCounts[template.id];

bool isRetiredAuthoredTemplate(PremiumTemplate template) {
  if (retiredAuthoredCollections.any((c) => c.bundledId == template.id))
    return true;
  final raw = template.templateJson;
  if (raw == null) return false;
  try {
    final document = jsonDecode(raw);
    if (document is! Map || document['id'] is! String) return false;
    final id = document['id'] as String;
    return retiredAuthoredCollections.any(
      (c) => CollectionAspect.values.any(
        (a) => id == 'snapfit_original_${c.id}_${a.name}',
      ),
    );
  } on FormatException {
    return false;
  }
}

List<PremiumTemplate> withBundledCreationTemplates(
  List<PremiumTemplate> catalog,
) => List<PremiumTemplate>.unmodifiable(
  bundledCreationTemplates.map((published) {
    // Only local favorite state may vary. Catalog refreshes cannot replace
    // artwork, pricing, IDs, or membership in the published collection.
    final match = catalog.where((item) => item.id == published.id).firstOrNull;
    if (match == null) return published;
    return published.copyWith(
      isLiked: match.isLiked,
      likeCount: match.likeCount,
    );
  }),
);
