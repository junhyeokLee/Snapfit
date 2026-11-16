import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'baseline_catalog_favorite_widgets.dart';

class _FavoritesStorage implements CatalogFavoritesStorage {
  String? value;
  bool failWrite = false;
  Completer<void>? writeGate;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String next) async {
    if (writeGate != null) await writeGate!.future;
    if (failWrite) throw StateError('Storage is full');
    value = next;
  }
}

Widget _library({List<String> keys = const ['a']}) => Scaffold(
  body: CatalogFavoritesBuilder(
    builder: (context, favorites) => Column(
      children: [
        for (final key in keys)
          if (favorites.contains(key))
            Row(
              key: ValueKey('favorite-card-$key'),
              children: [
                Text('item-$key'),
                CatalogFavoriteButton(
                  itemKey: key,
                  label: 'item-$key',
                ),
              ],
            ),
      ],
    ),
  ),
);

void main() {
  late CatalogFavorites previous;
  late CatalogFavorites favorites;
  late _FavoritesStorage storage;

  setUp(() async {
    previous = CatalogFavorites.instance;
    // Seed persistence without creating a write queue in setUp's real zone.
    storage = _FavoritesStorage()
      ..value = jsonEncode({'version': 1, 'keys': ['a']});
    favorites = CatalogFavorites(storage: storage);
    CatalogFavorites.instance = favorites;
    await favorites.load();
  });

  tearDown(() {
    favorites.dispose();
    CatalogFavorites.instance = previous;
  });

  testWidgets('undo restores the card after removal disposes its button', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: _library()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favorite-a')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('favorite-card-a')), findsNothing);
    expect(find.text('되돌리기'), findsOneWidget);
    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('favorite-card-a')), findsOneWidget);
    final restored = CatalogFavorites(storage: storage);
    addTearDown(restored.dispose);
    await tester.runAsync(restored.load);
    expect(restored.keys, ['a']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed restoration rolls back and reports the storage failure', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: _library()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favorite-a')));
    await tester.pumpAndSettle();
    expect(find.text('되돌리기'), findsOneWidget);
    storage.failWrite = true;
    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();

    expect(favorites.contains('a'), isFalse);
    expect(find.byKey(const ValueKey('favorite-card-a')), findsNothing);
    expect(find.text('즐겨찾기를 저장하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed removal keeps the card and offers no undo', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _library()));
    await tester.pumpAndSettle();
    storage.failWrite = true;
    await tester.tap(find.byKey(const ValueKey('favorite-a')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('favorite-card-a')), findsOneWidget);
    expect(find.text('되돌리기'), findsNothing);
    expect(find.text('즐겨찾기를 저장하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('undo preserves a re-favorite already queued by another view', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: _library()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favorite-a')));
    await tester.pumpAndSettle();
    expect(find.text('되돌리기'), findsOneWidget);
    final undo = tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed;

    // Both writes start before the next frame, so restore must be idempotent
    // inside the persistence queue rather than checking selection only in UI.
    final refavorite = favorites.toggle('a');
    undo();
    undo();
    await tester.pumpAndSettle();
    expect(await refavorite, isTrue);

    expect(favorites.keys, ['a']);
    expect(find.byKey(const ValueKey('favorite-card-a')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('another item changing does not cancel the available undo', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: _library()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favorite-a')));
    await tester.pumpAndSettle();
    expect(find.text('되돌리기'), findsOneWidget);
    final addOther = favorites.toggle('b');
    await tester.pumpAndSettle();
    expect(await addOther, isTrue);
    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();

    expect(favorites.keys, ['a', 'b']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an undo replaced by a newer removal cannot restore its old item', (
    tester,
  ) async {
    final addOther = favorites.toggle('b');
    await tester.pumpAndSettle();
    expect(await addOther, isTrue);
    await tester.pumpWidget(MaterialApp(home: _library(keys: const ['a', 'b'])));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favorite-a')));
    await tester.pumpAndSettle();
    expect(find.text('되돌리기'), findsOneWidget);
    final oldUndo = tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed;
    await tester.tap(find.byKey(const ValueKey('favorite-b')));
    await tester.pumpAndSettle();
    oldUndo();
    await tester.pumpAndSettle();

    expect(favorites.keys, isEmpty);
    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(favorites.keys, ['b']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an undo from a disposed route cannot restore an item', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const Scaffold(body: Text('home'))),
    );
    navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => _library()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favorite-a')));
    await tester.pumpAndSettle();
    expect(find.text('되돌리기'), findsOneWidget);
    final undo = tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed;
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    undo();
    await tester.pumpAndSettle();

    expect(favorites.keys, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late removal completion does not show undo on the next route', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const Scaffold(body: Text('home'))),
    );
    navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => _library()));
    await tester.pumpAndSettle();
    final gate = Completer<void>();
    storage.writeGate = gate;
    await tester.tap(find.byKey(const ValueKey('favorite-a')));
    await tester.pump();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    gate.complete();
    await tester.pumpAndSettle();

    expect(favorites.keys, isEmpty);
    expect(find.text('되돌리기'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
