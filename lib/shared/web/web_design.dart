import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../core/constants/snapfit_colors.dart';
import '../../core/theme/snapfit_design_tokens.dart';
import '../../core/navigation/web_app_location.dart';
import 'web_theme_controller.dart';

/// Desktop tools and confirmations share a centered, viewport-bounded frame.
/// The caller supplies the existing tool and keeps ownership of its result.
Future<T?> showWebAwareDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = 760,
  double maxHeight = 800,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
}) {
  if (!kIsWeb) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
      isDismissible: barrierDismissible,
      constraints: BoxConstraints(maxWidth: maxWidth),
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    builder: (dialogContext) {
      final available = MediaQuery.sizeOf(dialogContext);
      final horizontalInset = available.width < 600 ? 16.0 : 32.0;
      final verticalInset = available.height < 600 ? 16.0 : 32.0;
      return Dialog(
        backgroundColor: WebPalette.of(dialogContext).surface,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        insetPadding: EdgeInsets.symmetric(
          horizontal: horizontalInset,
          vertical: verticalInset,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: math.min(
              maxWidth,
              math.max(0.0, available.width - horizontalInset * 2),
            ),
            maxHeight: math.min(
              maxHeight,
              math.max(0.0, available.height - verticalInset * 2),
            ),
          ),
          child: builder(dialogContext),
        ),
      );
    },
  );
}

/// Website chrome only. Album artwork and print geometry keep their own styles.
@immutable
class WebPalette extends ThemeExtension<WebPalette> {
  const WebPalette({
    required this.background,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.brand,
    required this.brandInk,
    required this.onBrand,
    required this.softBrand,
    required this.secondary,
    required this.canvas,
    required this.danger,
    required this.dangerSurface,
    required this.success,
    required this.successSurface,
    required this.warning,
    required this.warningSurface,
  });

  final Color background,
      surface,
      ink,
      muted,
      line,
      brand,
      brandInk,
      onBrand,
      softBrand,
      secondary,
      canvas,
      danger,
      dangerSurface,
      success,
      successSurface,
      warning,
      warningSurface;

  static const light = WebPalette(
    background: SnapFitColors.surfaceLight,
    surface: SnapFitColors.pureWhite,
    ink: SnapFitColors.deepCharcoal,
    muted: Color(0xFF6C6C6C),
    line: Color(0xFFE6EBEA),
    brand: SnapFitColors.accent,
    brandInk: Color(0xFF007E90),
    onBrand: SnapFitColors.onAccent,
    softBrand: SnapFitColors.accentLight,
    secondary: SnapFitColors.primaryGradientEnd,
    canvas: Color(0xFFF3F6F5),
    danger: Color(0xFFB3261E),
    dangerSurface: Color(0xFFFFEDEA),
    success: Color(0xFF226843),
    successSurface: Color(0xFFE8F5EC),
    warning: Color(0xFF865900),
    warningSurface: Color(0xFFFFF4D8),
  );
  static const dark = WebPalette(
    background: Color(0xFF111719),
    surface: Color(0xFF1B2326),
    ink: Color(0xFFEDF3F4),
    muted: Color(0xFFA8B7BA),
    line: Color(0xFF344247),
    brand: SnapFitColors.accent,
    brandInk: Color(0xFF71D8E6),
    onBrand: SnapFitColors.onAccent,
    softBrand: Color(0xFF12383F),
    secondary: Color(0xFFBAA1FF),
    canvas: Color(0xFF141E21),
    danger: Color(0xFFFFB4AB),
    dangerSurface: Color(0xFF482621),
    success: Color(0xFF93D6AB),
    successSurface: Color(0xFF1E372A),
    warning: Color(0xFFF1CB7A),
    warningSurface: Color(0xFF3D321C),
  );

