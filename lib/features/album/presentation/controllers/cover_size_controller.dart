import '../../data/models/cover_size.dart';

/// 레이아웃 계산만 담당. 기존 getCoverTop/getCoverSidePadding 그대로 이식.
class CoverSizeController {
  double getCoverTop(CoverSize s, double maxHeight) {
    if (s.ratio > 1) return maxHeight * 0.16; // 가로형
    if (s.ratio < 1) return maxHeight * 0.12; // 세로형
    return maxHeight * 0.12;                  // 정사각형
  }

  double getCoverSidePadding(CoverSize s) {
    return 16.0;
  }
}