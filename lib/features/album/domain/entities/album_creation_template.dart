import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/cover_size.dart';
import 'layer.dart';

/// Pages use the physical album canvas, including each aspect variant.
class AlbumCreationTemplate {
  final String title;
  final String previewUrl;
  final bool isPremium;
  final CoverSize cover;
  final List<List<LayerModel>> pages;
  final Map<String, List<List<LayerModel>>> variants;
  final Map<String, Size> variantCanvasSizes;
  final Size? pagesCanvasSize;
  final bool preserveTypography;

  const AlbumCreationTemplate({
    required this.title,
    required this.previewUrl,
    required this.isPremium,
    required this.cover,
    required this.pages,
    this.variants = const {},
    this.variantCanvasSizes = const {},
    this.pagesCanvasSize,
    this.preserveTypography = false,
  });

  static String variantKey(CoverSize cover) =>
      cover.productId ?? aspectKey(cover);

  static String aspectKey(CoverSize cover) => cover.ratio < .95
      ? 'portrait'
      : cover.ratio > 1.05
      ? 'landscape'
      : 'square';

  static List<List<LayerModel>> preparePages(
    List<List<LayerModel>> pages, {
    required Size sourceCanvas,
    required CoverSize cover,
    bool clearSamplePhotos = true,
  }) {
    final target = coverCanvasBaseSize(cover);
    final scale = math.min(
      target.width / sourceCanvas.width,
      target.height / sourceCanvas.height,
    );
    final origin = Offset(
      (target.width - sourceCanvas.width * scale) / 2,
      (target.height - sourceCanvas.height * scale) / 2,
    );
    return pages
        .map(
          (page) => page
              .map(
                (layer) => layer.copyWith(
                  clearImage:
                      clearSamplePhotos && layer.type == LayerType.image,
                  position: layer.position * scale + origin,
                  width: layer.width * scale,
                  height: layer.height * scale,
                  textStyle: layer.textStyle?.copyWith(
                    fontSize: layer.textStyle?.fontSize == null
                        ? null
                        : layer.textStyle!.fontSize! * scale,
                    letterSpacing: layer.textStyle?.letterSpacing == null
                        ? null
                        : layer.textStyle!.letterSpacing! * scale,
                  ),
                  decorationBorderWidth: (layer.decorationBorderWidth ?? 0) > 1
                      ? layer.decorationBorderWidth! * scale
                      : layer.decorationBorderWidth,
                  decorationCornerRadius:
                      (layer.decorationCornerRadius ?? 0) > 1
                      ? layer.decorationCornerRadius! * scale
                      : layer.decorationCornerRadius,
                  decorationFillColor: layer.type == LayerType.image
                      ? layer.decorationFillColor ?? '#E7ECEB'
                      : layer.decorationFillColor,
                ),
              )
              .toList(),
        )
        .toList();
  }
}
