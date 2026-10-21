import 'dart:collection';
import 'dart:convert';

import '../../../core/templates/template_document_pages.dart';
import 'entities/premium_template.dart';

/// Describes the editable contents of the supplied document's default edition.
///
/// These are slot counts, not a recommendation to prepare that many unique
/// photographs. Other aspect variants are alternate layouts of the same book
/// and must not be added to these counts.
class TemplateDesignProfile {
  const TemplateDesignProfile._({
    this.photoSlotCount,
    this.innerPhotoSlotCount,
    this.innerPageCount,
    this.photoPageCount,
    this.recordPageCount,
  });

  static const _unknown = TemplateDesignProfile._();
  static const _cacheLimit = 24;
  static final _cache = LinkedHashMap<Object, _CachedDesignProfile>.identity();

  /// Editable picture slots, including the cover. A photo can be reused.
  final int? photoSlotCount;
  final int? innerPhotoSlotCount;
  final int? innerPageCount;
  final int? photoPageCount;

  /// Inner pages with an editable body or an explicit writing field. These
  /// pages can also contain photographs; the two page counts are not a split.
  final int? recordPageCount;

  bool get hasKnownDocument => innerPageCount != null;

  double? get photosPerInnerPage {
    final pages = innerPageCount;
    final photos = innerPhotoSlotCount;
    return pages == null || pages == 0 || photos == null
        ? null
        : photos / pages;
  }

  String get photoLabel =>
      photoSlotCount == null ? '사진 구성 확인 필요' : '사진 $photoSlotCount장 구성';

  String get pageLabel =>
      innerPageCount == null ? '쪽수 확인 필요' : '내지 $innerPageCount쪽';

  String get compositionLabel => !hasKnownDocument
      ? '내지 구성 확인 필요'
      : '사진 넣는 $photoSlotCount곳 · 글쓰기 $recordPageCount쪽';

  String get briefLabel => '$photoLabel · $pageLabel';

  factory TemplateDesignProfile.of(PremiumTemplate template) {
    String? source;
    try {
      source = template.templateJson;
    } on Object {
      // An optional remote builder must not prevent browsing other designs.
      return _unknown;
    }
    if (source == null || source.trim().isEmpty) return _unknown;

    // Favorite copies share their document builder. Raw JSON copies share the
    // string itself. IDs alone cannot identify artwork: a remote template can
    // have the same ID while containing a different document.
    final Object key = template.documentBuilder ?? source;
    final cached = _cache.remove(key);
    if (cached != null && cached.source == source) {
      _cache[key] = cached;
      return cached.profile;
    }

    final profile = _read(source);
    _cache[key] = _CachedDesignProfile(source, profile);
    while (_cache.length > _cacheLimit) {
      _cache.remove(_cache.keys.first);
    }
    return profile;
  }

  static TemplateDesignProfile _read(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) return _unknown;
      final rawPages = decoded['pages'];
      if (rawPages is! List || rawPages.any((page) => page is! Map)) {
        return _unknown;
      }
      final cover = decoded['cover'];
      if (cover != null && cover is! Map) return _unknown;
      if (cover is Map && !_validLayers(cover['layers'])) return _unknown;
      final pages = templateDocumentPages(decoded);
      if (pages.isEmpty || pages.any((page) => !_validLayers(page['layers']))) {
        return _unknown;
      }
      if (!pages.any((page) => (page['layers'] as List).isNotEmpty)) {
        return _unknown;
      }

      var totalPhotos = 0;
      var innerPhotos = 0;
      var photoPages = 0;
      var recordPages = 0;
      for (var index = 0; index < pages.length; index++) {
        final layers = (pages[index]['layers'] as List).cast<Map>();
        final photos = layers.where(_isPhotoSlot).length;
        totalPhotos += photos;
        if (index == 0) continue;
        innerPhotos += photos;
        if (photos > 0) photoPages++;
        if (layers.any(_isRecordField)) recordPages++;
      }
      return TemplateDesignProfile._(
        photoSlotCount: totalPhotos,
        innerPhotoSlotCount: innerPhotos,
        innerPageCount: pages.length - 1,
        photoPageCount: photoPages,
        recordPageCount: recordPages,
      );
    } on FormatException {
      return _unknown;
    } on TypeError {
      return _unknown;
    }
  }

  static bool _validLayers(Object? layers) =>
      layers is List && layers.every((layer) => layer is Map);

  static bool _editable(Map layer) =>
      layer['editable'] != false &&
      layer['locked'] != true &&
      layer['isLocked'] != true;

  static bool _isPhotoSlot(Map layer) =>
      '${layer['type']}'.toLowerCase() == 'image' && _editable(layer);

  static bool _isRecordField(Map layer) {
    if ('${layer['type']}'.toLowerCase() != 'text' || !_editable(layer)) {
      return false;
    }
    final role =
        '${layer['editorialTextRole'] ?? layer['typographyRole'] ?? ''}'
            .toLowerCase();
    final id = '${layer['id'] ?? ''}'.toLowerCase();
    // Match field suffixes, rather than collection names such as dates-of-us.
    // Folios, titles and short picture captions are not writing pages.
    if (RegExp(
      r'(?:^|_)(?:folio(?:_\w+)?|running_title|running_head|title|heading|headline|label|tag|date|period|byline|index|number)$',
    ).hasMatch(id)) {
      return false;
    }
    if (role == 'headline' || role == 'caption' || role.contains('title')) {
      return false;
    }
    if (role == 'body' ||
        role == 'journal' ||
        role == 'letter' ||
        role == 'note') {
      return true;
    }
    return RegExp(
      r'(?:^|_)(?:body|journal|letter|essay|note|message|memory_value|stop_note|list)(?:_\d+)?$',
    ).hasMatch(id);
  }
}

class _CachedDesignProfile {
  const _CachedDesignProfile(this.source, this.profile);

  final String source;
  final TemplateDesignProfile profile;
}
