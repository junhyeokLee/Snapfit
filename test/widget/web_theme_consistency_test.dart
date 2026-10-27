import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/snapfit_colors.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_theme.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_widgets.dart';
import 'package:snap_fit/shared/web/web_design.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('web surfaces share $brightness colors across feature themes', (
      tester,
    ) async {
      final web = SnapFitWebTheme.from(ThemeData(brightness: brightness));
      final palette = brightness == Brightness.dark
          ? WebPalette.dark
          : WebPalette.light;
      expect(web.scaffoldBackgroundColor, palette.background);
      expect(web.colorScheme.onSurface, palette.ink);
      expect(web.colorScheme.onSurfaceVariant, palette.muted);
      expect(web.appBarTheme.surfaceTintColor, Colors.transparent);
      expect(web.colorScheme.primary, SnapFitColors.actionAccent);
      expect(web.colorScheme.onPrimary, Colors.white);
      expect(
        web.filledButtonTheme.style!.foregroundColor!.resolve({}),
        Colors.white,
      );
      expect(
        (Colors.white.computeLuminance() + .05) /
            (web.colorScheme.primary.computeLuminance() + .05),
        greaterThanOrEqualTo(4.5),
      );
      if (!kIsWeb) return;

      final social = SocialTheme.from(web);
      expect(social.extension<WebPalette>()?.background, palette.background);
      expect(social.colorScheme.primary, web.colorScheme.primary);
      await tester.pumpWidget(
        MaterialApp(
          theme: social,
          home: Builder(
            builder: (context) {
              expect(SnapFitColors.backgroundOf(context), palette.background);
              expect(SnapFitColors.surfaceOf(context), palette.surface);
              expect(SnapFitColors.textPrimaryOf(context), palette.ink);
              expect(SnapFitColors.textSecondaryOf(context), palette.muted);
              expect(SocialStyle.background(context), palette.background);
              expect(SocialStyle.paper(context), palette.canvas);
              expect(SocialStyle.accent(context), palette.brandInk);
              expect(SocialStyle.line(context), palette.line);
              expect(SocialStyle.ink(context), palette.ink);
              return const Scaffold(body: Text('웹 공통 색상'));
            },
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
