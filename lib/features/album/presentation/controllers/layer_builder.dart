import 'dart:async';
import 'package:flutter/material.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../../../../shared/snapfit_image.dart';
import '../../domain/entities/layer.dart';
import 'layer_interaction_manager.dart';

/// 이미지/텍스트 레이어의 렌더링과 기본 사이즈 계산 전담
class LayerBuilder {
  final LayerInteractionManager interaction;
  final Size Function() getCoverSize;

  LayerBuilder(this.interaction, this.getCoverSize);

  Size _calculateStyleSize(String type, LayerModel layer, TextPainter painter) {
    final textSize = painter.size;

    switch (type) {
      case "tag":
        return Size(textSize.width + 24, textSize.height + 12);
      case "bubble":
        return Size(textSize.width + 28, textSize.height + 28);
      case "note":
        return Size(textSize.width + 24, textSize.height + 24);
      case "calligraphy":
        return Size(textSize.width + 32, textSize.height + 20);
      case "sticker":
        return Size(textSize.width + 36, textSize.height + 22);
      case "tape":
        return Size(textSize.width + 36, textSize.height + 20);
      default:
        return Size(textSize.width + 20, textSize.height + 10);
    }
  }

  /// 템플릿 적용 시 템플릿 비율 슬롯에 사진이 꽉 차게 cover, 자유 비율이면 cover
  static BoxFit _imageFitForLayer(LayerModel layer) {
    // 템플릿이 있든 없든 모두 cover로 꽉 차게 표시
    return BoxFit.cover;
  }

  /// 이미지 레이어 빌드
  Widget buildImage(LayerModel layer) {
    // 편집 중인 레이어면 숨김
    if (_isEditing(layer)) return const SizedBox.shrink();

    final fit = _imageFitForLayer(layer);

    if (layer.asset != null) {
      // 아직 업로드 전: 로컬 AssetEntity로 표시
      return interaction.buildInteractiveLayer(
        layer: layer,
        baseWidth: layer.width,
        baseHeight: layer.height,
        child: _buildFramedImage(
          layer,
          Image(
            image: AssetEntityImageProvider(layer.asset!),
            fit: fit,
            filterQuality: FilterQuality.medium,
          ),
        ),
      );
    }

    final url = layer.previewUrl ?? layer.imageUrl ?? layer.originalUrl;
    if (url == null || url.isEmpty) {
      return interaction.buildInteractiveLayer(
        layer: layer,
        baseWidth: layer.width,
        baseHeight: layer.height,
        child: _buildImagePlaceholder(layer),
      );
    }

    return interaction.buildInteractiveLayer(
      layer: layer,
      baseWidth: layer.width,
      baseHeight: layer.height,
      child: _buildFramedImage(
        layer,
        SnapfitImage(urlOrGs: url, fit: fit),
      ),
    );
  }

  /// 빈 이미지 슬롯(플레이스홀더) – 템플릿 적용 후 사진을 넣을 자리
  Widget _buildImagePlaceholder(LayerModel layer) {
    final placeholder = Container(
      width: layer.width,
      height: layer.height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400, width: 1.5, style: BorderStyle.solid),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_a_photo, size: 28, color: Colors.grey.shade500),
            const SizedBox(height: 4),
            Text("사진 추가", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
    return _buildFramedImage(layer, placeholder);
  }

  /// 이미지 프레임 적용 스위치
  Widget _buildFramedImage(LayerModel layer, Widget image) {
    switch (layer.imageBackground) {
      case "round":
        return _frameRound(image);
      case "polaroid":
        return _framePolaroid(image);
      case "polaroidClassic":
        return _framePolaroidClassic(image);
      case "polaroidWide":
        return _framePolaroidWide(image);
      case "softGlow":
        return _frameSoftGlow(image);
      case "sticker":
        return _frameSticker(image);
      case "vintage":
        return _frameVintage(image);
      case "film":
        return _frameFilm(image);
      case "sketch":
        return _frameSketch(image);
      default:
        return image;
    }
  }

