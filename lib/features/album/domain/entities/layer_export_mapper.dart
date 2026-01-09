import 'dart:ui';
import 'layer.dart';

class LayerExportMapper {
  static Map<String, dynamic> toJson(
      LayerModel layer, {
        required Size canvasSize,
      }) {
    final double finalWidth = layer.width * layer.scale;
    final double finalHeight = layer.height * layer.scale;

    return {
      'type': layer.type.name.toUpperCase(),
      'x': layer.position.dx / canvasSize.width,
      'y': layer.position.dy / canvasSize.height,
      'width': finalWidth / canvasSize.width,
      'height': finalHeight / canvasSize.height,
      'rotation': layer.rotation,
      'payload': layer.type == LayerType.image
          ? {
        'imageBackground': layer.imageBackground,
      }
          : {
        'text': layer.text,
        'textAlign': layer.textAlign?.name,
        'textStyleType': layer.textStyleType?.name,
        'textBackground': layer.textBackground,
        'bubbleColor': layer.bubbleColor != null
            ? '#${layer.bubbleColor!.value.toRadixString(16)}'
            : null,
      },
    };
  }
}