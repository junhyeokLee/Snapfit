import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../../../core/utils/image_url_policy.dart';
import '../../../album/domain/entities/layer.dart';

class TemplatePageRenderer extends StatelessWidget {
  final List<LayerModel> layers;
  final double width;
  final double height;
  final bool showCanvasChrome;
  final Size? designCanvasSize;

  /// true면 레이어 내용을 content bounds 기준으로 재정규화(레거시),
  /// false면 템플릿 좌표계를 그대로 스케일링(피그마 정합 우선).
  final bool normalizeToContentBounds;
  final Map<String, File>? localFiles;
  final VoidCallback? onImageTap;
  final Function(String layerId)? onLayerTap;

  const TemplatePageRenderer({
    super.key,
    required this.layers,
    required this.width,
    required this.height,
    this.showCanvasChrome = false,
    this.designCanvasSize,
    this.normalizeToContentBounds = false,
    this.localFiles,
    this.onImageTap,
    this.onLayerTap,
  });

  @override
  Widget build(BuildContext context) {
    final ordered = [...layers]..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    final bounds = normalizeToContentBounds
        ? _contentBounds(ordered)
        : _canvasBounds(ordered, designCanvasSize);

    final stack = Stack(
      clipBehavior: Clip.hardEdge,
      children: ordered
          .map((layer) => _buildLayerWidget(layer, width, height, bounds))
          .toList(),
    );

    if (!showCanvasChrome) {
      return SizedBox(
        width: width,
        height: height,
        child: ClipRect(child: stack),
      );
    }

    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
        ],
      ),
      child: stack,
    );
  }

  Rect _contentBounds(List<LayerModel> ordered) {
    if (ordered.isEmpty) return const Rect.fromLTWH(0, 0, 500, 500);
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;
    for (final l in ordered) {
      minX = math.min(minX, l.position.dx);
      minY = math.min(minY, l.position.dy);
      maxX = math.max(maxX, l.position.dx + l.width);
      maxY = math.max(maxY, l.position.dy + l.height);
    }
    if (!minX.isFinite || !minY.isFinite || !maxX.isFinite || !maxY.isFinite) {
      return const Rect.fromLTWH(0, 0, 500, 500);
    }
    final w = math.max(1.0, maxX - minX);
    final h = math.max(1.0, maxY - minY);
    return Rect.fromLTWH(minX, minY, w, h);
  }

  Rect _canvasBounds(List<LayerModel> ordered, Size? canvasSize) {
    if (canvasSize != null &&
        canvasSize.width > 1.0 &&
        canvasSize.height > 1.0) {
      return Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height);
    }
    if (ordered.isEmpty) return const Rect.fromLTWH(0, 0, 500, 500);
    double maxX = 0.0;
    double maxY = 0.0;
    for (final l in ordered) {
      maxX = math.max(maxX, l.position.dx + l.width);
      maxY = math.max(maxY, l.position.dy + l.height);
    }
    return Rect.fromLTWH(0, 0, math.max(1.0, maxX), math.max(1.0, maxY));
  }

  Widget _buildLayerWidget(
    LayerModel layer,
    double canvasW,
    double canvasH,
    Rect bounds,
  ) {
    final refW = math.max(1.0, bounds.width);
    final refH = math.max(1.0, bounds.height);
    final scaleX = canvasW / refW;
    final scaleY = canvasH / refH;

    final x = normalizeToContentBounds
        ? ((layer.position.dx - bounds.left) / bounds.width) * canvasW
        : (layer.position.dx - bounds.left) * scaleX;
    final y = normalizeToContentBounds
        ? ((layer.position.dy - bounds.top) / bounds.height) * canvasH
        : (layer.position.dy - bounds.top) * scaleY;
    final w = normalizeToContentBounds
        ? (layer.width / bounds.width) * canvasW
        : layer.width * scaleX;
    final h = normalizeToContentBounds
        ? (layer.height / bounds.height) * canvasH
        : layer.height * scaleY;

    // Figma 정합 우선:
    // 위치/크기를 캔버스 내부로 강제 보정(clamp)하면 원본 레이아웃이 틀어진다.
    // clip은 상위 컨테이너에서 처리하고, 여기서는 원본 좌표를 유지한다.
    final drawW = w.isFinite ? w.clamp(1.0, canvasW * 4).toDouble() : 1.0;
    final drawH = h.isFinite ? h.clamp(1.0, canvasH * 4).toDouble() : 1.0;
    final drawX = x.isFinite ? x : 0.0;
    final drawY = y.isFinite ? y : 0.0;

    if (layer.type == LayerType.image) {
      final localFile = localFiles?[layer.id];
      final url = layer.previewUrl ?? layer.imageUrl ?? layer.originalUrl;
      final frame = layer.imageBackground;

      Widget imageContent;
      if (localFile != null) {
        imageContent = Image.file(localFile, fit: BoxFit.cover);
      } else if (url != null && url.startsWith('asset:')) {
        imageContent = Image.asset(
          url.substring('asset:'.length),
          fit: BoxFit.cover,
        );
      } else if (url != null) {
        imageContent = Image.network(
          imageUrlByVariant(url, variant: ImageVariant.detail),
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: const Color(0xFFF1F3F5),
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 1.8),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE9EEF5), Color(0xFFDCE6F2)],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.photo_outlined,
                  size: 20,
                  color: Color(0xFF7A8AA0),
                ),
              ),
            );
          },
        );
      } else {
        imageContent = Container(
          color: Colors.grey[200],
          child: const Center(
            child: Icon(Icons.add_photo_alternate_outlined, color: Colors.grey),
          ),
        );
      }

      Widget layerWidget;
      if (frame == 'polaroid') {
        layerWidget = Container(
          padding: EdgeInsets.fromLTRB(5, 5, 5, 25),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
          ),
          child: imageContent,
        );

        // Adjust position/size for the frame effect if needed
        // But for simplicity, we assume the layer frame includes the polaroid border in design
        // Actually the code in detail screen manually adjusted rect.
        // Let's copy that logic:
        return Positioned(
          left: drawX - 6,
          top: drawY - 6,
          width: drawW + 12,
          height: drawH + 24,
          child: GestureDetector(
            onTap: onLayerTap != null
                ? () => onLayerTap!(layer.id)
                : onImageTap,
            child: layerWidget,
          ),
        );
      } else {
        layerWidget = _applyImageFrame(imageContent, frame);
      }

      return Positioned(
        left: drawX,
        top: drawY,
        width: drawW,
        height: drawH,
        child: GestureDetector(
          onTap: onLayerTap != null ? () => onLayerTap!(layer.id) : onImageTap,
          child: layerWidget,
        ),
      );
    } else if (layer.type == LayerType.decoration ||
        layer.type == LayerType.sticker) {
      return Positioned(
        left: drawX,
        top: drawY,
        width: drawW,
        height: drawH,
        child: _buildDecorationWidget(
          layer: layer,
          drawWidth: drawW,
          drawHeight: drawH,
          canvasWidth: canvasW,
          canvasHeight: canvasH,
        ),
      );
    } else {
      // Text
      final style = layer.textStyle ?? const TextStyle();
      final baseFont = style.fontSize ?? 14.0;
      // 피그마 정합 우선: 높이 기준 강제 축소 대신 원본 폰트를 동일 비율로만 스케일
      final scaledFont = normalizeToContentBounds
          ? math.min(baseFont, (drawH * 0.82).clamp(10.0, 220.0))
          : (baseFont * scaleY).clamp(6.0, 260.0).toDouble();
      final textFillMode = (layer.textFillMode ?? '').toLowerCase();
      final textFillImageUrl = _resolveTextFillUrl(layer);
      return Positioned(
        left: drawX,
        top: drawY,
        width: drawW,
        height: drawH,
        child: Container(
          // color: Colors.black12, // Debug
          alignment: _getAlignment(layer.textAlign),
          child: (textFillMode == 'textcutout')
              ? _StoreCutoutText(
                  text: layer.text ?? '',
                  textAlign: layer.textAlign ?? TextAlign.center,
                  style: style.copyWith(fontSize: scaledFont),
                )
              : (textFillMode == 'imageclip' && textFillImageUrl.isNotEmpty)
              ? _StoreImageClipText(
                  text: layer.text ?? '',
                  textAlign: layer.textAlign ?? TextAlign.center,
                  style: style.copyWith(
                    fontSize: scaledFont,
                    color: Colors.white,
                  ),
                  imageUrl: textFillImageUrl,
                )
              : Text(
                  layer.text ?? '',
                  textAlign: layer.textAlign ?? TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: style.copyWith(
                    fontSize: scaledFont,
                    color: style.color ?? Colors.black,
                  ),
                ),
        ),
      );
    }
  }

  Widget _buildDecorationWidget({
    required LayerModel layer,
    required double drawWidth,
    required double drawHeight,
    required double canvasWidth,
    required double canvasHeight,
  }) {
    final bg = layer.imageBackground ?? '';
    final rawRadius = layer.decorationCornerRadius;
    final radiusPx = rawRadius == null
        ? null
        : (rawRadius <= 1.0
              ? rawRadius * math.min(canvasWidth, canvasHeight)
              : rawRadius);
    final borderWidthRaw = layer.decorationBorderWidth;
    final borderWidth = borderWidthRaw == null
        ? null
        : (borderWidthRaw <= 1.0 ? borderWidthRaw * canvasWidth : borderWidthRaw);
    final fillOverride = _parseHexColor(layer.decorationFillColor);
    final borderOverride = _parseHexColor(layer.decorationBorderColor);

    Widget buildSolid(Color color) {
      return Container(
        decoration: BoxDecoration(
          color: fillOverride ?? color,
          borderRadius: radiusPx != null ? BorderRadius.circular(radiusPx) : null,
          border: borderOverride != null
              ? Border.all(color: borderOverride, width: borderWidth ?? 1.0)
              : null,
        ),
      );
    }

    if (fillOverride != null) {
      return Container(
        decoration: BoxDecoration(
          color: fillOverride,
          borderRadius: radiusPx != null ? BorderRadius.circular(radiusPx) : null,
          border: borderOverride != null
              ? Border.all(color: borderOverride, width: borderWidth ?? 1.0)
              : null,
        ),
      );
    }

    if (bg == 'paperWarm') {
      return buildSolid(const Color(0xFFF1E6D8));
    }
    if (bg == 'paperWhite') {
      return buildSolid(const Color(0xFFFFFFFF));
    }
    if (bg == 'paperBeige') {
      return buildSolid(const Color(0xFFE9DDCB));
    }
    if (bg == 'skyBlue') {
      return buildSolid(const Color(0xFFCDE2F2));
    }
    if (bg == 'cloudSkyBlue') {
      return buildSolid(const Color(0xFFDCE7EF));
    }
    if (bg == 'retroDark') {
      return buildSolid(const Color(0xFF2D3D4F));
    }
    if (bg == 'paperWhiteWarm') {
      return buildSolid(const Color(0xFFF7F1E8));
    }
    if (bg == 'minimalGray') {
      return buildSolid(const Color(0xFFD8DEE6));
    }
    if (bg == 'paperGray') {
      return buildSolid(const Color(0xFFE9EDF2));
    }
    if (bg == 'paperPink') {
      return buildSolid(const Color(0xFFF1DDE2));
    }
    if (bg == 'paperYellow') {
      return buildSolid(const Color(0xFFF6E6B0));
    }
    if (bg == 'paperBrownLined') {
      return buildSolid(const Color(0xFFD8C7B5));
    }
    if (bg == 'darkVignette') {
      return buildSolid(const Color(0xFF1F2937));
    }
    if (bg == 'deepNavy') {
      return buildSolid(const Color(0xFF24374A));
    }
    if (bg == 'saveDateHeroGradient') {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF6B92B3), Color(0xFFA98276)],
          ),
        ),
      );
    }
    if (bg == 'saveDateTopTint') {
      return Container(color: const Color(0x338EC5E8));
    }
    if (bg == 'saveDateBottomTint') {
      return Container(color: const Color(0x2EE8A580));
    }
    if (bg == 'saveDateHaze') {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(
            radiusPx ?? math.max(drawWidth, drawHeight),
          ),
        ),
      );
    }
    if (bg == 'chipPill' || bg == 'chipPillDark') {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111827).withOpacity(0.42),
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }
    if (bg == 'chipPillLight') {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }
    if (bg.startsWith('sticker')) {
      IconData icon = Icons.auto_awesome;
      Color color = const Color(0xFF5FA8FF);
      if (bg.contains('Flower')) {
        icon = Icons.local_florist_rounded;
        color = const Color(0xFFFF7AA8);
      } else if (bg.contains('Heart')) {
        icon = Icons.favorite_rounded;
        color = const Color(0xFFFF6289);
      } else if (bg.contains('Cloud')) {
        icon = Icons.cloud_rounded;
        color = const Color(0xFF9AC8FF);
      } else if (bg.contains('Clover') || bg.contains('Leaf')) {
        icon = Icons.eco_rounded;
        color = const Color(0xFF65B57A);
      } else if (bg.contains('Star') || bg.contains('Sparkle')) {
        icon = Icons.star_rounded;
        color = const Color(0xFFFFC45C);
      } else if (bg.contains('Tape')) {
        icon = Icons.horizontal_rule_rounded;
        color = const Color(0xFFE8CFA3);
      } else if (bg.contains('PaperClip')) {
        icon = Icons.attach_file_rounded;
        color = const Color(0xFF8B9BB4);
      }

      return Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.45)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 14, color: color),
      );
    }
    // Unknown decoration key fallback: keep visible mood instead of disappearing.
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE7EDF4),
        borderRadius: radiusPx != null ? BorderRadius.circular(radiusPx) : null,
      ),
    );
  }

  Widget _applyImageFrame(Widget child, String? frame) {
    if (frame == null || frame.isEmpty) return child;

    switch (frame) {
      case 'photoCard':
      case 'collageTile':
      case 'tornPaperCard':
      case 'tornNotebook':
      case 'tapeClip':
      case 'kraftPaper':
      case 'postalStamp':
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: child,
          ),
        );
      case 'filmSquare':
      case 'film':
      case 'vhs':
      case 'win95':
      case 'pixel8':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFDFDFD),
            border: Border.all(color: const Color(0xFFE0E0E0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x20000000),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: child,
        );
      case 'polaroidClassic':
      case 'posterPolaroid':
      case 'roughPolaroid':
      case 'ribbonPolaroid':
      case 'polaroidFilm':
      case 'polaroidWide':
      case 'polaroid':
        return Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: child,
        );
      case 'maskingTapeFrame':
      case 'paperTapeCard':
      case 'paperClipCard':
      case 'softPaperCard':
      case 'roundSoft':
      case 'round':
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFEFA),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: child,
        );
      case 'rounded28':
        return ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: child,
        );
      case 'circle':
        return ClipOval(child: child);
      case 'archSoft':
        return ClipPath(clipper: _StoreArchClipper(), child: child);
      case 'archOval':
        return LayoutBuilder(
          builder: (context, constraints) {
            final radius =
                math.min(constraints.maxWidth, constraints.maxHeight) * 0.41;
            return ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: child,
            );
          },
        );
      case 'circleRing':
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = math.min(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            final ringPadding = size * 0.054;
            final borderWidth = (size * 0.0027).clamp(1.0, 2.0);
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFC9D2DA),
                  width: borderWidth,
                ),
              ),
              padding: EdgeInsets.all(ringPadding),
              child: ClipOval(child: child),
            );
          },
        );
      case 'ticketStub':
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF243B53),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F0E6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: child,
                  ),
                ),
              ),
            ),
            const Positioned(left: -8, top: 44, child: _StoreTicketNotch()),
            const Positioned(right: -8, top: 44, child: _StoreTicketNotch()),
            const Positioned(left: -8, bottom: 30, child: _StoreTicketNotch()),
            const Positioned(right: -8, bottom: 30, child: _StoreTicketNotch()),
          ],
        );
      case 'oldNewspaper':
        return Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFEFE5D6),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: const Color(0xFFD3C3AB)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x16000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Color(0x22B08968),
              BlendMode.multiply,
            ),
            child: child,
          ),
        );
      case 'goldFrame':
      case 'neon':
      case 'floatingGlass':
      case 'gradientEdge':
      case 'offsetColorBlock':
      case 'comicBubble':
      case 'blob':
      case 'pinkSplatter':
      case 'toxicGlow':
      case 'stencilBlock':
      case 'midnightDrip':
      case 'vaporStreet':
        return Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEFF4FF), Color(0xFFDCE7FF)],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFB8C8E6), width: 1.3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: child,
          ),
        );
      case 'softGlow':
        return child;
      default:
        return child;
    }
  }

  Color? _parseHexColor(String? raw) {
    if (raw == null) return null;
    var value = raw.trim();
    if (value.isEmpty) return null;
    if (!value.startsWith('#')) value = '#$value';
    final hex = value.substring(1);
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return null;
  }

  Alignment _getAlignment(TextAlign? align) {
    switch (align) {
      case TextAlign.left:
        return Alignment.centerLeft;
      case TextAlign.right:
        return Alignment.centerRight;
      case TextAlign.justify:
        return Alignment.center;
      default:
        return Alignment.center;
    }
  }

  String _resolveTextFillUrl(LayerModel layer) {
    final raw = (layer.textFillImageUrl ?? '').trim();
    if (raw.isEmpty) return '';
    if (!raw.startsWith('@')) return raw;

    final key = raw.substring(1).toLowerCase();
    LayerModel? linked;
    for (final l in layers) {
      if (l.id == layer.id || l.type != LayerType.image) continue;
      if (l.id.toLowerCase().contains(key)) {
        linked = l;
        break;
      }
    }
    linked ??= layers.firstWhere(
      (l) => l.id != layer.id && l.type == LayerType.image,
      orElse: () => layer,
    );
    if (linked.id == layer.id) return '';
    return (linked.previewUrl ?? linked.imageUrl ?? linked.originalUrl ?? '')
        .trim();
  }
}

