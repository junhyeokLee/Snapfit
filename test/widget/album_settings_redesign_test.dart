import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts, wrapCreation;

Finder _key(String value, {bool skipOffstage = true}) =>
    find.byKey(ValueKey(value), skipOffstage: skipOffstage);

AlbumCreateStep1 _settings({
  String title = '',
  CoverSize? cover,
  int pages = 20,
  int minimumPages = 20,
  ValueChanged<String>? onTitle,
  ValueChanged<CoverSize>? onCover,
  ValueChanged<int>? onPages,
  VoidCallback? onNext,
}) => AlbumCreateStep1(
  albumTitle: title,
  selectedCover: cover ?? defaultCoverSize,
  selectedPageCount: pages,
  minPageCount: minimumPages,
  onTitleChanged: onTitle ?? (_) {},
  onCoverSelected: onCover ?? (_) {},
  onPageCountChanged: onPages ?? (_) {},
  onNext: onNext ?? () {},
);

Future<void> _mount(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  // A new host must exercise initial expansion rather than retained local state.
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  await tester.pumpWidget(wrapCreation(child, textScale: textScale));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Open only a closed section so existing tests do not accidentally close it.
Future<void> openAlbumSettingsSection(
  WidgetTester tester,
  String section,
) async {
  final content = switch (section) {
    'name' => _key('creation-album-title'),
    'book' => _key('print-cover-soft'),
    'pages' => find.byTooltip('페이지 늘리기'),
    _ => throw ArgumentError.value(section, 'section'),
  };
  if (content.evaluate().isNotEmpty) return;
  await _tap(tester, _key('creation-settings-$section-toggle'));
}

IconButton _pageButton(WidgetTester tester, String tooltip) =>
    tester.widget<IconButton>(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == tooltip,
      ),
    );

String? _assetName(ImageProvider image) => switch (image) {
  AssetImage() => image.assetName,
  ResizeImage() => _assetName(image.imageProvider),
  _ => null,
};

