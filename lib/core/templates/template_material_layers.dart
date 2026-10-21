import 'template_document_pages.dart';

/// Inspect authored, saved-payload and per-aspect layers through the same view.
/// This is publication inventory only; it never rewrites customer documents.
Iterable<Map<String, dynamic>> templateMaterialLayers(
  Map<String, dynamic> document,
) sync* {
  for (final page in [
    if (document['layers'] is List) document,
    ...templateDocumentPages(document),
  ]) {
    for (final raw in (page['layers'] as List? ?? const []).whereType<Map>()) {
      final base = Map<String, dynamic>.from(raw);
      final overrides = base['aspectOverrides'];
      final candidates = [
        base,
        if (overrides is Map)
          for (final override in overrides.values.whereType<Map>())
            <String, dynamic>{...base, ...Map<String, dynamic>.from(override)},
      ];
      for (final layer in candidates) {
        final payload = layer['payload'] is Map
            ? Map<String, dynamic>.from(layer['payload'] as Map)
            : const <String, dynamic>{};
        final style = layer['style'];
        final type = switch ((layer['type'] ?? 'image')
            .toString()
            .toLowerCase()) {
          'text' => 'text',
          'sticker' => 'sticker',
          'decoration' || 'background' => 'decoration',
          _ => 'image',
        };
        yield {
          ...payload,
          for (final entry in layer.entries)
            if (entry.value != null) entry.key: entry.value,
          'type': type,
          'frame':
              layer['frame'] ??
              layer['imageBackground'] ??
              payload['imageBackground'],
          'style':
              style ??
              layer['frame'] ??
              layer['imageBackground'] ??
              payload['imageBackground'] ??
              payload['imageTemplate'],
          'textFillImageUrl':
              layer['textFillImageUrl'] ??
              payload['textFillImageUrl'] ??
              (style is Map ? style['textFillImageUrl'] : null),
          'wordArtId':
              layer['wordArtId'] ??
              payload['wordArtId'] ??
              (style is Map ? style['wordArtId'] : null),
        };
      }
    }
  }
  final variants = document['variants'];
  final children = variants is Map
      ? variants.values
      : (variants is List ? variants : const []);
  for (final variant in children.whereType<Map>()) {
    yield* templateMaterialLayers(Map<String, dynamic>.from(variant));
  }
}

/// Include preview/original references as well as the currently visible image.
Set<String> templateMaterialImageReferences(Map<String, dynamic> layer) => {
  for (final field in ['imageUrl', 'previewUrl', 'originalUrl'])
    if (layer[field] case final String value when value.isNotEmpty)
      value.startsWith('assets/') ? 'asset:$value' : value,
};
