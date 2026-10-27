/// Short-lived failures keyed by cache/decode scope and actual download URL,
/// irrespective of the logical source used to reach it. Callers use immutable
/// scope tokens, never providers, managers, pixels or consumers. A new load may
/// reconsider an old failure without restarting the same failed generation.
class PhotoFailureVersions {
  PhotoFailureVersions({
    this.capacity = 1000,
    this.maxAge = const Duration(seconds: 30),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       assert(capacity > 0);

  final int capacity;
  final Duration maxAge;
  final DateTime Function() _now;
  final _entries =
      <
        (Object, String),
        ({int version, DateTime until, int? recoveredVersion})
      >{};
  int _version = 0;

  int get version => _version;

  int? rejectionVersion(Object scope, String url) {
    final key = (scope, url);
    final entry = _entries[key];
    if (entry == null) return null;
    if (!_now().isBefore(entry.until)) {
      _entries.remove(key);
      return null;
    }
    return entry.version;
  }

  bool rejectedSince(Object scope, String url, int version) =>
      (rejectionVersion(scope, url) ?? -1) > version;

  int? recoveryVersion(Object scope, String url) {
    if (rejectionVersion(scope, url) == null) return null;
    return _entries[(scope, url)]?.recoveredVersion;
  }

  void recover(Object scope, String url, int loadVersion) {
    final rejection = rejectionVersion(scope, url);
    if (rejection == null || rejection > loadVersion) return;
    final entry = _entries[(scope, url)]!;
    if ((entry.recoveredVersion ?? -1) >= loadVersion) return;
    // Only annotate an existing failure, without extending its age or count.
    // Older consumers must still reject it until they adopt this decoded result.
    _entries[(scope, url)] = (
      version: entry.version,
      until: entry.until,
      recoveredVersion: loadVersion,
    );
  }

  bool reject(Object scope, String url, int version) {
    if (rejectedSince(scope, url, version)) return false;
    final key = (scope, url);
    _entries.remove(key);
    _entries[key] = (
      version: ++_version,
      until: _now().add(maxAge),
      recoveredVersion: null,
    );
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
    return true;
  }

  void clear() {
    _entries.clear();
    // Existing loads keep their version; never recycle their failure identity.
    _version++;
  }
}
