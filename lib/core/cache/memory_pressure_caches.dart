/// Application-owned, reconstructible caches register static cleanup callbacks.
/// Entries must never capture widgets, accounts, or editor state. Disk caches
/// and data currently owned by a visible screen are left intact.
abstract final class MemoryPressureCaches {
  static final _clearers = <String, void Function()>{};

  static void register(String name, void Function() clear) {
    _clearers[name] = clear;
  }

  static void clear() {
    for (final clear in List.of(_clearers.values)) {
      clear();
    }
  }
}
