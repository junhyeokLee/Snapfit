import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Browser appearance is independent of the mobile app's theme preference.
final webThemeModeProvider = NotifierProvider<WebThemeModeController, ThemeMode>(
  WebThemeModeController.new,
);

class WebThemeModeController extends Notifier<ThemeMode> {
  static const _storageKey = 'snapfit_web_theme_mode_v1';
  Future<void>? _loading;
  Future<void> _writes = Future.value();
  var _selectionRevision = 0;

  @override
  ThemeMode build() => ThemeMode.system;

  Future<void> loadFromStorage() => _loading ??= _load();

  Future<void> _load() async {
    final revision = _selectionRevision;
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(_storageKey);
      if (!ref.mounted || revision != _selectionRevision) return;
      state = switch (saved) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      // Restricted browser storage still allows a theme for this session.
    }
  }

  /// Applies immediately and reports whether the browser retained the choice.
  Future<bool> select(ThemeMode mode) {
    _selectionRevision++;
    state = mode;
    final write = _writes.then((_) async {
      try {
        final preferences = await SharedPreferences.getInstance();
        return await preferences.setString(_storageKey, mode.name);
      } catch (_) {
        return false;
      }
    });
    _writes = write.then<void>((_) {});
    return write;
  }
}