void main() {
  setUpAll(loadCreationFonts);

  testWidgets('initial expansion follows whether the album name is empty', (
    tester,
  ) async {
    await _mount(tester, _settings());
    for (final section in ['name', 'book', 'pages']) {
      expect(_key('creation-settings-$section-toggle'), findsOneWidget);
    }
    expect(_key('creation-album-title'), findsOneWidget);
    expect(_key('print-cover-soft'), findsNothing);
    expect(find.byTooltip('페이지 늘리기'), findsNothing);

    await _mount(tester, _settings(title: '우리의 여름'));
    expect(_key('creation-album-title'), findsNothing);
    expect(_key('print-cover-soft'), findsOneWidget);
    expect(_key('print-cover-hard'), findsOneWidget);
    expect(find.byTooltip('페이지 늘리기'), findsNothing);
  });

  testWidgets('opening a section closes the previous one and can close all', (
    tester,
  ) async {
    await _mount(tester, _settings(title: '우리의 여름'));
    await _tap(tester, _key('creation-settings-name-toggle'));
    expect(_key('creation-album-title'), findsOneWidget);
    expect(_key('print-cover-soft'), findsNothing);

    await _tap(tester, _key('creation-settings-pages-toggle'));
    expect(_key('creation-album-title'), findsNothing);
    expect(_key('print-cover-soft'), findsNothing);
    expect(find.byTooltip('페이지 늘리기'), findsOneWidget);

    await _tap(tester, _key('creation-settings-pages-toggle'));
    expect(_key('creation-album-title'), findsNothing);
    expect(_key('print-cover-soft'), findsNothing);
    expect(find.byTooltip('페이지 늘리기'), findsNothing);
    for (final section in ['name', 'book', 'pages']) {
      expect(_key('creation-settings-$section-toggle'), findsOneWidget);
    }
  });

  testWidgets(
    'name rotation preserves composition and collapsing retains input',
    (tester) async {
      var storedName = '';
      await _mount(tester, _settings(onTitle: (value) => storedName = value));
      final name = _key('creation-album-title');
      await tester.ensureVisible(name);
      await tester.showKeyboard(name);
      const editing = TextEditingValue(
        text: '우리의 한',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 4, end: 5),
      );
      tester.testTextInput.updateEditingValue(editing);
      await tester.pump();
      final controller = tester.widget<TextField>(name).controller!;
      final input = tester.state<EditableTextState>(
        find.descendant(of: name, matching: find.byType(EditableText)),
      );
      expect(storedName, '우리의 한');

      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(name).controller, same(controller));
      expect(controller.value, editing);
      expect(
        tester.state<EditableTextState>(
          find.descendant(of: name, matching: find.byType(EditableText)),
        ),
        same(input),
      );

      // Explicitly leaving the input may commit IME composition; its stored text,
      // selection and input subtree must survive collapsing and reopening.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      final committed = controller.value;
      expect(committed.text, editing.text);
      expect(committed.selection, editing.selection);
      await _tap(tester, _key('creation-settings-book-toggle'));
      expect(name, findsNothing);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      final retainedName = _key('creation-album-title', skipOffstage: false);
      expect(
        tester.widget<TextField>(retainedName).controller,
        same(controller),
      );
      expect(controller.text, committed.text);
      expect(controller.selection, committed.selection);

      await _tap(tester, _key('creation-settings-name-toggle'));
      expect(tester.widget<TextField>(name).controller, same(controller));
      expect(
        tester.state<EditableTextState>(
          find.descendant(of: name, matching: find.byType(EditableText)),
        ),
        same(input),
      );
      expect(controller.text, committed.text);
      expect(controller.selection, committed.selection);
      expect(storedName, '우리의 한');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'name validation rejects whitespace and enforces fifty characters',
    (tester) async {
      var storedName = '';
      var continued = 0;
      await _mount(
        tester,
        _settings(
          onTitle: (value) => storedName = value,
          onNext: () => continued++,
        ),
      );
      final name = _key('creation-album-title');
      final next = _key('creation-setup-next');
      expect(tester.widget<ElevatedButton>(next).onPressed, isNull);
      await tester.enterText(name, '   ');
      await tester.pump();
      expect(storedName, '   ');
      expect(tester.widget<ElevatedButton>(next).onPressed, isNull);

      await tester.enterText(name, List.filled(51, '가').join());
      await tester.pump();
      expect(
        tester.widget<TextField>(name).controller!.text,
        List.filled(50, '가').join(),
      );
      expect(storedName, List.filled(50, '가').join());
      expect(tester.widget<ElevatedButton>(next).onPressed, isNotNull);
      FocusManager.instance.primaryFocus?.unfocus();
      await _tap(tester, next);
      expect(continued, 1);
    },
  );

  testWidgets('binding photos and copy keep the accepted parent selection', (
    tester,
  ) async {
    final requested = <CoverSize>[];
    await _mount(tester, _settings(title: '선택 확인', onCover: requested.add));
    for (final text in [
      '유연한 종이 표지',
      '일반 책·잡지 같은 형태',
      '단단한 보드 표지',
      '오래 간직하기 좋은 형태',
      '앨범 주문 시 적용',
    ]) {
      expect(find.text(text), findsOneWidget);
    }
    final photoAssets = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => _assetName(image.image))
        .whereType<String>()
        .toSet();
    expect(
      photoAssets,
      containsAll([
        'assets/print/cover_types/supplier_soft.png',
        'assets/print/cover_types/supplier_hard.png',
      ]),
    );

    await _tap(tester, _key('print-cover-hard'));
    expect(requested, hasLength(1));
    expect(requested.single.coverType, PrintCoverType.hard);
    expect(_key('print-cover-selected-soft'), findsOneWidget);
    expect(_key('print-cover-selected-hard'), findsNothing);

    await _tap(tester, _key('print-size-REDP_250X200_SOFT'));
    expect(requested, hasLength(2));
    expect(requested.last.sizeProductId, 'REDP_250X200_SOFT');
    expect(
      _key('print-size-selected-${defaultCoverSize.sizeProductId}'),
      findsOneWidget,
    );
    expect(_key('print-size-selected-REDP_250X200_SOFT'), findsNothing);
  });

  testWidgets('cover details explain construction without changing selection', (
    tester,
  ) async {
    final requested = <CoverSize>[];
    await _mount(tester, _settings(title: '커버 안내', onCover: requested.add));
    await _tap(tester, find.text('자세히 보기'));
    expect(find.text('커버 종류 안내'), findsOneWidget);
    expect(find.text('일반 책이나 잡지에 사용하는 종이 표지예요.'), findsOneWidget);
    expect(find.text('인쇄한 종이를 하드보드에 붙인 표지로, 오래 간직하는 책에 사용해요.'), findsOneWidget);
    expect(find.text('선택한 커버는 앨범 주문 시 적용돼요.'), findsOneWidget);
    expect(requested, isEmpty);
    await _tap(tester, find.text('닫기'));
    expect(find.text('커버 종류 안내'), findsNothing);
    expect(_key('print-cover-selected-soft'), findsOneWidget);
    expect(requested, isEmpty);
  });

  testWidgets('page callbacks preserve two-page steps and content boundaries', (
    tester,
  ) async {
    var pages = 20;
    final requested = <int>[];
    late StateSetter updateHost;
    await _mount(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          updateHost = setState;
          return _settings(
            title: '쪽수 확인',
            pages: pages,
            onPages: (value) {
              requested.add(value);
              setState(() => pages = value);
            },
          );
        },
      ),
    );
    await _tap(tester, _key('creation-settings-pages-toggle'));
    expect(_pageButton(tester, '페이지 줄이기').onPressed, isNull);
    await _tap(tester, find.byTooltip('페이지 늘리기'));
    expect(pages, 22);
    await _tap(tester, find.byTooltip('페이지 줄이기'));
    expect(pages, 20);
    expect(requested, [22, 20]);

    updateHost(() => pages = 80);
    await tester.pumpAndSettle();
    expect(_pageButton(tester, '페이지 늘리기').onPressed, isNull);
    await _tap(tester, find.byTooltip('페이지 줄이기'));
    expect(pages, 78);
    expect(requested, [22, 20, 78]);

    await _mount(
      tester,
      _settings(title: '내용 최소 쪽수', pages: 24, minimumPages: 23),
    );
    await _tap(tester, _key('creation-settings-pages-toggle'));
    expect(_pageButton(tester, '페이지 줄이기').onPressed, isNull);
    expect(_pageButton(tester, '페이지 늘리기').onPressed, isNotNull);

    await _mount(
      tester,
      _settings(title: '인쇄 범위를 넘는 내용', pages: 82, minimumPages: 81),
    );
    // The reason for a blocked next action stays visible with pages collapsed.
    expect(_key('creation-settings-page-limit').hitTestable(), findsOneWidget);
    await _tap(tester, _key('creation-settings-pages-toggle'));
    expect(_pageButton(tester, '페이지 줄이기').onPressed, isNull);
    expect(_pageButton(tester, '페이지 늘리기').onPressed, isNull);
    expect(
      tester.widget<ElevatedButton>(_key('creation-setup-next')).onPressed,
      isNull,
    );
    expect(find.textContaining('80쪽을 초과'), findsOneWidget);
  });

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets(
      'settings sections remain reachable at 200 percent text $size',
      (tester) async {
        await _mount(
          tester,
          _settings(title: '우리의 오래 기억할 여름'),
          size: size,
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
        for (final section in ['name', 'book', 'pages']) {
          final toggle = _key('creation-settings-$section-toggle');
          await _tap(tester, toggle);
          expect(toggle.hitTestable(), findsOneWidget);
          final touchSize = tester.getSize(toggle);
          expect(touchSize.height, greaterThanOrEqualTo(48));
          expect(touchSize.width, greaterThanOrEqualTo(48));
          expect(tester.takeException(), isNull);
        }
        final next = _key('creation-setup-next');
        await tester.ensureVisible(next);
        await tester.pumpAndSettle();
        expect(next.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
