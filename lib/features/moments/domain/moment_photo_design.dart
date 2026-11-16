import 'dart:convert';

import 'package:flutter/material.dart';

import '../../album/domain/entities/layer.dart';
import '../../album/domain/entities/layer_export_mapper.dart';

/// A portable reference to this photo's immutable original, never a signed URL.
const momentPhotoOriginalSource = 'moment-photo://original';

/// Private editable artwork. Feed captions deliberately have no place here.
class MomentPhotoDesign {
  MomentPhotoDesign._(this._json);

  static const maximumLayers = 40;
  static const maximumBytes = 128 * 1024;
  final Map<String, dynamic> _json;

  factory MomentPhotoDesign.fromJson(Map<String, dynamic> json) {
    try {
      final copy = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
      _validate(copy);
      return MomentPhotoDesign._(_freeze(copy) as Map<String, dynamic>);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('꾸민 사진 정보를 확인하지 못했어요.');
    }
  }

  factory MomentPhotoDesign.fromLayers({
    required Size canvasSize,
    required Color backgroundColor,
    required List<LayerModel> layers,
    required String photoSource,
  }) {
    dynamic portable(dynamic value, [String? key]) {
      if (value is List) return value.map((item) => portable(item)).toList();
      if (value is Map) {
        return <String, dynamic>{
          for (final entry in value.entries)
            entry.key as String: portable(entry.value, entry.key as String),
        };
      }
      if (_sourceKeys.contains(key) && value == photoSource) {
        return momentPhotoOriginalSource;
      }
      return value;
    }

    return MomentPhotoDesign.fromJson({
      'version': 1,
      'canvas': {'width': canvasSize.width, 'height': canvasSize.height},
      'backgroundColor':
          '#${backgroundColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
      'layers': [
        for (final layer in layers)
          portable(LayerExportMapper.toJson(layer, canvasSize: canvasSize)),
      ],
    });
  }

  Size get canvasSize {
    final canvas = _json['canvas'] as Map;
    return Size(
      (canvas['width'] as num).toDouble(),
      (canvas['height'] as num).toDouble(),
    );
  }

  Color get backgroundColor => Color(
    int.parse((_json['backgroundColor'] as String).substring(1), radix: 16),
  );

  double get aspectRatio => canvasSize.width / canvasSize.height;

  List<String> get fontFamilies => List.unmodifiable({
    for (final raw in _json['layers'] as List)
      if ((raw as Map)['payload'] case final Map payload)
        if (payload['textStyle'] case final Map style)
          if (style['fontFamily'] case final String family)
            if (family.trim().isNotEmpty) family,
  });

  /// Returns a detached copy so editor changes cannot mutate a saved draft.
  Map<String, dynamic> toJson() =>
      jsonDecode(jsonEncode(_json)) as Map<String, dynamic>;

  List<LayerModel> layersForPhoto(String photoSource, {Size? canvasSize}) {
    dynamic resolve(dynamic value, [String? key]) {
      if (value is List) return value.map((item) => resolve(item)).toList();
      if (value is Map) {
        return <String, dynamic>{
          for (final entry in value.entries)
            entry.key as String: resolve(entry.value, entry.key as String),
        };
      }
      return _sourceKeys.contains(key) && value == momentPhotoOriginalSource
          ? photoSource
          : value;
    }

    return List.unmodifiable([
      for (final raw in _json['layers'] as List)
        LayerExportMapper.fromJson(
          Map<String, dynamic>.from(resolve(raw) as Map),
          canvasSize: canvasSize ?? this.canvasSize,
        ),
    ]);
  }