  Widget _frameRound(Widget image) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: image,
    );
  }

  Widget _framePolaroid(Widget image) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: image,
      ),
    );
  }

  /// 폴라로이드 클래식: 더 두꺼운 하단 여백, 크림색 톤
  Widget _framePolaroidClassic(Widget image) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 36),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEF5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE8E4D8),
          width: 1.4,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: image,
      ),
    );
  }

  /// 폴라로이드 와이드: 얇은 테두리, 넓은 비율
  Widget _framePolaroidWide(Widget image) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: image,
      ),
    );
  }

  Widget _frameSoftGlow(Widget image) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.65),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.55),
            blurRadius: 40,
            spreadRadius: 12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: image,
      ),
    );
  }

  Widget _frameVintage(Widget image) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF4E8D3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.brown.withOpacity(0.45),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(3, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: image,
      ),
    );
  }

  Widget _frameSketch(Widget image) {
    return CustomPaint(
      painter: _SketchFramePainter(),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: image,
        ),
      ),
    );
  }


  Widget _frameSticker(Widget image) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: image,
      ),
    );
  }


  Widget _frameFilm(Widget image) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _FilmHolePainterV2(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: image,
            ),
          ),
        ],
      ),
    );
  }


  /// 텍스트 레이어 빌드
  Widget buildText(LayerModel layer) {
    if (_isEditing(layer)) return const SizedBox.shrink();

    // ✅ 기본 생성 텍스트 최소 폰트 크기 (너무 작게 생성되는 것 방지)
    const double minFontSize = 18;

    final TextStyle baseStyle = layer.textStyle ?? const TextStyle(fontSize: 18);

    // ✅ 실제 적용될 스타일 (최소값 보장)
    final TextStyle effectiveStyle = baseStyle.fontSize != null && baseStyle.fontSize! < minFontSize
        ? baseStyle.copyWith(fontSize: minFontSize)
        : baseStyle;

    final coverSize = getCoverSize();
    final textSpan = TextSpan(text: layer.text ?? "", style: effectiveStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: layer.textAlign ?? TextAlign.center,
    )..layout(minWidth: 0, maxWidth: coverSize.width * 0.8);

    // ───────────────────────────────────────────────
    // 텍스트 스타일(textStyleType) 우선 적용
    // 기존 backgroundMode는 유지하지만 styleType 있을 때는 스타일이 우선한다
    // ───────────────────────────────────────────────
    if (layer.textBackground != null) {
      Widget styled;

      switch (layer.textBackground) {
        case "tag":
          styled = _buildTagStyle(layer, textPainter, effectiveStyle);
          break;
        case "bubble":
          styled = _buildBubbleStyle(layer, textPainter, effectiveStyle);
          break;
        case "note":
          styled = _buildNoteStyle(layer, textPainter, effectiveStyle);
          break;
        case "calligraphy":
          styled = _buildCalligraphyStyle(layer, textPainter, effectiveStyle);
          break;
        case "sticker":
          styled = _buildStickerStyle(layer, textPainter, effectiveStyle);
          break;
        case "tape":
          styled = _buildTapeStyle(layer, textPainter, effectiveStyle);
          break;
        default:
          styled = Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              layer.text ?? "",
              style: effectiveStyle,
              textAlign: layer.textAlign ?? TextAlign.center,
            ),
          );
          break;
      }

      // ✅ style 텍스트도 하단 여유 보정
      final Size styleSize = _calculateStyleSize(layer.textBackground!, layer, textPainter);
      final realSize = Size(
        styleSize.width,
        styleSize.height + 12,
      );
      interaction.setBaseSize(layer.id, realSize);

      return interaction.buildInteractiveLayer(
        layer: layer,
        baseWidth: realSize.width,
        baseHeight: realSize.height,
        child: styled,
      );
    }

    // 배경 모드 처리
    Widget content;

    content = Padding(
      // ✅ descender(y, g 등) 안전 여유 확보
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Text(
        layer.text ?? "",
        style: effectiveStyle,
        textAlign: layer.textAlign ?? TextAlign.center,
      ),
    );

    // ✅ 아래 잘림 방지를 위해 baseHeight를 실측보다 크게 확보
    final realSize = Size(
      textPainter.size.width + 55,
      textPainter.size.height + 55,
    );
    interaction.setBaseSize(layer.id, realSize);

    return interaction.buildInteractiveLayer(
      layer: layer,
      baseWidth: realSize.width,
      baseHeight: realSize.height,
      child: content,
    );
  }

  bool _isEditing(LayerModel layer) {
    return interaction.selectedLayerId == layer.id
        ? false
        : false; // 현재 편집 중 레이어 숨김은 interaction에서 editing id로 제어 가능
  }

  // ImageInfo 프리패치가 필요해지면 여기에 precacheImage 등을 추가한다.

  Widget _buildTagStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final baseStyle = effectiveStyle;
    final style = baseStyle.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
    );

    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.06),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            layer.text ?? "",
            style: style,
            textAlign: layer.textAlign,
          ),
        ),
      ),
    );
  }

  Widget _buildBubbleStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final baseStyle = effectiveStyle;
    final style = baseStyle.copyWith(
      fontWeight: FontWeight.w500,
      height: 1.2,
    );

    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: CustomPaint(
          painter: _BubbleBackgroundPainter(
            fillColor: Colors.white,
            borderColor: Colors.black.withOpacity(0.22),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Text(
              layer.text ?? "",
              style: style,
              textAlign: layer.textAlign,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoteStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final baseStyle = effectiveStyle;
    final style = baseStyle.copyWith(
      height: 1.25,
    );

    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: ClipPath(
          clipper: _TornPaperClipper(),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9C4),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.brown.withOpacity(0.35)),
            ),
            child: Text(
              layer.text ?? "",
              style: style,
              textAlign: layer.textAlign,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalligraphyStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final baseStyle = effectiveStyle;
    final style = baseStyle.copyWith(
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w500,
      height: 1.25,
    );

    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.amber.shade700, width: 1),
          ),
          child: Text(
            layer.text ?? "",
            style: style,
            textAlign: layer.textAlign,
          ),
        ),
      ),
    );
  }

  Widget _buildStickerStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final baseStyle = effectiveStyle;
    final style = baseStyle.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );

    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 4,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: Text(
            layer.text ?? "",
            style: style,
            textAlign: layer.textAlign,
          ),
        ),
      ),
    );
  }

  Widget _buildTapeStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final baseStyle = effectiveStyle;
    final style = baseStyle.copyWith(
      fontWeight: FontWeight.w500,
    );

    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Transform.rotate(
          angle: -0.05,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.yellow.withOpacity(0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              layer.text ?? "",
              style: style,
              textAlign: layer.textAlign,
            ),
          ),
        ),
      ),
    );
  }
}

