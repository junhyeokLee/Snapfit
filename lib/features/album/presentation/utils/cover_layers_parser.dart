import 'dart:convert';
import 'dart:ui';

import '../../domain/entities/layer.dart';
import '../../domain/entities/layer_export_mapper.dart';

List<LayerModel>? parseCoverLayersForCanvas({
  required String rawJson,
  required Size canvasSize,
  bool isCover = true,
  int pageIndex = 0,
}) {
  if (rawJson.isEmpty) return null;
  try {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final pages = decoded['pages'] as List<dynamic>?;
    final List<dynamic> layerList =
        (pages != null && pages.length > pageIndex)
        ? ((pages[pageIndex] as Map<String, dynamic>)['layers'] as List?) ?? []
        : (decoded['layers'] as List?) ?? [];
    if (layerList.isEmpty) return null;
    return layerList
        .map(
          (layer) => LayerExportMapper.fromJson(
            layer as Map<String, dynamic>,
            canvasSize: canvasSize,
            isCover: isCover,
          ),
        )
        .toList();
  } catch (_) {
    return null;
  }
}
