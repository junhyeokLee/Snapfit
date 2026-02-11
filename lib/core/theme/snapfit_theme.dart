import 'package:flutter/material.dart';

import '../constants/snapfit_colors.dart';

/// SnapFit 공통 테마 (라이트/다크)
///
/// - 디자인 가이드 기준 (Primary Gradient, DeepCharcoal, PureWhite)
/// - 라이트/다크 모드 모두 지원
class SnapFitTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);

    const colorScheme = ColorScheme.light(
      primary: SnapFitColors.accent,
      secondary: SnapFitColors.accentLight,
      background: SnapFitColors.pureWhite,
      surface: SnapFitColors.surfaceLight,
      onBackground: SnapFitColors.deepCharcoal,
      onSurface: SnapFitColors.deepCharcoal,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: SnapFitColors.pureWhite,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: SnapFitColors.deepCharcoal,
        elevation: 0,
      ),
      textTheme: _textThemeLight(base.textTheme),
      inputDecorationTheme: _inputDecorationThemeLight(colorScheme),
      elevatedButtonTheme: _elevatedButtonThemeLight(colorScheme),
      outlinedButtonTheme: _outlinedButtonTheme(colorScheme),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);

    const colorScheme = ColorScheme.dark(
      primary: SnapFitColors.accent,
      secondary: SnapFitColors.accentLight,
      background: SnapFitColors.deepCharcoal,
      surface: SnapFitColors.surfaceDark,
      onBackground: SnapFitColors.pureWhite,
      onSurface: SnapFitColors.pureWhite,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: SnapFitColors.deepCharcoal,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: SnapFitColors.pureWhite,
        elevation: 0,
      ),
      textTheme: _textThemeDark(base.textTheme),
      inputDecorationTheme: _inputDecorationThemeDark(colorScheme),
      elevatedButtonTheme: _elevatedButtonThemeDark(colorScheme),
      outlinedButtonTheme: _outlinedButtonTheme(colorScheme),
    );
  }

  /// 라이트 모드용 텍스트 스케일
  static TextTheme _textThemeLight(TextTheme base) {
    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.02,
            color: SnapFitColors.deepCharcoal,
          ) ??
          const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.02,
            color: SnapFitColors.deepCharcoal,
          ),
      headlineMedium: base.headlineMedium?.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.015,
            color: SnapFitColors.deepCharcoal,
          ) ??
          const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.015,
            color: SnapFitColors.deepCharcoal,
          ),
      bodyLarge: base.bodyLarge?.copyWith(
            fontSize: 16,
            height: 1.6,
            fontWeight: FontWeight.w400,
            color: SnapFitColors.deepCharcoal,
          ) ??
          const TextStyle(
            fontSize: 16,
            height: 1.6,
            fontWeight: FontWeight.w400,
            color: SnapFitColors.deepCharcoal,
          ),
      bodySmall: base.bodySmall?.copyWith(
            fontSize: 12,
            letterSpacing: 0.05,
            fontWeight: FontWeight.w500,
            color: SnapFitColors.deepCharcoal,
          ) ??
          const TextStyle(
            fontSize: 12,
            letterSpacing: 0.05,
            fontWeight: FontWeight.w500,
            color: SnapFitColors.deepCharcoal,
          ),
    );
  }

  /// 다크 모드용 텍스트 스케일
  static TextTheme _textThemeDark(TextTheme base) {
    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.02,
            color: SnapFitColors.pureWhite,
          ) ??
          const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.02,
            color: SnapFitColors.pureWhite,
          ),
      headlineMedium: base.headlineMedium?.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.015,
            color: SnapFitColors.pureWhite,
          ) ??
          const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.015,
            color: SnapFitColors.pureWhite,
          ),
      bodyLarge: base.bodyLarge?.copyWith(
            fontSize: 16,
            height: 1.6,
            fontWeight: FontWeight.w400,
            color: SnapFitColors.pureWhite,
          ) ??
          const TextStyle(
            fontSize: 16,
            height: 1.6,
            fontWeight: FontWeight.w400,
            color: SnapFitColors.pureWhite,
          ),
      bodySmall: base.bodySmall?.copyWith(
            fontSize: 12,
            letterSpacing: 0.05,
            fontWeight: FontWeight.w500,
            color: SnapFitColors.pureWhite,
          ) ??
          const TextStyle(
            fontSize: 12,
            letterSpacing: 0.05,
            fontWeight: FontWeight.w500,
            color: SnapFitColors.pureWhite,
          ),
    );
  }

  static InputDecorationTheme _inputDecorationThemeLight(ColorScheme scheme) {
    return InputDecorationTheme(
      filled: false,
      hintStyle: TextStyle(
        color: SnapFitColors.deepCharcoal.withOpacity(0.5),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(
          color: SnapFitColors.deepCharcoal.withOpacity(0.06),
          width: 1,
        ),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(
          color: SnapFitColors.accent,
          width: 2,
        ),
      ),
    );
  }

  static InputDecorationTheme _inputDecorationThemeDark(ColorScheme scheme) {
    return InputDecorationTheme(
      filled: false,
      hintStyle: TextStyle(
        color: SnapFitColors.pureWhite.withOpacity(0.5),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(
          color: SnapFitColors.pureWhite.withOpacity(0.08),
          width: 1,
        ),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(
          color: SnapFitColors.accent,
          width: 2,
        ),
      ),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonThemeLight(
    ColorScheme scheme,
  ) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: SnapFitColors.pureWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonThemeDark(
    ColorScheme scheme,
  ) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: SnapFitColors.pureWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(ColorScheme scheme) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: scheme.onSurface.withOpacity(0.12),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
