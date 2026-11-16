import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/cover_size.dart';
import '../../album/domain/entities/layer.dart';
import 'moment_photo_design.dart';

/// New records use the same physical formats and logical canvas as albums.
/// The normalized original remains separate from this editable composition.
MomentPhotoDesign newMomentPhotoDesign({
  required Size photoSize,
  CoverSize cover = defaultCoverSize,
  String photoSource = momentPhotoOriginalSource,
}) {
  if (!photoSize.width.isFinite ||
      !photoSize.height.isFinite ||
      photoSize.width <= 0 ||
      photoSize.height <= 0) {
    throw ArgumentError.value(photoSize, 'photoSize', '사진 크기를 확인해 주세요.');
  }
  final canvas = coverCanvasBaseSize(newAlbumCoverSize(cover));
  final scale = math.min(
    canvas.width / photoSize.width,
    canvas.height / photoSize.height,
  );
  final size = photoSize * scale;
  return MomentPhotoDesign.fromLayers(
    canvasSize: canvas,
    backgroundColor: Colors.white,
    photoSource: photoSource,
    layers: [
      LayerModel(
        id: 'moment-original',
        type: LayerType.image,
        position: Offset(
          (canvas.width - size.width) / 2,
          (canvas.height - size.height) / 2,
        ),
        width: size.width,
        height: size.height,
        imageTemplate: 'free',
        originalUrl: photoSource,
        previewUrl: photoSource,
        imageUrl: photoSource,
      ),
    ],
  );
}

/// Only exact official canvases have an inferred format. Old free canvases
/// remain readable without silently assigning or changing their print size.
CoverSize? momentCoverForDesign(MomentPhotoDesign? design) {
  if (design == null) return null;
  final size = design.canvasSize;
  for (final cover in coverSizes) {
    final canonical = coverCanvasBaseSize(cover);
    if ((canonical.width - size.width).abs() < .001 &&
        (canonical.height - size.height).abs() < .001) {
      return cover;
    }
  }
  return null;
}

/// Explicit format changes fit the complete saved artboard uniformly. Reusing
/// normalized x/y against another aspect would stretch the artwork and crop.
MomentPhotoDesign resizeMomentPhotoDesign(
  MomentPhotoDesign source,
  CoverSize cover,
) {
  final canvas = coverCanvasBaseSize(newAlbumCoverSize(cover));
  final old = source.canvasSize;
  if (canvas == old) return source;
  final scale = math.min(canvas.width / old.width, canvas.height / old.height);
  final origin = Offset(
    (canvas.width - old.width * scale) / 2,
    (canvas.height - old.height * scale) / 2,
  );
  final oldBounds = Offset.zero & old;
  Rect transform(Rect rect) => Rect.fromLTWH(
    origin.dx + rect.left * scale,
    origin.dy + rect.top * scale,
    rect.width * scale,
    rect.height * scale,
  );
  final artboard = transform(oldBounds);
  double? dimension(double? value, double reference) {
    if (value == null || value <= 1) return value;
    final pixels = value * scale;
    // The existing schema uses <=1 for relative dimensions. An absolute 3px
    // stroke can become subpixel after a large canvas is fitted down; express
    // that result as its equivalent ratio rather than changing its meaning.
    return pixels > 1 ? pixels : math.min(1, value / reference);
  }

  return MomentPhotoDesign.fromLayers(
    canvasSize: canvas,
    backgroundColor: source.backgroundColor,
    photoSource: momentPhotoOriginalSource,
    layers: [
      for (final layer in source.layersForPhoto(momentPhotoOriginalSource))
        (() {
          // A saved layer can extend beyond its old canvas. Keep that existing
          // crop when the new format creates margins around the old artboard.
          final clip = (layer.canvasClip ?? oldBounds).intersect(oldBounds);
          final style = layer.textStyle;
          return layer.copyWith(
            position: origin + layer.position * scale,
            width: layer.width * scale,
            height: layer.height * scale,
            canvasClip: clip.isEmpty ? artboard : transform(clip),
            opacity: clip.isEmpty ? 0 : layer.opacity,
            imageOffset: layer.imageOffset == null
                ? null
                : layer.imageOffset! * scale,
            decorationBorderWidth: dimension(
              layer.decorationBorderWidth,
              layer.width,
            ),
            decorationCornerRadius: dimension(
              layer.decorationCornerRadius,
              math.min(layer.width, layer.height),
            ),
            textStyle: style?.copyWith(
              fontSize: style.fontSize == null ? null : style.fontSize! * scale,
              letterSpacing: style.letterSpacing == null
                  ? null
                  : style.letterSpacing! * scale,
              wordSpacing: style.wordSpacing == null
                  ? null
                  : style.wordSpacing! * scale,
              shadows: style.shadows
                  ?.map(
                    (shadow) => Shadow(
                      color: shadow.color,
                      offset: shadow.offset * scale,
                      blurRadius: shadow.blurRadius * scale,
                    ),
                  )
                  .toList(),
            ),
          );
        })(),
    ],
  );
}
