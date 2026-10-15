import 'dart:typed_data';

typedef PrintRunSourceLoader = Future<Uint8List> Function(String source);

/// Original encoded bytes live only for one owned render or verification run.
/// Decoded images still follow the existing per-page lifetime and memory checks.
class PrintRunSourceCache {
  PrintRunSourceCache(
    this._load, {
    this.maxEntryBytes = 16000000,
    this.maxTotalBytes = 32000000,
  }) {
    if (maxEntryBytes <= 0 ||
        maxEntryBytes > 16000000 ||
        maxTotalBytes < maxEntryBytes ||
        maxTotalBytes > 32000000) {
      throw ArgumentError('print_source_cache_budget_invalid');
    }
  }
  final PrintRunSourceLoader _load;
  final int maxEntryBytes, maxTotalBytes;
  final _bytes = <String, Uint8List>{};
  final _pending = <String, Future<Uint8List>>{};
  int _retainedBytes = 0;
  int _generation = 0;
  int get retainedBytes => _retainedBytes;

  Future<Uint8List> load(String originalSource) {
    final cached = _bytes.remove(originalSource);
    if (cached != null) {
      _bytes[originalSource] = cached;
      return Future.value(cached);
    }
    final pending = _pending[originalSource];
    if (pending != null) return pending;
    final generation = _generation;
    late Future<Uint8List> work;
    work = Future<Uint8List>.sync(() => _load(originalSource))
        .then((bytes) {
          if (generation == _generation && bytes.length <= maxEntryBytes) {
            while ((_retainedBytes + bytes.length > maxTotalBytes ||
                    _bytes.length >= 64) &&
                _bytes.isNotEmpty) {
              _retainedBytes -= _bytes.remove(_bytes.keys.first)!.length;
            }
            _bytes[originalSource] = bytes;
            _retainedBytes += bytes.length;
          }
          return bytes;
        })
        .whenComplete(() {
          if (identical(_pending[originalSource], work))
            _pending.remove(originalSource);
        });
    _pending[originalSource] = work;
    return work;
  }

  void clear() {
    _generation++;
    _pending.clear();
    _bytes.clear();
    _retainedBytes = 0;
  }
}
