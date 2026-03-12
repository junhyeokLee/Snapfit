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

  /// 액센트: Vibrant Cyan (텍스트/아이콘)
  /// 디자인 명세: #00C2E0
  static const Color accent = Color(0xFF00C2E0);
  /// 세컨드 액센트: Solid Very Light Cyan (배경/버튼)
  /// 디자인 명세: #E3F9FD
  static const Color accentLight = Color(0xFFE3F9FD);

  /// 패널/서피스 (기존 스냅핏 컬러 유지)
  static const Color surface = Color(0xFF162A2E);

  /// 중요 버튼용 Primary Gradient
  static const Color primaryGradientStart = Color(0xFF13C8EC);
  static const Color primaryGradientEnd = Color(0xFF8B5CF6);
  static const List<Color> primaryGradient = [
    primaryGradientStart,
    primaryGradientEnd,
  ];

  /// Freeze 테마 전용 색상
  static const Color freezeBackground = Color(0xFF0D1B1F);
  static const Color freezeSurface = Color(0xFF1C3A42);
  static const Color freezeSurfaceDark = Color(0xFF0F2226);
  static const Color freezeAccent = Color(0xFF00D4EE);
  static const Color freezeAccentDark = Color(0xFF00A8C4);
  static const Color freezeGlow = Color(0xFF00C2E0);

  /// 에러 및 경고 (삭제 등)
  static const Color error = Color(0xFFE53935);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color errorDark = Color(0xFFC62828);

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

  /// 앨범 리더용 배경 그라데이션
  static const List<Color> readerGradientDark = [
    Color(0xFF1A2E33),
    Color(0xFF0D1B1F),
  ];
  static const List<Color> readerGradientLight = [
    Color(0xFFF0F4F8),
    Color(0xFFE8EEF4),
  ];

  /// FannedPagesView 전용 배경 그라데이션
  static const List<Color> fannedGradient = [
    Color(0xFF7D7A97),
    Color(0xFF9893A9),
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

  static List<Color> readerGradientOf(BuildContext context) =>
      isDark(context) ? readerGradientDark : readerGradientLight;
}

/// 텍스트 스타일(라벨/태그/테이프/소프트필 등) 공통 기본 팔레트 — 색상·순서 통일
class SnapFitStylePalette {
  SnapFitStylePalette._();

  // —— 연한색 (배경/기본/말풍선 공통) ——
  static const Color white = Color(0xFFFFFFFF);
  static const Color gray = Color(0xFFF5F5F5);
  static const Color pink = Color(0xFFFFEFF4);
  static const Color blue = Color(0xFFE8F0FF);
  static const Color mint = Color(0xFFE0F7F0);
  static const Color lavender = Color(0xFFEDE7F6);
  static const Color orange = Color(0xFFFFF3E0);
  static const Color green = Color(0xFFE8F5E9);
  static const Color cream = Color(0xFFFFFBF0);
  static const Color gold = Color(0xFFE8D4A8);

  // —— 진한색 (많이 쓰는 기본 색) ——
  /// 진한 파랑 (네이비)
  static const Color navy = Color(0xFF1565C0);
  /// 진한 핑크/로즈
  static const Color rose = Color(0xFFAD1457);
  /// 진한 초록
  static const Color darkGreen = Color(0xFF2E7D32);
  /// 진한 그레이/차콜
  static const Color charcoal = Color(0xFF424242);
  /// 진한 오렌지
  static const Color darkOrange = Color(0xFFE65100);
  /// 진한 보라
  static const Color violet = Color(0xFF5E35B1);

  // —— 추가 연한/중간 톤 (색상 다양화) ——
  /// 코랄/살몬
  static const Color coral = Color(0xFFFFE5E0);
  /// 베이지
  static const Color beige = Color(0xFFF5F0E8);
  /// 틸/청록
  static const Color teal = Color(0xFFE0F2F1);
  /// 레몬/연노랑
  static const Color lemon = Color(0xFFFFF9C4);
  /// 스카이(하늘)
  static const Color sky = Color(0xFFE1F5FE);
  /// 와인/버건디
  static const Color wine = Color(0xFFFCE4EC);

  /// 기본/말풍선 등에 쓰는 통일 14색 (연한 + 진한) — 순서 고정
  static const List<Color> unifiedBackgroundColors = [
    gray,
    pink,
    blue,
    mint,
    lavender,
    orange,
    green,
    cream,
    coral,
    beige,
    teal,
    lemon,
    navy,
    rose,
  ];

  // 라벨 타원 배경 (연한 톤, 라벨 전용)
  static const Color labelGray = Color(0xFFEEEEEE);
  static const Color labelPink = Color(0xFFFFE4EC);
  static const Color labelBlue = Color(0xFFE3F2FD);
  static const Color labelMint = Color(0xFFE0F7F0);
  static const Color labelLavender = Color(0xFFEDE7F6);
  static const Color labelOrange = Color(0xFFFFF3E0);
  static const Color labelGreen = Color(0xFFE8F5E9);
  static const Color labelWhite = Color(0xFFFAFAFA);
  static const Color labelCream = Color(0xFFFFFBF0);

  // 태그 테두리
  static const Color tagGray = Color(0xFF9E9E9E);
  static const Color tagPink = Color(0xFFFFB6C1);
  static const Color tagBlue = Color(0xFF90CAF9);
  static const Color tagMint = Color(0xFF80CBC4);
  static const Color tagLavender = Color(0xFFB39DDB);
  static const Color tagOrange = Color(0xFFFFCC80);
  static const Color tagGreen = Color(0xFF81C784);

  // 스트라이프 테이프 (base, stripe) — 동일 순서
  static const Color stripeSkyBase = Color(0xFFB6E8FF);
  static const Color stripeSkyStripe = Color(0xFF8FC9E8);
  static const Color stripeYellowBase = Color(0xFFFFFDE7);
  static const Color stripeYellowStripe = Color(0xFFFFE082);
  static const Color stripePinkBase = Color(0xFFFFE4EC);
  static const Color stripePinkStripe = Color(0xFFFFB6C1);
  static const Color stripeMintBase = Color(0xFFE0F7F0);
  static const Color stripeMintStripe = Color(0xFF80CBC4);
  static const Color stripeLavenderBase = Color(0xFFEDE7F6);
  static const Color stripeLavenderStripe = Color(0xFFB39DDB);
  static const Color stripeGrayBase = Color(0xFFEEEEEE);
  static const Color stripeGrayStripe = Color(0xFFBDBDBD);

  // 테이프 단색
  static const Color tapeKraft = Color(0xFFD7CCC8);
  static const Color tapeGold = Color(0xFFE8D4A8);
}
