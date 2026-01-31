import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

/// 하나의 레이어(이미지 or 텍스트)를 정의하는 데이터 모델
// enum LayerType { image, text }
enum LayerType {
  image,        // 기존 사용자 이미지 레이어
  text,         // 기존 사용자 텍스트 레이어
}

enum TextStyleType {
  none,            // 기본
  textOuter,       // 글자 외곽선(흰/검 자동 대비)
  textInner,       // 글자 내부
}

class LayerModel {
  final String id;
  final LayerType type;
  final Offset position;
  final AssetEntity? asset;
  final String? text;
  final TextStyle? textStyle;
  final TextStyleType? textStyleType;
  final Color? bubbleColor;
  final double scale;
  final double rotation;
  final TextAlign? textAlign;
  final double width;   // 레이어 기본 너비
  final double height;  // 레이어 기본 높이
  final String? textBackground; // 텍스트 스타일 키 ("tag", "bubble", "note", ...)
  final String? imageBackground; // 이미지 프레임 스타일 키 ("polaroid", "shadow", "sticker", "tape", "film", "mat")
  final String? imageTemplate; // 이미지 슬롯 템플릿 ("free", "1:1", "4:3", ...) - null/ free면 원본 비율, 지정 시 contain으로 짤리지 않게
  /// 하위 호환용 preview URL (기존 스키마)
  final String? imageUrl;
  /// 운영급: 원본/미리보기 URL
  final String? originalUrl;
  final String? previewUrl;

  LayerModel({
    required this.id,
    required this.type,
    required this.position,
    this.asset,
    this.text,
    this.textStyle,
    this.textStyleType,
    this.bubbleColor,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.textAlign,
    this.width = 120,   // 기본값 (이미지 or 텍스트 크기)
    this.height = 120,  // 기본값
    this.textBackground,
    this.imageBackground,
    this.imageTemplate,
    this.imageUrl,
    this.originalUrl,
    this.previewUrl,
  });

  LayerModel copyWith({
    String? id,
    LayerType? type,
    Offset? position,
    AssetEntity? asset,
    String? text,
    TextStyle? textStyle,
    TextStyleType? textStyleType,
    Color? bubbleColor,
    double? scale,
    double? rotation,
    TextAlign? textAlign,
    double? width,
    double? height,
    String? textBackground,
    String? imageBackground,
    String? imageTemplate,
    bool? locked,
    bool? editable,
    String? imageUrl,
    String? originalUrl,
    String? previewUrl,
  }) {
    return LayerModel(
      id: id ?? this.id,
      type: type ?? this.type,
      position: position ?? this.position,
      asset: asset ?? this.asset,
      text: text ?? this.text,
      textStyle: textStyle ?? this.textStyle,
      textStyleType: textStyleType ?? this.textStyleType,
      bubbleColor: bubbleColor ?? this.bubbleColor,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      textAlign: textAlign ?? this.textAlign,
      width: width ?? this.width,
      height: height ?? this.height,
      textBackground: textBackground ?? this.textBackground,
      imageBackground: imageBackground ?? this.imageBackground,
      imageTemplate: imageTemplate ?? this.imageTemplate,
      imageUrl: imageUrl ?? this.imageUrl,
      originalUrl: originalUrl ?? this.originalUrl,
      previewUrl: previewUrl ?? this.previewUrl,
    );
  }
}