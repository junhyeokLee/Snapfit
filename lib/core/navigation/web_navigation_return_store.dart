import 'web_app_location.dart';

/// A single-use internal destination, with a memory fallback for blocked storage.
/// Queueing reads and writes prevents a late save from undoing a logout clear.
class WebNavigationReturnStore {
  WebNavigationReturnStore({
    required Future<String?> Function() read,
    required Future<void> Function(String value) write,
    required Future<void> Function() remove,
    DateTime Function()? now,
  }) : _read = read,
       _write = write,
       _remove = remove,
       _now = now ?? DateTime.now;

  final Future<String?> Function() _read;
  final Future<void> Function(String value) _write;
  final Future<void> Function() _remove;
  final DateTime Function() _now;
  Future<void> _queue = Future<void>.value();
  String? _memory;
  bool _memoryKnown = false;
  static const lifetime = Duration(minutes: 15);

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> remember(WebAppLocation location) {
    final canonical = WebAppLocation.parse(location.uri);
    if (canonical == WebAppLocation.home || canonical == WebAppLocation.login) {
      return Future<void>.value();
    }
    final record = '${_now().millisecondsSinceEpoch}|${canonical.uri}';
    return _serialize(() async {
      _memory = record;
      _memoryKnown = true;
      try {
        await _write(record);
      } catch (_) {
        // The current tab can still return after an email/password login.
      }
    });
  }

  Future<void> clear() => _serialize(() async {
    _memory = null;
    _memoryKnown = true;
    try {
      await _remove();
    } catch (_) {
      // Keep the cleared memory authoritative even if the browser store fails.
    }
  });

  Future<WebAppLocation?> take() => _serialize(() async {
    var record = _memory;
    if (!_memoryKnown) {
      try {
        record = await _read();
      } catch (_) {
        // Storage can be denied in private browsing or an embedded browser.
      }
    }
    _memory = null;
    _memoryKnown = true;
    try {
      await _remove();
    } catch (_) {}
    return _decode(record);
  });

  WebAppLocation? _decode(String? record) {
    final parts = record?.split('|');
    if (parts == null || parts.length != 2) return null;
    final created = int.tryParse(parts.first);
    if (created == null) return null;
    final age = _now().millisecondsSinceEpoch - created;
    if (age < 0 || age > lifetime.inMilliseconds) return null;
    final uri = Uri.tryParse(parts.last);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    final location = WebAppLocation.parse(uri);
    if (location == WebAppLocation.home || location == WebAppLocation.login) {
      return null;
    }
    return location.uri.toString() == parts.last ? location : null;
  }
}
