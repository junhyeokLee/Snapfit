import 'package:flutter/foundation.dart';

/// 앱 전역 로거
/// - 디버그 빌드에서만 출력
/// - print 대신 사용
class AppLogger {
  AppLogger._();

  static void debug(String message) {
    if (!kDebugMode) return;
    debugPrint(message);
  }

  static void warn(String message) {
    if (!kDebugMode) return;
    debugPrint('[WARN] $message');
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (!kDebugMode) return;
    final suffix = error == null ? '' : ' $error';
    debugPrint('[ERROR] $message$suffix');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }
}
