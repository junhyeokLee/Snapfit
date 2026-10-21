import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/shared/web/web_design.dart';

const _headerKey = ValueKey('web-utility-header');
const _navigationKey = ValueKey('web-primary-navigation');
const _contentKey = ValueKey('shell-fixture-content');

Finder _destination(WebSection section) =>
    find.byKey(ValueKey('web-navigation-${section.name}'));

Future<void> _mount(
  WidgetTester tester, {
  double width = 1440,
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
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: SnapFitWebTheme.from(
          ThemeData(splashFactory: NoSplash.splashFactory),
        ),
        home: WebNavigationScope(
          onNavigate: onNavigate ?? (_) {},
          onNotifications: onNotifications ?? () {},
          child: SnapFitWebShell(
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
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [390.0, 760.0, 1024.0, 1440.0, 1920.0]) {
    testWidgets('adaptive navigation fits at $width px', (tester) async {
      await _mount(
        tester,
        width: width,
        actions: [
          TextButton(onPressed: () {}, child: const Text('사진 업로드')),
          FilledButton(onPressed: () {}, child: const Text('앨범 만들기')),
        ],
      );
      final header = tester.getRect(find.byKey(_headerKey));
      final content = tester.getRect(find.byKey(_contentKey));
      expect(header.bottom, lessThan(content.top));
      expect(header.left, closeTo(content.left, .01));
      expect(header.right, closeTo(content.right, .01));
      if (width < 1180) {
        expect(find.byTooltip('전체 메뉴'), findsOneWidget);
        await tester.tap(find.byTooltip('전체 메뉴'));
        await tester.pumpAndSettle();
        for (final section in WebSection.values) {
          expect(_destination(section), findsOneWidget);
          expect(
            tester.getRect(_destination(section)).height,
            greaterThanOrEqualTo(48),
          );
        }
      } else {
        final navigation = tester.getRect(find.byKey(_navigationKey));
        expect(navigation.top, greaterThanOrEqualTo(header.top));
        expect(navigation.bottom, lessThanOrEqualTo(header.bottom));
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
                WebSection.create => '앨범 만들기',
                WebSection.designs => '템플릿·소재',
                WebSection.orders => '주문내역',
                WebSection.account => '계정',
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
    'explicit callback keeps precedence and utility actions stay independent',
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
      expect(homeCount, 2);
      expect(visited, [WebSection.orders]);
      expect(notifications, 1);
      expect(actions, 1);
    },
  );

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

  testWidgets(
    'explicit wide sidebar remains below the horizontal website chrome',
    (tester) async {
      await _mount(
        tester,
        sidebar: const SizedBox.expand(key: ValueKey('explicit-sidebar')),
      );
      final sidebar = tester.getRect(
        find.byKey(const ValueKey('explicit-sidebar')),
      );
      final navigation = tester.getRect(find.byKey(_navigationKey));
      expect(sidebar.width, 220);
      expect(sidebar.top, greaterThanOrEqualTo(navigation.bottom));
      expect(tester.takeException(), isNull);
    },
  );
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