  static WebPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<WebPalette>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  WebPalette copyWith({
    Color? background,
    Color? surface,
    Color? ink,
    Color? muted,
    Color? line,
    Color? brand,
    Color? brandInk,
    Color? onBrand,
    Color? softBrand,
    Color? secondary,
    Color? canvas,
    Color? danger,
    Color? dangerSurface,
    Color? success,
    Color? successSurface,
    Color? warning,
    Color? warningSurface,
  }) => WebPalette(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    line: line ?? this.line,
    brand: brand ?? this.brand,
    brandInk: brandInk ?? this.brandInk,
    onBrand: onBrand ?? this.onBrand,
    softBrand: softBrand ?? this.softBrand,
    secondary: secondary ?? this.secondary,
    canvas: canvas ?? this.canvas,
    danger: danger ?? this.danger,
    dangerSurface: dangerSurface ?? this.dangerSurface,
    success: success ?? this.success,
    successSurface: successSurface ?? this.successSurface,
    warning: warning ?? this.warning,
    warningSurface: warningSurface ?? this.warningSurface,
  );

  @override
  WebPalette lerp(covariant WebPalette? other, double t) {
    if (other == null) return this;
    return WebPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandInk: Color.lerp(brandInk, other.brandInk, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      softBrand: Color.lerp(softBrand, other.softBrand, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSurface: Color.lerp(dangerSurface, other.dangerSurface, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSurface: Color.lerp(successSurface, other.successSurface, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
    );
  }
}

abstract final class SnapFitWebTheme {
  static ThemeData from(ThemeData base) {
    final palette = base.brightness == Brightness.dark
        ? WebPalette.dark
        : WebPalette.light;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: palette.brand,
          brightness: base.brightness,
          surface: palette.surface,
        ).copyWith(
          primary: palette.brand,
          onPrimary: palette.onBrand,
          primaryContainer: palette.softBrand,
          onPrimaryContainer: palette.brandInk,
          secondary: palette.secondary,
          onSecondary: base.brightness == Brightness.dark
              ? const Color(0xFF261B3A)
              : Colors.white,
          surfaceContainerLowest: palette.background,
          surfaceContainerLow: palette.surface,
          surfaceContainer: palette.surface,
          surfaceContainerHigh: palette.canvas,
          surfaceContainerHighest: palette.canvas,
          onSurface: palette.ink,
          onSurfaceVariant: palette.muted,
          outlineVariant: palette.line,
          error: palette.danger,
          errorContainer: palette.dangerSurface,
          onErrorContainer: palette.danger,
        );
    const shape = StadiumBorder();
    return base.copyWith(
      extensions: [
        ...base.extensions.values.where(
          (extension) => extension is! WebPalette,
        ),
        palette,
      ],
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      dividerColor: palette.line,
      iconTheme: IconThemeData(color: palette.ink),
      hintColor: palette.muted,
      disabledColor: palette.muted.withValues(alpha: .55),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.brandInk,
        selectionColor: palette.brand.withValues(alpha: .28),
        selectionHandleColor: palette.brandInk,
      ),
      textTheme: base.textTheme
          .apply(bodyColor: palette.ink, displayColor: palette.ink)
          .copyWith(
            headlineLarge: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: palette.ink,
            ),
            headlineMedium: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: palette.ink,
            ),
            titleLarge: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: palette.ink,
            ),
            titleMedium: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: palette.ink,
            ),
            bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: palette.ink),
            bodyMedium: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: palette.ink,
            ),
            bodySmall: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: palette.muted,
            ),
            labelLarge: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          )
          .apply(fontFamily: 'NotoSans'),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface,
        foregroundColor: palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        hintStyle: TextStyle(color: palette.muted),
        labelStyle: TextStyle(color: palette.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SnapFitRadius.md),
          borderSide: BorderSide(color: palette.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SnapFitRadius.md),
          borderSide: BorderSide(color: palette.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SnapFitRadius.md),
          borderSide: BorderSide(color: palette.brandInk, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.brand,
          foregroundColor: palette.onBrand,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: shape,
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.brand,
          foregroundColor: palette.onBrand,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: shape,
          elevation: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SnapFitRadius.lg),
          side: BorderSide(color: palette.line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SnapFitRadius.lg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: palette.ink, fontSize: 14),
      ),
      listTileTheme: ListTileThemeData(
        textColor: palette.ink,
        iconColor: palette.muted,
        selectedColor: palette.brandInk,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surface,
        contentTextStyle: TextStyle(color: palette.ink, fontFamily: 'NotoSans'),
        actionTextColor: palette.brandInk,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SnapFitRadius.md),
          side: BorderSide(color: palette.line),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.ink,
          side: BorderSide(color: palette.line),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.brandInk,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          shape: shape,
        ),
      ),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 450),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.brand,
        linearTrackColor: palette.softBrand,
      ),
      checkboxTheme: CheckboxThemeData(
        checkColor: WidgetStatePropertyAll(palette.onBrand),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: palette.brandInk,
        unselectedLabelColor: palette.muted,
        indicatorColor: palette.brand,
      ),
      visualDensity: VisualDensity.standard,
    );
  }
}

