import 'dart:async';
import 'package:flutter/material.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../../../../features/album/domain/entities/layer.dart';
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

  /// 이미지 레이어 빌드
  Widget buildImage(LayerModel layer) {
    // 편집 중인 레이어면 숨김
    if (_isEditing(layer)) return const SizedBox.shrink();

    return FutureBuilder<ImageInfo>(
      future: _getImageInfo(layer),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        final coverSize = getCoverSize();
        final imgW = snapshot.data!.image.width.toDouble();
        final imgH = snapshot.data!.image.height.toDouble();
        final imgAspect = imgW / imgH;
        final coverAspect = coverSize.width / coverSize.height;

        final fillScale = imgAspect > coverAspect
            ? coverSize.height / imgH
            : coverSize.width / imgW;

        final baseW = imgW * fillScale;
        final baseH = imgH * fillScale;

        // 첫 진입시 중앙 배치 초기화
        final initialPos = Offset(
          (coverSize.width - baseW) / 2,
          (coverSize.height - baseH) / 2,
        );
        // 내부 인터랙션 맵 초기화는 manager가 담당
        interaction.setBaseSize(layer.id, Size(baseW, baseH));

        return interaction.buildInteractiveLayer(
          layer: layer,
          baseWidth: baseW,
          baseHeight: baseH,
          child: _buildFramedImage(
            layer,
            Image(
              image: AssetEntityImageProvider(layer.asset!),
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }

  /// 이미지 프레임 적용 스위치
  Widget _buildFramedImage(LayerModel layer, Widget image) {
    switch (layer.imageBackground) {
      case "polaroid":
        return _framePolaroid(image);
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

    final coverSize = getCoverSize();
    final textSpan = TextSpan(text: layer.text ?? "", style: layer.textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: layer.textAlign ?? TextAlign.center,
    )..layout(minWidth: 0, maxWidth: coverSize.width * 0.8);

    // Removed baseWidth and baseHeight calculation here

    // ───────────────────────────────────────────────
    // 텍스트 스타일(textStyleType) 우선 적용
    // 기존 backgroundMode는 유지하지만 styleType 있을 때는 스타일이 우선한다
    // ───────────────────────────────────────────────
    if (layer.textBackground != null) {
      Widget styled;

      switch (layer.textBackground) {
        case "tag":
          styled = _buildTagStyle(layer, textPainter);
          break;
        case "bubble":
          styled = _buildBubbleStyle(layer, textPainter);
          break;
        case "note":
          styled = _buildNoteStyle(layer, textPainter);
          break;
        case "calligraphy":
          styled = _buildCalligraphyStyle(layer, textPainter);
          break;
        case "sticker":
          styled = _buildStickerStyle(layer, textPainter);
          break;
        case "tape":
          styled = _buildTapeStyle(layer, textPainter);
          break;
        default:
          styled = Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              layer.text ?? "",
              style: layer.textStyle,
              textAlign: layer.textAlign ?? TextAlign.center,
            ),
          );
          break;
      }

      final realSize = _calculateStyleSize(layer.textBackground!, layer, textPainter);
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
      padding: const EdgeInsets.all(4),
      child: Text(
        layer.text ?? "",
        style: layer.textStyle,
        textAlign: layer.textAlign ?? TextAlign.center,
      ),
    );

    final realSize = Size(textPainter.size.width + 20, textPainter.size.height + 10);
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

  Future<ImageInfo> _getImageInfo(LayerModel layer) async {
    final provider = AssetEntityImageProvider(layer.asset!);
    final completer = Completer<ImageInfo>();
    provider.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((info, _) => completer.complete(info)),
    );
    return completer.future;
  }

  Widget _buildTagStyle(LayerModel layer, TextPainter painter) {
    final baseStyle = layer.textStyle ?? const TextStyle(fontSize: 14);
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

  Widget _buildBubbleStyle(LayerModel layer, TextPainter painter) {
    final baseStyle = layer.textStyle ?? const TextStyle(fontSize: 14);
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

  Widget _buildNoteStyle(LayerModel layer, TextPainter painter) {
    final baseStyle = layer.textStyle ?? const TextStyle(fontSize: 13);
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

  Widget _buildCalligraphyStyle(LayerModel layer, TextPainter painter) {
    final baseStyle = layer.textStyle ?? const TextStyle(fontSize: 16);
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

  Widget _buildStickerStyle(LayerModel layer, TextPainter painter) {
    final baseStyle = layer.textStyle ?? const TextStyle(fontSize: 14);
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

  Widget _buildTapeStyle(LayerModel layer, TextPainter painter) {
    final baseStyle = layer.textStyle ?? const TextStyle(fontSize: 13);
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