class _StoreArchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final archBottom = size.height * 0.32;
    final midX = size.width * 0.5;
    return Path()
      ..moveTo(0, size.height)
      ..lineTo(0, archBottom)
      ..quadraticBezierTo(midX, 0, size.width, archBottom)
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _StoreTicketNotch extends StatelessWidget {
  const _StoreTicketNotch();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F0E6),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF243B53), width: 1.2),
      ),
    );
  }
}

class _StoreImageClipText extends StatefulWidget {
  final String text;
  final TextAlign textAlign;
  final TextStyle style;
  final String imageUrl;

  const _StoreImageClipText({
    required this.text,
    required this.textAlign,
    required this.style,
    required this.imageUrl,
  });

  @override
  State<_StoreImageClipText> createState() => _StoreImageClipTextState();
}

class _StoreImageClipTextState extends State<_StoreImageClipText> {
  ui.Image? _image;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant _StoreImageClipText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _removeListener();
      _resolveImage();
    }
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  void _removeListener() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  void _resolveImage() {
    final provider = widget.imageUrl.startsWith('asset:')
        ? AssetImage(widget.imageUrl.substring('asset:'.length))
        : NetworkImage(
                imageUrlByVariant(
                  widget.imageUrl,
                  variant: ImageVariant.detail,
                ),
              )
              as ImageProvider;
    final stream = provider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        setState(() => _image = info.image);
      },
      onError: (_, __) {
        if (!mounted) return;
        setState(() => _image = null);
      },
    );
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) {
      return Text(
        widget.text,
        textAlign: widget.textAlign,
        style: widget.style.copyWith(color: Colors.black87),
      );
    }
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (_) => ImageShader(
        _image!,
        TileMode.clamp,
        TileMode.clamp,
        Matrix4.identity().storage,
      ),
      child: Text(
        widget.text,
        textAlign: widget.textAlign,
        style: widget.style,
      ),
    );
  }
}

class _StoreCutoutText extends StatelessWidget {
  final String text;
  final TextAlign textAlign;
  final TextStyle style;

  const _StoreCutoutText({
    required this.text,
    required this.textAlign,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstOut,
      shaderCallback: (_) => const LinearGradient(
        colors: [Colors.white, Colors.white],
      ).createShader(const Rect.fromLTWH(0, 0, 1, 1)),
      child: Text(
        text,
        textAlign: textAlign,
        style: style.copyWith(color: Colors.white),
      ),
    );
  }
}
