import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/decorate_panel.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/decorate_sticker_tab.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_access.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

import '../helpers/mock_repositories.dart';
import '../unit/album_editor_view_model_test.dart'
    show FakeAlbumPersistenceService, FakeStorageService;
import '../unit/catalog_favorites_test.dart' show MemoryFavoritesStorage;

final _decoration = studioDecorations.first;
Finder get _tile => find.byKey(ValueKey(_decoration.insertionValue));

Future<({ProviderContainer container, AlbumEditorViewModel vm})> _mount(
  WidgetTester tester, {
  required PointShopAccessGate gate,
  required VoidCallback onClose,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      albumRepositoryProvider.overrideWithValue(MockAlbumRepository()),
      albumEditorServiceProvider.overrideWithValue(const AlbumEditorService()),
      albumPersistenceServiceProvider.overrideWithValue(
        FakeAlbumPersistenceService(),
      ),
      storageServiceProvider.overrideWithValue(FakeStorageService()),
      albumEditorOwnerReaderProvider.overrideWithValue(() => 'fixture-owner'),
      albumEditorOwnerChangesProvider.overrideWith(
        (ref) => const Stream.empty(),
      ),
      pointShopAccessGateProvider.overrideWithValue(gate),
      pointShopCatalogProvider.overrideWith(
        (ref) async => [
          PointShopProduct(
            productKey: 'sticker:${_decoration.id}',
            kind: 'sticker',
            assetId: _decoration.id,
            title: _decoration.label,
            pointPrice: 120,
            isActive: true,
          ),
        ],
      ),
      ownedPointShopKeysProvider.overrideWith((ref) async => <String>{}),
    ],
  );
  addTearDown(container.dispose);
  await container.read(albumEditorViewModelProvider.future);
  final vm = container.read(albumEditorViewModelProvider.notifier)
    ..resetForCreate(targetPages: 2);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: DecoratePanel(
            mode: DecorateSheetMode.sticker,
            onClose: onClose,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(_tile.hitTestable(), findsOneWidget);
  return (container: container, vm: vm);
}

void main() {
  late CatalogFavorites previous;
  setUp(() async {
    previous = CatalogFavorites.instance;
    CatalogFavorites.instance = CatalogFavorites(
      storage: MemoryFavoritesStorage(),
    );
    await CatalogFavorites.instance.load();
  });
  tearDown(() {
    CatalogFavorites.instance.dispose();
    CatalogFavorites.instance = previous;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  for (final change in ['page', 'draft']) {
    testWidgets('delayed decoration never applies to a changed $change', (
      tester,
    ) async {
      final approval = Completer<bool>();
      final requests = <String>[];
      var closes = 0;
      final fixture = await _mount(
        tester,
        gate: (context, ref, {required productKey, required title}) {
          requests.add(productKey);
          return approval.future;
        },
        onClose: () => closes++,
      );
      final vm = fixture.vm;
      final state = tester.state(find.byType(DecorateStickerTab));
      await tester.tap(_tile);
      await tester.tap(_tile);
      await tester.pump();
      expect(requests, ['sticker:${_decoration.id}']);
      final oldPage = vm.currentPage!.id;
      switch (change) {
        case 'page':
          vm.goToPage(1);
          expect(vm.currentPage!.id, isNot(oldPage));
        case 'draft':
          final session = vm.editSessionIdentity;
          vm.resetForCreate(targetPages: 2);
          expect(vm.currentPage!.id, oldPage);
          expect(vm.editSessionIdentity, isNot(same(session)));
      }
      await tester.pump();
      expect(tester.state(find.byType(DecorateStickerTab)), same(state));
      approval.complete(true);
      await tester.pumpAndSettle();
      expect(vm.pages.every((page) => page.layers.isEmpty), isTrue);
      expect(closes, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('stale approval releases the lock for a fresh valid selection', (
    tester,
  ) async {
    var approval = Completer<bool>();
    var requests = 0, closes = 0;
    final fixture = await _mount(
      tester,
      gate: (context, ref, {required productKey, required title}) {
        requests++;
        return approval.future;
      },
      onClose: () => closes++,
    );
    await tester.tap(_tile);
    await tester.pump();
    fixture.vm.resetForCreate(targetPages: 2);
    approval.complete(true);
    await tester.pumpAndSettle();
    expect(fixture.vm.currentPage!.layers, isEmpty);
    expect(closes, 0);

    approval = Completer<bool>();
    await tester.tap(_tile);
    await tester.tap(_tile);
    await tester.pump();
    expect(requests, 2);
    approval.complete(true);
    await tester.pumpAndSettle();
    expect(fixture.vm.currentPage!.layers, hasLength(1));
    expect(closes, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('same-target edits preserve valid insertion and duplicate lock', (
    tester,
  ) async {
    final approval = Completer<bool>();
    var requests = 0, closes = 0;
    final fixture = await _mount(
      tester,
      gate: (context, ref, {required productKey, required title}) {
        requests++;
        return approval.future;
      },
      onClose: () => closes++,
    );
    await tester.tap(_tile);
    await tester.pump();
    fixture.vm.updatePageLayers([
      LayerModel(
        id: 'keep-my-edit',
        type: LayerType.text,
        position: Offset.zero,
        width: 100,
        height: 40,
        text: '내 기록',
      ),
    ]);
    await tester.tap(_tile);
    approval.complete(true);
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(closes, 1);
    expect(fixture.vm.currentPage!.layers, hasLength(2));
    expect(fixture.vm.currentPage!.layers.first.id, 'keep-my-edit');
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'inline panel captures the page at selection, not panel opening',
    (tester) async {
      final approval = Completer<bool>();
      var closes = 0;
      final fixture = await _mount(
        tester,
        gate: (context, ref, {required productKey, required title}) =>
            approval.future,
        onClose: () => closes++,
      );
      final state = tester.state(find.byType(DecorateStickerTab));
      fixture.vm.goToPage(1);
      await tester.pump();
      expect(tester.state(find.byType(DecorateStickerTab)), same(state));
      await tester.tap(_tile);
      approval.complete(true);
      await tester.pumpAndSettle();
      expect(fixture.vm.pages.first.layers, isEmpty);
      expect(fixture.vm.pages[1].layers, hasLength(1));
      expect(closes, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('closing the panel while access is pending never inserts', (
    tester,
  ) async {
    final approval = Completer<bool>();
    var closes = 0;
    final fixture = await _mount(
      tester,
      gate: (context, ref, {required productKey, required title}) =>
          approval.future,
      onClose: () => closes++,
    );
    await tester.tap(_tile);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    approval.complete(true);
    await tester.pumpAndSettle();
    expect(fixture.vm.pages.every((page) => page.layers.isEmpty), isTrue);
    expect(closes, 0);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
