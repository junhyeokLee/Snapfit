import 'package:flutter/material.dart';

import '../constants/snapfit_colors.dart';

class SnapFitFonts {
  SnapFitFonts._();

  static const String body = 'NotoSans';
  static const String display = 'Raleway';
}

class SnapFitSpace {
  SnapFitSpace._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

class SnapFitRadius {
  SnapFitRadius._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double pill = 999;
}

class SnapFitMotion {
  SnapFitMotion._();

  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 220);
}

extension SnapFitTextTokens on BuildContext {
  TextStyle sfTitle({double size = 16, FontWeight weight = FontWeight.w800}) {
    return TextStyle(
      fontFamily: SnapFitFonts.display,
      fontSize: size,
      fontWeight: weight,
      color: SnapFitColors.textPrimaryOf(this),
      letterSpacing: -0.2,
    );
  }

  TextStyle sfBody({double size = 14, FontWeight weight = FontWeight.w500}) {
    return TextStyle(
      fontFamily: SnapFitFonts.body,
      fontSize: size,
      fontWeight: weight,
      color: SnapFitColors.textPrimaryOf(this),
    );
  }

  TextStyle sfSub({double size = 12, FontWeight weight = FontWeight.w500}) {
    return TextStyle(
      fontFamily: SnapFitFonts.body,
      fontSize: size,
      fontWeight: weight,
      color: SnapFitColors.textSecondaryOf(this),
    );
  }
}
