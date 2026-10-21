import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/constants/snapfit_colors.dart';
import '../../core/theme/snapfit_design_tokens.dart';
import 'experience_style.dart';
import '../web/web_design.dart';

/// Form surfaces share the catalog's visual language without changing editor chrome.
abstract final class ExperienceFormStyle {
  static Color ink(BuildContext context) => kIsWeb
      ? WebPalette.of(context).ink
      : SnapFitColors.isDark(context)
      ? const Color(0xFFF2F6F5)
      : ExperienceStyle.ink;
  static Color muted(BuildContext context) => kIsWeb
      ? WebPalette.of(context).muted
      : SnapFitColors.isDark(context)
      ? const Color(0xFFB0BAB8)
      : const Color(0xFF63706E);
  static Color surface(BuildContext context) => kIsWeb
      ? WebPalette.of(context).surface
      : SnapFitColors.isDark(context)
      ? const Color(0xFF202726)
      : ExperienceStyle.wash;
  static Color line(BuildContext context) => kIsWeb
      ? WebPalette.of(context).line
      : SnapFitColors.isDark(context)
      ? const Color(0xFF3B4543)
      : ExperienceStyle.line;
  static Color selection(BuildContext context) => kIsWeb
      ? WebPalette.of(context).softBrand
      : SnapFitColors.isDark(context)
      ? const Color(0xFF163838)
      : const Color(0xFFE3F4F3);
  static Color selectionInk(BuildContext context) => kIsWeb
      ? WebPalette.of(context).brandInk
      : SnapFitColors.isDark(context)
      ? const Color(0xFF7DD4D2)
      : const Color(0xFF0D8A88);

  static TextStyle text(
    BuildContext context,
    double size, {
    FontWeight weight = FontWeight.w400,
    bool secondary = false,
    Color? color,
  }) => ExperienceStyle.text(
    size,
    weight: weight,
    color: color ?? (secondary ? muted(context) : ink(context)),
  );

  static ButtonStyle primary(BuildContext context) => FilledButton.styleFrom(
    backgroundColor: kIsWeb
        ? WebPalette.of(context).brand
        : ExperienceStyle.accent,
    foregroundColor: kIsWeb
        ? WebPalette.of(context).onBrand
        : SnapFitColors.onAccent,
    disabledBackgroundColor: surface(context),
    disabledForegroundColor: muted(context),
    elevation: 0,
    minimumSize: const Size(0, 48),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    textStyle: ExperienceStyle.text(14, weight: FontWeight.w600),
    tapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    animationDuration: SnapFitMotion.duration(context, SnapFitMotion.fast),
    shape: const StadiumBorder(),
  );

  static InputDecoration input(
    BuildContext context, {
    String? hint,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: text(context, 14, secondary: true),
    filled: true,
    fillColor: surface(context),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(SnapFitRadius.md),
      borderSide: BorderSide(color: line(context)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(SnapFitRadius.md),
      borderSide: BorderSide(color: line(context)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(SnapFitRadius.md),
      borderSide: BorderSide(color: selectionInk(context), width: 1.5),
    ),
    errorStyle: const TextStyle(fontSize: 12, height: 1.4, letterSpacing: 0),
  );
}
