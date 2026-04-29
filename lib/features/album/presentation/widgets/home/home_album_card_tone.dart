import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../domain/entities/album.dart';

Color? albumCardToneOrNull(Album album) {
  return _extractCoverBackgroundTone(album.coverLayersJson);
}

Color albumCardTone(Album album) {
  return albumCardToneOrNull(album) ?? const Color(0xFFE8D6B8);
}

Color softenedAlbumCardToneForBrightness(
  Color tone,
  Brightness brightness,
) {
  return brightness == Brightness.dark
      ? _softenedAlbumCardToneDark(tone)
      : _softenedAlbumCardToneLight(tone);
}

Color softenedHomeBackgroundToneForBrightness(
  Color tone,
  Brightness brightness,
) {
  return brightness == Brightness.dark
      ? _softenedHomeBackgroundToneDark(tone)
      : _softenedHomeBackgroundToneLight(tone);
}

Color readableAlbumCardTone(Color tone) {
  final hsl = HSLColor.fromColor(tone);
  final luminance = tone.computeLuminance();

  // 원색에 가깝게 유지하되, 너무 탁하거나 완전 블랙으로 뭉개지는 경우만 최소 보정
  final boostedSaturation = (hsl.saturation * 0.96).clamp(0.10, 0.78);
  final minLightness = luminance < 0.06
      ? 0.12
      : luminance < 0.12
      ? 0.16
      : 0.20;
  final adjustedLightness = hsl.lightness.clamp(minLightness, 0.86);

  return hsl
      .withSaturation(boostedSaturation.toDouble())
      .withLightness(adjustedLightness.toDouble())
      .toColor();
}

Color softenedAlbumCardTone(Color tone) {
  return _softenedAlbumCardToneLight(tone);
}

Color softenedHomeBackgroundTone(Color tone) {
  return _softenedHomeBackgroundToneLight(tone);
}

Color _softenedAlbumCardToneLight(Color tone) {
  final hsl = HSLColor.fromColor(tone);
  // final softenedSaturation = (hsl.saturation * 0.78).clamp(0.12, 0.72);
  final softenedSaturation = (hsl.saturation * 0.78).clamp(0.02, 0.62);
  final softenedLightness = (hsl.lightness + 0.12).clamp(0.32, 0.58);
  return hsl
      .withSaturation(softenedSaturation.toDouble())
      .withLightness(softenedLightness.toDouble())
      .toColor();
}

Color _softenedHomeBackgroundToneLight(Color tone) {
  final hsl = HSLColor.fromColor(tone);
  // final softenedSaturation = (hsl.saturation * 0.78).clamp(0.02, 0.62);
  // final softenedLightness = (hsl.lightness + 0.12).clamp(0.42, 0.68);
  final softenedSaturation = (hsl.saturation * 0.78).clamp(0.02, 0.62);
  final softenedLightness = (hsl.lightness + 0.12).clamp(0.32, 0.58);
  return hsl
      .withSaturation(softenedSaturation.toDouble())
      .withLightness(softenedLightness.toDouble())
      .toColor();
}

Color _softenedAlbumCardToneDark(Color tone) {
  final hsl = HSLColor.fromColor(tone);
  final softenedSaturation = (hsl.saturation * 0.78).clamp(0.12, 0.72);
  final softenedLightness = (hsl.lightness + 0.12).clamp(0.42, 0.68);
  return hsl
      .withSaturation(softenedSaturation.toDouble())
      .withLightness(softenedLightness.toDouble())
      .toColor();
}

// final softenedSaturation = (hsl.saturation * 0.54).clamp(0.08, 0.46);
// final softenedLightness = (hsl.lightness * 0.42 + 0.05).clamp(0.14, 0.24);
// final softenedLightness = (hsl.lightness + 0.12).clamp(0.72, 0.88);

Color _softenedHomeBackgroundToneDark(Color tone) {
  final hsl = HSLColor.fromColor(tone);
  final softenedSaturation = (hsl.saturation * 0.78).clamp(0.12, 0.72);
  final softenedLightness = (hsl.lightness + 0.12).clamp(0.42, 0.68);
  return hsl
      .withSaturation(softenedSaturation.toDouble())
      .withLightness(softenedLightness.toDouble())
      .toColor();
}

