import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/cover_size.dart';
import 'layer.dart';

class LayerExportMapper {
  /// 1. 서버 저장용 JSON으로 변환 (상대 좌표 계산)
  static const double referenceWidth = 1000.0; // 가상의 기준 너비

  static Map<String, dynamic> toJson(
    LayerModel layer, {
    required Size canvasSize,
    bool isCover = false,
  }) {
    final double refWidth = isCover
        ? (canvasSize.width - kCoverSpineWidth).clamp(1.0, 5000.0)
        : canvasSize.width;

    double xRatio;
    double widthRatio;

    if (isCover) {
      final availableW = canvasSize.width - kCoverSpineWidth;
      xRatio = (layer.position.dx - kCoverSpineWidth) / availableW;
      widthRatio = layer.width / availableW;
    } else {
      xRatio = layer.position.dx / canvasSize.width;
      widthRatio = layer.width / canvasSize.width;
    }

    return {
      'id': layer.id,
      'type': layer.type.name.toUpperCase(),
      'zIndex': layer.zIndex,
      'x': xRatio, // 0.0 ~ 1.0 (relative to content area)
      'y': (layer.position.dy / canvasSize.height), // 0.0 ~ 1.0
      'width': widthRatio, // scale 제외 - 원본 비율 보존 (relative to content area)
      'height': layer.height / canvasSize.height, // scale 제외 - 원본 비율 보존
      'scale': layer.scale, // scale 별도 저장
      'rotation': layer.rotation,
      'opacity': layer.opacity,
      'payload': switch (layer.type) {
        LayerType.image => {
          'imageBackground': layer.imageBackground,
          'imageTemplate': layer.imageTemplate,
          // 운영급: original/preview 우선 저장 + 하위 호환 imageUrl 미러링
          'originalUrl': layer.originalUrl,
          'previewUrl': layer.previewUrl ?? layer.imageUrl,
          'imageUrl': layer.previewUrl ?? layer.imageUrl,
        },
        LayerType.sticker || LayerType.decoration => {
          'imageBackground': layer.imageBackground,
          'imageTemplate': layer.imageTemplate,
          'originalUrl': layer.originalUrl,
          'previewUrl': layer.previewUrl ?? layer.imageUrl,
          'imageUrl': layer.previewUrl ?? layer.imageUrl,
        },
        LayerType.text => {
          'text': layer.text,
          'textAlign': layer.textAlign?.name,
          'textStyleType': layer.textStyleType?.name,
          'textBackground': layer.textBackground,
          'bubbleColor': layer.bubbleColor != null
              ? '#${layer.bubbleColor!.value.toRadixString(16).padLeft(8, '0')}'
              : null,
          'textStyle': _textStyleToJson(layer.textStyle, refWidth),
        },
      },
    };
  }

  /// 2. 서버 JSON 데이터를 LayerModel 객체로 복원 (절대 좌표 계산)
  static LayerModel fromJson(
    Map<String, dynamic> json, {
    required Size canvasSize,
    bool isCover = false,
  }) {
    final Map<String, dynamic> payload =
        (json['payload'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    // 서버의 비율(0~1) 데이터를 현재 전달받은 canvasSize에 곱해 절대 좌표로 복원

    double x;
    double width;

    if (isCover) {
      final availableW = canvasSize.width - kCoverSpineWidth;
      x = kCoverSpineWidth + ((json['x'] as num).toDouble() * availableW);
      width = (json['width'] as num).toDouble() * availableW;
    } else {
      x = (json['x'] as num).toDouble() * canvasSize.width;
      width = (json['width'] as num).toDouble() * canvasSize.width;
    }

    final double y = (json['y'] as num).toDouble() * canvasSize.height;
    final double height =
        (json['height'] as num).toDouble() * canvasSize.height;

    final String typeStr = (json['type'] as String? ?? 'IMAGE').toUpperCase();
    final LayerType type = switch (typeStr) {
      'TEXT' => LayerType.text,
      'STICKER' => LayerType.sticker,
      'DECORATION' => LayerType.decoration,
      _ => LayerType.image,
    };
    return LayerModel(
      id:
          json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      zIndex: json['zIndex'] as int? ?? 0,
      // 하위 호환: imageUrl만 오면 previewUrl로 간주
      previewUrl: (payload['previewUrl'] ?? payload['imageUrl']) as String?,
      imageUrl: (payload['previewUrl'] ?? payload['imageUrl']) as String?,
      originalUrl: payload['originalUrl'] as String?,
      position: Offset(x, y), // 현재 화면에 최적화된 좌표
      width: width,
      height: height,
      scale:
          (json['scale'] as num?)?.toDouble() ??
          1.0, // scale 복원 (하위 호환: 없으면 1.0)
      rotation: (json['rotation'] as num).toDouble(),
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      text: payload['text'] as String?,
      textAlign: _parseTextAlign(payload['textAlign'] as String?),
      textStyleType: _parseTextStyleType(payload['textStyleType'] as String?),
      textBackground: payload['textBackground'] as String?,
      bubbleColor: _parseColor(payload['bubbleColor'] as String?),
      textStyle: _textStyleFromJson(
        payload['textStyle'] as Map<String, dynamic>?,
        isCover ? (canvasSize.width - kCoverSpineWidth) : canvasSize.width,
      ),

      // 이미지 전용 데이터
      imageBackground: payload['imageBackground'] as String?,
      imageTemplate: payload['imageTemplate'] as String?,
    );
  }

  // --- Helper Methods ---

  static TextAlign? _parseTextAlign(String? value) {
    if (value == null) return null;
    return TextAlign.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TextAlign.center,
    );
  }

  static TextStyleType? _parseTextStyleType(String? value) {
    if (value == null) return null;
    return TextStyleType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TextStyleType.none,
    );
  }

