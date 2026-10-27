import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../../shared/web/web_design.dart' show WebPalette;

/// The journal uses the shared web neutrals on both surfaces. Printed cover
/// artwork has its own fixed paper color and is not recolored by dark mode.
abstract final class MomentVisualStyle {
  static Color paper(BuildContext context) => kIsWeb
      ? WebPalette.of(context).canvas
      : Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF1A262C)
      : const Color(0xFFF7F9FA);

  static Color line(BuildContext context) => kIsWeb
      ? WebPalette.of(context).line
      : Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF32434B)
      : const Color(0xFFDFE8EC);
}
