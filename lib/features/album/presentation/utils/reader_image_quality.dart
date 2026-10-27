import 'dart:math' as math;
import 'package:flutter/painting.dart';

/// All turn textures share a fixed budget, independent of the album's length.
/// Resting spreads render their two live pages at screen resolution instead.
const readerCaptureByteBudget = 16 * 1024 * 1024;

double readerCapturePixelRatio(Size page, int count, double devicePixelRatio) {
  if (count <= 0 ||
      page.isEmpty ||
      !page.width.isFinite ||
      !page.height.isFinite) {
    return 1;
  }
  final device = devicePixelRatio.isFinite && devicePixelRatio > 0
      ? devicePixelRatio
      : 1.0;
  final budget = math.sqrt(
    readerCaptureByteBudget / (count * page.width * page.height * 4),
  );
  final cols = math.sqrt(count).ceil();
  final rows = (count / cols).ceil();
  final atlas = math.min(
    4096 / (cols * page.width),
    4096 / (rows * page.height),
  );
  return math.min(math.min(device, 3), math.min(budget, atlas));
}

int readerPageDecodeWidth(Size page, double devicePixelRatio) =>
    (math.max(page.width, page.height) * devicePixelRatio).ceil().clamp(
      128,
      1600,
    );

/// Navigator previews need only their displayed pixels, independently of the
/// full reader, zoom and print builders. Bucket widths to reuse decode keys.
int readerThumbnailDecodeWidth(
  Size page,
  double devicePixelRatio, {
  int? maximumWidth,
}) {
  final edge = math.max(page.width, page.height);
  final device = devicePixelRatio.isFinite && devicePixelRatio > 0
      ? devicePixelRatio
      : 1.0;
  final pixels = !edge.isFinite || edge <= 0
      ? 128.0
      : (edge * device).clamp(128.0, 512.0);
  final width = (pixels / 64).ceil() * 64;
  return maximumWidth != null && maximumWidth > 0
      ? math.min(width, maximumWidth)
      : width;
}
