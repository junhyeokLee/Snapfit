import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/page_templates.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/api/storage_service.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/page_layout_catalog.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/page_template_picker.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/template_selection_panel.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'package:snap_fit/features/album/service/album_persistence_service.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

import '../helpers/mock_repositories.dart';
import '../unit/catalog_favorites_test.dart' show MemoryFavoritesStorage;

class _Storage extends Fake implements StorageService {}

class _Persistence extends Fake implements AlbumPersistenceService {}

Widget _app(Widget child, {bool dark = false, double scale = 1}) =>
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: child),
      ),
    );

Future<void> _tapFilter(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<({ProviderContainer container, AlbumEditorViewModel vm})>
_editor() async {
  final container = ProviderContainer(
    overrides: [
      albumEditorOwnerReaderProvider.overrideWithValue(() => 'fixture-owner'),
      albumRepositoryProvider.overrideWithValue(MockAlbumRepository()),
      albumEditorServiceProvider.overrideWithValue(const AlbumEditorService()),
      albumPersistenceServiceProvider.overrideWithValue(_Persistence()),
      storageServiceProvider.overrideWithValue(_Storage()),
    ],
  );
  addTearDown(container.dispose);
  await container.read(albumEditorViewModelProvider.future);
  final vm = container.read(albumEditorViewModelProvider.notifier);
  vm.resetForCreate();
  vm.goToPage(1);
  vm.updatePageLayers([
    LayerModel(
      id: 'personal-caption',
      type: LayerType.text,
      position: const Offset(20, 30),
      width: 200,
      height: 50,
      text: '내가 쓴 문구',
      textStyle: const TextStyle(fontSize: 18),
    ),
  ]);
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
  });

  testWidgets(
    'category and photo filters combine and reset the actual results',
    (tester) async {
      await tester.pumpWidget(_app(PageLayoutCatalog(onSelect: (_) {})));
      await tester.pumpAndSettle();
      expect(find.text('${pageTemplates.length}가지 레이아웃'), findsOneWidget);
      await _tapFilter(tester, 'layout-category-diary');
      await _tapFilter(tester, 'layout-photos-two');
      final expected = pageTemplates
          .where(
            (layout) =>
                layout.category == PageLayoutCategory.diary &&
                layout.photoCount == 2,
          )
          .toList();
      expect(expected, isNotEmpty);
      expect(find.text('${expected.length}가지 레이아웃'), findsOneWidget);
      final shown = tester.widgetList<CatalogFavoriteTile>(
        find.byType(CatalogFavoriteTile),
      );
      expect(shown, isNotEmpty);
      expect(
        shown.every(
          (tile) => expected.any(
            (t) => tile.itemKey == CatalogFavoriteKeys.layout(t.id),
          ),
        ),
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('layout-reset-filters')));
      await tester.pumpAndSettle();
      expect(find.text('${pageTemplates.length}가지 레이아웃'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty combined filters have a reachable reset', (tester) async {
    await tester.pumpWidget(_app(PageLayoutCatalog(onSelect: (_) {})));
    await tester.pumpAndSettle();
    await _tapFilter(tester, 'layout-category-diary');
    await _tapFilter(tester, 'layout-photos-sevenPlus');
    expect(find.text('조건에 맞는 레이아웃이 없어요.'), findsOneWidget);
    final reset = find.text('모든 레이아웃 보기');
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(find.text('${pageTemplates.length}가지 레이아웃'), findsOneWidget);
  });

  testWidgets('favorites remain independent of choosing a layout', (
    tester,
  ) async {
    final selected = <String>[];
    await tester.pumpWidget(
      _app(PageTemplatePicker(onSelect: (layout) => selected.add(layout.id))),
    );
    await tester.pumpAndSettle();
    final favorite = find.byType(CatalogFavoriteButton).first;
    final itemKey = tester.widget<CatalogFavoriteButton>(favorite).itemKey;
    await tester.ensureVisible(favorite);
    await tester.tap(favorite);
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    expect(CatalogFavorites.instance.contains(itemKey), isTrue);
    // The lazy sliver header leaves the tree when ensureVisible scrolls the
    // first card to the top. Return with a normal scroll before locating it.
    await tester.drag(
      find.byKey(const PageStorageKey('page-layout-catalog-scroll')),
      const Offset(0, 600),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(CatalogFavoriteFilter));
    await tester.tap(find.byType(CatalogFavoriteFilter));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogFavoriteTile), findsOneWidget);
    final layout = pageTemplates.firstWhere(
      (t) => CatalogFavoriteKeys.layout(t.id) == itemKey,
    );
    final card = find.text(layout.name);
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(selected, [layout.id]);
    expect(CatalogFavorites.instance.contains(itemKey), isTrue);
  });

  testWidgets(
    'editor preview cancellation is nondestructive and apply is undoable',
    (tester) async {
      final fixture = await _editor();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: _app(const TemplateSelectionPanel(closeOnApply: false)),
        ),
      );
      await tester.pumpAndSettle();
      final before = fixture.vm.exportFullAlbumLayersJson(null);
      final card = find.text(pageTemplates.first.name);
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.textContaining('현재 쪽의 사진과 문구가 교체됩니다.'), findsOneWidget);
      expect(fixture.vm.exportFullAlbumLayersJson(null), before);
      await tester.tap(find.byTooltip('미리보기 닫기'));
      await tester.pumpAndSettle();
      expect(fixture.vm.exportFullAlbumLayersJson(null), before);
      await tester.tap(card);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-template-apply')));
      await tester.pumpAndSettle();
      expect(fixture.vm.layers.length, pageTemplates.first.slots.length);
      expect(
        fixture.vm.layers.every((layer) => layer.isTemplateContent == true),
        isTrue,
      );
      fixture.vm.undo();
      expect(fixture.vm.exportFullAlbumLayersJson(null), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a preview cannot apply to a replaced session with the same page id',
    (tester) async {
      final fixture = await _editor();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: _app(const TemplateSelectionPanel(closeOnApply: false)),
        ),
      );
      await tester.pumpAndSettle();
      final pageId = fixture.vm.currentPage!.id;
      final card = find.text(pageTemplates.first.name);
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      fixture.vm.resetForCreate();
      fixture.vm.goToPage(1);
      expect(fixture.vm.currentPage!.id, pageId);
      final replacement = fixture.vm.exportFullAlbumLayersJson(null);
      await tester.tap(find.byKey(const ValueKey('confirm-template-apply')));
      await tester.pumpAndSettle();
      expect(fixture.vm.exportFullAlbumLayersJson(null), replacement);
      expect(tester.takeException(), isNull);
    },
  );

  for (final sample in [
    (size: const Size(320, 568), dark: true, scale: 1.8),
    (size: const Size(844, 390), dark: false, scale: 1.0),
    (size: const Size(390, 844), dark: false, scale: 1.6),
  ]) {
    testWidgets(
      'layout picker remains usable ${sample.size} large=${sample.scale}',
      (tester) async {
        tester.view.physicalSize = sample.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _app(
            PageTemplatePicker(onSelect: (_) {}),
            dark: sample.dark,
            scale: sample.scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final firstFavorite = find.byType(CatalogFavoriteButton).first;
        await tester.ensureVisible(firstFavorite);
        await tester.pumpAndSettle();
        await tester.tap(firstFavorite);
        await tester.pumpAndSettle();
        expect(CatalogFavorites.instance.keys, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
