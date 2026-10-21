import 'package:flutter/material.dart';

import '../constants/snapfit_colors.dart';

class SnapFitFonts {
  SnapFitFonts._();

  static const String body = 'NotoSans';
  static const String display = 'NotoSans';
}

class SnapFitSpace {
  SnapFitSpace._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double section = 48;
}

class SnapFitRadius {
  SnapFitRadius._();

  static const double sm = 10;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 999;
}

/// Semantic shadow tokens. Pass `dark` from `Theme.of(context).brightness == Brightness.dark`.
class SnapFitShadow {
  SnapFitShadow._();

  /// Subtle card lift — interactive tiles, raised surfaces
  static List<BoxShadow> card(bool dark) => [
    BoxShadow(
      color: Color(dark ? 0x30000000 : 0x0D000000),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: Color(dark ? 0x18000000 : 0x06000000),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  /// Modal / bottom-sheet lifting shadow
  static List<BoxShadow> panel(bool dark) => [
    BoxShadow(
      color: Color(dark ? 0x44000000 : 0x16000000),
      blurRadius: 32,
      offset: const Offset(0, 8),
    ),
  ];

  /// Album artwork / cover dramatic depth
  static List<BoxShadow> artwork(bool dark) => [
    BoxShadow(
      color: Color(dark ? 0x55000000 : 0x22000000),
      blurRadius: 48,
      offset: const Offset(0, 16),
    ),
  ];

  /// Bottom navigation bar top-shadow (replaces hard border line)
  static List<BoxShadow> navBar(bool dark) => [
    BoxShadow(
      color: Color(dark ? 0x20000000 : 0x0A000000),
      offset: const Offset(0, -1),
      blurRadius: 20,
    ),
  ];
}

class SnapFitMotion {
  SnapFitMotion._();

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration medium = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);

  // Book turns keep the approved rhythm, independently of screen navigation.
  static const Duration pageTurn = Duration(milliseconds: 390);
  static const Duration pageTurnFast = Duration(milliseconds: 220);
  static const Curve entrance = Curves.easeOutCubic;
  static const Curve settle = Curves.easeOutQuart;
  static const Curve pageTurnCurve = Curves.easeOutQuart;
  static const Curve pageTurnExitCurve = Curves.easeInCubic;

  static bool reduced(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    return media?.disableAnimations == true ||
        media?.accessibleNavigation == true;
  }

  static Duration duration(BuildContext context, Duration value) =>
      reduced(context) ? Duration.zero : value;
}

/// Interface type only. Album artwork keeps its document fonts and geometry.
abstract final class SnapFitType {
  static TextStyle style(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) => TextStyle(
    fontFamily: SnapFitFonts.body,
    fontSize: size,
    fontWeight: weight,
    // Display-size headings breathe tighter; body text keeps generous Korean spacing.
    height: size >= 32 ? 1.2 : size >= 20 ? 1.3 : 1.55,
    letterSpacing: size >= 32 ? -0.6 : size >= 24 ? -0.4 : size >= 20 ? -0.3 : -0.1,
    color: color,
  );
}

extension SnapFitTextTokens on BuildContext {
  TextStyle sfTitle({double size = 16, FontWeight weight = FontWeight.w800}) {
    return SnapFitType.style(
      size,
      weight: weight,
      color: SnapFitColors.textPrimaryOf(this),
    );
  }

  TextStyle sfBody({double size = 14, FontWeight weight = FontWeight.w500}) {
    return SnapFitType.style(
      size,
      weight: weight,
      color: SnapFitColors.textPrimaryOf(this),
    );
  }

  TextStyle sfSub({double size = 12, FontWeight weight = FontWeight.w500}) {
    return SnapFitType.style(
      size,
      weight: weight,
      color: SnapFitColors.textSecondaryOf(this),
    );
  }
}
