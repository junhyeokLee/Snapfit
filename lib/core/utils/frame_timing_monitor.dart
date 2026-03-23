import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'app_logger.dart';

/// 프레임 타이밍 모니터
/// - debug/profile 에서만 동작
/// - 5초 간격으로 프레임 통계를 출력
class FrameTimingMonitor {
  FrameTimingMonitor._();

  static bool _started = false;
  static Duration _windowTotal = Duration.zero;
  static int _windowFrameCount = 0;
  static int _windowOver16ms = 0;
  static int _windowOver33ms = 0;
  static Duration _windowWorst = Duration.zero;
  static DateTime? _windowStartedAt;

  static void start() {
    if (_started) return;
    if (!kDebugMode && !kProfileMode) return;
    _started = true;
    _windowStartedAt = DateTime.now();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    AppLogger.perf('[PERF] FrameTimingMonitor started');
  }

  static void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final total = timing.totalSpan;
      _windowFrameCount += 1;
      _windowTotal += total;
      if (total > _windowWorst) _windowWorst = total;
      if (total.inMicroseconds > 16000) _windowOver16ms += 1;
      if (total.inMicroseconds > 33000) _windowOver33ms += 1;
    }

    final startedAt = _windowStartedAt;
    if (startedAt == null) return;
    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    if (elapsedMs < 5000 || _windowFrameCount == 0) return;

    final avgMs = _windowTotal.inMicroseconds / _windowFrameCount / 1000.0;
    final worstMs = _windowWorst.inMicroseconds / 1000.0;
    final over16Pct = (_windowOver16ms * 100) / _windowFrameCount;
    final over33Pct = (_windowOver33ms * 100) / _windowFrameCount;
    final fps = (_windowFrameCount * 1000) / elapsedMs;

    AppLogger.perf(
      '[PERF] ${elapsedMs}ms | frames=$_windowFrameCount | '
      'avg=${avgMs.toStringAsFixed(2)}ms | '
      'worst=${worstMs.toStringAsFixed(2)}ms | '
      '>16ms=${over16Pct.toStringAsFixed(1)}% | '
      '>33ms=${over33Pct.toStringAsFixed(1)}% | '
      'fps=${fps.toStringAsFixed(1)}',
    );

    _windowStartedAt = DateTime.now();
    _windowTotal = Duration.zero;
    _windowFrameCount = 0;
    _windowOver16ms = 0;
    _windowOver33ms = 0;
    _windowWorst = Duration.zero;
  }
}
