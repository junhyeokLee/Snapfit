import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/shared/web/web_design.dart';

const _headerKey = ValueKey('web-utility-header');
const _globalHeaderKey = ValueKey('web-global-header');
const _desktopSidebarKey = ValueKey('web-desktop-sidebar');
const _menuKey = ValueKey('web-navigation-menu');
const _navigationKey = ValueKey('web-primary-navigation');
const _contentKey = ValueKey('shell-fixture-content');

Finder _destination(WebSection section) =>
    find.byKey(ValueKey('web-navigation-${section.name}'));

class _RetainedShellContent extends StatefulWidget {
  const _RetainedShellContent({required this.parentRevision});
  final int parentRevision;

  @override
  State<_RetainedShellContent> createState() => _RetainedShellContentState();
}

class _RetainedShellContentState extends State<_RetainedShellContent> {
  final draft = TextEditingController();
  final scroll = ScrollController();

  @override
  void dispose() {
    draft.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const ValueKey('retained-shell-scroll'),
    controller: scroll,
    child: Column(
      children: [
        TextField(
          key: const ValueKey('retained-shell-draft'),
          controller: draft,
        ),
        Text('parent revision: ${widget.parentRevision}'),
        const SizedBox(height: 2400),
      ],
    ),
  );
}

Future<void> _mount(
  WidgetTester tester, {
  double width = 1440,
  double height = 900,
  double textScale = 1,
  bool withNavigationScope = true,
  WebSection section = WebSection.albums,
  bool showNavigation = true,
  bool workspace = false,
  List<Widget> actions = const [],
  Widget? sidebar,
  Widget? headerTitle,
  bool compactBrand = false,
  bool denseHeader = false,
  ValueChanged<WebSection>? onNavigate,
  VoidCallback? onNotifications,
  VoidCallback? onHome,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: SnapFitWebTheme.from(
          ThemeData(splashFactory: NoSplash.splashFactory),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (_) {
            final shell = SnapFitWebShell(
              title: '내 앨범과 소중한 추억',
              headerTitle: headerTitle,
              compactBrand: compactBrand,
              denseHeader: denseHeader,
              section: section,
              showNavigation: showNavigation,
              workspace: workspace,
              actions: actions,
              sidebar: sidebar,
              onHome: onHome,
              child: const SizedBox.expand(key: _contentKey),
            );
            return withNavigationScope
                ? WebNavigationScope(
                    onNavigate: onNavigate ?? (_) {},
                    onNotifications: onNotifications ?? () {},
                    child: shell,
                  )
                : shell;
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'theme and parent rebuilds retain child state, draft and scroll',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late StateSetter rebuild;
      var dark = false;
      var revision = 0;
      await tester.pumpWidget(
        ProviderScope(
          child: StatefulBuilder(
            builder: (_, update) {
              rebuild = update;
              return MaterialApp(
                theme: SnapFitWebTheme.from(
                  ThemeData(
                    brightness: dark ? Brightness.dark : Brightness.light,
                  ),
                ),
                home: WebNavigationScope(
                  onNavigate: (_) {},
                  onNotifications: () {},
                  child: SnapFitWebShell(
                    child: _RetainedShellContent(parentRevision: revision),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initial = tester.state<_RetainedShellContentState>(
        find.byType(_RetainedShellContent),
      );
      await tester.enterText(
        find.byKey(const ValueKey('retained-shell-draft')),
        '아직 저장하지 않은 여행 기록',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(initial.scroll.position.maxScrollExtent, greaterThan(420));
      initial.scroll.jumpTo(420);
      await tester.pumpAndSettle();
      final offset = initial.scroll.offset;
      expect(offset, greaterThan(0));

      rebuild(() => revision++);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(_RetainedShellContent)), same(initial));
      expect(initial.draft.text, '아직 저장하지 않은 여행 기록');
      expect(initial.scroll.offset, closeTo(offset, .1));

      rebuild(() => dark = true);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(_RetainedShellContent)), same(initial));
      expect(initial.draft.text, '아직 저장하지 않은 여행 기록');
      expect(initial.scroll.offset, closeTo(offset, .1));
      expect(Theme.of(initial.context).brightness, Brightness.dark);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [600.0, 700.0]) {
    for (final scale in [1.6, 2.0]) {
      for (final focused in [false, true]) {
        testWidgets(
          '${focused ? 'focused' : 'global'} header fits $width px at ${scale}x text',
          (tester) async {
            var actions = 0;
            await _mount(
              tester,
              width: width,
              textScale: scale,
              showNavigation: !focused,
              workspace: focused,
              headerTitle: focused
                  ? const Text(
                      '우리의 여행 기록을 편집하고 있어요',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              actions: focused
                  ? [
                      FilledButton(
                        onPressed: () => actions++,
                        child: const Text('앨범 저장'),
                      ),
                    ]
                  : const [],
            );
            expect(tester.takeException(), isNull);
            final header = tester.getRect(find.byKey(_headerKey));
            expect(header.left, greaterThanOrEqualTo(0));
            expect(header.right, lessThanOrEqualTo(width));
            expect(find.byType(WebThemeMenu), findsOneWidget);
            if (focused) {
              await tester.tap(find.text('앨범 저장'));
              expect(actions, 1);
            } else {
              expect(find.byKey(_menuKey).hitTestable(), findsOneWidget);
              expect(find.byTooltip('새 앨범 만들기').hitTestable(), findsOneWidget);
              expect(find.byTooltip('알림').hitTestable(), findsOneWidget);
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final width in [390.0, 760.0, 1024.0, 1099.0, 1100.0, 1440.0, 1920.0]) {
    testWidgets('adaptive navigation fits at $width px', (tester) async {
      await _mount(
        tester,
        width: width,
        actions: [
          TextButton(onPressed: () {}, child: const Text('사진 업로드')),
          FilledButton(onPressed: () {}, child: const Text('앨범 만들기')),
        ],
      );
      final header = tester.getRect(find.byKey(_globalHeaderKey));
      final content = tester.getRect(find.byKey(_contentKey));
      expect(header.height, 68);
      expect(header.bottom, lessThanOrEqualTo(content.top));
      expect(content.left, greaterThanOrEqualTo(header.left));
      expect(content.right, lessThanOrEqualTo(header.right));
      if (width < 1100) {
        expect(find.byKey(_desktopSidebarKey), findsNothing);
        expect(find.byKey(_menuKey), findsOneWidget);
        expect(header.left, 0);
        expect(header.width, width);
        await tester.tap(find.byKey(_menuKey));
        await tester.pumpAndSettle();
        for (final section in WebSection.values) {
          expect(_destination(section), findsOneWidget);
          expect(
            tester.getRect(_destination(section)).height,
            greaterThanOrEqualTo(48),
          );
        }
      } else {
        final sidebar = tester.getRect(find.byKey(_desktopSidebarKey));
        final navigation = tester.getRect(find.byKey(_navigationKey));
        expect(sidebar.width, 224);
        expect(sidebar.left, 0);
        expect(sidebar.height, 900);
        expect(header.left, sidebar.right);
        expect(header.right, width);
        expect(navigation.left, sidebar.left);
        expect(navigation.top, sidebar.top);
        expect(navigation.bottom, sidebar.bottom);
        expect(navigation.right, sidebar.right - 1);
        expect(find.byKey(_menuKey), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'compact menu exposes every destination without horizontal scrolling',
    (tester) async {
      final visited = <WebSection>[];
      await _mount(tester, width: 390, onNavigate: visited.add);
      for (final section in WebSection.values) {
        await tester.tap(find.byTooltip('전체 메뉴'));
        await tester.pumpAndSettle();
        await tester.tap(_destination(section));
        await tester.pumpAndSettle();
      }
      expect(visited, WebSection.values);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'current destination exposes selected semantics and updates with the route',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _mount(tester, section: WebSection.orders);
        for (final section in WebSection.values) {
          expect(
            tester.getSemantics(
              find.byKey(ValueKey('web-navigation-semantics-${section.name}')),
            ),
            matchesSemantics(
              label: switch (section) {
                WebSection.albums => '내 앨범',
                WebSection.moments => '나의 기록',
                WebSection.feed => '피드',
                WebSection.create => '앨범 만들기',
                WebSection.designs => '템플릿·소재',
                WebSection.orders => '주문내역',
                WebSection.myProfile => '내 프로필',
                WebSection.account => '설정',
              },
              isButton: true,
              hasSelectedState: true,
              isSelected: section == WebSection.orders,
              hasEnabledState: true,
              isEnabled: true,
              isFocusable: true,
              hasTapAction: true,
              hasFocusAction: true,
            ),
          );
        }
        await _mount(tester, section: WebSection.designs);
        final selected = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .where((widget) => widget.properties.selected == true);
        expect(selected, hasLength(1));
        expect(
          find.descendant(
            of: find.byWidget(selected.single),
            matching: _destination(WebSection.designs),
          ),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'global navigation owns menu actions and local tools stay independent',
    (tester) async {
      final visited = <WebSection>[];
      var homeCount = 0;
      var notifications = 0;
      var actions = 0;
      await _mount(
        tester,
        onNavigate: visited.add,
        onHome: () => homeCount++,
        onNotifications: () => notifications++,
        actions: [
          TextButton(onPressed: () => actions++, child: const Text('사진 업로드')),
        ],
      );
      await tester.tap(_destination(WebSection.albums));
      await tester.tap(find.text('스냅핏'));
      await tester.tap(_destination(WebSection.orders));
      await tester.tap(find.byTooltip('알림'));
      await tester.tap(find.text('사진 업로드'));
      expect(homeCount, 0);
      expect(visited, [
        WebSection.albums,
        WebSection.albums,
        WebSection.orders,
      ]);
      expect(notifications, 1);
      expect(actions, 1);
    },
  );

  testWidgets('standalone shells retain their explicit destination callbacks', (
    tester,
  ) async {
    var homeCount = 0;
    await _mount(tester, withNavigationScope: false, onHome: () => homeCount++);
    await tester.tap(_destination(WebSection.albums));
    await tester.tap(find.text('스냅핏'));
    expect(homeCount, 2);
    expect(_destination(WebSection.feed), findsNothing);
    expect(find.byTooltip('알림'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('section pages share the same header and navigation geometry', (
    tester,
  ) async {
    Rect? expectedHeader;
    Rect? expectedSidebar;
    for (final section in WebSection.values) {
      await _mount(
        tester,
        section: section,
        workspace: section == WebSection.feed,
        compactBrand: section == WebSection.myProfile,
        denseHeader: section == WebSection.myProfile,
      );
      final header = tester.getRect(find.byKey(_globalHeaderKey));
      final sidebar = tester.getRect(find.byKey(_desktopSidebarKey));
      expectedHeader ??= header;
      expectedSidebar ??= sidebar;
      expect(header, expectedHeader, reason: section.name);
      expect(sidebar, expectedSidebar, reason: section.name);
      expect(header.height, 68);
      expect(find.byType(WebBrand), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('page tools sit below the shared header', (tester) async {
    await _mount(
      tester,
      headerTitle: const Text('페이지 제목', key: ValueKey('local-page-heading')),
      actions: [
        FilledButton(
          key: const ValueKey('local-page-action'),
          onPressed: () {},
          child: const Text('사진 추가'),
        ),
      ],
    );
    final header = tester.getRect(find.byKey(_globalHeaderKey));
    final title = tester.getRect(
      find.byKey(const ValueKey('local-page-heading')),
    );
    final action = tester.getRect(
      find.byKey(const ValueKey('local-page-action')),
    );
    final content = tester.getRect(find.byKey(_contentKey));
    expect(title.top, greaterThanOrEqualTo(header.bottom));
    expect(action.top, greaterThanOrEqualTo(header.bottom));
    expect(content.top, greaterThanOrEqualTo(action.bottom));
    expect(tester.takeException(), isNull);
  });

  for (final entry in [
    (name: 'short viewport', height: 460.0, textScale: 1.0),
    (name: 'large text', height: 900.0, textScale: 2.0),
  ]) {
    testWidgets('${entry.name} uses an accessible compact menu', (
      tester,
    ) async {
      await _mount(tester, height: entry.height, textScale: entry.textScale);
      expect(find.byKey(_desktopSidebarKey), findsNothing);
      expect(find.byKey(_menuKey), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(_menuKey));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_destination(WebSection.account));
      await tester.pumpAndSettle();
      expect(_destination(WebSection.account).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'focused workspace keeps original header and has no global navigation',
    (tester) async {
      final visited = <WebSection>[];
      await _mount(
        tester,
        width: 1440,
        workspace: true,
        showNavigation: false,
        onNavigate: visited.add,
      );
      final header = tester.getRect(find.byKey(_headerKey));
      final content = tester.getRect(find.byKey(_contentKey));
      expect(header.left, 28);
      expect(header.width, 1440 - 56);
      expect(header.height, 72);
      expect(content.top, 73);
      expect(content.left, 0);
      expect(content.width, 1440);
      expect(find.byKey(_navigationKey), findsNothing);
      expect(find.byTooltip('알림'), findsNothing);
      expect(find.byType(WebThemeMenu), findsOneWidget);
      await tester.tap(find.text('스냅핏'));
      expect(visited, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('page sidebar stays beside content below the global header', (
    tester,
  ) async {
    await _mount(
      tester,
      sidebar: const SizedBox.expand(key: ValueKey('explicit-sidebar')),
    );
    final sidebar = tester.getRect(
      find.byKey(const ValueKey('explicit-sidebar')),
    );
    final header = tester.getRect(find.byKey(_globalHeaderKey));
    final navigation = tester.getRect(find.byKey(_desktopSidebarKey));
    expect(sidebar.width, 220);
    expect(sidebar.top, header.bottom);
    expect(sidebar.left, navigation.right);
    expect(tester.takeException(), isNull);
  });
  testWidgets('website brand uses the mobile app image without recoloring it', (
    tester,
  ) async {
    await _mount(tester);
    final image = tester.widget<Image>(
      find.descendant(of: find.byType(WebBrand), matching: find.byType(Image)),
    );
    expect((image.image as AssetImage).assetName, WebBrand.asset);
    expect(image.fit, BoxFit.contain);
    expect(image.color, isNull);
    expect(find.text('스냅핏'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop utility buttons align to the content right edge', (
    tester,
  ) async {
    await _mount(tester);
    final header = tester.getRect(find.byKey(_headerKey));
    final notifications = tester.getRect(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == '알림',
      ),
    );
    expect(notifications.right, closeTo(header.right, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('web surfaces keep list tile feedback visible and interactive', (
    tester,
  ) async {
    var agreed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: Scaffold(
          body: WebSurface(
            child: StatefulBuilder(
              builder: (context, update) => CheckboxListTile(
                title: const Text('주문 내용 확인'),
                value: agreed,
                onChanged: (value) => update(() => agreed = value!),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(agreed, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'document header and save action fit at $width without another document bar',
      (tester) async {
        var saves = 0;
        await _mount(
          tester,
          width: width,
          workspace: true,
          showNavigation: false,
          compactBrand: true,
          denseHeader: true,
          headerTitle: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '우리의 기록',
                key: ValueKey('fixture-document-title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '저장하지 않은 변경사항',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            FilledButton(onPressed: () => saves++, child: const Text('앨범 저장')),
          ],
        );
        expect(find.byTooltip('스냅핏'), findsOneWidget);
        final header = tester.getRect(find.byKey(_headerKey));
        final title = tester.getRect(
          find.byKey(const ValueKey('fixture-document-title')),
        );
        expect(header.contains(title.center), isTrue);
        if (width > 760) expect(header.height, 64);
        await tester.tap(find.text('앨범 저장'));
        expect(saves, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