// 말풍선 스타일: 꼬리와 배경 그림자
class _BubbleBackgroundPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;

  _BubbleBackgroundPainter({
    required this.fillColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bubbleHeight = size.height - 6;

    final path = Path();

    // Rounded main body
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, bubbleHeight),
      const Radius.circular(16),
    );
    path.addRRect(body);

    // Tail (seamlessly connected)
    final tailWidth = 18.0;
    final tailHeight = 10.0;
    final tailCenterX = size.width * 0.32;

    path.moveTo(tailCenterX - tailWidth / 2, bubbleHeight);
    path.lineTo(tailCenterX, bubbleHeight + tailHeight);
    path.lineTo(tailCenterX + tailWidth / 2, bubbleHeight);
    path.close();

    final fill = Paint()..color = fillColor..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _BubbleBackgroundPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor;
  }
}

// 노트 스타일: 아래 찢어진 종이 효과
class _TornPaperClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height - 4);

    // 아랫부분 찢어진 효과
    const step = 8.0;
    double x = size.width;
    bool up = true;
    while (x > 0) {
      x -= step;
      final y = size.height - (up ? 0 : 4);
      path.lineTo(x.clamp(0, size.width), y);
      up = !up;
    }

    path.lineTo(0, size.height - 4);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
// Film hole painter V2 for frameFilm
class _FilmHolePainterV2 extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final holePaint = Paint()
      ..color = Colors.black.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    const holeSize = 6.0;
    const gap = 16.0;

    for (double y = gap; y < size.height - gap; y += gap) {
      canvas.drawCircle(Offset(4, y), holeSize / 2, holePaint);
      canvas.drawCircle(Offset(size.width - 4, y), holeSize / 2, holePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
// Sketch frame painter for _frameSketch
class _SketchFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    path.moveTo(4, 8);
    path.lineTo(size.width - 4, 4);
    path.lineTo(size.width - 6, size.height - 6);
    path.lineTo(6, size.height - 4);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}