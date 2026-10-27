import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/cover_size.dart';
import '../../../../core/data/catalog_detail_assets.dart';
import '../../../../core/data/catalog_preview.dart'
    show canonicalCatalogPreviewId;
import '../../../../core/templates/retired_store_templates.dart';
import '../../../../core/templates/template_document_pages.dart';
import '../../../../core/templates/template_visual_material_inventory.dart';
import '../../domain/entities/premium_template.dart';
import '../../domain/template_design_profile.dart';
import '../widgets/public_template_information.dart';

class TemplateDetailBook {
  const TemplateDetailBook(this.canvas, this.pages);
  final Size canvas;
  final List<Map<String, dynamic>> pages;
}

/// Only data crosses the worker boundary. Native page models stay lazy and
/// bounded by the visible detail's page cache.
class TemplateDetailDocument {
  const TemplateDetailDocument({
    required this.source,
    required this.book,
    required this.variants,
    required this.profile,
    required this.materials,
    required this.facts,
    required this.retired,
  });
  final String source;
  final TemplateDetailBook book;
  final Map<String, TemplateDetailBook> variants;
  final TemplateDesignProfile profile;
  final Set<String> materials;
  final PublicTemplateFacts facts;
  final bool retired;
}

/// Runs in compute, including custom builders. Published books use exported
/// native-font layouts rather than invoking UI-only text measurement here.
TemplateDetailDocument? analyzeTemplateDetailDocument(
  Map<String, dynamic> message,
) {
  final bytes = message['bytes'] as List<int>?;
  final builder = message['builder'] as String Function()?;
  final source = bytes != null
      ? utf8.decode(GZipDecoder().decodeBytes(bytes))
      : message['source'] as String? ?? builder?.call();
  if (source == null || source.trim().isEmpty) return null;
  final data = jsonDecode(source) as Map<String, dynamic>;
  final metadata = data['metadata'] as Map? ?? const {};
  final retired = [
    data['id'],
    data['templateId'],
    metadata['id'],
    metadata['templateId'],
  ].any((id) => RetiredStoreTemplates.matches(templateId: id?.toString()));
  TemplateDetailBook readBook(Map<String, dynamic> node) {
    final width =
        (node['designWidth'] as num? ?? metadata['designWidth'] as num? ?? 500)
            .toDouble();
    final height =
        (node['designHeight'] as num? ??
                metadata['designHeight'] as num? ??
                500)
            .toDouble();
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      throw const FormatException('Invalid template canvas');
    }
    return TemplateDetailBook(Size(width, height), templateDocumentPages(node));
  }

  bool supported(TemplateDetailBook book) => coverSizes.any(
    (size) => (size.ratio - book.canvas.aspectRatio).abs() < .0001,
  );
  final book = readBook(data);
  if (!supported(book)) return null;
  final variants = <String, TemplateDetailBook>{};
  void addVariant(String key, Object? value) {
    if (key.isEmpty || value is! Map) return;
    final variant = readBook(Map<String, dynamic>.from(value));
    if (variant.pages.isNotEmpty && supported(variant)) {
      variants[templateVariantForRatio(variant.canvas.aspectRatio)] = variant;
    }
  }

  final rawVariants = data['variants'];
  if (rawVariants is Map) {
    for (final entry in rawVariants.entries) {
      addVariant(entry.key.toString().toLowerCase(), entry.value);
    }
  } else if (rawVariants is List) {
    for (final node in rawVariants.whereType<Map>()) {
      final key = (node['aspect'] ?? node['variantId'] ?? '')
          .toString()
          .toLowerCase();
      final normalized =
          const [
            'square',
            'landscape',
            'landscape4x3',
            'landscape5x4',
          ].where((aspect) => key.endsWith('_$aspect')).firstOrNull ??
          key;
      addVariant(normalized, node);
    }
  }
  return TemplateDetailDocument(
    source: source,
    book: book,
    variants: variants,
    profile: TemplateDesignProfile.fromDocument(data),
    materials: retired ? const {} : templateVisualMaterialKeys(data),
    facts: PublicTemplateFacts.fromDocument(message['id'] as int, data),
    retired: retired,
  );
}

