import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../features/album/data/bundled_creation_templates.dart';
import '../../features/album/domain/entities/layer.dart';
import '../../features/store/domain/entities/premium_template.dart';
import '../templates/data_template_engine.dart';
import '../cache/memory_pressure_caches.dart';
import 'catalog_preview_document.dart';
import 'catalog_preview_documents.g.dart';

/// An ID is sufficient only when the supplied builder is the published builder.
/// In particular, a remote/custom document with that ID must keep its own art.
int? canonicalCatalogPreviewId(PremiumTemplate? template) {
  if (template == null || template.documentBuilder == null) return null;
  final canonical = publishedCreationTemplateById(template.id);
  return canonical != null &&
          identical(canonical.documentBuilder, template.documentBuilder)
      ? canonical.id
      : null;
}

class CatalogPreviewProfile {
  CatalogPreviewProfile._(Map<String, dynamic> data)
    : photoSlotCount = data['photoSlotCount'] as int?,
      innerPhotoSlotCount = data['innerPhotoSlotCount'] as int?,
      innerPageCount = data['innerPageCount'] as int?,
      photoPageCount = data['photoPageCount'] as int?,
      recordPageCount = data['recordPageCount'] as int?,
      compositionLabel = data['compositionLabel'] as String,
      briefLabel = data['briefLabel'] as String;

  final int? photoSlotCount, innerPhotoSlotCount, innerPageCount;
  final int? photoPageCount, recordPageCount;
  final String compositionLabel, briefLabel;
}

/// Only the cover and the two displayed interiors become native layer models.
/// No full document, variants, or widget trees are retained by the UI cache.
class CatalogPreview {
  CatalogPreview._(Map<String, dynamic> data)
    : canvas = Size(data['width'] as double, data['height'] as double),
      profile = CatalogPreviewProfile._(
        data['profile'] as Map<String, dynamic>,
      ),
      _coverSource = data['cover'],
      _spreadSource = data['spread'] as List;

  static const firstSpreadPage = 3;
  final Size canvas;
  final CatalogPreviewProfile profile;
  Object? _coverSource;
  List? _spreadSource;
  List<LayerModel>? _cover;
  List<List<LayerModel>>? _spread;

  bool hasPreparedParts({bool cover = false, bool spread = false}) =>
      (!cover || _cover != null) && (!spread || _spread != null);

  void prepareParts({bool cover = false, bool spread = false}) {
    if (cover) _cover ??= _takeCover();
    if (spread) _spread ??= _takeSpread();
  }

  // A profile label or a cover tile does not need two native interior pages.
  // Release the corresponding raw maps once their immutable models are used.
  List<LayerModel> get cover => _cover ??= _takeCover();
  List<List<LayerModel>> get spread => _spread ??= _takeSpread();

  List<LayerModel> _compile(Object? layers) {
    try {
      return List.unmodifiable(
        DataTemplateEngine.buildLayersFromJson({
          'strictLayout': true,
          'designWidth': canvas.width,
          'designHeight': canvas.height,
          'layers': layers,
        }, canvas),
      );
    } on Object {
      // Deferred compilation keeps malformed documents on the existing
      // empty-artwork fallback instead of throwing during a widget build.
      return const [];
    }
  }

  List<LayerModel> _takeCover() {
    final layers = _compile(_coverSource);
    _coverSource = null;
    return layers;
  }

  List<List<LayerModel>> _takeSpread() {
    final pages = List<List<LayerModel>>.unmodifiable(
      _spreadSource!.map(_compile),
    );
    _spreadSource = null;
    return pages;
  }
}

/// A mounted consumer's interest in a shared preview. Releasing the final
/// consumer cancels queued work; an already running worker may finish safely.
class CatalogPreviewRequest {
  CatalogPreviewRequest._(this.future, [this._release]);

  final Future<CatalogPreview?> future;
  final VoidCallback? _release;
  bool _released = false;

  void release() {
    if (_released) return;
    _released = true;
    _release?.call();
  }
}

class _PreviewJob {
  _PreviewJob(this.message, this.cacheEpoch);

  final Map<String, dynamic> message;
  final int cacheEpoch;
  final completer = Completer<CatalogPreview?>();
  int consumers = 0;
}

/// Covers, spreads, composition text, and favorite copies share one request.
/// One worker bounds peak construction memory. Queued work belongs only to
/// mounted consumers. FIFO keeps the first visible cover ahead of prefetch.
class CatalogPreviews {
  CatalogPreviews._();

  static const cacheLimit = 18;
  static const _maxSourceCharacters = 2 * 1024 * 1024;
  static final _cache = <Object, CatalogPreview?>{};
  static final _inflight = <Object, _PreviewJob>{};
  static final _queued = <Object, _PreviewJob>{};
  static bool _running = false;
  static int _cacheEpoch = 0;
  static int _sourceCharacters = 0;

