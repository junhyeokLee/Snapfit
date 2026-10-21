import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/services.dart';

import '../constants/snapfit_colors.dart';
import 'snapfit_design_tokens.dart';

/// Interface chrome only; books retain their document fonts and geometry.
class SnapFitTheme {
  static SystemUiOverlayStyle systemOverlayStyle(
    BuildContext context, {
    Color? background,
  }) => _overlayFor(background ?? SnapFitColors.backgroundOf(context));

  static SystemUiOverlayStyle _overlayFor(Color background) {
    final dark =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: background,
      systemNavigationBarIconBrightness: dark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    );
  }

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark
        ? SnapFitColors.deepCharcoal
        : const Color(0xFFF9F7F4);
    final ink = dark ? const Color(0xFFF2F6F5) : const Color(0xFF222A2B);
    final muted = dark ? const Color(0xFFB0BAB8) : const Color(0xFF63706E);
    final surface = dark ? const Color(0xFF202726) : const Color(0xFFF3F6F5);
    final line = dark ? const Color(0xFF3B4543) : const Color(0xFFE6EBEA);
    final selection = dark ? const Color(0xFF163838) : const Color(0xFFE3F4F3);
    final selectionInk = dark
        ? const Color(0xFF7DD4D2)
        : const Color(0xFF0D8A88);
    const onAccent = SnapFitColors.onAccent;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: SnapFitColors.accent,
          brightness: brightness,
          surface: background,
        ).copyWith(
          primary: SnapFitColors.accent,
          onPrimary: onAccent,
          primaryContainer: selection,
          onPrimaryContainer: selectionInk,
          secondary: selectionInk,
          onSecondary: background,
          secondaryContainer: selection,
          onSecondaryContainer: selectionInk,
          surfaceContainerLowest: background,
          surfaceContainerLow: surface,
          surfaceContainer: surface,
          surfaceContainerHigh: surface,
          surfaceContainerHighest: surface,
          onSurface: ink,
          onSurfaceVariant: muted,
          outline: muted,
          outlineVariant: line,
        );
    final text = _textTheme(ink, muted);
    const control = StadiumBorder();
    final controlRounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SnapFitRadius.md),
    );
    final card = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SnapFitRadius.lg),
      side: BorderSide(color: line),
    );
    const padding = EdgeInsets.symmetric(horizontal: 18, vertical: 12);
    final filled = FilledButton.styleFrom(
      backgroundColor: scheme.primary,
      foregroundColor: onAccent,
      disabledBackgroundColor: surface,
      disabledForegroundColor: muted,
      minimumSize: const Size(48, 48),
      padding: padding,
      textStyle: text.labelLarge,
      shape: control,
      elevation: 0,
      animationDuration: SnapFitMotion.fast,
      tapTargetSize: MaterialTapTargetSize.padded,
    );
    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(SnapFitRadius.md),
          borderSide: BorderSide(color: color, width: width),
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: SnapFitFonts.body,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: line,
      hintColor: muted,
      disabledColor: muted,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: text,
      iconTheme: IconThemeData(color: ink, size: 22),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: selectionInk,
        selectionColor: scheme.primary.withValues(alpha: .25),
        selectionHandleColor: selectionInk,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: _overlayFor(background),
      ),
      filledButtonTheme: FilledButtonThemeData(style: filled),
      elevatedButtonTheme: ElevatedButtonThemeData(style: filled),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          disabledForegroundColor: muted,
          minimumSize: const Size(48, 48),
          padding: padding,
          textStyle: text.labelLarge,
          side: BorderSide(color: line),
          shape: control,
          animationDuration: SnapFitMotion.fast,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: selectionInk,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: text.labelLarge,
          shape: control,
          animationDuration: SnapFitMotion.fast,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: ink,
          disabledForegroundColor: muted,
          minimumSize: const Size(48, 48),
          shape: controlRounded,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: text.bodyMedium?.copyWith(color: muted),
        labelStyle: text.bodyMedium?.copyWith(color: muted),
        errorStyle: text.bodySmall?.copyWith(color: scheme.error),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: inputBorder(line),
        enabledBorder: inputBorder(line),
        focusedBorder: inputBorder(selectionInk, 1.5),
        errorBorder: inputBorder(scheme.error),
        focusedErrorBorder: inputBorder(scheme.error, 1.5),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: card,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: card,
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: background,
        modalBackgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SnapFitRadius.lg),
          ),
        ),
        dragHandleColor: muted,
        dragHandleSize: const Size(32, 4),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: background,
        surfaceTintColor: Colors.transparent,
        shape: card,
        textStyle: text.bodyMedium,
      ),
      listTileTheme: ListTileThemeData(
        textColor: ink,
        iconColor: muted,
        selectedColor: selectionInk,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
      ),
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: selection,
        secondarySelectedColor: selection,
        disabledColor: surface,
        labelStyle: text.labelMedium,
        secondaryLabelStyle: text.labelMedium?.copyWith(color: selectionInk),
        checkmarkColor: selectionInk,
        side: BorderSide(color: line),
        shape: control,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: selectionInk,
        unselectedLabelColor: muted,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.bodyMedium,
        indicatorColor: selectionInk,
        dividerColor: line,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: selection,
        indicatorShape: control,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium!.copyWith(
            color: states.contains(WidgetState.selected) ? selectionInk : muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? selectionInk : muted,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: background,
        indicatorColor: selection,
        indicatorShape: control,
        selectedLabelTextStyle: text.labelMedium?.copyWith(color: selectionInk),
        unselectedLabelTextStyle: text.bodySmall,
        selectedIconTheme: IconThemeData(color: selectionInk),
        unselectedIconTheme: IconThemeData(color: muted),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: text.bodyMedium,
        actionTextColor: selectionInk,
        elevation: 0,
        shape: card,
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: text.bodySmall?.copyWith(color: background),
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(SnapFitRadius.sm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        waitDuration: const Duration(milliseconds: 450),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: selectionInk,
        linearTrackColor: selection,
      ),
      checkboxTheme: CheckboxThemeData(
        checkColor: const WidgetStatePropertyAll(onAccent),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? onAccent : null,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SnapFitPageTransitionsBuilder(),
          TargetPlatform.iOS: SnapFitPageTransitionsBuilder(),
          TargetPlatform.macOS: SnapFitPageTransitionsBuilder(),
          TargetPlatform.windows: SnapFitPageTransitionsBuilder(),
          TargetPlatform.linux: SnapFitPageTransitionsBuilder(),
          TargetPlatform.fuchsia: SnapFitPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _textTheme(Color ink, Color muted) {
    TextStyle type(double size, FontWeight weight, [Color? color]) =>
        SnapFitType.style(size, weight: weight, color: color ?? ink);
    return TextTheme(
      displayLarge: type(48, FontWeight.w700),
      displayMedium: type(40, FontWeight.w700),
      displaySmall: type(34, FontWeight.w700),
      headlineLarge: type(32, FontWeight.w700),
      headlineMedium: type(26, FontWeight.w700),
      headlineSmall: type(24, FontWeight.w700),
      titleLarge: type(22, FontWeight.w700),
      titleMedium: type(16, FontWeight.w600),
      titleSmall: type(14, FontWeight.w600),
      bodyLarge: type(16, FontWeight.w400),
      bodyMedium: type(14, FontWeight.w400),
      bodySmall: type(12, FontWeight.w400, muted),
      labelLarge: type(14, FontWeight.w600),
      labelMedium: type(12, FontWeight.w600),
      labelSmall: type(11, FontWeight.w600),
    );
  }
}

/// Shared timing with platform back gestures and reduced-motion support.
class SnapFitPageTransitionsBuilder extends PageTransitionsBuilder {
  const SnapFitPageTransitionsBuilder();

  @override
  Duration get transitionDuration => SnapFitMotion.medium;
  @override
  Duration get reverseTransitionDuration => SnapFitMotion.fast;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final platform = Theme.of(context).platform;
    final PageTransitionsBuilder native =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS
        ? const CupertinoPageTransitionsBuilder()
        : const PredictiveBackPageTransitionsBuilder();
    final stationary =
        SnapFitMotion.reduced(context) && !route.popGestureInProgress;
    return native.buildTransitions(
      route,
      context,
      stationary ? kAlwaysCompleteAnimation : animation,
      stationary ? kAlwaysDismissedAnimation : secondaryAnimation,
      child,
    );
  }
}
