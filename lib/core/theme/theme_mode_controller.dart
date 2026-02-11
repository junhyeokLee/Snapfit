import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_mode_controller.g.dart';

const String _kThemeModeKey = 'theme_mode';
const String _kThemeLight = 'light';
const String _kThemeDark = 'dark';

/// 앱 테마 모드 상태 관리 (기본: 라이트, 로컬 저장으로 유지)
@riverpod
class ThemeModeController extends _$ThemeModeController {
  @override
  ThemeMode build() => ThemeMode.light;

  /// 로컬에 저장된 테마를 불러와 state에 반영 (앱 시작 시 1회 호출)
  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kThemeModeKey);
      if (saved == _kThemeDark) {
        state = ThemeMode.dark;
      } else if (saved == _kThemeLight) {
        state = ThemeMode.light;
      }
    } catch (_) {
      // 저장소 읽기 실패 시 기본값 유지
    }
  }

  Future<void> _saveThemeMode(String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThemeModeKey, value);
    } catch (_) {}
  }

  /// 라이트 모드로 변경 후 로컬 저장
  void setLight() {
    state = ThemeMode.light;
    _saveThemeMode(_kThemeLight);
  }

  /// 다크 모드로 변경 후 로컬 저장
  void setDark() {
    state = ThemeMode.dark;
    _saveThemeMode(_kThemeDark);
  }
}
