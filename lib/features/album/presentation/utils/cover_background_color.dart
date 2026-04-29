import 'dart:convert';

import 'package:flutter/material.dart';

Color? extractCoverBackgroundColor(String raw) {
  if (raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;

    final coverPage = _extractCoverPage(decoded);
    final pageColor = _extractColorFromMap(
      coverPage,
      const ['backgroundColor', 'canvasColor', 'bgColor', 'color'],
    );
    if (pageColor != null) {
      return pageColor.withAlpha(0xFF);
    }
  } catch (_) {
    return null;
  }
  return null;
}

Map<String, dynamic>? _extractCoverPage(Map<String, dynamic> decoded) {
  final pages = decoded['pages'];
  if (pages is! List || pages.isEmpty) return null;
  for (final pageValue in pages) {
    if (pageValue is! Map) continue;
    final page = pageValue.cast<String, dynamic>();
    final isCover = page['isCover'] == true;
    final index = (page['index'] as num?)?.toInt();
    if (isCover || index == 0) return page;
  }

  final first = pages.first;
  if (first is Map) return first.cast<String, dynamic>();
  return null;
}

Color? _extractColorFromMap(Map<String, dynamic>? src, List<String> keys) {
  if (src == null) return null;
  for (final key in keys) {
    final color = _parseDynamicColor(src[key]);
    if (color != null) return color;
  }
  return null;
}

Color? _parseDynamicColor(dynamic value) {
  if (value == null) return null;
  if (value is int) return Color(value);
  if (value is String) {
    final raw = value.trim();
    if (raw.isEmpty) return null;
    final normalized = raw.startsWith('#')
        ? raw.substring(1)
        : raw.replaceFirst(RegExp(r'^0x', caseSensitive: false), '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$|^[0-9a-fA-F]{8}$').hasMatch(normalized)) {
      return null;
    }
    final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
    final parsedValue = int.tryParse(hex, radix: 16);
    return parsedValue == null ? null : Color(parsedValue);
  }
  return null;
}
