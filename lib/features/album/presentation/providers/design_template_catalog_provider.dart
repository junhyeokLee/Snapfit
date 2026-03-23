import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/design_templates.dart';
import '../../../../../core/network/dio_provider.dart';
import '../../../../../core/templates/data_template_engine.dart';

final designTemplateCatalogProvider = FutureProvider<List<DesignTemplate>>((
  ref,
) async {
  final merged = <String, DesignTemplate>{
    for (final t in designTemplates) t.id: _hydratePreviewMeta(t),
  };

  // 1) Real-time supply from server (no app redeploy)
  try {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/api/design-templates');
    final payload = response.data;
    final items = payload is List
        ? payload
        : (payload is Map<String, dynamic> ? payload['templates'] : null);
    if (items is List) {
      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        final t = _hydratePreviewMeta(
          DataTemplateEngine.templateFromJson(item),
        );
        if (t.id.isNotEmpty) merged[t.id] = t;
      }
    }
  } catch (_) {
    // Network/API unavailable -> fallback to local JSON
  }

  // 2) Local JSON fallback
  try {
    final raw = await rootBundle.loadString(
      'assets/templates/design_templates_v1.json',
    );
    final decoded = jsonDecode(raw);
    final items = decoded is List
        ? decoded
        : (decoded is Map<String, dynamic> ? decoded['templates'] : null);

    if (items is List) {
      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        final t = _hydratePreviewMeta(
          DataTemplateEngine.templateFromJson(item),
        );
        if (t.id.isNotEmpty) merged[t.id] = t;
      }
    }
  } catch (_) {
    // Keep built-in templates only (phase-1 safe fallback)
  }

  return merged.values.toList();
});

DesignTemplate _hydratePreviewMeta(DesignTemplate t) {
  final slotUrls = t.previewImageUrls.isNotEmpty
      ? t.previewImageUrls
      : templatePreviewImagesForId(t.id);
  final thumb = t.previewThumbUrl.isNotEmpty
      ? t.previewThumbUrl
      : templatePreviewThumbForId(t.id);
  final detail = t.previewDetailUrl.isNotEmpty
      ? t.previewDetailUrl
      : templatePreviewDetailForId(t.id);

  return DesignTemplate(
    id: t.id,
    name: t.name,
    buildLayers: t.buildLayers,
    forCover: t.forCover,
    aspect: t.aspect,
    category: t.category,
    tags: t.tags,
    style: t.style,
    recommendedPhotoCount: t.recommendedPhotoCount,
    difficulty: t.difficulty,
    isFeatured: t.isFeatured,
    priority: t.priority,
    previewThumbUrl: thumb,
    previewDetailUrl: detail,
    previewImageUrls: slotUrls,
  );
}
