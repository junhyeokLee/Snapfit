import 'dart:async';
import 'dart:convert';

typedef _CachedStorageUrl = ({
  String url,
  DateTime until,
  bool rejected,
  String? replaces,
  int rejectionVersion,
});

/// Only URL metadata is retained. Pending signing requests are shared until
/// completion, independently of the completed-entry LRU.
class StorageImageUrlCache {
  StorageImageUrlCache({
    this.capacity = 500,
    this.maxAge = const Duration(hours: 1),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       assert(capacity > 0);

  final int capacity;
  final Duration maxAge;
  final DateTime Function() _now;
  final _completed = <String, _CachedStorageUrl>{};
  final _pending = <String, Future<String>>{};
  int _epoch = 0;

  String? peek(String source) {
    final entry = _entry(source);
    return entry == null || entry.rejected ? null : entry.url;
  }

  bool consumedFailure(String source, String url, int failureVersion) {
    final entry = _entry(source);
    return entry != null &&
        entry.url == url &&
        entry.rejectionVersion >= failureVersion;
  }

  void acceptRecovery(String source, String url, int failureVersion) {
    final entry = _entry(source);
    if (entry == null ||
        entry.url != url ||
        entry.rejectionVersion > failureVersion)
      return;
    // A URL alias has actually decoded these pixels after the failure. Reuse
    // that same result without changing lifetime, creating entries or signing.
    _completed[source] = (
      url: url,
      until: entry.until,
      rejected: false,
      replaces: entry.replaces,
      rejectionVersion: failureVersion,
    );
  }

  _CachedStorageUrl? _entry(String source) {
    final entry = _completed.remove(source);
    if (entry == null || !_now().isBefore(entry.until)) return null;
    _completed[source] = entry;
    return entry;
  }

  Future<String> resolve(String source, Future<String> Function() sign) {
    final cached = peek(source);
    if (cached != null) return Future.value(cached);
    return _pending[source] ??
        _start(
          source,
          sign,
          rejectionVersion: _completed[source]?.rejectionVersion ?? 0,
        );
  }

  Future<String> refresh(
    String source,
    String failedUrl,
    Future<String> Function() sign, {
    bool explicit = false,
  }) {
    // Another visible page may already have refreshed the same failed version.
    final entry = _entry(source);
    if (entry != null &&
        ((!explicit && entry.replaces == failedUrl) ||
            (entry.url != failedUrl && (!entry.rejected || !explicit)))) {
      return Future.value(entry.url);
    }
    _completed.remove(source);
    return _pending[source] ??
        _start(
          source,
          sign,
          replaces: failedUrl,
          rejectionVersion: entry?.rejectionVersion ?? 0,
        );
  }

  Future<String> _start(
    String source,
    Future<String> Function() sign, {
    String? replaces,
    int rejectionVersion = 0,
  }) {
    final epoch = _epoch;
    final result = Completer<String>();
    _pending[source] = result.future;
    // A closing view may leave before attaching its next FutureBuilder. Consume
    // bookkeeping errors without hiding the same error from real consumers.
    unawaited(
      result.future.then<void>((_) {}, onError: (Object _, StackTrace __) {}),
    );
    () async {
      try {
        final url = await sign();
        if (url.trim().isEmpty) throw StateError('empty_storage_image_url');
        final until = _validUntil(url);
        if (epoch == _epoch && _now().isBefore(until)) {
          _completed.remove(source);
          _completed[source] = (
            url: url,
            until: until,
            rejected: false,
            replaces: replaces,
            rejectionVersion: rejectionVersion,
          );
          while (_completed.length > capacity) {
            _completed.remove(_completed.keys.first);
          }
        }
        _pending.remove(source);
        result.complete(url);
      } catch (error, stack) {
        _pending.remove(source);
        result.completeError(error, stack);
      }
    }();
    return result.future;
  }

  DateTime _validUntil(String url) {
    final limit = _now().add(maxAge);
    try {
      final token = Uri.parse(url).queryParameters['token'];
      if (token == null) return limit;
      final parts = token.split('.');
      if (parts.length != 3) return limit;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final exp = payload is Map ? payload['exp'] : null;
      if (exp is! num) return limit;
      // This is a cache lifetime hint, never an authorization decision.
      final expiry = DateTime.fromMillisecondsSinceEpoch(
        (exp * 1000).toInt(),
        isUtc: true,
      ).subtract(const Duration(seconds: 30));
      return expiry.isBefore(limit) ? expiry : limit;
    } catch (_) {
      return limit;
    }
  }

  void invalidate(String source, {String? failedUrl, int? failureVersion}) {
    if (failedUrl == null) {
      _completed.remove(source);
    } else if (_completed[source] case final entry?
        when entry.url == failedUrl) {
      // Different aliases can observe the same stream error. Once its version
      // was consumed by a renewal, an older observer must not reject it again.
      if (failureVersion != null && failureVersion <= entry.rejectionVersion) {
        return;
      }
      // Retain only the bounded metadata of a completed renewal. A late failure
      // of its predecessor can follow this same result, even if it also failed.
      // New loads and explicit retries still request fresh authorization.
      _completed[source] = (
        url: entry.url,
        until: entry.until,
        rejected: true,
        replaces: entry.replaces,
        rejectionVersion: failureVersion ?? entry.rejectionVersion,
      );
    }
  }

  void clear() {
    _epoch++;
    _completed.clear();
    // Keep current work shared; a pre-pressure completion cannot refill the LRU.
  }
}
