import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class CatalogFavoritesStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class PreferencesFavoritesStorage implements CatalogFavoritesStorage {
  static const key = 'catalog_favorites_v1';
  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String value) async {
    if (!await (await SharedPreferences.getInstance()).setString(key, value)) {
      throw StateError('Favorites could not be saved');
    }
  }
}

/// Device-local, shared across picker routes. Order is the actual save order,
/// independent of clock changes, usage frequency or catalog refreshes.
class CatalogFavorites extends ChangeNotifier {
  CatalogFavorites({CatalogFavoritesStorage? storage})
    : _storage = storage ?? PreferencesFavoritesStorage();
  static CatalogFavorites instance = CatalogFavorites();
  final CatalogFavoritesStorage _storage;
  List<String> _keys = [];
  Set<String> _migrations = {};
  Future<bool>? _loading;
  Future<void>? _writes;
  bool _loaded = false;
  bool _disposed = false;

  List<String> get keys => List.unmodifiable(_keys);
  bool contains(String key) => _keys.contains(key);

  Future<bool> load() => _loading ??= _read();
  Future<bool> _read() async {
    try {
      final raw = await _storage.read();
      if (raw != null) {
        try {
          final data = jsonDecode(raw);
          if (data is Map && data['version'] is num && data['version'] != 1) {
            return false;
          }
          if (data is Map && data['version'] == 1) {
            _keys = _strings(data['keys']).toList();
            _migrations = _strings(data['migrations']);
          }
        } on FormatException {
          // A malformed preference must not prevent using the editor.
        }
      }
      _loaded = true;
      _notify();
      return true;
    } catch (_) {
      return false;
    }
  }

  Set<String> _strings(dynamic value) => value is List
      ? value.whereType<String>().where((s) => s.isNotEmpty).toSet()
      : <String>{};

  Future<bool> _enqueue(Future<bool> Function() operation) {
    final result = (_writes ?? Future<void>.value()).then((_) async {
      if (!_loaded) {
        if (!await load()) {
          _loading = null;
          return false;
        }
      }
      return operation();
    });
    _writes = result.then((_) {});
    return result;
  }

  Future<bool> toggle(String key) => _enqueue(() async {
    if (key.isEmpty) return false;
    final previous = List<String>.of(_keys);
    _keys = contains(key)
        ? _keys.where((k) => k != key).toList()
        : [key, ..._keys];
    _notify();
    try {
      await _save();
      return true;
    } catch (_) {
      _keys = previous;
      _notify();
      return false;
    }
  });

  Future<bool> importLegacyTemplates(
    Iterable<String> keys, {
    required String scope,
  }) => _enqueue(() async {
    if (_migrations.contains(scope)) return true;
    final previous = List<String>.of(_keys);
    _keys = [..._keys, ...keys.where((key) => !_keys.contains(key)).toSet()];
    _migrations.add(scope);
    try {
      await _save();
      _notify();
      return true;
    } catch (_) {
      _keys = previous;
      _migrations.remove(scope);
      return false;
    }
  });

  List<T> arrange<T>(
    Iterable<T> items,
    String Function(T) keyOf, {
    bool onlyFavorites = false,
  }) {
    final rank = {for (var i = 0; i < _keys.length; i++) _keys[i]: i};
    final indexed = items.indexed
        .where((entry) => !onlyFavorites || rank.containsKey(keyOf(entry.$2)))
        .toList();
    indexed.sort((a, b) {
      final order = (rank[keyOf(a.$2)] ?? _keys.length).compareTo(
        rank[keyOf(b.$2)] ?? _keys.length,
      );
      return order == 0 ? a.$1.compareTo(b.$1) : order;
    });
    return indexed.map((entry) => entry.$2).toList();
  }

  Future<void> _save() => _storage.write(
    jsonEncode({
      'version': 1,
      'keys': _keys,
      'migrations': _migrations.toList(),
    }),
  );
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
