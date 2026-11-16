part of 'web_design.dart';

/// Every signed-in destination uses the same navigation geometry. Page tools
/// belong below the global bar; only focused document editors use their own bar.
class SnapFitWebShell extends StatefulWidget {
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
    this.onMoments,
    this.onFeed,
    this.onCreate,
    this.onOrders,
    this.onAccount,
    this.onMyProfile,
    this.onDesigns,
    this.onNotifications,
  });
  final Widget child;
  final String? title;
  final Widget? headerTitle, sidebar;
  final bool compactBrand, denseHeader, workspace, showNavigation;
  final WebSection section;
  final List<Widget> actions;
  final VoidCallback? onHome,
      onMoments,
      onFeed,
      onCreate,
      onOrders,
      onAccount,
      onMyProfile,
      onDesigns,
      onNotifications;

  static String sectionLabel(WebSection section) => switch (section) {
    WebSection.albums => '내 앨범',
    WebSection.moments => '나의 기록',
    WebSection.feed => '피드',
    WebSection.create => '앨범 만들기',
    WebSection.designs => '템플릿·소재',
    WebSection.orders => '주문내역',
    WebSection.myProfile => '내 프로필',
    WebSection.account => '설정',
  };
  static IconData _sectionIcon(WebSection section) => switch (section) {
    WebSection.albums => Icons.auto_stories_outlined,
    WebSection.moments => Icons.photo_camera_outlined,
    WebSection.feed => Icons.grid_view_outlined,
    WebSection.create => Icons.add_rounded,
    WebSection.designs => Icons.palette_outlined,
    WebSection.orders => Icons.local_shipping_outlined,
    WebSection.myProfile => Icons.person_outline_rounded,
    WebSection.account => Icons.tune_rounded,
  };

  @override
  State<SnapFitWebShell> createState() => _SnapFitWebShellState();

  Widget _build(BuildContext context, GlobalKey<ScaffoldState> scaffoldKey) {
    final palette = WebPalette.of(context);
    final scope = WebNavigationScope.maybeOf(context);
    VoidCallback? destination(WebSection target) {
      if (scope != null) return () => scope.onNavigate(target);
      return switch (target) {
        WebSection.albums => onHome,
        WebSection.moments => onMoments,
        WebSection.feed => onFeed,
        WebSection.create => onCreate,
        WebSection.designs => onDesigns,
        WebSection.orders => onOrders,
        WebSection.myProfile => onMyProfile,
        WebSection.account => onAccount,
      };
    }

    final notifications = scope?.onNotifications ?? onNotifications;
    return LayoutBuilder(
      builder: (context, bounds) {
        final desktop =
            showNavigation &&
            bounds.maxWidth >= 1100 &&
            bounds.maxHeight >= 480 &&
            MediaQuery.textScalerOf(context).scale(14) <= 20;
        final small = bounds.maxWidth < 600;
        final compactToolbar =
            small || MediaQuery.textScalerOf(context).scale(14) > 20;
        final compactHeight = bounds.maxHeight < 420;

        Widget navItem(WebSection target, {bool drawer = false}) {
          final callback = destination(target);
          if (callback == null) return const SizedBox.shrink();
          final selected = target == section;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: MergeSemantics(
              key: ValueKey('web-navigation-semantics-${target.name}'),
              child: Semantics(
                selected: selected,
                child: TextButton(
                  key: ValueKey('web-navigation-${target.name}'),
                  onPressed: () {
                    if (drawer) scaffoldKey.currentState?.closeDrawer();
                    callback();
                  },
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    minimumSize: const Size(double.infinity, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    foregroundColor: selected ? palette.onBrand : palette.muted,
                    backgroundColor: selected
                        ? palette.brand
                        : Colors.transparent,
                    textStyle: TextStyle(
                      fontFamily: 'NotoSans',
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(_sectionIcon(target), size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text(sectionLabel(target))),
                      if (selected)
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: palette.onBrand,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        Widget navigation({bool drawer = false}) => ColoredBox(
          key: const ValueKey('web-primary-navigation'),
          color: palette.surface,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                SizedBox(
                  height: 80,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: WebBrand(
                        onPressed: () {
                          if (drawer) scaffoldKey.currentState?.closeDrawer();
                          destination(WebSection.albums)?.call();
                        },
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _WebNavGroupLabel('나의 공간', palette),
                        for (final target in [
                          WebSection.albums,
                          WebSection.moments,
                          WebSection.feed,
                        ])
                          navItem(target, drawer: drawer),
                        const SizedBox(height: 24),
                        _WebNavGroupLabel('만들고 꾸미기', palette),
                        for (final target in [
                          WebSection.create,
                          WebSection.designs,
                        ])
                          navItem(target, drawer: drawer),
                        const SizedBox(height: 24),
                        _WebNavGroupLabel('계정', palette),
                        for (final target in [
                          WebSection.myProfile,
                          WebSection.orders,
                          WebSection.account,
                        ])
                          navItem(target, drawer: drawer),
                        if (scope?.onPublicNavigate != null) ...[
                          const SizedBox(height: 24),
                          Divider(color: palette.line),
                          TextButton.icon(
                            key: const ValueKey('web-print-products-link'),
                            onPressed: () {
                              if (drawer)
                                scaffoldKey.currentState?.closeDrawer();
                              scope!.onPublicNavigate!(
                                WebAppLocation.printProducts,
                              );
                            },
                            style: TextButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              foregroundColor: palette.muted,
                              padding: const EdgeInsets.all(14),
                            ),
                            icon: const ExperienceIcon('Printer', size: 18),
                            label: const Text('인쇄 상품·가격'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        Widget content = child;
        if (!workspace) {
          content = Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: WebPageLayout.maxWidth,
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  WebPageLayout.horizontalInset(bounds.maxWidth),
                  compactHeight ? 16 : 32,
                  WebPageLayout.horizontalInset(bounds.maxWidth),
                  24,
                ),
                child: content,
              ),
            ),
          );
        }
        if (sidebar != null && bounds.maxWidth - (desktop ? 224 : 0) >= 1000) {
          content = Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 220, child: sidebar!),
              Expanded(child: content),
            ],
          );
        }

        Widget globalBar() => Container(
          key: const ValueKey('web-global-header'),
          height: 68,
          padding: EdgeInsets.symmetric(horizontal: small ? 16 : 32),
          decoration: BoxDecoration(
            color: palette.background,
            border: Border(bottom: BorderSide(color: palette.line)),
          ),
          child: Row(
            key: const ValueKey('web-utility-header'),
            children: [
              if (!desktop) ...[
                IconButton(
                  key: const ValueKey('web-navigation-menu'),
                  tooltip: '전체 메뉴',
                  onPressed: () => scaffoldKey.currentState?.openDrawer(),
                  icon: const ExperienceIcon('Menu', size: 22),
                ),
                const SizedBox(width: 4),
                WebBrand(
                  compact: compactToolbar,
                  onPressed: destination(WebSection.albums),
                ),
              ] else ...[
                Icon(_sectionIcon(section), size: 18, color: palette.muted),
                const SizedBox(width: 10),
                Text(
                  sectionLabel(section),
                  style: TextStyle(
                    fontFamily: 'NotoSans',
                    color: palette.ink,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
              const Spacer(),
              if (destination(WebSection.create) != null) ...[
                if (compactToolbar)
                  IconButton(
                    tooltip: '새 앨범 만들기',
                    onPressed: destination(WebSection.create),
                    icon: const ExperienceIcon('Plus'),
                  )
                else
                  FilledButton.icon(
                    onPressed: destination(WebSection.create),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.brand,
                      foregroundColor: palette.onBrand,
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const ExperienceIcon('Plus', size: 18),
                    label: const Text('새 앨범'),
                  ),
                const SizedBox(width: 12),
              ],
              const WebThemeMenu(),
              if (notifications != null)
                IconButton(
                  onPressed: notifications,
                  tooltip: '알림',
                  icon: const ExperienceIcon('Bell', size: 21),
                ),
            ],
          ),
        );

        Widget focusedBar() => Container(
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border(bottom: BorderSide(color: palette.line)),
          ),
          padding: EdgeInsets.symmetric(horizontal: small ? 12 : 28),
          child: SizedBox(
            height: denseHeader ? 64 : 72,
            child: Row(
              key: const ValueKey('web-utility-header'),
              children: [
                WebBrand(compact: compactBrand || compactToolbar),
                const SizedBox(width: 16),
                Expanded(
                  child:
                      headerTitle ??
                      Text(
                        title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                ),
                const WebThemeMenu(),
                if (compactToolbar && actions.isNotEmpty)
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
        );

        return Scaffold(
          key: scaffoldKey,
          backgroundColor: palette.background,
          drawer: showNavigation && !desktop
              ? Drawer(
                  width: math.min(304, bounds.maxWidth - 24),
                  backgroundColor: palette.surface,
                  child: navigation(drawer: true),
                )
              : null,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (desktop)
                Container(
                  key: const ValueKey('web-desktop-sidebar'),
                  width: 224,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: palette.line)),
                  ),
                  child: navigation(),
                ),
              Expanded(
                child: Column(
                  children: [
                    if (showNavigation) globalBar() else focusedBar(),
                    if (showNavigation &&
                        (headerTitle != null || actions.isNotEmpty))
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          WebPageLayout.horizontalInset(bounds.maxWidth),
                          16,
                          WebPageLayout.horizontalInset(bounds.maxWidth),
                          0,
                        ),
                        child: Row(
                          children: [
                            if (headerTitle != null)
                              Expanded(child: headerTitle!)
                            else
                              const Spacer(),
                            Flexible(
                              child: Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 8,
                                runSpacing: 8,
                                children: actions,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(child: content),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SnapFitWebShellState extends State<SnapFitWebShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) => widget._build(context, _scaffoldKey);
}

class _WebNavGroupLabel extends StatelessWidget {
  const _WebNavGroupLabel(this.label, this.palette);
  final String label;
  final WebPalette palette;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 0, 8, 9),
    child: Text(
      label,
      style: TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: palette.muted,
        letterSpacing: .3,
      ),
    ),
  );
}
