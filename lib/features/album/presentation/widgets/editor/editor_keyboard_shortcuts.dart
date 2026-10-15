import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Editor commands stay local to the active editor route. Text fields retain
/// their own delete/undo/save keystrokes, including text fields in tool panels.
class EditorKeyboardShortcuts extends StatelessWidget {
  const EditorKeyboardShortcuts({
    super.key,
    required this.child,
    this.enabled = true,
    this.onDelete,
    this.onUndo,
    this.onRedo,
    this.onSave,
    this.onEscape,
  });

  final Widget child;
  final bool enabled;
  final VoidCallback? onDelete;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onSave;
  final VoidCallback? onEscape;

  bool _editingText() {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return false;
    var editable = focused.widget is EditableText;
    focused.visitAncestorElements((element) {
      if (element.widget is EditableText) {
        editable = true;
        return false;
      }
      return true;
    });
    return editable;
  }

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    debugLabel: 'album-editor-commands',
    onKeyEvent: (_, event) {
      if (!enabled ||
          event is! KeyDownEvent ||
          ModalRoute.of(context)?.isCurrent == false ||
          _editingText()) {
        return KeyEventResult.ignored;
      }
      final keyboard = HardwareKeyboard.instance;
      final command = keyboard.isControlPressed || keyboard.isMetaPressed;
      final shift = keyboard.isShiftPressed;
      if (keyboard.isAltPressed) return KeyEventResult.ignored;
      VoidCallback? action;
      final key = event.logicalKey;
      if (command && key == LogicalKeyboardKey.keyZ) {
        action = shift ? onRedo : onUndo;
      } else if (command && key == LogicalKeyboardKey.keyY) {
        action = onRedo;
      } else if (command && key == LogicalKeyboardKey.keyS) {
        action = onSave;
      } else if (!command &&
          !shift &&
          (key == LogicalKeyboardKey.delete ||
              key == LogicalKeyboardKey.backspace)) {
        action = onDelete;
      } else if (!command && key == LogicalKeyboardKey.escape) {
        action = onEscape;
      }
      if (action == null) return KeyEventResult.ignored;
      action();
      return KeyEventResult.handled;
    },
    child: child,
  );
}
