import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/design_templates.dart';
import '../../features/album/domain/entities/layer.dart';

/// Data-driven template engine (Phase 1)
/// - Keeps existing `DesignTemplate` runtime contract
/// - Compiles JSON maps into LayerModel list
class DataTemplateEngine {
  const DataTemplateEngine._();

  static DesignTemplate templateFromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString();
    final name = (json['name'] ?? id).toString();
    final forCover = json['forCover'] == true;
    final aspect = _parseAspect((json['aspect'] ?? 'any').toString());
    final category = (json['category'] ?? '전체').toString();
    final tags = _parseStringList(json['tags']);

    return DesignTemplate(
      id: id,
      name: name,
      forCover: forCover,
      aspect: aspect,
      category: category,
      tags: tags,
      buildLayers: (canvas) => buildLayersFromJson(json, canvas),
    );
  }

  static List<LayerModel> buildLayersFromJson(
    Map<String, dynamic> spec,
    Size canvas,
  ) {
    final layersRaw = spec['layers'];
    if (layersRaw is! List) return const [];
    final aspectKey = _aspectKey(canvas);

    final variants = (spec['variants'] is Map<String, dynamic>)
        ? (spec['variants'] as Map<String, dynamic>)
        : const <String, dynamic>{};
    final variant = (variants[aspectKey] is Map<String, dynamic>)
        ? (variants[aspectKey] as Map<String, dynamic>)
        : const <String, dynamic>{};

    final globalScale = _toDouble(variant['scale'], 1.0);
    final globalOffsetX = _toDouble(variant['offsetX'], 0.0) * canvas.width;
    final globalOffsetY = _toDouble(variant['offsetY'], 0.0) * canvas.height;

    final out = <LayerModel>[];
    for (final raw in layersRaw) {
      if (raw is! Map<String, dynamic>) continue;
      final layer = _compileLayer(
        raw,
        canvas: canvas,
        aspectKey: aspectKey,
        globalScale: globalScale,
        globalOffsetX: globalOffsetX,
        globalOffsetY: globalOffsetY,
      );
      if (layer != null) out.add(layer);
    }
    // Default-on: keep template contents centered and safe across ratios.
    // Explicit `autoFit: false` can disable this per template.
    final autoFit = spec['autoFit'] != false;
    final autoFitPadding = _toDouble(
      spec['autoFitPadding'],
      0.0,
    ).clamp(0.0, 0.2);
    final fitted = (!autoFit || out.isEmpty)
        ? out
        : _autoFitLayers(out, canvas, autoFitPadding);
    final resolved = _resolveTextOverlaps(fitted, canvas);
    return _clampLayersToCanvas(resolved, canvas);
  }

  static List<LayerModel> _autoFitLayers(
    List<LayerModel> layers,
    Size canvas,
    double paddingRatio,
  ) {
    final content = layers.where((layer) {
      if (layer.type == LayerType.decoration &&
          layer.position == Offset.zero &&
          (layer.width - canvas.width).abs() <= 0.1 &&
          (layer.height - canvas.height).abs() <= 0.1) {
        return false;
      }
      return true;
    }).toList();
    if (content.isEmpty) return layers;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    for (final layer in content) {
      final rect = Rect.fromLTWH(
        layer.position.dx,
        layer.position.dy,
        layer.width,
        layer.height,
      );
      minX = math.min(minX, rect.left);
      minY = math.min(minY, rect.top);
      maxX = math.max(maxX, rect.right);
      maxY = math.max(maxY, rect.bottom);
    }

    final bounds = Rect.fromLTRB(minX, minY, maxX, maxY);
    if (!bounds.isFinite || bounds.width <= 0 || bounds.height <= 0) {
      return layers;
    }

    final insetW = canvas.width * paddingRatio;
    final insetH = canvas.height * paddingRatio;
    final target = Rect.fromLTWH(
      insetW,
      insetH,
      canvas.width - (insetW * 2),
      canvas.height - (insetH * 2),
    );
    if (target.width <= 0 || target.height <= 0) return layers;

    final fitScale = math.min(
      1.0,
      math.min(target.width / bounds.width, target.height / bounds.height),
    );
    if (fitScale >= 0.999) return layers;

    final transformed = <LayerModel>[];
    for (final layer in layers) {
      if (layer.type == LayerType.decoration &&
          layer.position == Offset.zero &&
          (layer.width - canvas.width).abs() <= 0.1 &&
          (layer.height - canvas.height).abs() <= 0.1) {
        transformed.add(layer);
        continue;
      }
      final center = Offset(
        layer.position.dx + (layer.width / 2),
        layer.position.dy + (layer.height / 2),
      );
      final fittedCenter =
          target.center + ((center - bounds.center) * fitScale);
      final fittedW = layer.width * fitScale;
      final fittedH = layer.height * fitScale;
      final baseStyle = layer.textStyle;
      final nextStyle = baseStyle?.copyWith(
        fontSize: (baseStyle.fontSize ?? 12) * fitScale,
        letterSpacing: baseStyle.letterSpacing == null
            ? null
            : baseStyle.letterSpacing! * fitScale,
      );
      transformed.add(
        layer.copyWith(
          position: Offset(
            fittedCenter.dx - (fittedW / 2),
            fittedCenter.dy - (fittedH / 2),
          ),
          width: fittedW,
          height: fittedH,
          textStyle: nextStyle,
        ),
      );
    }
    return transformed;
  }

  static List<LayerModel> _resolveTextOverlaps(
    List<LayerModel> layers,
    Size canvas,
  ) {
    if (layers.length < 2) return layers;
    final sorted = [...layers]..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    final placed = <LayerModel>[];

    Rect _rect(LayerModel l) =>
        Rect.fromLTWH(l.position.dx, l.position.dy, l.width, l.height);

    for (final layer in sorted) {
      if (layer.type != LayerType.text) {
        placed.add(layer);
        continue;
      }

      var current = layer;
      var box = _rect(current);
      final step = math.max(4.0, canvas.height * 0.008);
      var guard = 0;
      while (guard < 8) {
        final overlaps = placed.any((p) {
          if (p.type == LayerType.decoration &&
              p.position == Offset.zero &&
              (p.width - canvas.width).abs() <= 0.1 &&
              (p.height - canvas.height).abs() <= 0.1) {
            return false;
          }
          return box.overlaps(_rect(p));
        });
        if (!overlaps) break;
        final nextTop = math.min(
          canvas.height - current.height,
          box.top + step,
        );
        if ((nextTop - box.top).abs() < 0.1) break;
        current = current.copyWith(
          position: Offset(current.position.dx, nextTop),
        );
        box = _rect(current);
        guard++;
      }
      if (guard >= 8) {
        final style = current.textStyle;
        if (style?.fontSize != null) {
          final base = style!.fontSize!;
          if (base.isFinite) {
            final minSize = math.min(8.0, base);
            final maxSize = math.max(8.0, base);
            final shrunk = (base * 0.9).clamp(minSize, maxSize).toDouble();
            current = current.copyWith(
              textStyle: style.copyWith(fontSize: shrunk),
            );
          }
        }
      }
      placed.add(current);
    }
    return placed..sort((a, b) => a.zIndex.compareTo(b.zIndex));
  }

  static List<LayerModel> _clampLayersToCanvas(
    List<LayerModel> layers,
    Size canvas,
  ) {
    const pad = 2.0;
    return layers.map((layer) {
      if (layer.type == LayerType.decoration &&
          layer.position == Offset.zero &&
          (layer.width - canvas.width).abs() <= 0.1 &&
          (layer.height - canvas.height).abs() <= 0.1) {
        return layer;
      }
      final maxW = math.max(10.0, canvas.width - (pad * 2));
      final maxH = math.max(10.0, canvas.height - (pad * 2));
      final w = layer.width.clamp(10.0, maxW).toDouble();
      final h = layer.height.clamp(10.0, maxH).toDouble();
      final x = layer.position.dx
          .clamp(pad, math.max(pad, canvas.width - w - pad))
          .toDouble();
      final y = layer.position.dy
          .clamp(pad, math.max(pad, canvas.height - h - pad))
          .toDouble();
      return layer.copyWith(position: Offset(x, y), width: w, height: h);
    }).toList();
  }

  static LayerModel? _compileLayer(
    Map<String, dynamic> baseLayer, {
    required Size canvas,
    required String aspectKey,
    required double globalScale,
    required double globalOffsetX,
    required double globalOffsetY,
  }) {
    final merged = _applyAspectOverrides(baseLayer, aspectKey);
    final id = (merged['id'] ?? '').toString();
    if (id.isEmpty) return null;

    final type = _parseLayerType((merged['type'] ?? 'image').toString());
    final x = _toDouble(merged['x'], 0);
    final y = _toDouble(merged['y'], 0);
    final w = _toDouble(merged['w'], 1);
    final h = _toDouble(merged['h'], 1);
    final rot = _toDouble(merged['rotation'], 0);
    final z = _toInt(merged['z'], 0);
    final opacity = _toDouble(merged['opacity'], 1.0).clamp(0.0, 1.0);

    final left = x * canvas.width;
    final top = y * canvas.height;
    final width = w * canvas.width;
    final height = h * canvas.height;

    var transformed = _applyGlobalTransform(
      left: left,
      top: top,
      width: width,
      height: height,
      canvas: canvas,
      globalScale: globalScale,
      globalOffsetX: globalOffsetX,
      globalOffsetY: globalOffsetY,
    );

    // Dense collage templates sometimes generate tiny slots on non-portrait ratios.
    // Keep a minimum visible slot size so user images don't disappear.
    if ((type == LayerType.image || type == LayerType.sticker) &&
        (transformed.width < 26 || transformed.height < 26)) {
      final minW = math.max(26.0, transformed.width);
      final minH = math.max(26.0, transformed.height);
      final center = Offset(
        transformed.left + (transformed.width / 2),
        transformed.top + (transformed.height / 2),
      );
      transformed = _Rect(
        center.dx - (minW / 2),
        center.dy - (minH / 2),
        minW,
        minH,
      );
    }

    if (type == LayerType.text) {
      final style = (merged['style'] is Map<String, dynamic>)
          ? (merged['style'] as Map<String, dynamic>)
          : const <String, dynamic>{};
      final color = _parseColor(style['color']) ?? Colors.black87;
      final fontSize = _toDouble(style['fontSize'], 14);
      final family = style['fontFamily']?.toString();
      final weight = _parseWeight(style['fontWeight']?.toString());
      final letterSpacing = _toNullableDouble(style['letterSpacing']);
      final heightMul = _toNullableDouble(style['height']);
      final align = _parseAlign((merged['align'] ?? 'center').toString());

      // Use shorter side as baseline to reduce ratio-dependent drift
      // between preview and applied canvases.
      final baseUnit = math.min(canvas.width, canvas.height);
      final rawFontSize = fontSize * (baseUnit / 300.0) * globalScale;
      final multiLine = ((merged['text'] ?? '').toString()).contains('\n');
      final maxFontByBox = math.max(
        8.0,
        transformed.height * (multiLine ? 0.52 : 0.76),
      );
      final fittedFontSize = math.min(rawFontSize, maxFontByBox);

      return LayerModel(
        id: id,
        type: LayerType.text,
        position: Offset(transformed.left, transformed.top),
        width: transformed.width,
        height: transformed.height,
        rotation: rot,
        text: (merged['text'] ?? '').toString(),
        textBackground: merged['textBackground']?.toString(),
        textAlign: align,
        textStyleType: TextStyleType.none,
        opacity: opacity,
        zIndex: z,
        textStyle: TextStyle(
          fontSize: fittedFontSize,
          color: color,
          fontWeight: weight,
          fontFamily: family,
          letterSpacing: letterSpacing == null
              ? null
              : letterSpacing * globalScale,
          height: heightMul,
        ),
      );
    }

    String? frame;
    String? imageUrl;
    if (type == LayerType.decoration) {
      frame = (merged['style'] ?? merged['frame'])?.toString();
    } else {
      frame = merged['frame']?.toString();
      imageUrl = merged['imageUrl']?.toString();
      final asset = merged['asset']?.toString();
      if (asset != null && asset.isNotEmpty) {
        imageUrl = asset.startsWith('asset:') ? asset : 'asset:$asset';
      }
    }

    return LayerModel(
      id: id,
      type: type,
      position: Offset(transformed.left, transformed.top),
      width: transformed.width,
      height: transformed.height,
      rotation: rot,
      imageBackground: frame,
      imageUrl: imageUrl,
      opacity: opacity,
      zIndex: z,
    );
  }

  static _Rect _applyGlobalTransform({
    required double left,
    required double top,
    required double width,
    required double height,
    required Size canvas,
    required double globalScale,
    required double globalOffsetX,
    required double globalOffsetY,
  }) {
    if ((globalScale - 1).abs() < 0.0001 &&
        globalOffsetX.abs() < 0.0001 &&
        globalOffsetY.abs() < 0.0001) {
      return _Rect(left, top, width, height);
    }

    final canvasCenter = Offset(canvas.width / 2, canvas.height / 2);
    final center = Offset(left + (width / 2), top + (height / 2));
    final transformedCenter =
        canvasCenter +
        ((center - canvasCenter) * globalScale) +
        Offset(globalOffsetX, globalOffsetY);
    final newW = width * globalScale;
    final newH = height * globalScale;
    return _Rect(
      transformedCenter.dx - (newW / 2),
      transformedCenter.dy - (newH / 2),
      newW,
      newH,
    );
  }

  static Map<String, dynamic> _applyAspectOverrides(
    Map<String, dynamic> base,
    String aspectKey,
  ) {
    final merged = Map<String, dynamic>.from(base);
    final overrides = base['aspectOverrides'];
    if (overrides is Map<String, dynamic>) {
      final selected = overrides[aspectKey];
      if (selected is Map<String, dynamic>) {
        merged.addAll(selected);
      }
    }
    return merged;
  }

  static TemplateAspect _parseAspect(String raw) {
    switch (raw) {
      case 'portrait':
        return TemplateAspect.portrait;
      case 'square':
        return TemplateAspect.square;
      case 'landscape':
        return TemplateAspect.landscape;
      default:
        return TemplateAspect.any;
    }
  }

  static String _aspectKey(Size canvas) {
    final ratio = canvas.width / canvas.height;
    if ((ratio - 1.0).abs() <= 0.08) return 'square';
    return ratio > 1 ? 'landscape' : 'portrait';
  }

  static LayerType _parseLayerType(String raw) {
    switch (raw) {
      case 'text':
        return LayerType.text;
      case 'sticker':
        return LayerType.sticker;
      case 'decoration':
      case 'background':
        return LayerType.decoration;
      default:
        return LayerType.image;
    }
  }

  static TextAlign _parseAlign(String raw) {
    switch (raw) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      case 'justify':
        return TextAlign.justify;
      default:
        return TextAlign.center;
    }
  }

  static FontWeight _parseWeight(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'w100':
        return FontWeight.w100;
      case 'w200':
        return FontWeight.w200;
      case 'w300':
        return FontWeight.w300;
      case 'w400':
        return FontWeight.w400;
      case 'w500':
        return FontWeight.w500;
      case 'w600':
        return FontWeight.w600;
      case 'w700':
        return FontWeight.w700;
      case 'w800':
        return FontWeight.w800;
      case 'w900':
        return FontWeight.w900;
      default:
        return FontWeight.w600;
    }
  }

  static Color? _parseColor(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return Color(raw);
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    final hex = s.startsWith('#') ? s.substring(1) : s;
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return null;
  }

  static double _toDouble(Object? raw, double fallback) {
    if (raw is num) return raw.toDouble();
    final parsed = double.tryParse(raw?.toString() ?? '');
    return parsed ?? fallback;
  }

  static double? _toNullableDouble(Object? raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString());
  }

  static int _toInt(Object? raw, int fallback) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }

  static List<String> _parseStringList(Object? raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }
}

class _Rect {
  final double left;
  final double top;
  final double width;
  final double height;

  const _Rect(this.left, this.top, this.width, this.height);
}
