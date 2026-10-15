import 'dart:convert';
import '../../../core/templates/authored_collections.dart';
import '../../../core/templates/published_premium_templates.dart';
import '../../../core/templates/template_document_pages.dart';
import '../../store/domain/entities/premium_template.dart';

String Function() _lazyDocument(Map<String, dynamic> Function() build) {
  String? cached;
  return () => cached ??= jsonEncode(build());
}

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
      documentBuilder: _lazyDocument(authoredCollections[i].catalogDocument),
    ),
]);

final publishedPremiumTemplates = List<PremiumTemplate>.unmodifiable([
  for (final entry in premiumVolumeCatalogIds.entries)
    PremiumTemplate(
      id: entry.value,
      title: entry.key.title,
      subTitle: '내지 ${entry.key.pageCounts.join('·')}쪽 · 세 가지 규격',
      description: '사진과 기록을 한 권으로 엮는 ${entry.key.category} 컬렉션',
      category: entry.key.category,
      coverImageUrl: '',
      previewImages: const [],
      pageCount: entry.key.extendedPages,
      userCount: 0,
      isNew: true,
      isPremium: true,
      tags: const ['SnapFit Original', '프리미엄 컬렉션'],
      documentBuilder: _lazyDocument(() => premiumCatalogDocument(entry.key)),
    ),
  for (final entry in conceptVolumeCatalogIds.entries)
    PremiumTemplate(
      id: entry.value,
      title: entry.key.title,
      subTitle: entry.key.concept,
      description: '${entry.key.concept} · 내지 24쪽 · 세 가지 규격',
      category: entry.key.category,
      coverImageUrl: '',
      previewImages: const [],
      pageCount: 24,
      userCount: 0,
      isNew: true,
      isPremium: true,
      tags: const ['SnapFit Original', '컨셉 에디션'],
      documentBuilder: _lazyDocument(() => conceptCatalogDocument(entry.key)),
    ),
]);

final publishedCreationTemplates = List<PremiumTemplate>.unmodifiable([
  ...bundledCreationTemplates,
  ...publishedPremiumTemplates,
]);

bool isBundledCreationTemplate(PremiumTemplate template) =>
    isPublishedCreationTemplate(template) ||
    retiredAuthoredCollections.any((local) => local.bundledId == template.id);

bool isPublishedCreationTemplate(PremiumTemplate template) =>
    publishedCreationTemplates.any((local) => local.id == template.id);

final _publishedPhotoCounts = <int, int>{};

int? publishedTemplatePhotoCount(PremiumTemplate template) {
  final canonical = publishedCreationTemplates
      .where((item) => item.id == template.id)
      .firstOrNull;
  if (canonical == null) return null;
  return _publishedPhotoCounts.putIfAbsent(
    template.id,
    () =>
        templateDocumentPages(
          jsonDecode(canonical.templateJson!) as Map<String, dynamic>,
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
  );
}

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
  publishedCreationTemplates.map((published) {
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
