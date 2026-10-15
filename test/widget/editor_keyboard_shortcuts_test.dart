import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/editor_keyboard_shortcuts.dart';

void main() {
  Future<void> command(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool shift = false,
    bool meta = false,
  }) async {
    final modifier = meta
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await tester.sendKeyDownEvent(modifier);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(modifier);
    await tester.pump();
  }

  testWidgets(
    'editor accepts Windows and Mac undo redo delete and save commands',
    (tester) async {
      final actions = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorKeyboardShortcuts(
              onDelete: () => actions.add('delete'),
              onUndo: () => actions.add('undo'),
              onRedo: () => actions.add('redo'),
              onSave: () => actions.add('save'),
              onEscape: () => actions.add('escape'),
              child: const Text('canvas'),
            ),
          ),
        ),
      );
      await tester.pump();
      await command(tester, LogicalKeyboardKey.keyZ);
      await command(tester, LogicalKeyboardKey.keyZ, meta: true, shift: true);
      await command(tester, LogicalKeyboardKey.keyY);
      await command(tester, LogicalKeyboardKey.keyS, meta: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(actions, [
        'undo',
        'redo',
        'redo',
        'save',
        'delete',
        'delete',
        'escape',
      ]);
    },
  );

  testWidgets(
    'typing in a tool text field never deletes or undoes document layers',
    (tester) async {
      final actions = <String>[];
      final controller = TextEditingController(text: '앨범 제목');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorKeyboardShortcuts(
              onDelete: () => actions.add('delete'),
              onUndo: () => actions.add('undo'),
              onRedo: () => actions.add('redo'),
              onSave: () => actions.add('save'),
              child: TextField(controller: controller),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await command(tester, LogicalKeyboardKey.keyZ);
      await command(tester, LogicalKeyboardKey.keyZ, shift: true);
      await command(tester, LogicalKeyboardKey.keyS);
      expect(actions, isEmpty);
    },
  );

  testWidgets('saving overlay disables all editor commands', (tester) async {
    var deletes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorKeyboardShortcuts(
            enabled: false,
            onDelete: () => deletes++,
            child: const Text('saving'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    expect(deletes, 0);
  });
}
