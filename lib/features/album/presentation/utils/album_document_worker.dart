import 'dart:async';

/// Cover and progress workers share one slot so large documents never create
/// two decoded copies at once. Only their compact results return to the UI.
abstract final class AlbumDocumentWorker {
  static Future<void>? _tail;

  static Future<T?> run<T>(
    Future<T> Function() work, {
    required bool Function() isCurrent,
  }) {
    final previous = _tail;
    final released = Completer<void>();
    _tail = released.future;
    return () async {
      if (previous != null) await previous;
      try {
        if (!isCurrent()) return null;
        final result = await work();
        return isCurrent() ? result : null;
      } finally {
        // An error or cancelled consumer must not block the next worker.
        // An idle queue needn't retain a completed Future (or its async zone).
        if (identical(_tail, released.future)) _tail = null;
        released.complete();
      }
    }();
  }
}
