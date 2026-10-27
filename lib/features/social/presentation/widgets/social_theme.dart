import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/web/web_design.dart';

/// Neutral interface surfaces let the published artwork carry the color.
abstract final class SocialTheme {
  static ThemeData from(ThemeData base) {
    if (kIsWeb) return SnapFitWebTheme.from(base);
    final dark = base.brightness == Brightness.dark;
    final background = dark ? SnapFitColors.deepCharcoal : Colors.white;
    final paper = dark ? const Color(0xFF202222) : const Color(0xFFF6F6F3);
    final ink = dark ? const Color(0xFFF5F6F4) : const Color(0xFF202523);
    final muted = dark ? const Color(0xFFA4AAA6) : const Color(0xFF6C736E);
    final line = dark ? const Color(0xFF323632) : const Color(0xFFE8EBE7);
    final accentInk = dark
        ? SnapFitColors.accentInkDark
        : SnapFitColors.accentInk;
    final accentSurface = dark
        ? SnapFitColors.accentSurfaceDark
        : SnapFitColors.accentLight;
    final web =
        (base.extension<WebPalette>() ??
                (dark ? WebPalette.dark : WebPalette.light))
            .copyWith(
              background: background,
              surface: background,
              canvas: paper,
              ink: ink,
              muted: muted,
              line: line,
              brand: SnapFitColors.actionAccent,
              brandInk: accentInk,
              onBrand: SnapFitColors.onAccent,
              softBrand: accentSurface,
            );
    return base.copyWith(
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: line,
      colorScheme: base.colorScheme.copyWith(
        surface: background,
        surfaceContainerLowest: background,
        surfaceContainerLow: paper,
        surfaceContainer: paper,
        surfaceContainerHigh: paper,
        surfaceContainerHighest: paper,
        surfaceTint: Colors.transparent,
        onSurface: ink,
        onSurfaceVariant: muted,
        outlineVariant: line,
        primary: SnapFitColors.actionAccent,
        onPrimary: SnapFitColors.onAccent,
        primaryContainer: accentSurface,
        onPrimaryContainer: accentInk,
        secondary: accentInk,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: background,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 64,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: ink,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -.6,
        ),
        iconTheme: IconThemeData(color: ink, size: 24),
      ),
      extensions: [
        ...base.extensions.values.where((value) => value is! WebPalette),
        web,
      ],
    );
  }
}
