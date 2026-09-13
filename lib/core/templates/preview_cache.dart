/// Small LRU for immutable preview models. Exact revision equality (not a hash)
/// prevents collisions; replacing an ID releases its previous document revision.
class PreviewCache<K, V> {
  PreviewCache({this.capacity = 32}) : assert(capacity > 0);
  final int capacity;
  final _entries = <K, ({Object? revision, V value})>{};
  int get length => _entries.length;

  V get(K key, Object? revision, V Function() create) {
    final previous = _entries.remove(key);
    if (previous != null && previous.revision == revision) {
      _entries[key] = previous;
      return previous.value;
    }
    final value = create();
    _entries[key] = (revision: revision, value: value);
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
    return value;
  }

  void clear() => _entries.clear();
}
