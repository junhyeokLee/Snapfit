import 'package:flutter/material.dart';

/// SnapFit 앱 브랜드 색상 (스플래시 화면 기준)
class SnapFitColors {
  SnapFitColors._();

  /// 배경: 딥 틸
  static const Color background = Color(0xFF101F22);
  static const Color backgroundDark = Color(0xFF0B1517);

  /// 액센트: 시안 블루
  static const Color accent = Color(0xFF00D2FF);
  /// 세컨드 액센트: 블루
  static const Color accentLight = Color(0xFF3A7BD5);

  /// 패널/서피스
  static const Color surface = Color(0xFF162A2E);

  /// 텍스트
  static const Color textPrimary = Color(0xFFFFFFFF);
  static Color textSecondary = Colors.white.withOpacity(0.7);
  static Color textMuted = Colors.white.withOpacity(0.5);

  static Color overlayLight = Colors.white.withOpacity(0.08);
  static Color overlayMedium = Colors.white.withOpacity(0.15);
  static Color overlayStrong = Colors.white.withOpacity(0.25);

  static const List<Color> editorGradient = [
    background,
    Color(0xFF0E1A1D),
    backgroundDark,
  ];
}
