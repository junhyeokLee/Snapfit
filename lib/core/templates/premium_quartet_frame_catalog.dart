part 'premium_quartet_frame_catalog.g.dart';

/// Native frame stock, independent from the replaceable sample photograph.
class PremiumQuartetFrameSpec {
  const PremiumQuartetFrameSpec(
    this.id,
    this.label,
    this.kind,
    this.variant,
    this.ink,
    this.tint,
    this.accent,
  );

  final String id, label, ink, tint, accent;
  final int kind, variant;
}

final premiumQuartetFramesById =
    Map<String, PremiumQuartetFrameSpec>.unmodifiable({
      for (final frame in premiumQuartetFrames) frame.id: frame,
    });
