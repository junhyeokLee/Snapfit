import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../album/domain/entities/layer.dart';

class TemplatePageRenderer extends StatelessWidget {
  final List<LayerModel> layers;
  final double width;
  final double height;
  final Map<String, File>? localFiles;
  final VoidCallback? onImageTap;
  final Function(String layerId)? onLayerTap;

  const TemplatePageRenderer({
    super.key,
    required this.layers,
    required this.width,
    required this.height,
    this.localFiles,
    this.onImageTap,
    this.onLayerTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,

          )
        ],
      ),
      child: Stack(
        children: layers.map((layer) => _buildLayerWidget(layer, width, height)).toList(),
      ),
    );
  }

  Widget _buildLayerWidget(LayerModel layer, double canvasW, double canvasH) {
    // Parsing base was 500x500
    const double baseW = 500;
    const double baseH = 500;

    final scaleX = canvasW / baseW;
    final scaleY = canvasH / baseH;

    final x = layer.position.dx * scaleX;
    final y = layer.position.dy * scaleY;
    final w = layer.width * scaleX;
    final h = layer.height * scaleY;

    if (layer.type == LayerType.image) {
      final localFile = localFiles?[layer.id];
      final url = layer.previewUrl ?? layer.imageUrl ?? layer.originalUrl;
      final frame = layer.imageBackground;

      Widget imageContent;
      if (localFile != null) {
        imageContent = Image.file(localFile, fit: BoxFit.cover);
      } else if (url != null) {
        imageContent = Image.network(url, fit: BoxFit.cover);
      } else {
        imageContent = Container(
          color: Colors.grey[200],
          child: const Center(
              child: Icon(Icons.add_photo_alternate_outlined, color: Colors.grey)),
        );
      }

      Widget layerWidget;
      if (frame == 'polaroid') {
        layerWidget = Container(
          padding: EdgeInsets.fromLTRB(5 * scaleX, 5 * scaleX, 5 * scaleX, 25 * scaleX),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
          ),
          child: imageContent,
        );
        
        // Adjust position/size for the frame effect if needed
        // But for simplicity, we assume the layer frame includes the polaroid border in design
        // Actually the code in detail screen manually adjusted rect. 
        // Let's copy that logic:
        return Positioned(
            left: x - 10 * scaleX, 
            top: y - 10 * scaleY, 
            width: w + 20 * scaleX, 
            height: h + 40 * scaleY, 
            child: GestureDetector(
              onTap: onLayerTap != null ? () => onLayerTap!(layer.id) : onImageTap,
              child: layerWidget,
            ),
         );
      } else {
        layerWidget = imageContent;
      }

      return Positioned(
        left: x,
        top: y,
        width: w,
        height: h,
        child: GestureDetector(
          onTap: onLayerTap != null ? () => onLayerTap!(layer.id) : onImageTap,
          child: layerWidget,
        ),
      );
    } else {
      // Text
      final style = layer.textStyle ?? const TextStyle();
      return Positioned(
        left: x,
        top: y,
        width: w,
        height: h,
        child: Container(
          // color: Colors.black12, // Debug
          alignment: _getAlignment(layer.textAlign),
          child: Text(
            layer.text ?? '',
            textAlign: layer.textAlign ?? TextAlign.center,
            style: style.copyWith(
              fontSize: (style.fontSize ?? 14) * scaleX,
              color: style.color ?? Colors.black,
            ),
          ),
        ),
      );
    }
  }
  
  Alignment _getAlignment(TextAlign? align) {
    switch (align) {
      case TextAlign.left: return Alignment.centerLeft;
      case TextAlign.right: return Alignment.centerRight;
      case TextAlign.justify: return Alignment.center;
      default: return Alignment.center;
    }
  }
}
