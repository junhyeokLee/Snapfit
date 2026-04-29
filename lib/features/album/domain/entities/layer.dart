import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

/// 하나의 레이어(이미지/텍스트/스티커/장식)를 정의하는 데이터 모델
/// 통합 스키마: docs/template_schema.md
enum LayerType {
  image, // 사용자 사진 레이어
  text, // 텍스트 레이어
  sticker, // 스티커(이미지 기반 장식)
  decoration, // 배경 장식(잎사귀, 찢어진 종이 등)
}

enum TextStyleType {
  none, // 기본
  textOuter, // 글자 외곽선(흰/검 자동 대비)
  textInner, // 글자 내부
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
  final double width; // 레이어 기본 너비
  final double height; // 레이어 기본 높이
  final String? textBackground; // 텍스트 스타일 키 ("tag", "bubble", "note", ...)
  /// 텍스트 채움 모드 ("solid" | "imageClip")
  final String? textFillMode;

  /// textFillMode=imageClip 일 때 채움 이미지 URL
  final String? textFillImageUrl;
  final String?
  imageBackground; // 이미지 프레임 스타일 키 ("polaroid", "shadow", "sticker", "tape", "film", "mat")
  final String?
  imageTemplate; // 이미지 슬롯 템플릿 ("free", "1:1", "4:3", ...) - null/ free면 원본 비율, 지정 시 contain으로 짤리지 않게
  final String? decorationFillColor; // 장식 레이어 채움색(hex)
  final String? decorationBorderColor; // 장식 레이어 테두리색(hex)
  final double? decorationBorderWidth; // 장식 레이어 테두리 두께(비율/px)
  final double? decorationCornerRadius; // 장식 레이어 라운드(비율/px)
  /// 프레임 적용 전 기본 상태(크기/위치)를 되돌리기 위한 베이스 값 (런타임 전용, 서버 저장 X)
  final double? frameBaseWidth;
  final double? frameBaseHeight;
  final Offset? frameBasePosition;

  /// 템플릿/프레임 안에서 사진 자체를 이동시킬 때 사용하는 오프셋 (런타임 기준 좌표)
  final Offset? imageOffset;

  /// 하위 호환용 preview URL (기존 스키마)
  final String? imageUrl;

  /// 운영급: 원본/미리보기 URL
  final String? originalUrl;
  final String? previewUrl;
  final double opacity; // 레이어 불투명도 (0.0 ~ 1.0)
  /// 겹침 순서. 클수록 앞에 그림. 통합 템플릿(결혼/스크랩북/포토북 등)용.
  final int zIndex;

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
    this.width = 120, // 기본값 (이미지 or 텍스트 크기)
    this.height = 120, // 기본값
    this.textBackground,
    this.textFillMode,
    this.textFillImageUrl,
    this.imageBackground,
    this.imageTemplate,
    this.decorationFillColor,
    this.decorationBorderColor,
    this.decorationBorderWidth,
    this.decorationCornerRadius,
    this.frameBaseWidth,
    this.frameBaseHeight,
    this.frameBasePosition,
    this.imageOffset,
    this.imageUrl,
    this.originalUrl,
    this.previewUrl,
    this.opacity = 1.0,
    this.zIndex = 0,
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
    String? textFillMode,
    String? textFillImageUrl,
    String? imageBackground,
    String? imageTemplate,
    String? decorationFillColor,
    String? decorationBorderColor,
    double? decorationBorderWidth,
    double? decorationCornerRadius,
    double? frameBaseWidth,
    double? frameBaseHeight,
    Offset? frameBasePosition,
    Offset? imageOffset,
    bool? locked,
    bool? editable,
    String? imageUrl,
    String? originalUrl,
    String? previewUrl,
    double? opacity,
    int? zIndex,
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
      textFillMode: textFillMode ?? this.textFillMode,
      textFillImageUrl: textFillImageUrl ?? this.textFillImageUrl,
      imageBackground: imageBackground ?? this.imageBackground,
      imageTemplate: imageTemplate ?? this.imageTemplate,
      decorationFillColor: decorationFillColor ?? this.decorationFillColor,
      decorationBorderColor:
          decorationBorderColor ?? this.decorationBorderColor,
      decorationBorderWidth:
          decorationBorderWidth ?? this.decorationBorderWidth,
      decorationCornerRadius:
          decorationCornerRadius ?? this.decorationCornerRadius,
      frameBaseWidth: frameBaseWidth ?? this.frameBaseWidth,
      frameBaseHeight: frameBaseHeight ?? this.frameBaseHeight,
      frameBasePosition: frameBasePosition ?? this.frameBasePosition,
      imageOffset: imageOffset ?? this.imageOffset,
      imageUrl: imageUrl ?? this.imageUrl,
      originalUrl: originalUrl ?? this.originalUrl,
      previewUrl: previewUrl ?? this.previewUrl,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
    );
  }
}
