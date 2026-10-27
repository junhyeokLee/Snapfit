import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/snapfit_colors.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_theme.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_widgets.dart';
import 'package:snap_fit/shared/widgets/experience_form_style.dart';
import 'package:snap_fit/shared/widgets/experience_style.dart';

double _contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
}

void _expectFilledBrand(ButtonStyle style) {
  for (final states in [
    <WidgetState>{},
    {WidgetState.hovered},
    {WidgetState.focused},
    {WidgetState.pressed},
  ]) {
    final background = style.backgroundColor!.resolve(states)!;
    final foreground = style.foregroundColor!.resolve(states)!;
    expect(background, SnapFitColors.actionAccent);
    expect(foreground, Colors.white);
    expect(_contrast(foreground, background), greaterThanOrEqualTo(4.5));
  }
}

void main() {
  test('brand keeps the logo cyan and a readable white-label action tone', () {
    expect(SnapFitColors.accent, const Color(0xFF0AB5D1));
    expect(SnapFitColors.onAccent, Colors.white);
    expect(
      _contrast(SnapFitColors.onAccent, SnapFitColors.actionAccent),
      greaterThanOrEqualTo(4.5),
    );
  });

  for (final dark in [false, true]) {
    final name = dark ? 'dark' : 'light';
    final ink = dark ? SnapFitColors.accentInkDark : SnapFitColors.accentInk;
    final selection = dark
        ? SnapFitColors.accentSurfaceDark
        : SnapFitColors.accentLight;

    test(
      '$name native theme uses white for filled actions and selected icons',
      () {
        final theme = dark ? SnapFitTheme.dark() : SnapFitTheme.light();
        final social = SocialTheme.from(theme);
        for (final candidate in [theme, social]) {
          expect(candidate.colorScheme.primary, SnapFitColors.actionAccent);
          expect(candidate.colorScheme.onPrimary, Colors.white);
          expect(candidate.colorScheme.primaryContainer, selection);
          expect(candidate.colorScheme.onPrimaryContainer, ink);
          _expectFilledBrand(candidate.filledButtonTheme.style!);
          _expectFilledBrand(candidate.elevatedButtonTheme.style!);
        }
        expect(
          theme.navigationBarTheme.indicatorColor,
          SnapFitColors.actionAccent,
        );
        expect(
          theme.navigationBarTheme.iconTheme!.resolve({
            WidgetState.selected,
          })!.color,
          Colors.white,
        );
        expect(
          theme.navigationBarTheme.labelTextStyle!.resolve({
            WidgetState.selected,
          })!.color,
          ink,
        );
        expect(
          theme.navigationRailTheme.indicatorColor,
          SnapFitColors.actionAccent,
        );
        expect(
          theme.navigationRailTheme.selectedIconTheme!.color,
          Colors.white,
        );
        expect(theme.navigationRailTheme.selectedLabelTextStyle!.color, ink);
        expect(
          theme.switchTheme.trackColor!.resolve({WidgetState.selected}),
          SnapFitColors.actionAccent,
        );
        expect(
          theme.switchTheme.thumbColor!.resolve({WidgetState.selected}),
          Colors.white,
        );
      },
    );

    testWidgets('$name form and social primary actions share the brand', (
      tester,
    ) async {
      final theme = dark ? SnapFitTheme.dark() : SnapFitTheme.light();
      await tester.pumpWidget(
        MaterialApp(
          theme: SocialTheme.from(theme),
          home: Builder(
            builder: (context) {
              _expectFilledBrand(ExperienceStyle.primary);
              _expectFilledBrand(ExperienceFormStyle.primary(context));
              _expectFilledBrand(SocialStyle.primary(context));
              expect(ExperienceFormStyle.selection(context), selection);
              expect(ExperienceFormStyle.selectionInk(context), ink);
              expect(SocialStyle.accent(context), ink);
              expect(
                _contrast(ink, ExperienceFormStyle.selection(context)),
                greaterThanOrEqualTo(4.5),
              );
              return const Scaffold(body: Text('브랜드 액션 색상'));
            },
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
