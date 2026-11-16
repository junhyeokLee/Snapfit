import 'dart:convert';
import '../../domain/entities/layer_content_provenance.dart';

/// Only primitive metadata crosses the worker boundary, never decoded pages.
class AlbumDocumentMetadata {
  const AlbumDocumentMetadata({
    this.completedPages = 0,
    this.innerPages = 0,
    this.firstIncompletePageIndex,
    this.firstIncompletePageNumber,
    this.firstIncompletePhotoSlots = 0,
    this.firstUnfilledPhotoLayerId,
    this.productId,
    this.trimWidthMm,
    this.trimHeightMm,
  });
  final int completedPages;
  final int innerPages;

  /// Position in the saved `pages` list, including the cover when present.
  /// This is navigation metadata, not the page's printed/logical number.
  final int? firstIncompletePageIndex;
  final int? firstIncompletePageNumber;
  final int firstIncompletePhotoSlots;
  final String? firstUnfilledPhotoLayerId;
  final String? productId;
  final num? trimWidthMm, trimHeightMm;

  Map<String, dynamic> get printProduct => {
    'id': productId,
    'trimWidthMm': trimWidthMm,
    'trimHeightMm': trimHeightMm,
  };
}

/// Size and progress share one decode rather than spawning a size-only worker.
AlbumDocumentMetadata analyzeAlbumDocument(String raw) {
  if (raw.isEmpty) return const AlbumDocumentMetadata();
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return const AlbumDocumentMetadata();
    final product = decoded['printProduct'];
    final id = product is Map ? product['id'] : null;
    final width = product is Map ? product['trimWidthMm'] : null;
    final height = product is Map ? product['trimHeightMm'] : null;
    final progress = _pageProgress(decoded);
    return AlbumDocumentMetadata(
      completedPages: progress.completed,
      innerPages: progress.total,
      firstIncompletePageIndex: progress.firstIncomplete,
      firstIncompletePageNumber: progress.firstIncompleteNumber,
      firstIncompletePhotoSlots: progress.emptyPhotos,
      firstUnfilledPhotoLayerId: progress.firstPhotoId,
      productId: id is String ? id : null,
      trimWidthMm: width is num ? width : null,
      trimHeightMm: height is num ? height : null,
    );
  } catch (_) {
    return const AlbumDocumentMetadata();
  }
}

int countCompletedAlbumPages(String raw) =>
    analyzeAlbumDocument(raw).completedPages;

({
  int completed,
  int total,
  int? firstIncomplete,
  int? firstIncompleteNumber,
  int emptyPhotos,
  String? firstPhotoId,
})
_pageProgress(Map<String, dynamic> decoded) {
  final pages = decoded['pages'];
  if (pages is! List) {
    return (
      completed: 0,
      total: 0,
      firstIncomplete: null,
      firstIncompleteNumber: null,
      emptyPhotos: 0,
      firstPhotoId: null,
    );
  }
  var completed = 0;
  var total = 0;
  int? firstIncomplete;
  int? firstIncompleteNumber;
  var emptyPhotos = 0;
  String? firstPhotoId;
  var lastPage = 0;
  var zeroBasedInteriors = false;
  final seen = <int>{};
  for (var position = 0; position < pages.length; position++) {
    final page = pages[position];
    if (page is Map &&
        (page['isCover'] == true ||
            (page['index'] == 0 && page['isCover'] != false) ||
            (position == 0 &&
                page['index'] == null &&
                page['isCover'] != false))) {
      continue;
    }
    // A malformed or empty interior still occupies a page; it cannot disappear
    // from the completion target just because its layers cannot be inspected.
    total++;
    if (page is Map && page['index'] is int) {
      final index = page['index'] as int;
      if (index < 0 || !seen.add(index)) {
        firstIncomplete ??= position;
        firstIncompleteNumber ??= total;
        continue;
      }
      // Explicit interior metadata takes precedence over legacy cover inference.
      // Some documents number interiors from zero, with the cover kept separate.
      if (index == 0) zeroBasedInteriors = true;
      if (index > lastPage) lastPage = index;
    }
    if (page is Map &&
        page['layers'] is List &&
        isAlbumPageContentComplete(page['layers'] as List)) {
      completed++;
    } else {
      if (firstIncomplete == null) {
        firstIncomplete = position;
        firstIncompleteNumber = total;
        final summary = albumPageContentSummary(
          page is Map && page['layers'] is List
              ? page['layers'] as List
              : const [],
        );
        emptyPhotos = summary.photoSlots - summary.filledPhotoSlots;
        firstPhotoId = summary.firstUnfilledPhotoId;
      }
    }
  }
  final indexedTotal = lastPage + (zeroBasedInteriors ? 1 : 0);
  return (
    completed: completed,
    total: indexedTotal > total ? indexedTotal : total,
    firstIncomplete: firstIncomplete,
    firstIncompleteNumber: firstIncompleteNumber,
    emptyPhotos: emptyPhotos,
    firstPhotoId: firstPhotoId,
  );
}

