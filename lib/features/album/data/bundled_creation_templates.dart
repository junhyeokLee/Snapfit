import 'dart:convert';
import '../../../core/cache/memory_pressure_caches.dart';
import '../../../core/templates/authored_collections.dart';
import '../../../core/templates/published_premium_templates.dart';
import '../../../core/templates/template_document_pages.dart';
import '../../store/domain/entities/premium_template.dart';

String Function() _lazyDocument(Map<String, dynamic> Function() build) {
  final key = Object();
  return () => _documentFor(key, build);
}

// Published builders live for the entire app session. Keep their full books in
// one bounded LRU instead of retaining every opened book inside its closure.
const _maxDocumentEntries = 4;
const _maxDocumentCharacters = 2 * 1024 * 1024;
final _documents = <Object, String>{};
int _documentCharacters = 0;

void clearBundledTemplateDocumentCache() {
  _documents.clear();
  _documentCharacters = 0;
}

String _documentFor(Object key, Map<String, dynamic> Function() build) {
  MemoryPressureCaches.register(
    'template-documents',
    clearBundledTemplateDocumentCache,
  );
  final cached = _documents.remove(key);
  if (cached != null) {
    _documents[key] = cached;
    return cached;
  }
  final source = jsonEncode(build());
  if (source.length <= _maxDocumentCharacters) {
    _documents[key] = source;
    _documentCharacters += source.length;
    while (_documents.length > _maxDocumentEntries ||
        _documentCharacters > _maxDocumentCharacters) {
      final oldest = _documents.keys.first;
      _documentCharacters -= _documents.remove(oldest)!.length;
    }
  }
  return source;
}

/// Negative IDs identify published artwork bundled with the app.
/// Point-shop configuration determines its price independently.
final bundledCreationTemplates = List<PremiumTemplate>.unmodifiable([
  for (var i = 0; i < authoredCollections.length; i++)
    PremiumTemplate(
      id: authoredCollections[i].bundledId,
      title: authoredCollections[i].catalogTitle,
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
  for (final edition in storyEditions.where((e) => !e.isPremium))
    _storyTemplate(edition),
]);

final publishedPremiumTemplates = List<PremiumTemplate>.unmodifiable([
  for (final entry in premiumVolumeCatalogIds.entries)
    PremiumTemplate(
      id: entry.value,
      title: entry.key.title,
      subTitle: '내지 ${entry.key.pageCounts.join('·')}쪽 · 인쇄 5가지 크기',
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
      description: '${entry.key.concept} · 내지 24쪽 · 인쇄 5가지 크기',
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
  for (final edition in AtelierEdition.values)
    PremiumTemplate(
      id: edition.catalogId,
      title: edition.title,
      subTitle: edition.concept,
      description: '${edition.concept} · 내지 32쪽 · 인쇄 5가지 크기',
      category: edition.category,
      coverImageUrl: '',
      previewImages: const [],
      pageCount: edition.innerPageCount,
      userCount: 0,
      isNew: true,
      isPremium: true,
      tags: const ['SnapFit Original', '아틀리에 에디션', '내지 32쪽'],
      documentBuilder: _lazyDocument(edition.catalogDocument),
    ),
  for (final edition in StudioEdition.values.where((e) => e.premium))
    PremiumTemplate(
      id: edition.catalogId,
      title: edition.title,
      category: edition.category,
      subTitle: edition.subtitle,
      description: '내지 32쪽 · 인쇄 5가지 크기 · 사진과 문구를 개별 편집하는 신규 유료 시안',
      coverImageUrl: '',
      previewImages: const [],
      pageCount: edition.innerPageCount,
      userCount: 0,
      isNew: true,
      isPremium: true,
      tags: const ['SnapFit Original', '스튜디오 에디션', '내지 32쪽'],
      documentBuilder: _lazyDocument(edition.catalogDocument),
    ),
  for (final edition in storyEditions.where((e) => e.isPremium))
    _storyTemplate(edition),
]);

PremiumTemplate _storyTemplate(StoryEdition edition) => PremiumTemplate(
  id: edition.catalogId,
  title: edition.title,
  category: edition.category,
  subTitle: edition.subtitle,
  description: '${edition.subtitle} · 내지 24쪽 · 인쇄 5가지 크기 · 전용 소재 3종',
  coverImageUrl: '',
  previewImages: const [],
  pageCount: StoryEdition.innerPageCount,
  userCount: 0,
  isNew: true,
  isPremium: edition.isPremium,
  tags: [
    'SnapFit Original',
    '스토리 에디션',
    edition.category,
    ...edition.discoveryTags,
  ],
  documentBuilder: _lazyDocument(() => storyEditionCatalogDocument(edition)),
);

final publishedCreationTemplates = List<PremiumTemplate>.unmodifiable([
  ...bundledCreationTemplates,
  ...publishedPremiumTemplates,
]);

// Shares existing catalog objects; no document or preview is materialized.
final _publishedCreationTemplatesById = {
  for (final template in publishedCreationTemplates) template.id: template,
};
final _retiredAuthoredIds = {
  for (final collection in retiredAuthoredCollections) collection.bundledId,
};

PremiumTemplate? publishedCreationTemplateById(int id) =>
    _publishedCreationTemplatesById[id];

bool isBundledCreationTemplate(PremiumTemplate template) =>
    isPublishedCreationTemplate(template) ||
    _retiredAuthoredIds.contains(template.id);

bool isPublishedCreationTemplate(PremiumTemplate template) =>
    _publishedCreationTemplatesById.containsKey(template.id);

final _publishedPhotoCounts = <int, int>{};

int? publishedTemplatePhotoCount(PremiumTemplate template) {
  final canonical = publishedCreationTemplateById(template.id);
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
  if (_retiredAuthoredIds.contains(template.id)) return true;
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
) {
  // Preserve the first matching row, including for legacy duplicate inputs.
  final byId = <int, PremiumTemplate>{};
  for (final item in catalog) {
    if (_publishedCreationTemplatesById.containsKey(item.id)) {
      byId.putIfAbsent(item.id, () => item);
    }
  }
  return List<PremiumTemplate>.unmodifiable(
    publishedCreationTemplates.map((published) {
      // Only local favorite state may vary. Catalog refreshes cannot replace
      // artwork, pricing, IDs, or membership in the published collection.
      final match = byId[published.id];
      if (match == null ||
          (match.isLiked == published.isLiked &&
              match.likeCount == published.likeCount)) {
        return published;
      }
      return published.copyWith(
        isLiked: match.isLiked,
        likeCount: match.likeCount,
      );
    }),
  );
}
