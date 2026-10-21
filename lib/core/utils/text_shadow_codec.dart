import 'package:flutter/material.dart';

/// Keeps optional photographic typography shadows consistent after saving and
/// resizing an album. Documents without shadows retain their existing style.
abstract final class TextShadowCodec {
  static List<Shadow>? decode(
    Object? value, {
    double scale = 1,
    double? canvasWidth,
  }) {
    if (value is! List) return null;
    final result = <Shadow>[];
    for (final entry in value.whereType<Map>()) {
      final hex = entry['color'];
      if (hex is! String ||
          !RegExp(r'^#?(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(hex)) {
        continue;
      }
      final offset = entry['offset'];
      final ratio = entry['offsetRatio'];
      final radiusRatio = entry['blurRadiusRatio'];
      final blur = canvasWidth != null && radiusRatio is num
          ? radiusRatio.toDouble() * canvasWidth
          : _number(entry['blurRadius']) * scale;
      final dx = canvasWidth != null && ratio is Map
          ? _number(ratio['dx']) * canvasWidth
          : _number(offset is Map ? offset['dx'] : null) * scale;
      final dy = canvasWidth != null && ratio is Map
          ? _number(ratio['dy']) * canvasWidth
          : _number(offset is Map ? offset['dy'] : null) * scale;
      if (!blur.isFinite || blur < 0 || !dx.isFinite || !dy.isFinite) continue;
      final digits = hex.replaceFirst('#', '');
      result.add(
        Shadow(
          color: Color(
            int.parse(digits.length == 6 ? 'FF$digits' : digits, radix: 16),
          ),
          blurRadius: blur,
          offset: Offset(dx, dy),
        ),
      );
    }
    return result.isEmpty ? null : result;
  }

  static List<Map<String, dynamic>> encode(
    List<Shadow> shadows,
    double canvasWidth,
  ) => [
    for (final shadow in shadows)
      {
        'color':
            '#${shadow.color.toARGB32().toRadixString(16).padLeft(8, '0')}',
        'blurRadius': shadow.blurRadius,
        'blurRadiusRatio': shadow.blurRadius / canvasWidth,
        'offset': {'dx': shadow.offset.dx, 'dy': shadow.offset.dy},
        'offsetRatio': {
          'dx': shadow.offset.dx / canvasWidth,
          'dy': shadow.offset.dy / canvasWidth,
        },
      },
  ];

  static List<Shadow>? scaled(List<Shadow>? shadows, double scale) => shadows
      ?.map(
        (shadow) => Shadow(
          color: shadow.color,
          blurRadius: shadow.blurRadius * scale,
          offset: shadow.offset * scale,
        ),
      )
      .toList(growable: false);

  static double _number(Object? value) => value is num ? value.toDouble() : 0;
}
