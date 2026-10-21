import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/editor_bottom_menu.dart';
import 'package:snap_fit/features/album/presentation/widgets/web/web_editor_tool_dialog.dart';
import 'package:snap_fit/shared/web/web_design.dart';

const _frame = ValueKey('web-editor-tool-dialog-frame');

Future<void> _mount(
  WidgetTester tester, {
  Size size = const Size(1440, 1000),
  Brightness brightness = Brightness.light,
  EditorMode initialMode = EditorMode.layer,
  ValueNotifier<int>? revision,
  ValueChanged<EditorMode>? onModeChanged,
  Widget Function(BuildContext, EditorMode, VoidCallback)? panelBuilder,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final buildPanel =
      panelBuilder ??
      (_, mode, __) => Center(
        child: Text('panel:${mode.name}', key: ValueKey('panel-${mode.name}')),
      );
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(viewInsets: viewInsets),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              key: const ValueKey('open-editor-fixture'),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    key: const ValueKey('underlying-editor-route'),
                    body: Center(
                      child: ElevatedButton(
                        key: const ValueKey('open-tool-fixture'),
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => revision == null
                              ? WebEditorToolDialog(
                                  initialMode: initialMode,
                                  onModeChanged: onModeChanged,
                                  panelBuilder: buildPanel,
                                )
                              : ValueListenableBuilder<int>(
                                  valueListenable: revision,
                                  builder: (_, value, __) =>
                                      WebEditorToolDialog(
                                        initialMode: value == 0
                                            ? initialMode
                                            : EditorMode.layout,
                                        onModeChanged: onModeChanged,
                                        panelBuilder: buildPanel,
                                      ),
                                ),
                        ),
                        child: const Text('도구 열기'),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('편집 화면 열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-editor-fixture')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('open-tool-fixture')));
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, EditorMode mode) async {
  final tab = find.byKey(ValueKey('web-editor-tool-tab-${mode.name}'));
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'wide selector is centered and gives its content a large bounded area',
    (tester) async {
      BoxConstraints? contentConstraints;
      await _mount(
        tester,
        panelBuilder: (_, __, ___) => LayoutBuilder(
          builder: (_, constraints) {
            contentConstraints = constraints;
            return GridView.builder(
              itemCount: 80,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
              ),
              itemBuilder: (_, index) => Text('item $index'),
            );
          },
        ),
      );
      final frame = tester.getRect(find.byKey(_frame));
      expect(frame.size, const Size(1120, 860));
      expect(frame.center, const Offset(720, 500));
      expect(contentConstraints!.hasBoundedWidth, isTrue);
      expect(contentConstraints!.hasBoundedHeight, isTrue);
      expect(contentConstraints!.maxWidth, 1120);
      expect(contentConstraints!.maxHeight, greaterThan(650));
      expect(find.text('앨범 편집 도구'), findsOneWidget);
      for (final label in ['레이어', '레이아웃', '템플릿', '꾸미기', '배경']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'narrow selector fills the screen and scrolls all five navigation tabs',
    (tester) async {
      await _mount(tester, size: const Size(390, 760));
      final frame = tester.getRect(find.byKey(_frame));
      expect(frame.left, 12);
      expect(frame.top, 12);
      expect(frame.size, const Size(366, 736));
      await _select(tester, EditorMode.backgroundColor);
      expect(
        find.byKey(const ValueKey('panel-backgroundColor')),
        findsOneWidget,
      );
      await _select(tester, EditorMode.layer);
      expect(find.byKey(const ValueKey('panel-layer')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tab selection survives parent rebuild and notifies once per new mode',
    (tester) async {
      final revision = ValueNotifier(0);
      addTearDown(revision.dispose);
      final changes = <EditorMode>[];
      await _mount(tester, revision: revision, onModeChanged: changes.add);
      await _select(tester, EditorMode.template);
      expect(
        find.byKey(const ValueKey('web-editor-tool-content-template')),
        findsOneWidget,
      );
      await _select(tester, EditorMode.template);
      expect(changes, [EditorMode.template]);
      revision.value = 1;
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('panel-template')), findsOneWidget);
      expect(find.byKey(const ValueKey('panel-layout')), findsNothing);
      expect(find.text('디자인을 크게 살펴보세요. 선택하면 현재 페이지에 적용됩니다.'), findsOneWidget);
      await _select(tester, EditorMode.sticker);
      expect(changes, [EditorMode.template, EditorMode.sticker]);
      expect(
        find.byKey(const ValueKey('web-editor-tool-content-sticker')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'controller navigation keeps selected content and mode notices in sync',
    (tester) async {
      final changes = <EditorMode>[];
      await _mount(tester, onModeChanged: changes.add);
      final tabs = tester.widget<TabBar>(
        find.byKey(const ValueKey('web-editor-tool-tabs')),
      );
      // Controller changes bypass TabBar.onTap, as accessibility or another
      // navigation action can do. Repeated animation notifications stay silent.
      tabs.controller!.animateTo(4);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('panel-backgroundColor')),
        findsOneWidget,
      );
      expect(changes, [EditorMode.backgroundColor]);
      tabs.controller!.index = 0;
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('panel-layer')), findsOneWidget);
      expect(changes, [EditorMode.backgroundColor, EditorMode.layer]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dark selector follows the existing web palette', (tester) async {
    await _mount(tester, brightness: Brightness.dark);
    final dialog = tester.widget<Dialog>(
      find.byKey(const ValueKey('web-editor-tool-dialog')),
    );
    final subtitle = tester.widget<Text>(
      find.byKey(const ValueKey('web-editor-tool-subtitle')),
    );
    final tabs = tester.widget<TabBar>(
      find.byKey(const ValueKey('web-editor-tool-tabs')),
    );
    expect(dialog.backgroundColor, WebPalette.dark.surface);
    expect(subtitle.style!.color, WebPalette.dark.muted);
    expect(tabs.labelColor, WebPalette.dark.brandInk);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keyboard inset keeps selector and scrollable content inside the view',
    (tester) async {
      BoxConstraints? contentConstraints;
      await _mount(
        tester,
        size: const Size(720, 600),
        viewInsets: const EdgeInsets.only(bottom: 200),
        panelBuilder: (_, __, ___) => LayoutBuilder(
          builder: (_, constraints) {
            contentConstraints = constraints;
            return ListView.builder(
              itemCount: 80,
              itemBuilder: (_, index) => Text('item $index'),
            );
          },
        ),
      );
      final frame = tester.getRect(find.byKey(_frame));
      expect(frame.height, 352);
      expect(frame.bottom, lessThanOrEqualTo(400));
      expect(contentConstraints!.hasBoundedHeight, isTrue);
      expect(contentConstraints!.maxHeight, greaterThan(100));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'repeated or stale apply close cannot pop the underlying editor',
    (tester) async {
      VoidCallback? closePanel;
      await _mount(
        tester,
        panelBuilder: (_, __, close) {
          closePanel = close;
          return const Center(child: Text('apply fixture'));
        },
      );
      final close = closePanel!;
      close();
      close();
      await tester.pumpAndSettle();
      close();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('web-editor-tool-dialog')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('underlying-editor-route')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('open-tool-fixture')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('header close returns to the same editor route', (tester) async {
    await _mount(tester, initialMode: EditorMode.layout);
    expect(find.byKey(const ValueKey('panel-layout')), findsOneWidget);
    await tester.tap(find.byTooltip('편집 도구 닫기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('web-editor-tool-dialog')), findsNothing);
    expect(
      find.byKey(const ValueKey('underlying-editor-route')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
