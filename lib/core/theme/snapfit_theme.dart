import 'package:flutter/material.dart';

import '../constants/snapfit_colors.dart';

class SnapFitTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: SnapFitColors.pureWhite,
      colorScheme: const ColorScheme.light(
        primary: SnapFitColors.accent,
        secondary: SnapFitColors.accentLight,
        background: SnapFitColors.pureWhite,
        surface: SnapFitColors.surfaceLight,
        onBackground: SnapFitColors.deepCharcoal,
        onSurface: SnapFitColors.deepCharcoal,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: SnapFitColors.deepCharcoal,
        elevation: 0,
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: SnapFitColors.deepCharcoal,
      colorScheme: const ColorScheme.dark(
        primary: SnapFitColors.accent,
        secondary: SnapFitColors.accentLight,
        background: SnapFitColors.deepCharcoal,
        surface: SnapFitColors.surfaceDark,
        onBackground: SnapFitColors.pureWhite,
        onSurface: SnapFitColors.pureWhite,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: SnapFitColors.pureWhite,
        elevation: 0,
      ),
    );
  }
}
