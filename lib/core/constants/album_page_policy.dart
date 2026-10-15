/// Redprinting photo book interior pages. The cover is counted separately.
abstract final class AlbumPagePolicy {
  static const int minInnerPages = 20;
  static const int maxInnerPages = 80;
  static const int pageStep = 2;

  static bool isValid(int count) =>
      count >= minInnerPages && count <= maxInnerPages && count % pageStep == 0;

  /// A new selection is bounded and rounded up to a complete sheet.
  static int normalize(int count) {
    final bounded = count.clamp(minInnerPages, maxInnerPages);
    return bounded.isEven ? bounded : bounded + 1;
  }

  /// Keeps oversized content visible so callers can block, never truncate it.
  static int minimumForContent(int count) {
    final minimum = count < minInnerPages ? minInnerPages : count;
    return minimum.isEven ? minimum : minimum + 1;
  }
}
