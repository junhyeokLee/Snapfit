import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/widgets/web/web_layer_transform_inspector.dart';
import 'package:snap_fit/shared/web/web_design.dart';

LayerModel _layer({
  String id = 'selected-layer',
  LayerType type = LayerType.image,
  Offset position = const Offset(10, 20),
  double scale = 2,
  double rotation = 30,
}) => LayerModel(
  id: id,
  type: type,
  position: position,
  // The inspector must use the rendered baseSize supplied by its caller.
  width: 999,
  height: 999,
  scale: scale,
  rotation: rotation,
);

Finder _field(String name) => find.byKey(ValueKey('web-layer-$name'));

String _value(WidgetTester tester, String name) =>
    tester.widget<TextField>(_field(name)).controller!.text;

class _Fixture {
  final selection = ValueNotifier<LayerModel>(_layer());
  final enabled = ValueNotifier<bool>(true);
  final calls = <Map<String, double>>[];

  Future<void> pump(
    WidgetTester tester, {
    bool dark = false,
    bool expanded = true,
  }) async {
    addTearDown(selection.dispose);
    addTearDown(enabled.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: SnapFitWebTheme.from(
          dark ? ThemeData.dark() : ThemeData.light(),
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: SingleChildScrollView(
                child: ValueListenableBuilder<LayerModel>(
                  valueListenable: selection,
                  builder: (_, layer, _) => ValueListenableBuilder<bool>(
                    valueListenable: enabled,
                    builder: (_, active, _) => WebLayerTransformInspector(
                      layer: layer,
                      baseSize: const Size(100, 50),
                      enabled: active,
                      onChanged: ({x, y, width, height, rotation}) {
                        calls.add({
                          if (x != null) 'x': x,
                          if (y != null) 'y': y,
                          if (width != null) 'width': width,
                          if (height != null) 'height': height,
                          if (rotation != null) 'rotation': rotation,
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    if (expanded) {
      await tester.tap(find.byKey(const ValueKey('web-layer-advanced-toggle')));
      await tester.pump();
    }
  }

  Future<void> submit(WidgetTester tester, String name, String value) async {
    await tester.ensureVisible(_field(name));
    await tester.enterText(_field(name), value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }
}

void main() {
  testWidgets(
    'advanced coordinates start collapsed and opening does not edit',
    (tester) async {
      final fixture = _Fixture();
      await fixture.pump(tester, expanded: false);
      expect(find.text('고급 조정'), findsOneWidget);
      expect(_field('x'), findsNothing);
      expect(find.textContaining('페이지 가로 500'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(_value(tester, 'x'), '10');
      expect(fixture.calls, isEmpty);
      await fixture.submit(tester, 'x', '25');
      expect(fixture.calls, [
        <String, double>{'x': 25},
      ]);
    },
  );

  testWidgets(
    'renders current frame dimensions and themed precision guidance',
    (tester) async {
      final fixture = _Fixture()..selection.value = _layer(rotation: 90);
      await fixture.pump(tester, dark: true);
      expect(_value(tester, 'x'), '10');
      expect(_value(tester, 'y'), '20');
      expect(_value(tester, 'width'), '200');
      expect(_value(tester, 'height'), '100');
      expect(_value(tester, 'rotation'), '90');
      expect(find.textContaining('레이어 기준 좌표'), findsOneWidget);
      expect(find.textContaining('가로·세로 비율 유지'), findsOneWidget);
      expect(find.textContaining('사진 안쪽'), findsOneWidget);
      expect(
        tester.widget<TextField>(_field('x')).style!.color,
        WebPalette.dark.ink,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'negative position commits on Enter once despite later focus loss',
    (tester) async {
      final fixture = _Fixture();
      await fixture.pump(tester);
      await fixture.submit(tester, 'x', '-12.5');
      await tester.tap(_field('y'));
      await tester.pump();
      expect(fixture.calls, [
        <String, double>{'x': -12.5},
      ]);
    },
  );

  testWidgets(
    'focus loss commits a changed value and a numeric no-op does not',
    (tester) async {
      final fixture = _Fixture();
      await fixture.pump(tester);
      await fixture.submit(tester, 'x', '10.000');
      expect(fixture.calls, isEmpty);
      await tester.enterText(_field('y'), '-8');
      await tester.tap(_field('x'));
      await tester.pump();
      expect(fixture.calls, [
        <String, double>{'y': -8},
      ]);
    },
  );

  testWidgets(
    'width and height request uniform displayed sizes independently',
    (tester) async {
      final fixture = _Fixture();
      await fixture.pump(tester);
      await fixture.submit(tester, 'width', '250');
      await fixture.submit(tester, 'height', '75');
      expect(fixture.calls, [
        <String, double>{'width': 250},
        <String, double>{'height': 75},
      ]);
    },
  );

  testWidgets('rotation normalizes and reset discards an unfinished angle', (
    tester,
  ) async {
    final fixture = _Fixture();
    await fixture.pump(tester);
    await fixture.submit(tester, 'rotation', '450');
    expect(fixture.calls, [
      <String, double>{'rotation': 90},
    ]);
    fixture.selection.value = fixture.selection.value.copyWith(rotation: 90);
    await tester.pump();
    await tester.enterText(_field('rotation'), '125');
    await tester.tap(find.byKey(const ValueKey('web-layer-rotation-reset')));
    await tester.pump();
    expect(fixture.calls, [
      <String, double>{'rotation': 90},
      <String, double>{'rotation': 0},
    ]);
  });

  testWidgets(
    'nonfinite values and nonpositive or oversized dimensions are rejected',
    (tester) async {
      final fixture = _Fixture();
      await fixture.pump(tester);
      for (final invalid in ['NaN', 'Infinity', '1e309', 'abc', '']) {
        await fixture.submit(tester, 'x', invalid);
        expect(find.text('유효한 숫자를 입력해주세요.'), findsOneWidget);
        expect(fixture.calls, isEmpty);
      }
      for (final invalid in ['0', '-12']) {
        await fixture.submit(tester, 'width', invalid);
        expect(find.text('0보다 큰 값을 입력해주세요.'), findsOneWidget);
        expect(fixture.calls, isEmpty);
      }
      await fixture.submit(tester, 'width', '301');
      expect(find.text('30~300 px 범위예요.'), findsOneWidget);
      expect(fixture.calls, isEmpty);
    },
  );

  testWidgets(
    'focused drafts survive rebuilds and Escape restores the latest model',
    (tester) async {
      final fixture = _Fixture();
      await fixture.pump(tester);
      await tester.enterText(_field('x'), '123');
      fixture.selection.value = fixture.selection.value.copyWith(
        position: const Offset(-40, 42),
      );
      await tester.pump();
      expect(_value(tester, 'x'), '123');
      expect(_value(tester, 'y'), '42');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(_value(tester, 'x'), '-40');
      expect(fixture.calls, isEmpty);
    },
  );

  testWidgets('external undo refreshes an untouched focused field', (
    tester,
  ) async {
    final fixture = _Fixture();
    await fixture.pump(tester);
    await tester.tap(_field('width'));
    fixture.selection.value = fixture.selection.value.copyWith(scale: .5);
    await tester.pump();
    expect(_value(tester, 'width'), '50');
    expect(_value(tester, 'height'), '25');
    expect(fixture.calls, isEmpty);
  });

  testWidgets(
    'selection change discards a draft without editing either layer',
    (tester) async {
      final fixture = _Fixture();
      await fixture.pump(tester);
      await tester.enterText(_field('x'), '77');
      fixture.selection.value = _layer(
        id: 'other-layer',
        position: const Offset(3, 4),
        type: LayerType.text,
      );
      await tester.pump();
      await tester.tap(_field('y'));
      await tester.pump();
      expect(_value(tester, 'x'), '3');
      expect(fixture.calls, isEmpty);
      expect(find.textContaining('글 내용과 글꼴'), findsOneWidget);
    },
  );

  testWidgets(
    'saving disables controls and discards drafts without committing',
    (tester) async {
      final fixture = _Fixture();
      await fixture.pump(tester);
      await tester.enterText(_field('x'), '77');
      fixture.enabled.value = false;
      await tester.pump();
      for (final name in ['x', 'y', 'width', 'height', 'rotation']) {
        expect(tester.widget<TextField>(_field(name)).enabled, isFalse);
      }
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('web-layer-rotation-reset')),
            )
            .onPressed,
        isNull,
      );
      expect(_value(tester, 'x'), '10');
      expect(fixture.calls, isEmpty);
    },
  );

  testWidgets('disposing a focused draft does not commit it', (tester) async {
    final fixture = _Fixture();
    await fixture.pump(tester);
    await tester.enterText(_field('x'), '77');
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    expect(fixture.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
