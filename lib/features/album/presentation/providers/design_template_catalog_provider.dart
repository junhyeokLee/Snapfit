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
    final response = await dio.get('/api/templates');
    final payload = response.data;
    final items = payload is List
        ? payload
        : (payload is Map<String, dynamic> ? payload['templates'] : null);
    if (items is List) {
      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        final converted = _toDesignTemplateJson(item);
        if (converted == null) continue;
        final t = _hydratePreviewMeta(DataTemplateEngine.templateFromJson(converted));
        if (t.id.isNotEmpty) {
          merged[t.id] = t;
        }
      }
    }
  } catch (_) {
    // Network/API unavailable -> fallback to local JSON
  }

  // 2) Local JSON fallback (base catalog)
  try {
    await _mergeTemplatesFromAssetPath(
      merged: merged,
      assetPath: 'assets/templates/design_templates_v1.json',
    );
  } catch (_) {
    // Keep built-in templates only (phase-1 safe fallback)
  }

  // 3) Periodic auto-generated pack (if exists)
  try {
    await _mergeTemplatesFromAssetPath(
      merged: merged,
      assetPath: 'assets/templates/generated/latest.json',
    );
  } catch (_) {
    // Optional asset: ignore when not generated yet
  }

  return merged.values.toList();
});

Future<void> _mergeTemplatesFromAssetPath({
  required Map<String, DesignTemplate> merged,
  required String assetPath,
}) async {
  final raw = await rootBundle.loadString(assetPath);
  final decoded = jsonDecode(raw);
  final items = decoded is List
      ? decoded
      : (decoded is Map<String, dynamic> ? decoded['templates'] : null);

  if (items is! List) return;
  for (final item in items) {
    if (item is! Map<String, dynamic>) continue;
    final t = _hydratePreviewMeta(DataTemplateEngine.templateFromJson(item));
    if (t.id.isNotEmpty) merged[t.id] = t;
  }
}

Map<String, dynamic>? _toDesignTemplateJson(Map<String, dynamic> apiItem) {
  final rawTemplateJson = apiItem['templateJson'];
  if (rawTemplateJson is! String || rawTemplateJson.trim().isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(rawTemplateJson);
    if (decoded is! Map<String, dynamic>) return null;
    final normalized = _normalizeTemplateSpecForEditor(decoded);
    final baseId = (decoded['templateId'] ?? apiItem['id'] ?? '').toString();
    final title = (decoded['name'] ?? apiItem['title'] ?? '').toString();
    return {
      ...normalized,
      'templateId': baseId.isEmpty ? title : baseId,
      'name': title.isEmpty ? baseId : title,
    };
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> _normalizeTemplateSpecForEditor(Map<String, dynamic> decoded) {
  final out = Map<String, dynamic>.from(decoded);
  if (out['layers'] is List) return out;

  List<dynamic>? layers;
  final cover = out['cover'];
  if (cover is Map<String, dynamic> && cover['layers'] is List) {
    layers = cover['layers'] as List<dynamic>;
  }
  if (layers == null || layers.isEmpty) {
    final pages = out['pages'];
    if (pages is List && pages.isNotEmpty && pages.first is Map<String, dynamic>) {
      final first = pages.first as Map<String, dynamic>;
      if (first['layers'] is List) {
        layers = first['layers'] as List<dynamic>;
      }
    }
  }
  if (layers != null && layers.isNotEmpty) {
    out['layers'] = layers;
  }

  if (out['aspect'] == null) {
    final ratioRaw = (out['ratio'] ?? '').toString();
    final ratio = double.tryParse(ratioRaw);
    if (ratio != null) {
      if ((ratio - 1.0).abs() <= 0.05) {
        out['aspect'] = 'square';
      } else if (ratio > 1.0) {
        out['aspect'] = 'landscape';
      } else {
        out['aspect'] = 'portrait';
      }
    }
  }

  final metadata = out['metadata'];
  if (metadata is Map<String, dynamic>) {
    out['designWidth'] ??= metadata['designWidth'];
    out['designHeight'] ??= metadata['designHeight'];
  }
  return out;
}

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