/// Shared by saved-document progress and the prepared editor's resume action.
/// Keeping one predicate prevents the next-action card from skipping a page
/// that the library still correctly considers unfinished.
bool isAlbumPageContentComplete(Iterable<dynamic> layers) {
  return albumPageContentSummary(layers).isComplete;
}

/// The same provenance rules drive progress, the home suggestion and the
/// one-page editor. A bundled sample or an unverified legacy URL is not filled.
({
  bool isComplete,
  int photoSlots,
  int filledPhotoSlots,
  String? firstUnfilledPhotoId,
})
albumPageContentSummary(Iterable<dynamic> layers) {
  var photos = 0;
  var filledPhotos = 0;
  var personalText = false;
  String? firstPhotoId;
  for (final rawLayer in layers) {
    if (rawLayer is! Map) continue;
    final payload = rawLayer['payload'] is Map
        ? rawLayer['payload'] as Map
        : const {};
    final type = rawLayer['type']?.toString().toUpperCase();
    final opacity = rawLayer['opacity'];
    final visible =
        rawLayer['hidden'] != true && (opacity is! num || opacity > 0);
    if (type == 'IMAGE') {
      photos++;
      if (visible && _hasPhoto(rawLayer, payload)) {
        filledPhotos++;
      } else if (rawLayer['id'] is String) {
        firstPhotoId ??= rawLayer['id'] as String;
      }
    } else if (type == 'TEXT' &&
        visible &&
        _hasPersonalText(rawLayer, payload)) {
      personalText = true;
    }
  }
  // Every photo slot is required, even when a personal caption is present.
  // Backgrounds, frames and stickers never complete a page by themselves.
  return (
    isComplete: photos > 0 ? filledPhotos == photos : personalText,
    photoSlots: photos,
    filledPhotoSlots: filledPhotos,
    firstUnfilledPhotoId: firstPhotoId,
  );
}

// Only explicit personal provenance is evidence. Missing or malformed markers,
// examples and placeholders stay unfinished, even when they contain text/URLs.
bool _isPersonalLayer(Map layer, Map payload) =>
    layerTemplateContentFromJson(layer, payload) == false;

bool _hasPhoto(Map layer, Map payload) {
  if (!_isPersonalLayer(layer, payload)) return false;
  for (final key in ['originalUrl', 'previewUrl', 'imageUrl']) {
    final value = payload[key] ?? layer[key];
    if (value is! String || value.trim().isEmpty) continue;
    final url = value.trim();
    // Bundled photographs are store samples, not a customer's saved photo.
    if (url.startsWith('asset:') || url.startsWith('assets/')) continue;
    return true;
  }
  return false;
}

bool _hasPersonalText(Map layer, Map payload) {
  if (!_isPersonalLayer(layer, payload)) return false;
  final text = payload['text'] ?? layer['text'];
  return text is String && text.trim().isNotEmpty;
}
