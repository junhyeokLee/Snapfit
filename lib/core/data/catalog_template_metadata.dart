import 'dart:convert';

import '../../features/album/data/bundled_creation_templates.dart';
import '../../features/store/domain/entities/premium_template.dart';
import 'catalog_template_metadata.g.dart';

final _catalogMetadata =
    jsonDecode(catalogTemplateMetadataJson) as Map<String, dynamic>;

/// Catalog descriptions must not evaluate font-measured document builders.
/// Identity protects a remote/custom document that happens to reuse a local ID.
Map<String, dynamic>? canonicalTemplateMetadata(PremiumTemplate template) {
  // Worker documents are eager, data-only JSON. Do not initialize the authored
  // registry in that isolate merely to discover that there is no lazy builder.
  if (template.documentBuilder == null) return null;
  final canonical = publishedCreationTemplateById(template.id);
  if (canonical == null ||
      !identical(canonical.documentBuilder, template.documentBuilder)) {
    return null;
  }
  return _catalogMetadata['${template.id}'] as Map<String, dynamic>?;
}

Map<String, dynamic>? publishedTemplateMetadataById(int id) =>
    _catalogMetadata['$id'] as Map<String, dynamic>?;
