import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/image_frame_style_picker.dart';
import 'package:snap_fit/shared/widgets/studio_phrase_picker.dart';
import 'package:snap_fit/shared/widgets/font_picker_list.dart';
import 'package:snap_fit/core/templates/studio_phrase_catalog.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/decorate_sticker_tab.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/page_template_picker.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/text_style_picker_sheet.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_start_step.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import '../unit/catalog_favorites_test.dart' show MemoryFavoritesStorage;
import 'ai_album_start_step_test.dart' show wrapCreation, loadCreationFonts;

void main() {
  late CatalogFavorites previous;
  late MemoryFavoritesStorage storage;
  setUpAll(loadCreationFonts);
  setUp(() async {
    previous = CatalogFavorites.instance;
    storage = MemoryFavoritesStorage();
    CatalogFavorites.instance = CatalogFavorites(storage: storage);
    await CatalogFavorites.instance.load();
  });
  tearDown(() {
    CatalogFavorites.instance.dispose();
    CatalogFavorites.instance = previous;
  });

  testWidgets(
    'star has independent 44px hit target, no apply, latest first and persistent',
    (tester) async {
      final applied = <String>[];
      Widget grid() => wrapCreation(
        CatalogFavoriteGrid<String>(
          items: const ['a', 'b', 'c'],
          keyOf: (s) => s,
          labelOf: (s) => s,
          itemBuilder: (_, s) => InkWell(
            onTap: () => applied.add(s),
            child: Center(child: Text(s)),
          ),
        ),
      );
      await tester.pumpWidget(grid());
      await tester.pumpAndSettle();
      final star = find.byKey(const ValueKey('favorite-b'));
      expect(tester.getSize(star).width, greaterThanOrEqualTo(44));
      await tester.tap(star);
      await tester.pumpAndSettle();
      expect(applied, isEmpty);
      expect(
        tester
            .widgetList<CatalogFavoriteTile>(find.byType(CatalogFavoriteTile))
            .map((t) => t.itemKey),
        ['b', 'a', 'c'],
      );
      await tester.tap(find.byKey(const ValueKey('favorite-c')));
      await tester.pumpAndSettle();
      expect(CatalogFavorites.instance.keys, ['c', 'b']);
      await tester.tap(find.text('c'));
      await tester.pumpAndSettle();
      expect(applied, ['c']);
      expect(CatalogFavorites.instance.keys, ['c', 'b']);
      await tester.pumpWidget(const SizedBox());
      CatalogFavorites.instance.dispose();
      CatalogFavorites.instance = CatalogFavorites(storage: storage);
      await tester.pumpWidget(grid());
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<CatalogFavoriteTile>(find.byType(CatalogFavoriteTile))
            .first
            .itemKey,
        'c',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'filter empty state, unstar last item, reset and failed write feedback',
    (tester) async {
      await tester.pumpWidget(
        wrapCreation(
          CatalogFavoriteGrid<String>(
            items: const ['a'],
            keyOf: (s) => s,
            labelOf: (s) => s,
            itemBuilder: (_, s) => Center(child: Text(s)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CatalogFavoriteFilter));
      await tester.pumpAndSettle();
      expect(find.text('즐겨찾기한 항목이 없어요'), findsOneWidget);
      await tester.tap(find.text('전체 보기'));
      await tester.pumpAndSettle();
      storage.failWrite = true;
      await tester.tap(find.byKey(const ValueKey('favorite-a')));
      await tester.pumpAndSettle();
      expect(find.text('즐겨찾기를 저장하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
      expect(CatalogFavorites.instance.keys, isEmpty);
      storage.failWrite = false;
      await tester.tap(find.byKey(const ValueKey('favorite-a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CatalogFavoriteFilter));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('favorite-a')));
      await tester.pumpAndSettle();
      expect(find.text('즐겨찾기한 항목이 없어요'), findsOneWidget);
    },
  );

  final sizes = [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ];
  for (final size in sizes) {
    for (final kind in [
      'frame',
      'decoration',
      'phrase',
      'font',
      'layout',
      'textStyle',
    ]) {
      testWidgets('$size $kind: favorite without applying or dismissing', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var applied = 0;
        final Widget picker = switch (kind) {
          'frame' => ImageFrameStylePicker(
            selectedKey: null,
            onSelect: (_) => applied++,
          ),
          'decoration' => DecorateStickerTab(
            surfaceColor: Colors.white,
            onStickerTap: (_) => applied++,
          ),
          'phrase' => StudioPhrasePicker(onSelect: (_) => applied++),
          'font' => Center(
            child: FontPickerList(
              families: const ['NotoSans', 'Pretendard', 'Roboto'],
              current: 'Roboto',
              onPick: (_) => applied++,
            ),
          ),
          'layout' => PageTemplatePicker(onSelect: (_) => applied++),
          _ => TextStylePickerSheet(
            selectedKey: null,
            onSelect: (_) => applied++,
          ),
        };
        await tester.pumpWidget(wrapCreation(picker));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final button = find.byType(CatalogFavoriteButton).first;
        final key = tester.widget<CatalogFavoriteButton>(button).itemKey;
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(applied, 0);
        expect(CatalogFavorites.instance.contains(key), true);
        expect(tester.takeException(), isNull);
        if (kind != 'font') {
          await tester.tap(find.byType(CatalogFavoriteFilter).first);
          await tester.pumpAndSettle();
          expect(find.byType(CatalogFavoriteButton), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets('phrase favorites span categories, still narrow by category', (
    tester,
  ) async {
    final phrase = studioPhrases.last;
    await CatalogFavorites.instance.toggle(
      CatalogFavoriteKeys.phrase(phrase.id),
    );
    await tester.pumpWidget(wrapCreation(StudioPhrasePicker(onSelect: (_) {})));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<CatalogFavoriteTile>(find.byType(CatalogFavoriteTile))
          .first
          .itemKey,
      CatalogFavoriteKeys.phrase(phrase.id),
    );
    await tester.tap(find.byType(CatalogFavoriteFilter));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogFavoriteTile), findsOneWidget);
    await tester.tap(find.text('웨딩'));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogFavoritesEmpty), findsOneWidget);
  });

  testWidgets(
    'creation catalog reorders shared template saves without selecting',
    (tester) async {
      var selected = 0;
      final template = bundledCreationTemplates[1];
      await CatalogFavorites.instance.toggle(
        CatalogFavoriteKeys.template(template.id),
      );
      await tester.pumpWidget(
        wrapCreation(
          AiAlbumStartStep(
            onAiStart: () {},
            onManualStart: () {},
            templates: AsyncData(bundledCreationTemplates),
            onTemplateSelected: (_) => selected++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(CatalogFavoriteFilter),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byType(CatalogFavoriteFilter));
      await tester.pumpAndSettle();
      final star = find.byType(CatalogFavoriteButton).first;
      await tester.ensureVisible(star);
      await tester.pumpAndSettle();
      expect(
        tester.widget<CatalogFavoriteButton>(star).itemKey,
        CatalogFavoriteKeys.template(template.id),
      );
      await tester.tap(star);
      await tester.pumpAndSettle();
      expect(selected, 0);
      expect(CatalogFavorites.instance.keys, isEmpty);
      expect(find.text('즐겨찾기한 항목이 없어요'), findsOneWidget);
    },
  );
}