  static void clearCache() {
    _cache.clear();
    _sourceCharacters = 0;
    // Active consumers still receive their result, but jobs started before
    // memory pressure must not immediately refill the cache being released.
    _cacheEpoch++;
  }

  /// For callers that await a result. Widgets should acquire/release instead.
  static Future<CatalogPreview?> request(PremiumTemplate template) {
    final request = acquire(template);
    request.future.then((_) => request.release());
    return request.future;
  }

  /// Scrolling widgets can reuse compiled previews without scheduling workers
  /// or evaluating lazy document builders on a cache miss.
  static CatalogPreviewRequest? acquireCached(
    PremiumTemplate template, {
    bool needsCover = false,
    bool needsSpread = false,
  }) {
    try {
      final key = template.documentBuilder ?? template.templateJson;
      final preview = _cache[key];
      if (preview != null &&
          !preview.hasPreparedParts(cover: needsCover, spread: needsSpread)) {
        return null;
      }
      return _cachedRequest(key);
    } on Object {
      return null;
    }
  }

  static CatalogPreviewRequest? _cachedRequest(Object? key) {
    if (key == null || !_cache.containsKey(key)) return null;
    final cached = _cache.remove(key);
    _cache[key] = cached;
    // Cache values, not completed futures tied to a former consumer's zone.
    return CatalogPreviewRequest._(SynchronousFuture(cached));
  }

  static CatalogPreviewRequest acquire(PremiumTemplate template) {
    MemoryPressureCaches.register('catalog-previews', clearCache);
    final canonicalId = canonicalCatalogPreviewId(template);
    final builder = template.documentBuilder;
    // Reading eager JSON is cheap. Never call a lazy builder on the UI isolate,
    // including custom builders, which may also capture unsendable objects.
    String? source;
    if (builder == null) {
      try {
        source = template.templateJson;
      } on Object {
        return CatalogPreviewRequest._(Future.value());
      }
    }
    final Object? key = builder ?? source;
    if (key == null) return CatalogPreviewRequest._(Future.value());
    final cached = _cachedRequest(key);
    if (cached != null) return cached;
    var job = _inflight[key];
    if (job == null) {
      // Published messages contain only an ID, never the original lazy closure.
      job = _PreviewJob({
        if (canonicalId != null)
          'id': canonicalId
        else if (builder != null)
          'builder': builder
        else
          'source': source,
      }, _cacheEpoch);
      _inflight[key] = job;
      _queued[key] = job;
    }
    final shared = job;
    shared.consumers++;
    scheduleMicrotask(_drain);
    return CatalogPreviewRequest._(shared.completer.future, () {
      shared.consumers--;
      if (shared.consumers == 0 && identical(_queued[key], shared)) {
        _queued.remove(key);
        _inflight.remove(key);
        shared.completer.complete();
      }
    });
  }

  static Future<void> _drain() async {
    if (_running) return;
    _running = true;
    try {
      while (_queued.isNotEmpty) {
        final key = _queued.keys.first;
        final job = _queued.remove(key)!;
        CatalogPreview? preview;
        try {
          final data = await compute(
            _readCatalogPreview,
            job.message,
            debugLabel: 'catalog-preview',
          );
          if (job.consumers > 0 && data != null) {
            preview = CatalogPreview._(data);
          }
        } on Object {
          // Bad documents and unsendable custom closures leave a static
          // fallback. Never retry the original builder on the UI isolate.
        }
        _inflight.remove(key);
        if (job.consumers > 0 && job.cacheEpoch == _cacheEpoch) {
          // Remote cache keys contain eager documents. An entry count alone
          // allowed a handful of large books to retain megabytes of JSON.
          final sourceCharacters = key is String ? key.length : 0;
          if (sourceCharacters <= _maxSourceCharacters) {
            _cache[key] = preview;
            _sourceCharacters += sourceCharacters;
            while (_cache.length > cacheLimit ||
                _sourceCharacters > _maxSourceCharacters) {
              final oldest = _cache.keys.first;
              _cache.remove(oldest);
              if (oldest is String) _sourceCharacters -= oldest.length;
            }
          }
        }
        job.completer.complete(preview);
      }
    } finally {
      _running = false;
    }
  }
}

/// Runs entirely in compute. Only primitive maps for three pages and profile
/// strings/counts cross back; alternate editions remain in the worker.
Map<String, dynamic>? _readCatalogPreview(Map<String, dynamic> message) {
  final id = message['id'] as int?;
  if (id != null) {
    // Exact native-font layouts are exported at development time. Resolving a
    // published ID never initializes the authored registry in this isolate.
    final source = catalogPreviewDocuments[id];
    return source == null ? null : jsonDecode(source) as Map<String, dynamic>;
  }
  final builder = message['builder'] as String Function()?;
  final source = message['source'] as String? ?? builder?.call();
  return source == null ? null : compactCatalogPreviewDocument(source);
}
