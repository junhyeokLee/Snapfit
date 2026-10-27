import 'dart:math' as math;

/// A small photo or sticker needs fewer decoded pixels than the entire page.
/// Null keeps editor/print callers that did not opt into preview sizing intact.
int? previewLayerDecodeWidth({
  required int? canvasDecodeWidth,
  required double widthFraction,
  required double heightFraction,
  double scale = 1,
  double zoom = 1,
}) {
  final limit = canvasDecodeWidth;
  if (limit == null || limit <= 0) return null;
  final fraction =
      math.max(widthFraction, heightFraction) *
      scale.abs() *
      math.max(1.0, zoom);
  if (!fraction.isFinite) return limit;
  final pixels = limit * fraction.clamp(0.0, 1.0);
  return ((pixels / 64).ceil() * 64).clamp(math.min(64, limit), limit).toInt();
}