  static const _sourceKeys = {
    'originalUrl',
    'previewUrl',
    'imageUrl',
    'textFillImageUrl',
  };
  static const _layerKeys = {
    'id',
    'type',
    'zIndex',
    'x',
    'y',
    'width',
    'height',
    'scale',
    'rotation',
    'opacity',
    'templateContent',
    'payload',
    'canvasClip',
  };
  static const freeStickerKeys = {
    'stickerBlueStar',
    'stickerHeartRed',
    'stickerLeafGreen',
    'stickerFlowerPink',
    'stickerPaperClip',
    'stickerTapeBeige',
    'stickerCloudSoft',
    'stickerCloverGreen',
  };
  static const _imageKeys = {
    'imageBackground',
    'imageTemplate',
    'imageZoom',
    'imageOffsetRatio',
    'originalUrl',
    'previewUrl',
    'imageUrl',
  };
  static const _decorationKeys = {
    'imageBackground',
    'imageTemplate',
    'fillColor',
    'borderColor',
    'borderWidth',
    'cornerRadius',
    'originalUrl',
    'previewUrl',
    'imageUrl',
  };
  static const _textKeys = {
    'text',
    'textAlign',
    'textStyleType',
    'textBackground',
    'textFillMode',
    'textFillImageUrl',
    'bubbleColor',
    'textStyle',
  };

  static Never _invalid() =>
      throw const FormatException('꾸민 사진 정보를 확인하지 못했어요.');

  static double _number(dynamic value, double min, double max) {
    if (value is! num || !value.isFinite || value < min || value > max) {
      _invalid();
    }
    return (value as num).toDouble();
  }

  static void _optionalNumber(Map value, String key, double min, double max) {
    if (value[key] != null) _number(value[key], min, max);
  }

  static void _string(dynamic value, [int limit = 4000]) {
    if (value != null && (value is! String || value.length > limit)) _invalid();
  }

