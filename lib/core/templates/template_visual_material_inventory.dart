import 'studio_decoration_catalog.dart';
import 'studio_photo_frame_catalog.dart';
import 'template_document_pages.dart';

/// Editorial inventory only. A trusted server release manifest must authorize
/// bundle ownership; customer-supplied layers never grant paid products.
Set<String> templateVisualMaterialKeys(Map<String, dynamic> document) {
  final result = <String>{};
  final byValue = {
    for (final spec in studioDecorations) spec.insertionValue: spec,
  };
  final byId = {for (final spec in studioDecorations) spec.id: spec};
  void inspect(Map<String, dynamic> data) {
    for (final page in templateDocumentPages(data)) {
      for (final layer
          in (page['layers'] as List? ?? const []).whereType<Map>()) {
        final type = layer['type']?.toString().toLowerCase();
        if (type == 'sticker' || type == 'decoration') {
          final style = layer['imageBackground'] ?? layer['style'];
          final spec = byValue[layer['imageUrl']] ?? byId[style];
          if (spec != null) result.add('sticker:${spec.id}');
        }
        if (type == 'image') {
          final frame = layer['imageBackground'] ?? layer['frame'];
          if (studioPhotoFrames.contains(frame)) {
            result.add('frame:$frame');
            final included = keepsakeFrameIncludedMaterials[frame];
            if (included != null) result.add(included);
          }
        }
      }
    }
    final variants = data['variants'];
    if (variants is Map) {
      for (final variant in variants.values.whereType<Map>()) {
        inspect(Map<String, dynamic>.from(variant));
      }
    }
  }

  inspect(document);
  return Set.unmodifiable(result);
}
