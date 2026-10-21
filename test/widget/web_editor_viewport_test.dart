import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/presentation/widgets/web/web_editor_viewport.dart';

const _viewportKey = ValueKey('web-editor-viewport');
const _transformKey = ValueKey('web-editor-viewport-transform');
const _documentKey = ValueKey('fixture-document');

Matrix4 _matrix(WidgetTester tester) =>
    tester.widget<Transform>(find.byKey(_transformKey)).transform;

double _zoom(WidgetTester tester) => _matrix(tester).storage[0];

Offset _translation(WidgetTester tester) {
  final matrix = _matrix(tester);
  return Offset(matrix.storage[12], matrix.storage[13]);
}

Future<void> _mount(
  WidgetTester tester, {
  Size size = const Size(900, 640),
  Widget? child,
  bool enabled = true,
  ValueNotifier<bool>? saving,
  TextEditingController? textController,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final canvas = child ?? const ColoredBox(color: Colors.white);
  Widget viewport(bool enabled) => WebEditorViewport(
    enabled: enabled,
    child: SizedBox.expand(key: _documentKey, child: canvas),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            if (textController != null)
              SizedBox(width: 180, child: TextField(controller: textController)),
            Expanded(
              child: saving == null
                  ? viewport(enabled)
                  : ValueListenableBuilder<bool>(
                      valueListenable: saving,
                      builder: (_, saving, __) => viewport(!saving),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<bool?> _wheel(
  WidgetTester tester,
  Offset position,
  double dy,
) async {
  bool? allowDefault;
  await tester.sendEventToBinding(
    PointerScrollEvent(
      kind: PointerDeviceKind.mouse,
      position: position,
      scrollDelta: Offset(0, dy),
      onRespond: ({required bool allowPlatformDefault}) {
        // Capture whether an ordinary scroll remains available to the browser.
        // This callback never invokes browser APIs or a backend.
        allowDefault = allowPlatformDefault;
      },
    ),
  );
  await tester.pump();
  return allowDefault;
}

void main() {
  testWidgets('zoom is a bounded view transform and fit recenters the view', (
    tester,
  ) async {
    final observedLayouts = <Size>[];
    final observedZooms = <double>[];
    await _mount(
      tester,
      child: Builder(
        builder: (context) {
          observedZooms.add(WebEditorViewportScale.of(context));
          return LayoutBuilder(
            builder: (_, constraints) {
              observedLayouts.add(constraints.biggest);
              return const ColoredBox(color: Colors.white);
            },
          );
        },
      ),
    );
    final originalSize = tester.getSize(find.byKey(_documentKey));
    expect(find.text('100%'), findsOneWidget);
    expect(_zoom(tester), 1);
    await tester.tap(find.byTooltip('화면 확대'));
    await tester.pump();
    expect(find.text('125%'), findsOneWidget);
    expect(observedZooms.last, 1.25);
    expect(tester.getSize(find.byKey(_documentKey)), originalSize);
    expect(observedLayouts.every((size) => size == originalSize), isTrue);
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byTooltip('화면 축소'));
      await tester.pump();
    }
    expect(_zoom(tester), .25);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('web-editor-zoom-out')))
          .onPressed,
      isNull,
    );
    for (var i = 0; i < 15; i++) {
      await tester.tap(find.byTooltip('화면 확대'));
      await tester.pump();
    }
    expect(_zoom(tester), 3);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('web-editor-zoom-in')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('web-editor-zoom-fit')));
    await tester.pump();
    expect(_zoom(tester), 1);
    expect(_translation(tester), Offset.zero);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ctrl and Cmd wheel zoom around the pointer without changing layout', (
    tester,
  ) async {
    await _mount(tester);
    final document = tester.renderObject<RenderBox>(find.byKey(_documentKey));
    final anchor = tester.getTopLeft(find.byKey(_viewportKey)) +
        const Offset(170, 120);
    final before = document.globalToLocal(anchor);
    final layout = document.size;
    expect(await _wheel(tester, anchor, -90), isTrue);
    expect(_zoom(tester), 1);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    expect(await _wheel(tester, anchor, -90), isFalse);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(_zoom(tester), greaterThan(1));
    expect((document.globalToLocal(anchor) - before).distance, lessThan(.0001));
    expect(document.size, layout);
    final previousZoom = _zoom(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    expect(await _wheel(tester, anchor, 40), isFalse);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    expect(_zoom(tester), lessThan(previousZoom));
    expect((document.globalToLocal(anchor) - before).distance, lessThan(.0001));
  });

  testWidgets('ordinary mouse drags stay with the document layer gesture', (
    tester,
  ) async {
    var layerMoves = 0;
    await _mount(
      tester,
      child: GestureDetector(
        onScaleUpdate: (_) => layerMoves++,
        child: const ColoredBox(color: Colors.white),
      ),
    );
    final start = tester.getCenter(find.byKey(_viewportKey));
    final mouse = await tester.startGesture(start, kind: PointerDeviceKind.mouse);
    await mouse.moveBy(const Offset(30, 0));
    await mouse.moveBy(const Offset(30, 10));
    await mouse.up();
    await tester.pump();
    expect(layerMoves, greaterThan(0));
    expect(_zoom(tester), 1);
    expect(_translation(tester), Offset.zero);
  });

  testWidgets('Space held before entering pans the view without dragging a layer', (
    tester,
  ) async {
    var layerMoves = 0;
    await _mount(
      tester,
      child: GestureDetector(
        onScaleUpdate: (_) => layerMoves++,
        child: const ColoredBox(color: Colors.white),
      ),
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    final start = tester.getCenter(find.byKey(_viewportKey));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: start);
    await tester.pump();
    await mouse.down(start);
    await mouse.moveBy(const Offset(45, 32));
    await mouse.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await mouse.removePointer();
    await tester.pump();
    expect(layerMoves, 0);
    expect(_translation(tester).dx, closeTo(45, .001));
    expect(_translation(tester).dy, closeTo(32, .001));
    expect(_zoom(tester), 1);
  });

  testWidgets('middle mouse pans and fit clears the pan', (tester) async {
    var layerMoves = 0;
    await _mount(
      tester,
      child: GestureDetector(
        onScaleUpdate: (_) => layerMoves++,
        child: const ColoredBox(color: Colors.white),
      ),
    );
    final mouse = await tester.startGesture(
      tester.getCenter(find.byKey(_viewportKey)),
      kind: PointerDeviceKind.mouse,
      buttons: kMiddleMouseButton,
    );
    await mouse.moveBy(const Offset(-55, 25));
    await mouse.up();
    await tester.pump();
    expect(layerMoves, 0);
    expect(_translation(tester).dx, closeTo(-55, .001));
    expect(_translation(tester).dy, closeTo(25, .001));
    await tester.tap(find.byKey(const ValueKey('web-editor-zoom-fit')));
    await tester.pump();
    expect(_translation(tester), Offset.zero);
  });

  testWidgets('text focus preserves typing and never enables viewport gestures', (
    tester,
  ) async {
    final controller = TextEditingController(text: '앨범 이름');
    addTearDown(controller.dispose);
    await _mount(tester, textController: controller);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    final position = tester.getCenter(find.byKey(_viewportKey));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: position);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    expect(await _wheel(tester, position, -100), isTrue);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    // A deliberate click outside the field may dismiss its focus. The earlier
    // Space key press must not leave a sticky viewport-pan mode behind.
    await mouse.down(position);
    await mouse.moveBy(const Offset(40, 35));
    await mouse.up();
    await mouse.removePointer();
    expect(_translation(tester), Offset.zero);
    expect(_zoom(tester), 1);
    expect(controller.text, '앨범 이름');
  });

  testWidgets('wheel cannot change the view during an active layer drag', (
    tester,
  ) async {
    await _mount(tester);
    final position = tester.getCenter(find.byKey(_viewportKey));
    final mouse = await tester.startGesture(position, kind: PointerDeviceKind.mouse);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    expect(await _wheel(tester, position, -100), isTrue);
    expect(_zoom(tester), 1);
    await mouse.up();
    expect(await _wheel(tester, position, -100), isFalse);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(_zoom(tester), greaterThan(1));
  });

  testWidgets('saving disables controls and cancels an active viewport pan', (
    tester,
  ) async {
    final saving = ValueNotifier(false);
    addTearDown(saving.dispose);
    await _mount(tester, saving: saving);
    final position = tester.getCenter(find.byKey(_viewportKey));
    final mouse = await tester.startGesture(
      position,
      kind: PointerDeviceKind.mouse,
      buttons: kMiddleMouseButton,
    );
    await mouse.moveBy(const Offset(25, 20));
    await tester.pump();
    final before = _translation(tester);
    saving.value = true;
    await tester.pump();
    await mouse.moveBy(const Offset(40, 35));
    await mouse.up();
    await tester.pump();
    expect(_translation(tester), before);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('web-editor-zoom-in')))
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<TextButton>(find.byKey(const ValueKey('web-editor-zoom-fit'))).onPressed,
      isNull,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    expect(await _wheel(tester, position, -100), isTrue);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    expect(_zoom(tester), 1);
  });

  testWidgets('compact footer keeps all zoom controls without overflow', (
    tester,
  ) async {
    await _mount(tester, size: const Size(280, 500));
    expect(find.byTooltip('화면 확대'), findsOneWidget);
    expect(find.byTooltip('화면 축소'), findsOneWidget);
    expect(find.text('화면 맞춤'), findsOneWidget);
    await tester.tap(find.byTooltip('화면 확대'));
    await tester.pump();
    expect(find.text('125%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