  static Color? _parseColor(String? hexString) {
    if (hexString == null) return null;
    final buffer = StringBuffer();
    if (hexString.length == 7 || hexString.length == 9) {
      buffer.write(hexString.replaceFirst('#', ''));
    }
    // #AARRGGBB 또는 #RRGGBB 형태 처리
    String finalHex = buffer.toString();
    if (finalHex.length == 6) finalHex = "FF$finalHex";
    return Color(int.parse(finalHex, radix: 16));
  }

  static const List<FontWeight> _fontWeights = [
    FontWeight.w100,
    FontWeight.w200,
    FontWeight.w300,
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
    FontWeight.w800,
    FontWeight.w900,
  ];

  static Map<String, dynamic>? _textStyleToJson(
    TextStyle? style,
    double referenceWidth,
  ) {
    if (style == null) return null;
    final weightIdx = style.fontWeight != null
        ? _fontWeights.indexOf(style.fontWeight!)
        : -1;
    final int? storedWeight = weightIdx >= 0 ? weightIdx : null;
    return {
      'fontSize': style.fontSize, // 하위 호환성 위해 유지
      'fontSizeRatio': (style.fontSize ?? 14.0) / referenceWidth, // [New] 비율 저장
      'fontWeight': storedWeight,
      'fontStyle': style.fontStyle == FontStyle.italic ? 1 : 0,
      'fontFamily': style.fontFamily,
      'color': style.color != null
          ? '#${style.color!.value.toRadixString(16).padLeft(8, '0')}'
          : null,
      'letterSpacing': style.letterSpacing,
    };
  }

  static TextStyle? _textStyleFromJson(
    Map<String, dynamic>? json,
    double currentWidth,
  ) {
    if (json == null || json.isEmpty) return null;

    double fontSize;
    final fontSizeRatio = json['fontSizeRatio'] as num?;

    if (fontSizeRatio != null) {
      // 1. 비율 데이터가 있으면 현재 캔버스에 맞춰 복원
      fontSize = fontSizeRatio.toDouble() * currentWidth;
    } else {
      // 2. 구버전 데이터(비율 없음)인 경우
      final oldFontSize = (json['fontSize'] as num?)?.toDouble() ?? 14.0;
      // 에디터 평균 너비(358.0) 대비 현재 캔버스 비율로 대략적인 스케일링 적용
      fontSize = oldFontSize * (currentWidth / 358.0);
    }

    final fontWeightIdx = json['fontWeight'] as int?;
    final fontStyleIdx = json['fontStyle'] as int?;
    final fontFamily = json['fontFamily'] as String?;
    final color = _parseColor(json['color'] as String?);
    final letterSpacing = json['letterSpacing'] as num?;
    return TextStyle(
      fontSize: fontSize,
      fontWeight:
          fontWeightIdx != null &&
              fontWeightIdx >= 0 &&
              fontWeightIdx < _fontWeights.length
          ? _fontWeights[fontWeightIdx]
          : null,
      fontStyle: fontStyleIdx == 1 ? FontStyle.italic : FontStyle.normal,
      fontFamily: fontFamily,
      color: color,
      letterSpacing: letterSpacing?.toDouble(),
    );
  }
}
