import 'studio_decoration_catalog.dart';
import 'studio_photo_frame_catalog.dart';
import 'template_material_layers.dart';

/// Editorial inventory only. A trusted server release manifest must authorize
/// bundle ownership; customer-supplied layers never grant paid products.
Set<String> templateVisualMaterialKeys(Map<String, dynamic> document) {
  final result = <String>{};
  final byValue = {
    for (final spec in studioDecorations) spec.insertionValue: spec,
  };
  final byId = {for (final spec in studioDecorations) spec.id: spec};
  for (final layer in templateMaterialLayers(document)) {
    final style = layer['style'];
    final decoration = byId[style];
    if (decoration != null) result.add('sticker:${decoration.id}');
    for (final value in {
      ...templateMaterialImageReferences(layer),
      if (layer['textFillImageUrl'] case final String fill) fill,
    }) {
      final spec = byValue[value];
      if (spec != null) result.add('sticker:${spec.id}');
    }
    if (layer['wordArtId'] case final String wordArt) {
      result.add('phrase:collage-$wordArt');
    }
    if (layer['type'] == 'image') {
      final frame = layer['frame'];
      if (studioPhotoFrames.contains(frame)) {
        result.add('frame:$frame');
        final included = keepsakeFrameIncludedMaterials[frame];
        if (included != null) result.add(included);
      }
    }
  }
  return Set.unmodifiable(result);
}
