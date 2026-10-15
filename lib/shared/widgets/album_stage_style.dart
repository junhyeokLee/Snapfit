import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/snapfit_colors.dart';
import '../../core/theme/snapfit_theme.dart';

/// The same surface follows the album from the home stage into the reader.
abstract final class AlbumStageStyle {
  static Color top(BuildContext context) => SnapFitColors.isDark(context)
      ? const Color(0xFF202323)
      : const Color(0xFFF3F6F6);
  static Color bottom(BuildContext context) => SnapFitColors.isDark(context)
      ? const Color(0xFF151818)
      : const Color(0xFFFAFCFC);
  static Color ink(BuildContext context) => SnapFitColors.isDark(context)
      ? const Color(0xFFF1F4F2)
      : const Color(0xFF222725);
  static Color glass(BuildContext context) => SnapFitColors.isDark(context)
      ? const Color(0xFF303635)
      : Colors.white.withValues(alpha: 0.72);
  static Color line(BuildContext context) => SnapFitColors.isDark(context)
      ? const Color(0xFF48504D)
      : const Color(0xFFE0E6DF);
  static Color controlFill(BuildContext context) =>
      SnapFitColors.isDark(context)
      ? const Color(0xFF354440)
      : const Color(0xFFEDF3F2);
  static LinearGradient gradient(BuildContext context) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [top(context), bottom(context)],
  );
  static SystemUiOverlayStyle overlay(BuildContext context) =>
      SnapFitTheme.systemOverlayStyle(context);
}
