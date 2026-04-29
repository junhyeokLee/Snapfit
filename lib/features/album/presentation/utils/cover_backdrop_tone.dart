import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../../../core/cache/snapfit_cache_manager.dart';
import '../../domain/entities/layer.dart';

String? resolveBackdropImageUrl(List<LayerModel> layers) {
  LayerModel? candidate;
  var candidateArea = 0.0;
  for (final layer in layers) {
    if (layer.type != LayerType.image) continue;
    final url = layer.previewUrl ?? layer.originalUrl ?? layer.imageUrl;
    if (url == null || url.isEmpty) continue;
    if (layer.width <= 0 || layer.height <= 0) continue;
    final area = layer.width * layer.height;
    if (area < 4000) continue;
    if (area <= candidateArea) continue;
    candidate = layer;
    candidateArea = area;
  }
  if (candidate == null) return null;
  return candidate.previewUrl ?? candidate.originalUrl ?? candidate.imageUrl;
}

Future<Color?> extractBackdropToneFromImageUrl(String imageUrl) async {
  try {
    final resolvedUrl = await resolveImageUrl(imageUrl);
    final file = await snapfitImageCacheManager.getSingleFile(resolvedUrl);
    final bytes = await file.readAsBytes();
    return computeBackdropTone(bytes);
  } catch (_) {
    return null;
  }
}

Future<String> resolveImageUrl(String imageUrl) async {
  if (!imageUrl.startsWith('gs://')) return imageUrl;
  final ref = FirebaseStorage.instance.refFromURL(imageUrl);
  return ref.getDownloadURL();
}

Color? computeBackdropTone(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  final resized = img.copyResize(
    decoded,
    width: 24,
    height: 24,
    interpolation: img.Interpolation.average,
  );

  final buckets = <int, ({double r, double g, double b, double weight, int count})>{};

  for (var y = 0; y < resized.height; y++) {
    for (var x = 0; x < resized.width; x++) {
      final pixel = resized.getPixel(x, y);
      final alpha = pixel.aNormalized;
      if (alpha < 0.2) continue;
      final isOuterEdge =
          x < 2 ||
          x >= resized.width - 2 ||
          y < 2 ||
          y >= resized.height - 2;
      final isInnerEdge =
          x < 4 ||
          x >= resized.width - 4 ||
          y < 4 ||
          y >= resized.height - 4;
      final edgeBoost = isOuterEdge
          ? 1.08
          : isInnerEdge
              ? 1.03
              : 1.0;
      final brightness = (pixel.r + pixel.g + pixel.b) / 3.0;
      final brightnessWeight =
          brightness < 28 || brightness > 242 ? 0.55 : 1.0;
      final weight = alpha * edgeBoost * brightnessWeight;

      final rq = (pixel.r ~/ 24).clamp(0, 10);
      final gq = (pixel.g ~/ 24).clamp(0, 10);
      final bq = (pixel.b ~/ 24).clamp(0, 10);
      final key = (rq << 16) | (gq << 8) | bq;
      final current = buckets[key];
      buckets[key] = current == null
          ? (
              r: pixel.r * weight,
              g: pixel.g * weight,
              b: pixel.b * weight,
              weight: weight,
              count: 1,
            )
          : (
              r: current.r + (pixel.r * weight),
              g: current.g + (pixel.g * weight),
              b: current.b + (pixel.b * weight),
              weight: current.weight + weight,
              count: current.count + 1,
            );
    }
  }

  if (buckets.isEmpty) return null;

  final dominant = buckets.values.reduce((best, current) {
    final bestScore = best.weight + (best.count * 0.24);
    final currentScore = current.weight + (current.count * 0.24);
    return currentScore > bestScore ? current : best;
  });

  final base = Color.fromARGB(
    0xFF,
    (dominant.r / dominant.weight).round().clamp(0, 255),
    (dominant.g / dominant.weight).round().clamp(0, 255),
    (dominant.b / dominant.weight).round().clamp(0, 255),
  );
  final hsl = HSLColor.fromColor(base);
  return hsl
      .withSaturation((hsl.saturation * 1.16).clamp(0.10, 0.96))
      .withLightness(hsl.lightness.clamp(0.16, 0.80))
      .toColor();
}
