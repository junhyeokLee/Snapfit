import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
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
    final ordered = [...layers]..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    final bounds = _contentBounds(ordered);

    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: ordered
            .map((layer) => _buildLayerWidget(layer, width, height, bounds))
            .toList(),
      ),
    );
  }

  Rect _contentBounds(List<LayerModel> ordered) {
    if (ordered.isEmpty) return const Rect.fromLTWH(0, 0, 500, 500);
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;
    for (final l in ordered) {
      minX = math.min(minX, l.position.dx);
      minY = math.min(minY, l.position.dy);
      maxX = math.max(maxX, l.position.dx + l.width);
      maxY = math.max(maxY, l.position.dy + l.height);
    }
    if (!minX.isFinite || !minY.isFinite || !maxX.isFinite || !maxY.isFinite) {
      return const Rect.fromLTWH(0, 0, 500, 500);
    }
    final w = math.max(1.0, maxX - minX);
    final h = math.max(1.0, maxY - minY);
    return Rect.fromLTWH(minX, minY, w, h);
  }

  Widget _buildLayerWidget(
    LayerModel layer,
    double canvasW,
    double canvasH,
    Rect bounds,
  ) {
    final x = ((layer.position.dx - bounds.left) / bounds.width) * canvasW;
    final y = ((layer.position.dy - bounds.top) / bounds.height) * canvasH;
    final w = (layer.width / bounds.width) * canvasW;
    final h = (layer.height / bounds.height) * canvasH;

    final safeW = w.clamp(8.0, canvasW).toDouble();
    final safeH = h.clamp(8.0, canvasH).toDouble();
    final safeX = x.clamp(0.0, canvasW - safeW).toDouble();
    final safeY = y.clamp(0.0, canvasH - safeH).toDouble();

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
            child: Icon(Icons.add_photo_alternate_outlined, color: Colors.grey),
          ),
        );
      }

      Widget layerWidget;
      if (frame == 'polaroid') {
        layerWidget = Container(
          padding: EdgeInsets.fromLTRB(5, 5, 5, 25),
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
          left: (safeX - 6).clamp(0.0, canvasW - safeW),
          top: (safeY - 6).clamp(0.0, canvasH - safeH),
          width: (safeW + 12).clamp(8.0, canvasW),
          height: (safeH + 24).clamp(8.0, canvasH),
          child: GestureDetector(
            onTap: onLayerTap != null
                ? () => onLayerTap!(layer.id)
                : onImageTap,
            child: layerWidget,
          ),
        );
      } else {
        layerWidget = imageContent;
      }

      return Positioned(
        left: safeX,
        top: safeY,
        width: safeW,
        height: safeH,
        child: GestureDetector(
          onTap: onLayerTap != null ? () => onLayerTap!(layer.id) : onImageTap,
          child: layerWidget,
        ),
      );
    } else if (layer.type == LayerType.decoration ||
        layer.type == LayerType.sticker) {
      return Positioned(
        left: safeX,
        top: safeY,
        width: safeW,
        height: safeH,
        child: _buildDecorationWidget(layer),
      );
    } else {
      // Text
      final style = layer.textStyle ?? const TextStyle();
      return Positioned(
        left: safeX,
        top: safeY,
        width: safeW,
        height: safeH,
        child: Container(
          // color: Colors.black12, // Debug
          alignment: _getAlignment(layer.textAlign),
          child: Text(
            layer.text ?? '',
            textAlign: layer.textAlign ?? TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(
              fontSize: (style.fontSize ?? 14) * (safeW / 500.0),
              color: style.color ?? Colors.black,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildDecorationWidget(LayerModel layer) {
    final bg = layer.imageBackground ?? '';
    if (bg == 'paperWarm') {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF6EDE0), Color(0xFFECDDCB)],
          ),
        ),
      );
    }
    if (bg == 'paperWhite') {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFAFAF7), Color(0xFFF0F0EC)],
          ),
        ),
      );
    }
    if (bg == 'paperBeige') {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF1E8D7), Color(0xFFE5DCC9)],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Alignment _getAlignment(TextAlign? align) {
    switch (align) {
      case TextAlign.left:
        return Alignment.centerLeft;
      case TextAlign.right:
        return Alignment.centerRight;
      case TextAlign.justify:
        return Alignment.center;
      default:
        return Alignment.center;
    }
  }
}