enum WebSection { albums, create, designs, orders, account }

/// Global browser navigation is owned by the Router so every page shares the
/// same destinations and the current document can still block an unsafe exit.
class WebNavigationScope extends InheritedWidget {
  const WebNavigationScope({
    super.key,
    required this.onNavigate,
    required this.onNotifications,
    this.onPublicNavigate,
    required super.child,
  });
  final ValueChanged<WebSection> onNavigate;
  final VoidCallback onNotifications;
  final ValueChanged<WebAppLocation>? onPublicNavigate;
  static WebNavigationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WebNavigationScope>();
  @override
  bool updateShouldNotify(WebNavigationScope oldWidget) =>
      onNavigate != oldWidget.onNavigate ||
      onNotifications != oldWidget.onNotifications ||
      onPublicNavigate != oldWidget.onPublicNavigate;
}

/// Website navigation and content grid, independent of the mobile tab shell.
/// Callers own scrolling and navigation so workflow exit guards remain intact.
class SnapFitWebShell extends StatelessWidget {
  const SnapFitWebShell({
    super.key,
    required this.child,
    this.title,
    this.headerTitle,
    this.compactBrand = false,
    this.denseHeader = false,
    this.section = WebSection.albums,
    this.actions = const [],
    this.sidebar,
    this.workspace = false,
    this.showNavigation = true,
    this.onHome,
    this.onCreate,
    this.onOrders,
    this.onAccount,
    this.onDesigns,
    this.onNotifications,
  });

