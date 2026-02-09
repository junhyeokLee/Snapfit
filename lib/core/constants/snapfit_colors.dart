import 'package:flutter/material.dart';

/// SnapFit 앱 브랜드 색상
class SnapFitColors {
  SnapFitColors._();

  /// 배경: DeepCharcoal / PureWhite
  static const Color deepCharcoal = Color(0xFF121212);
  static const Color pureWhite = Color(0xFFFFFFFF);

  /// 카드/요소: 다크/라이트 서피스
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color surfaceLight = Color(0xFFF5F5F5);

  @Deprecated('Use backgroundOf(context) for theme-aware colors.')
  static const Color background = deepCharcoal;
  @Deprecated('Use backgroundOf(context) for theme-aware colors.')
  static const Color backgroundDark = Color(0xFF0E0E0E);

  /// 액센트: 시안 블루
  static const Color accent = Color(0xFF00D2FF);
  /// 세컨드 액센트: 블루
  static const Color accentLight = Color(0xFF3A7BD5);

  /// 패널/서피스 (기존 스냅핏 컬러 유지)
  static const Color surface = Color(0xFF162A2E);

  /// 중요 버튼용 Primary Gradient
  static const Color primaryGradientStart = Color(0xFF13C8EC);
  static const Color primaryGradientEnd = Color(0xFF8B5CF6);
  static const List<Color> primaryGradient = [
    primaryGradientStart,
    primaryGradientEnd,
  ];

  /// 배경 그라데이션 (다크/라이트)
  static const List<Color> editorGradientDark = [
    deepCharcoal,
    Color(0xFF1A1A1A),
    Color(0xFF0E0E0E),
  ];
  static const List<Color> editorGradientLight = [
    pureWhite,
    Color(0xFFF7F7F7),
    surfaceLight,
  ];

  @Deprecated('Use textPrimaryOf(context) for theme-aware colors.')
  static const Color textPrimary = pureWhite;
  @Deprecated('Use textSecondaryOf(context) for theme-aware colors.')
  static Color textSecondary = Colors.white.withOpacity(0.7);
  @Deprecated('Use textMutedOf(context) for theme-aware colors.')
  static Color textMuted = Colors.white.withOpacity(0.5);

  @Deprecated('Use overlayLightOf(context) for theme-aware colors.')
  static Color overlayLight = Colors.white.withOpacity(0.08);
  @Deprecated('Use overlayMediumOf(context) for theme-aware colors.')
  static Color overlayMedium = Colors.white.withOpacity(0.15);
  @Deprecated('Use overlayStrongOf(context) for theme-aware colors.')
  static Color overlayStrong = Colors.white.withOpacity(0.25);

  @Deprecated('Use editorGradientOf(context) for theme-aware colors.')
  static const List<Color> editorGradient = [
    deepCharcoal,
    Color(0xFF1A1A1A),
    Color(0xFF0E0E0E),
  ];

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color backgroundOf(BuildContext context) =>
      isDark(context) ? deepCharcoal : pureWhite;

  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? surfaceDark : surfaceLight;

  static Color textPrimaryOf(BuildContext context) =>
      isDark(context) ? pureWhite : deepCharcoal;

  static Color textSecondaryOf(BuildContext context) =>
      isDark(context) ? pureWhite.withOpacity(0.7) : deepCharcoal.withOpacity(0.7);

  static Color textMutedOf(BuildContext context) =>
      isDark(context) ? pureWhite.withOpacity(0.5) : deepCharcoal.withOpacity(0.5);

  static Color overlayLightOf(BuildContext context) =>
      isDark(context) ? pureWhite.withOpacity(0.08) : deepCharcoal.withOpacity(0.06);

  static Color overlayMediumOf(BuildContext context) =>
      isDark(context) ? pureWhite.withOpacity(0.15) : deepCharcoal.withOpacity(0.12);

  static Color overlayStrongOf(BuildContext context) =>
      isDark(context) ? pureWhite.withOpacity(0.25) : deepCharcoal.withOpacity(0.18);

  static List<Color> editorGradientOf(BuildContext context) =>
      isDark(context) ? editorGradientDark : editorGradientLight;
}
