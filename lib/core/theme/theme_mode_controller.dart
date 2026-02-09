import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_mode_controller.g.dart';

/// 앱 테마 모드 상태 관리 (기본: 라이트)
@riverpod
class ThemeModeController extends _$ThemeModeController {
  @override
  ThemeMode build() => ThemeMode.light;

  /// 라이트 모드로 변경
  void setLight() => state = ThemeMode.light;

  /// 다크 모드로 변경
  void setDark() => state = ThemeMode.dark;
}