  final Widget child;
  final String? title;
  final Widget? headerTitle;
  final bool compactBrand, denseHeader;
  final WebSection section;
  final List<Widget> actions;
  final Widget? sidebar;
  final bool workspace;
  final bool showNavigation;
  final VoidCallback? onHome,
      onCreate,
      onOrders,
      onAccount,
      onDesigns,
      onNotifications;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: WebPalette.of(context).background,
    body: LayoutBuilder(
      builder: (context, bounds) {
        final compact = bounds.maxWidth < 760;
        // A keyboard or a short browser window must leave room for the
        // scrollable form instead of giving all available height to chrome.
        final shortViewport = bounds.maxHeight < 420 && headerTitle == null;
        final scope = WebNavigationScope.maybeOf(context);
        VoidCallback? destination(WebSection section, VoidCallback? explicit) =>
            explicit ??
            (scope == null ? null : () => scope.onNavigate(section));
        final homeAction = destination(WebSection.albums, onHome);
        final createAction = destination(WebSection.create, onCreate);
        final designsAction = destination(WebSection.designs, onDesigns);
        final ordersAction = destination(WebSection.orders, onOrders);
        final accountAction = destination(WebSection.account, onAccount);
        final notificationsAction = onNotifications ?? scope?.onNotifications;
        final links = <Widget>[
          if (homeAction != null)
            _navigation(context, '내 앨범', WebSection.albums, homeAction),
          if (createAction != null)
            _navigation(context, '앨범 만들기', WebSection.create, createAction),
          if (designsAction != null)
            _navigation(context, '템플릿·소재', WebSection.designs, designsAction),
          if (ordersAction != null)
            _navigation(context, '주문내역', WebSection.orders, ordersAction),
          if (accountAction != null)
            _navigation(context, '계정', WebSection.account, accountAction),
          if (scope?.onPublicNavigate != null)
            TextButton(
              key: const ValueKey('web-print-products-link'),
              onPressed: () =>
                  scope!.onPublicNavigate!(WebAppLocation.printProducts),
              child: const Text('인쇄 상품·가격'),
            ),
        ];
        final navigation = showNavigation && links.isNotEmpty;
        final brand = WebBrand(
          compact: compactBrand || shortViewport || (showNavigation && compact),
          onPressed: showNavigation ? homeAction : null,
        );
        Widget content = child;
        if (!workspace) {
          content = Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 20 : 32,
                  vertical: shortViewport ? 12 : (compact ? 20 : 32),
                ),
                child: content,
              ),
            ),
          );
        }
        Widget chromeRow(Widget child) => showNavigation
            ? Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 20 : 32,
                    ),
                    child: child,
                  ),
                ),
              )
            : Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 28),
                child: child,
              );
        return Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: WebPalette.of(context).surface,
                border: Border(
                  bottom: BorderSide(color: WebPalette.of(context).line),
                ),
              ),
              child: Column(
                children: [
                  if (showNavigation)
                    chromeRow(
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              key: const ValueKey('web-utility-header'),
                              children: [
                                brand,
                                if (navigation &&
                                    bounds.maxWidth >= 1180 &&
                                    MediaQuery.textScalerOf(
                                          context,
                                        ).scale(14) <=
                                        19)
                                  Expanded(
                                    child: Row(
                                      key: const ValueKey(
                                        'web-primary-navigation',
                                      ),
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: links,
                                    ),
                                  )
                                else
                                  const Spacer(),
                                const WebThemeMenu(),
                                if (notificationsAction != null)
                                  IconButton(
                                    onPressed: notificationsAction,
                                    tooltip: '알림',
                                    icon: const Icon(
                                      Icons.notifications_none,
                                      size: 21,
                                    ),
                                  ),
                                if (navigation &&
                                    (bounds.maxWidth < 1180 ||
                                        MediaQuery.textScalerOf(
                                              context,
                                            ).scale(14) >
                                            19))
                                  PopupMenuButton<VoidCallback>(
                                    key: const ValueKey(
                                      'web-primary-navigation',
                                    ),
                                    tooltip: '전체 메뉴',
                                    icon: const Icon(Icons.menu),
                                    onSelected: (action) => action(),
                                    itemBuilder: (_) => [
                                      for (final entry
                                          in <
                                            (String, WebSection, VoidCallback?)
                                          >[
                                            (
                                              '내 앨범',
                                              WebSection.albums,
                                              homeAction,
                                            ),
                                            (
                                              '앨범 만들기',
                                              WebSection.create,
                                              createAction,
                                            ),
                                            (
                                              '템플릿·소재',
                                              WebSection.designs,
                                              designsAction,
                                            ),
                                            (
                                              '주문내역',
                                              WebSection.orders,
                                              ordersAction,
                                            ),
                                            (
                                              '계정',
                                              WebSection.account,
                                              accountAction,
                                            ),
                                          ])
                                        if (entry.$3 != null)
                                          PopupMenuItem<VoidCallback>(
                                            key: ValueKey(
                                              'web-navigation-${entry.$2.name}',
                                            ),
                                            value: entry.$3,
                                            child: Semantics(
                                              selected: section == entry.$2,
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(entry.$1),
                                                  ),
                                                  if (section == entry.$2)
                                                    const Icon(
                                                      Icons.check,
                                                      size: 18,
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      if (scope?.onPublicNavigate != null)
                                        PopupMenuItem<VoidCallback>(
                                          value: () => scope!.onPublicNavigate!(
                                            WebAppLocation.printProducts,
                                          ),
                                          child: const Text('인쇄 상품·가격'),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                            if (headerTitle != null) ...[
                              const SizedBox(height: 8),
                              headerTitle!,
                            ],
                            if (actions.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 6,
                                runSpacing: 6,
                                children: actions,
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  else
                    chromeRow(
                      KeyedSubtree(
                        key: const ValueKey('web-utility-header'),
                        child: compact && !shortViewport
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        runSpacing: 8,
                                        children: [
                                          brand,
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const WebThemeMenu(),
                                              if (showNavigation &&
                                                  notificationsAction != null)
                                                IconButton(
                                                  onPressed:
                                                      notificationsAction,
                                                  tooltip: '알림',
                                                  icon: const Icon(
                                                    Icons.notifications_none,
                                                    size: 21,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (headerTitle != null) ...[
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: headerTitle!,
                                      ),
                                    ],
                                    if (actions.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Wrap(
                                          alignment: WrapAlignment.end,
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: actions,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            : SizedBox(
                                height: shortViewport
                                    ? math.max(
                                        52,
                                        MediaQuery.textScalerOf(
                                                  context,
                                                ).scale(14) *
                                                1.5 +
                                            20,
                                      )
                                    : denseHeader
                                    ? 64
                                    : 72,
                                child: Row(
                                  children: [
                                    brand,
                                    if (headerTitle != null) ...[
                                      const SizedBox(width: 16),
                                      Expanded(child: headerTitle!),
                                    ] else if (title != null && !compact) ...[
                                      const SizedBox(width: 24),
                                      const SizedBox(
                                        height: 20,
                                        child: VerticalDivider(width: 1),
                                      ),
                                      const SizedBox(width: 24),
                                      Expanded(
                                        child: Text(
                                          title!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (headerTitle == null && title == null)
                                      const Spacer(),
                                    const WebThemeMenu(),
                                    if (showNavigation &&
                                        notificationsAction != null)
                                      IconButton(
                                        onPressed: notificationsAction,
                                        tooltip: '알림',
                                        icon: const Icon(
                                          Icons.notifications_none,
                                          size: 21,
                                        ),
                                      ),
                                    if (shortViewport && actions.isNotEmpty)
                                      Flexible(
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: actions,
                                          ),
                                        ),
                                      )
                                    else
                                      ...actions,
                                  ],
                                ),
                              ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (sidebar != null && bounds.maxWidth >= 1000)
                    SizedBox(
                      width: 220,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: WebPalette.of(context).surface,
                          border: Border(
                            right: BorderSide(
                              color: WebPalette.of(context).line,
                            ),
                          ),
                        ),
                        child: sidebar!,
                      ),
                    ),
                  Expanded(child: content),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _navigation(
    BuildContext context,
    String label,
    WebSection target,
    VoidCallback callback,
  ) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: MergeSemantics(
      key: ValueKey('web-navigation-semantics-${target.name}'),
      child: Semantics(
        selected: section == target,
        child: TextButton(
          key: ValueKey('web-navigation-${target.name}'),
          onPressed: callback,
          style: TextButton.styleFrom(
            minimumSize: const Size(64, 44),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            textStyle: const TextStyle(
              fontFamily: 'NotoSans',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            foregroundColor: section == target
                ? WebPalette.of(context).brandInk
                : WebPalette.of(context).muted,
            backgroundColor: section == target
                ? WebPalette.of(context).softBrand.withValues(alpha: .55)
                : Colors.transparent,
          ),
          child: Text(label),
        ),
      ),
    ),
  );
}

/// Reuses the exact app mark without recoloring or stretching it.
class WebBrand extends StatelessWidget {
  const WebBrand({super.key, this.compact = false, this.onPressed});
  static const asset = 'assets/snapfit_logo.png';
  final bool compact;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final button = TextButton(
      key: const ValueKey('web-app-brand'),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: 8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              asset,
              width: 32,
              height: 32,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              filterQuality: FilterQuality.medium,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 10),
            Text(
              '스냅핏',
              style: TextStyle(
                fontFamily: 'NotoSans',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: WebPalette.of(context).ink,
              ),
            ),
          ],
        ],
      ),
    );
    return compact ? Tooltip(message: '스냅핏', child: button) : button;
  }
}

String webThemeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.light => '밝게',
  ThemeMode.dark => '어둡게',
  ThemeMode.system => '시스템 설정',
};

IconData _webThemeModeIcon(ThemeMode mode) => switch (mode) {
  ThemeMode.light => Icons.light_mode_outlined,
  ThemeMode.dark => Icons.dark_mode_outlined,
  ThemeMode.system => Icons.brightness_auto_outlined,
};

Future<void> _selectWebTheme(
  BuildContext context,
  WidgetRef ref,
  ThemeMode mode,
) async {
  final saved = await ref.read(webThemeModeProvider.notifier).select(mode);
  if (!saved && context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('테마를 적용했지만 브라우저에 저장하지 못했어요. 다음 방문 때 다시 선택해주세요.'),
      ),
    );
  }
}

/// Always available in website chrome, including guarded editing workflows.
class WebThemeMenu extends ConsumerWidget {
  const WebThemeMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(webThemeModeProvider);
    return PopupMenuButton<ThemeMode>(
      tooltip: '화면 테마: ${webThemeModeLabel(mode)}',
      initialValue: mode,
      icon: Icon(_webThemeModeIcon(mode), size: 21),
      onSelected: (next) => _selectWebTheme(context, ref, next),
      itemBuilder: (context) => [
        for (final option in ThemeMode.values)
          CheckedPopupMenuItem<ThemeMode>(
            value: option,
            checked: option == mode,
            child: Row(
              children: [
                Icon(_webThemeModeIcon(option), size: 18),
                const SizedBox(width: 12),
                Text(webThemeModeLabel(option)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Browser-only setting; never changes the native theme controller or key.
class WebThemeSetting extends ConsumerWidget {
  const WebThemeSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(webThemeModeProvider);
    final palette = WebPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '화면 테마',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: palette.ink,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in ThemeMode.values)
              ChoiceChip(
                label: Text(webThemeModeLabel(option)),
                avatar: Icon(
                  _webThemeModeIcon(option),
                  size: 17,
                  color: mode == option ? palette.brandInk : palette.muted,
                ),
                selected: mode == option,
                selectedColor: palette.softBrand,
                backgroundColor: palette.surface,
                labelStyle: TextStyle(
                  color: mode == option ? palette.brandInk : palette.ink,
                ),
                side: BorderSide(
                  color: mode == option ? palette.brandInk : palette.line,
                ),
                onSelected: (_) => _selectWebTheme(context, ref, option),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '이 브라우저에 저장됩니다. 시스템 설정은 기기의 밝은·어두운 화면 설정을 따라갑니다.',
          style: TextStyle(fontSize: 12, height: 1.7, color: palette.muted),
        ),
      ],
    );
  }
}

class WebPageHeading extends StatelessWidget {
  const WebPageHeading({
    super.key,
    required this.title,
    this.eyebrow,
    this.description,
    this.trailing,
  });
  final String title;
  final String? eyebrow, description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final text = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            Text(
              eyebrow!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: WebPalette.of(context).brandInk,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: bounds.maxWidth < 650 ? 24 : 28,
              letterSpacing: -.6,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description!,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: WebPalette.of(context).muted,
              ),
            ),
          ],
        ],
      );
      if (bounds.maxWidth < 650)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            text,
            if (trailing != null) ...[const SizedBox(height: 20), trailing!],
          ],
        );
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: text),
          if (trailing != null) ...[const SizedBox(width: 24), trailing!],
        ],
      );
    },
  );
}

class WebSurface extends StatelessWidget {
  const WebSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Material(
    color: WebPalette.of(context).surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: WebPalette.of(context).line),
    ),
    child: Padding(padding: padding, child: child),
  );
}
