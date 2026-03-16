import 'dart:ui';

/// 통합 템플릿 스키마의 캔버스 정의.
/// 배경색, 텍스처, 배경 장식(decorations)을 담당.
/// 자세한 스키마는 docs/template_schema.md 참고.
class TemplateCanvas {
  final double width;
  final double height;
  final String? background;
  final String? textureUrl;
  final String? effect;
  final List<CanvasDecoration> decorations;

  const TemplateCanvas({
    required this.width,
    required this.height,
    this.background,
    this.textureUrl,
    this.effect,
    this.decorations = const [],
  });

  Size get size => Size(width, height);

  /// 비율(0~1) 기반 캔버스인지 여부. true면 width/height는 기준치만 저장하고
  /// 실제 렌더 시 전달받은 Size로 스케일한다.
  bool get isRatioBased => width <= 1.0 && height <= 1.0;

  TemplateCanvas copyWith({
    double? width,
    double? height,
    String? background,
    String? textureUrl,
    String? effect,
    List<CanvasDecoration>? decorations,
  }) {
    return TemplateCanvas(
      width: width ?? this.width,
      height: height ?? this.height,
      background: background ?? this.background,
      textureUrl: textureUrl ?? this.textureUrl,
      effect: effect ?? this.effect,
      decorations: decorations ?? this.decorations,
    );
  }
}

/// 캔버스 배경 위에 깔리는 장식 레이어 (잎사귀, 찢어진 종이 등).
class CanvasDecoration {
  final String id;
  final String? url;
  final String? assetRef;
  /// 캔버스 대비 비율 0.0~1.0
  final double left;
  final double top;
  final double width;
  final double height;
  final double rotation;
  final int zIndex;
  final String? blendMode;

  const CanvasDecoration({
    required this.id,
    this.url,
    this.assetRef,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.zIndex = 0,
    this.blendMode,
  });
}