  static void _color(dynamic value) {
    if (value != null &&
        (value is! String ||
            !RegExp(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(value))) {
      _invalid();
    }
  }

  static void _pair(dynamic value, Set<String> keys, double min, double max) {
    if (value == null) return;
    if (value is! Map ||
        value.length != 2 ||
        value.keys.any((key) => !keys.contains(key)))
      _invalid();
    for (final key in keys) _number((value as Map)[key], min, max);
  }

  static void _textStyle(dynamic value) {
    if (value == null) return;
    if (value is! Map ||
        value.keys.any(
          (key) => !{
            'fontSize',
            'fontSizeRatio',
            'fontWeight',
            'fontStyle',
            'fontFamily',
            'color',
            'letterSpacing',
            'height',
            'shadows',
          }.contains(key),
        ))
      _invalid();
    final style = value as Map;
    _optionalNumber(style, 'fontSize', .1, 4096);
    _optionalNumber(style, 'fontSizeRatio', .00001, 8);
    _optionalNumber(style, 'letterSpacing', -1000, 1000);
    _optionalNumber(style, 'height', .01, 20);
    for (final field in ['fontWeight', 'fontStyle']) {
      if (style[field] != null &&
          (style[field] is! int ||
              style[field] < 0 ||
              style[field] > (field == 'fontStyle' ? 1 : 8))) {
        _invalid();
      }
    }
    _string(style['fontFamily'], 100);
    _color(style['color']);
    final shadows = style['shadows'];
    if (shadows == null) return;
    if (shadows is! List || shadows.length > 8) _invalid();
    for (final raw in shadows as List) {
      if (raw is! Map ||
          raw.keys.any(
            (key) => !{
              'color',
              'blurRadius',
              'blurRadiusRatio',
              'offset',
              'offsetRatio',
            }.contains(key),
          ))
        _invalid();
      final shadow = raw as Map;
      if (shadow['color'] == null) _invalid();
      _color(shadow['color']);
      _optionalNumber(shadow, 'blurRadius', 0, 4096);
      _optionalNumber(shadow, 'blurRadiusRatio', 0, 8);
      _pair(shadow['offset'], {'dx', 'dy'}, -4096, 4096);
      _pair(shadow['offsetRatio'], {'dx', 'dy'}, -8, 8);
    }
  }

  static void _validate(Map<String, dynamic> value) {
    if (utf8.encode(jsonEncode(value)).length > maximumBytes ||
        value.keys.any(
          (key) =>
              !{'version', 'canvas', 'backgroundColor', 'layers'}.contains(key),
        ) ||
        value['version'] != 1)
      _invalid();
    final canvas = value['canvas'];
    if (canvas is! Map ||
        canvas.length != 2 ||
        canvas.keys.any((key) => key != 'width' && key != 'height'))
      _invalid();
    final width = _number((canvas as Map)['width'], 64, 4096);
    final height = _number(canvas['height'], 64, 4096);
    if (width / height < .1 ||
        width / height > 10 ||
        value['backgroundColor'] is! String ||
        !RegExp(
          r'^#[0-9a-fA-F]{8}$',
        ).hasMatch(value['backgroundColor'] as String)) {
      _invalid();
    }
    final layers = value['layers'];
    if (layers is! List || layers.isEmpty || layers.length > maximumLayers)
      _invalid();
    final ids = <String>{};
    var hasOriginal = false;
    for (final raw in layers as List) {
      if (raw is! Map || raw.keys.any((key) => !_layerKeys.contains(key)))
        _invalid();
      final layer = raw as Map;
      final id = layer['id'];
      final type = layer['type'];
      if (id is! String ||
          id.isEmpty ||
          id.length > 128 ||
          !ids.add(id) ||
          !{'IMAGE', 'TEXT', 'DECORATION'}.contains(type))
        _invalid();
      _number(layer['x'], -4, 4);
      _number(layer['y'], -4, 4);
      _number(layer['width'], .00001, 8);
      _number(layer['height'], .00001, 8);
      _number(layer['scale'] ?? 1, .01, 20);
      _number(layer['rotation'] ?? 0, -3600, 3600);
      _number(layer['opacity'] ?? 1, 0, 1);
      final z = layer['zIndex'];
      if (z != null && (z is! int || z.abs() > 10000)) _invalid();
      if (layer['templateContent'] != null && layer['templateContent'] is! bool)
        _invalid();
      final clip = layer['canvasClip'];
      if (clip != null) {
        if (clip is! Map ||
            clip.length != 4 ||
            clip.keys.any(
              (key) => !{'x', 'y', 'width', 'height'}.contains(key),
            ))
          _invalid();
        _number((clip as Map)['x'], -4, 4);
        _number(clip['y'], -4, 4);
        _number(clip['width'], .00001, 8);
        _number(clip['height'], .00001, 8);
      }
      final payload = layer['payload'];
      final allowed = type == 'IMAGE'
          ? _imageKeys
          : type == 'TEXT'
          ? _textKeys
          : _decorationKeys;
      if (payload is! Map || payload.keys.any((key) => !allowed.contains(key)))
        _invalid();
      final p = payload as Map;
      for (final key in _sourceKeys) {
        final source = p[key];
        _string(source);
        if (source != null &&
            source != '' &&
            source != momentPhotoOriginalSource)
          _invalid();
        if (type == 'DECORATION' && source != null && source != '') _invalid();
        if (type == 'IMAGE' && source == momentPhotoOriginalSource)
          hasOriginal = true;
      }
      for (final key in [
        'imageBackground',
        'imageTemplate',
        'text',
        'textAlign',
        'textStyleType',
        'textBackground',
        'textFillMode',
      ])
        _string(p[key]);
      if (type == 'IMAGE') {
        if (![
          p['originalUrl'],
          p['previewUrl'],
          p['imageUrl'],
        ].contains(momentPhotoOriginalSource))
          _invalid();
        _optionalNumber(p, 'imageZoom', 1, 4);
        _pair(p['imageOffsetRatio'], {'x', 'y'}, -8, 8);
      } else if (type == 'DECORATION' &&
          !freeStickerKeys.contains(p['imageBackground'])) {
        _invalid();
      }
      for (final key in ['fillColor', 'borderColor', 'bubbleColor'])
        _color(p[key]);
      _optionalNumber(p, 'borderWidth', 0, 1000);
      _optionalNumber(p, 'cornerRadius', 0, 4096);
      _textStyle(p['textStyle']);
      // Older normalized maps may omit an unrotated layer's angle.
      layer['rotation'] ??= 0;
      // Parse at the trust boundary so malformed data never reaches a painter.
      LayerExportMapper.fromJson(
        Map<String, dynamic>.from(layer),
        canvasSize: Size(width, height),
      );
    }
    if (!hasOriginal) _invalid();
  }

  static dynamic _freeze(dynamic value) {
    if (value is Map)
      return Map<String, dynamic>.unmodifiable({
        for (final entry in value.entries)
          entry.key as String: _freeze(entry.value),
      });
    if (value is List) return List<dynamic>.unmodifiable(value.map(_freeze));
    return value;
  }
}