class TemplateDetailDocumentRequest {
  TemplateDetailDocumentRequest._(this._job);
  _DetailJob? _job;
  final _result = Completer<TemplateDetailDocument?>();
  Future<TemplateDetailDocument?> get future => _result.future;
  void cancel() {
    final job = _job;
    if (job == null) return;
    _job = null;
    job.clients.remove(this);
    _result.complete(null);
    if (job.clients.isEmpty && TemplateDetailDocuments._queued.remove(job)) {
      TemplateDetailDocuments._jobs.remove(job.key);
      job.message = const {};
    }
  }
}

class _DetailJob {
  _DetailJob(this.key, this.message, this.asset);
  final Object key;
  Map<String, dynamic> message;
  final String? asset;
  final clients = <TemplateDetailDocumentRequest>{};
}

class _IdentityInput {
  const _IdentityInput(this.value);
  final Object value;
  @override
  int get hashCode => identityHashCode(value);
  @override
  bool operator ==(Object other) =>
      other is _IdentityInput && identical(value, other.value);
}

/// One worker at a time; queued jobs disappear when their last screen leaves.
/// Completed full books are owned by screens, never by a global result cache.
abstract final class TemplateDetailDocuments {
  static final _jobs = <Object, _DetailJob>{};
  static final _queued = <_DetailJob>[];
  static bool _running = false;
  static bool get hasPendingWork => _running || _queued.isNotEmpty;

  static TemplateDetailDocumentRequest acquire(
    PremiumTemplate template, {
    int? innerPages,
  }) {
    final canonical = canonicalCatalogPreviewId(template);
    if (innerPages != null && canonical == null) {
      return TemplateDetailDocumentRequest._(null).._result.complete(null);
    }
    final asset = canonical == null
        ? null
        : catalogDetailAssetPath(
            '$canonical${innerPages == null ? '' : '-$innerPages'}',
          );
    final builder = template.documentBuilder;
    final source = asset == null && builder == null
        ? template.templateJson
        : null;
    // Hashing a multi-megabyte JSON string on entry would itself use the UI
    // frame budget. Favorite copies share the original immutable input object.
    final Object key = (
      template.id,
      asset ?? _IdentityInput(builder ?? source ?? Object()),
    );
    final job = _jobs.putIfAbsent(key, () {
      final job = _DetailJob(key, {
        'id': template.id,
        if (asset == null && builder != null) 'builder': builder,
        if (asset == null && builder == null) 'source': source,
      }, asset);
      _queued.add(job);
      return job;
    });
    final request = TemplateDetailDocumentRequest._(job);
    job.clients.add(request);
    scheduleMicrotask(_drain);
    return request;
  }

  static Future<void> _drain() async {
    if (_running) return;
    _running = true;
    try {
      while (_queued.isNotEmpty) {
        final job = _queued.removeAt(0);
        TemplateDetailDocument? document;
        try {
          if (job.asset case final asset?) {
            final bytes = await rootBundle.load(asset);
            job.message = {
              ...job.message,
              'bytes': bytes.buffer.asUint8List(
                bytes.offsetInBytes,
                bytes.lengthInBytes,
              ),
            };
          }
          if (job.clients.isNotEmpty) {
            document = await compute(
              analyzeTemplateDetailDocument,
              job.message,
              debugLabel: 'template-detail-document',
            );
          }
        } on Object {
          // An invalid document/unsendable builder is a retryable preview error.
          // Never fall back to running the builder on the UI isolate.
        }
        _jobs.remove(job.key);
        job.message = const {};
        for (final client in job.clients) {
          client._job = null;
          client._result.complete(document);
        }
        job.clients.clear();
      }
    } finally {
      _running = false;
    }
  }
}
