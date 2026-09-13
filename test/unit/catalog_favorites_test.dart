import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/templates/catalog_favorites.dart';
import 'package:snap_fit/core/templates/catalog_favorite_keys.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/features/album/presentation/providers/design_template_catalog_provider.dart';

class MemoryFavoritesStorage implements CatalogFavoritesStorage {
  String? value;
  bool failRead = false, failWrite = false;
  Completer<void>? readGate;
  @override
  Future<String?> read() async {
    if (readGate != null) await readGate!.future;
    if (failRead) throw StateError('offline');
    return value;
  }

  @override
  Future<void> write(String text) async {
    if (failWrite) throw StateError('full');
    value = text;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryFavoritesStorage storage;
  late CatalogFavorites favorites;
  setUp(() {
    storage = MemoryFavoritesStorage();
    favorites = CatalogFavorites(storage: storage);
  });
  tearDown(() => favorites.dispose());

  test(
    'latest save first, stable catalog remainder, does not mutate catalog',
    () async {
      const items = ['a', 'b', 'c', 'd'];
      await favorites.toggle('c');
      await favorites.toggle('b');
      expect(favorites.arrange(items, (s) => s), ['b', 'c', 'a', 'd']);
      expect(favorites.arrange(items, (s) => s, onlyFavorites: true), [
        'b',
        'c',
      ]);
      expect(items, ['a', 'b', 'c', 'd']);
      await favorites.toggle('c');
      expect(favorites.arrange(items, (s) => s), ['b', 'a', 'c', 'd']);
      await favorites.toggle('c');
      expect(favorites.keys, ['c', 'b']);
    },
  );
  test(
    'rapid cross-kind writes preserve every toggle in invocation order',
    () async {
      await Future.wait([
        favorites.toggle('frame:a'),
        favorites.toggle('phrase:b'),
        favorites.toggle('font:c'),
        favorites.toggle('frame:a'),
      ]);
      expect(favorites.keys, ['font:c', 'phrase:b']);
      expect(jsonDecode(storage.value!)['keys'], favorites.keys);
    },
  );
  test(
    'toggle before preference load merges without dropping old saves',
    () async {
      storage.value = jsonEncode({
        'version': 1,
        'keys': ['old'],
      });
      storage.readGate = Completer();
      final load = favorites.load();
      final toggle = favorites.toggle('new');
      storage.readGate!.complete();
      expect(await load, true);
      expect(await toggle, true);
      expect(favorites.keys, ['new', 'old']);
    },
  );
  test('new instance restores recency and all kinds', () async {
    await favorites.toggle('template:a');
    await favorites.toggle('decoration:b');
    final restored = CatalogFavorites(storage: storage);
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.keys, ['decoration:b', 'template:a']);
    expect(
      restored.arrange(
        ['template:a', 'missing'],
        (s) => s,
        onlyFavorites: true,
      ),
      ['template:a'],
    );
  });
  test('actual SharedPreferences adapter survives re-creation', () async {
    SharedPreferences.setMockInitialValues({});
    final first = CatalogFavorites();
    final second = CatalogFavorites();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    expect(await first.toggle('frame:studioOvalMat'), true);
    await second.load();
    expect(second.keys, ['frame:studioOvalMat']);
  });
  test('failed write rolls back, queue accepts retry', () async {
    await favorites.toggle('old');
    storage.failWrite = true;
    expect(await favorites.toggle('new'), false);
    expect(favorites.keys, ['old']);
    storage.failWrite = false;
    expect(await favorites.toggle('new'), true);
    expect(favorites.keys, ['new', 'old']);
  });
  test(
    'failed read does not overwrite saved preferences and can retry',
    () async {
      storage.value = jsonEncode({
        'version': 1,
        'keys': ['old'],
      });
      storage.failRead = true;
      expect(await favorites.toggle('new'), false);
      expect(jsonDecode(storage.value!)['keys'], ['old']);
      storage.failRead = false;
      expect(await favorites.toggle('new'), true);
      expect(favorites.keys, ['new', 'old']);
    },
  );
  test(
    'malformed preference recovers; duplicate and non-string IDs ignored',
    () async {
      storage.value = '{broken';
      expect(await favorites.toggle('new'), true);
      expect(favorites.keys, ['new']);
      storage.value = jsonEncode({
        'version': 1,
        'keys': ['a', 3, 'a', '', 'b'],
      });
      final clean = CatalogFavorites(storage: storage);
      addTearDown(clean.dispose);
      await clean.load();
      expect(clean.keys, ['a', 'b']);
    },
  );
  test(
    'one-time legacy migration cannot resurrect an unfavorited template',
    () async {
      await favorites.toggle('recent');
      await favorites.importLegacyTemplates([
        'legacy',
        'legacy',
      ], scope: 'guest');
      expect(favorites.keys, ['recent', 'legacy']);
      await favorites.toggle('legacy');
      final restored = CatalogFavorites(storage: storage);
      addTearDown(restored.dispose);
      await restored.importLegacyTemplates(['legacy'], scope: 'guest');
      expect(restored.keys, ['recent']);
    },
  );
  test('failed migration can retry without duplicates', () async {
    storage.failWrite = true;
    expect(await favorites.importLegacyTemplates(['a'], scope: 'guest'), false);
    expect(favorites.keys, isEmpty);
    storage.failWrite = false;
    expect(await favorites.importLegacyTemplates(['a'], scope: 'guest'), true);
    expect(favorites.keys, ['a']);
  });
  test('unknown schema version is not silently overwritten', () async {
    final raw = jsonEncode({
      'version': 2,
      'keys': ['future'],
    });
    storage.value = raw;
    expect(await favorites.toggle('new'), false);
    expect(storage.value, raw);
  });
  test(
    'template identity shared across store and editor; stable artwork identity',
    () {
      for (final c in authoredCollections) {
        final design = publishedDesignTemplates.singleWhere(
          (t) => t.id == c.id,
        );
        expect(
          CatalogFavoriteKeys.template(c.bundledId),
          CatalogFavoriteKeys.design(design.id),
        );
      }
      for (final spec in studioDecorations) {
        expect(
          CatalogFavoriteKeys.decoration(spec.insertionValue),
          'decoration:${spec.id}',
        );
      }
      expect(CatalogFavoriteKeys.template(42), 'template:remote:42');
      expect(
        CatalogFavoriteKeys.frame('a'),
        isNot(CatalogFavoriteKeys.font('a')),
      );
    },
  );
}