Color? _extractCoverBackgroundTone(String raw) {
  if (raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;

    final coverPage = _extractCoverPage(decoded);
    if (coverPage != null) {
      final pageColor = _extractColorFromMap(coverPage, const [
        'backgroundColor',
        'canvasColor',
        'bgColor',
        'color',
      ]);
      if (pageColor != null) return pageColor;
    }

    final layers = _extractCoverLayers(decoded, coverPage: coverPage);
    for (final rawLayer in layers.reversed) {
      if (rawLayer is! Map) continue;
      final layer = rawLayer.cast<String, dynamic>();
      final payload = (layer['payload'] is Map)
          ? (layer['payload'] as Map).cast<String, dynamic>()
          : const <String, dynamic>{};

      final layerColor = _extractColorFromMap(payload, const [
        'backgroundColor',
        'canvasColor',
        'bgColor',
        'fillColor',
        'bubbleColor',
        'color',
      ]);
      if (layerColor != null) return layerColor;

      final styleColor = _templateBackgroundStyleColor(
        payload['imageBackground'] ?? layer['imageBackground'],
      );
      if (styleColor != null) return styleColor;
    }
  } catch (_) {
    return null;
  }
  return null;
}

Map<String, dynamic>? _extractCoverPage(Map<String, dynamic> decoded) {
  final pages = decoded['pages'];
  if (pages is! List || pages.isEmpty) return null;
  for (final p in pages) {
    if (p is! Map) continue;
    final page = p.cast<String, dynamic>();
    final isCover = page['isCover'] == true;
    final idx = (page['index'] as num?)?.toInt();
    if (isCover || idx == 0) return page;
  }
  final first = pages.first;
  if (first is Map) return first.cast<String, dynamic>();
  return null;
}

List<dynamic> _extractCoverLayers(
  Map<String, dynamic> decoded, {
  Map<String, dynamic>? coverPage,
}) {
  final fromCoverPage = coverPage?['layers'];
  if (fromCoverPage is List) return fromCoverPage;
  final fromRoot = decoded['layers'];
  if (fromRoot is List) return fromRoot;
  return const <dynamic>[];
}

Color? _extractColorFromMap(Map<String, dynamic> src, List<String> keys) {
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
    if (raw.startsWith('#')) return _parseHexColor(raw);

    final noPrefix = raw.replaceAll(RegExp(r'^0x', caseSensitive: false), '');
    if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(noPrefix) ||
        RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(noPrefix)) {
      return _parseHexColor('#$noPrefix');
    }
    final numeric = int.tryParse(raw);
    if (numeric != null) return Color(numeric);
  }
  return null;
}

Color? _parseHexColor(String hex) {
  final cleaned = hex.replaceFirst('#', '').trim();
  if (cleaned.length == 6) {
    return Color(int.parse('FF$cleaned', radix: 16));
  }
  if (cleaned.length == 8) {
    return Color(int.parse(cleaned, radix: 16));
  }
  return null;
}

Color? _templateBackgroundStyleColor(dynamic rawStyle) {
  final style = rawStyle?.toString().trim();
  switch (style) {
    case 'paperWhite':
      return const Color(0xFFFFFFFF);
    case 'paperWhiteWarm':
      return const Color(0xFFF7F1E8);
    case 'paperWarm':
      return const Color(0xFFF1E6D8);
    case 'paperBeige':
      return const Color(0xFFE9DDCB);
    case 'paperYellow':
      return const Color(0xFFF6E6B0);
    case 'paperPink':
      return const Color(0xFFF1DDE2);
    case 'paperGray':
      return const Color(0xFFE9EDF2);
    case 'paperBrown':
    case 'paperBrownLined':
      return const Color(0xFFD8C7B5);
    case 'paperBrownPlain':
      return const Color(0xFFCDB08E);
    case 'minimalGray':
      return const Color(0xFFD8DEE6);
    case 'softSkyBloom':
      return const Color(0xFF8FBCE7);
    case 'blossomPinkDust':
      return const Color(0xFFE688A6);
    case 'darkVignette':
      return const Color(0xFF2E2C3E);
    case 'dreamyNightSky':
      return const Color(0xFF1D235A);
    case 'deepNavy':
      return const Color(0xFF24374A);
    case 'cloudSkyBlue':
      return const Color(0xFFDCE7EF);
    case 'skyBlue':
      return const Color(0xFFCDE2F2);
    case 'notebookPunchPage':
      return const Color(0xFFF7F1E8);
  }
  return null;
}
