import 'package:flutter/foundation.dart';

/// 앱 전역 로거
/// - 디버그 빌드에서만 출력
/// - print 대신 사용
class AppLogger {
  AppLogger._();

  static bool get _debugEnabled => kDebugMode;
  static bool get _perfEnabled => kDebugMode || kProfileMode;

  static void debug(String message) {
    if (!_debugEnabled) return;
    debugPrint(message);
  }

  static void warn(String message) {
    if (!_debugEnabled) return;
    debugPrint('[WARN] $message');
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (!_debugEnabled) return;
    final suffix = error == null ? '' : ' $error';
    debugPrint('[ERROR] $message$suffix');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }

  static void perf(String message) {
    if (!_perfEnabled) return;
    debugPrint(message);
  }
}
