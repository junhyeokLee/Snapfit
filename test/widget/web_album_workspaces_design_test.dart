import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/presentation/widgets/web/web_album_workspace.dart';
import 'package:snap_fit/features/album/presentation/widgets/web/web_editor_viewport.dart';
import 'package:snap_fit/shared/web/web_design.dart';

Future<void> _mount(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1440, 900),
  bool dark = false,
  double textScale = 1,
  double keyboardInset = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: SnapFitWebTheme.from(
          ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
            splashFactory: NoSplash.splashFactory,
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

WebAlbumEditorWorkspace _editor({
  bool saving = false,
  VoidCallback? save,
  String? selectedLayerId,
  DateTime? accountSavedAt,
  DateTime? draftSavedAt,
}) => WebAlbumEditorWorkspace(
  title: '우리가 함께 만든 여행 앨범',
  pageLabel: '내지 1쪽',
  specification: '정사각 210 × 210mm · 소프트커버 · 내지 80쪽',
  hasUnsavedChanges: true,
  isPersisted: true,
  isSaving: saving,
  selectedLayerId: selectedLayerId,
  lastAccountSavedAt: accountSavedAt,
  lastDraftSavedAt: draftSavedAt,
  onBack: () {},
  onSave: save ?? () {},
  onSaveDraft: () {},
  onUndo: () {},
  onRedo: () {},
  canvas: const ColoredBox(
    key: ValueKey('fixture-canvas'),
    color: Colors.white,
  ),
  pageRail: const Center(child: Text('페이지 목록')),
  compactPageRail: const Center(child: Text('페이지 목록')),
  properties: const Center(child: Text('사진과 글의 속성')),
  tools: [
    for (final label in ['사진 추가', '텍스트', '레이어', '레이아웃', '템플릿', '꾸미기', '배경'])
      WebAlbumEditorTool(
        label: label,
        icon: Icons.layers_outlined,
        onPressed: () {},
        opensProperties: false,
      ),
  ],
);

void main() {
  testWidgets(
    'editor combines document identity and save without another document header',
    (tester) async {
      var saves = 0;
      await _mount(tester, _editor(save: () => saves++));
      final header = find.byKey(const ValueKey('web-editor-document-header'));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('web-utility-header')),
          matching: header,
        ),
        findsOneWidget,
      );
      expect(find.text('우리가 함께 만든 여행 앨범'), findsOneWidget);
      expect(
        tester
            .getSize(
              find.byKey(const ValueKey('web-editor-document-workspace')),
            )
            .height,
        greaterThan(900 * .8),
      );
      expect(
        tester.getSize(find.byType(WebEditorViewport)).height,
        greaterThan(900 * .75),
      );
      await tester.tap(find.text('계정에 저장'));
      expect(saves, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final size in [
    const Size(1440, 900),
    const Size(1024, 768),
    const Size(768, 900),
    const Size(390, 844),
    const Size(320, 568),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('editor and reader fit $size dark=$dark with larger text', (
        tester,
      ) async {
        await _mount(tester, _editor(), size: size, dark: dark, textScale: 1.3);
        expect(tester.takeException(), isNull);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('web-editor-viewport')))
              .height,
          greaterThan(size.height * .25),
        );
        await _mount(
          tester,
          WebAlbumReaderWorkspace(
            title: '여행에서 만난 소중한 순간들을 모은 앨범',
            description: '정사각 210 × 210mm · 하드커버 · 내지 80쪽',
            pageLabel: '내지 80 / 80쪽',
            canvas: const SizedBox.expand(key: ValueKey('reader-artwork')),
            pageRail: const Center(child: Text('페이지 목록')),
            compactPageRail: const Center(child: Text('페이지 목록')),
            onBack: () {},
            onEdit: () {},
            onOrder: () {},
            onDetail: () {},
            onPrevious: () {},
            onNext: () {},
          ),
          size: size,
          dark: dark,
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
        final artwork = tester.getRect(
          find.byKey(const ValueKey('reader-artwork')),
        );
        expect(artwork.height, greaterThan(60));
        expect(artwork.bottom, lessThanOrEqualTo(size.height));
        expect(find.text('앨범 편집'), findsOneWidget);
        expect(find.text('책으로 주문'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets(
    'short narrow editor gives canvas priority and keeps pages one click away',
    (tester) async {
      await _mount(
        tester,
        _editor(),
        size: const Size(320, 568),
        textScale: 1.3,
      );
      final before = tester
          .getSize(find.byKey(const ValueKey('web-editor-viewport')))
          .height;
      expect(find.text('페이지 목록'), findsNothing);
      expect(before, greaterThan(140));
      await tester.tap(find.byTooltip('페이지 목록 보기'));
      await tester.pumpAndSettle();
      expect(find.text('페이지 목록'), findsOneWidget);
      final artwork = tester.getRect(
        find.byKey(const ValueKey('web-editor-viewport')),
      );
      expect(artwork.height, greaterThan(140));
      expect(
        artwork.intersect(const Rect.fromLTWH(0, 0, 320, 568)).height,
        greaterThan(140),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('페이지 목록 접기'));
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(find.byKey(const ValueKey('web-editor-viewport')))
            .height,
        closeTo(before, .1),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('saving disables document and persistence actions', (
    tester,
  ) async {
    await _mount(tester, _editor(saving: true));
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '계정에 저장 중'),
    );
    expect(save.onPressed, isNull);
    final back = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.arrow_back),
    );
    expect(back.onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [
    const Size(390, 844),
    const Size(320, 568),
    const Size(844, 390),
    const Size(1024, 768),
  ]) {
    testWidgets('selected properties share space with artwork at $size', (
      tester,
    ) async {
      await _mount(
        tester,
        _editor(selectedLayerId: 'photo'),
        size: size,
        textScale: 1.8,
      );
      final canvas = tester.getRect(
        find.byKey(const ValueKey('web-editor-document-workspace')),
      );
      final panel = tester.getRect(
        find.byKey(
          ValueKey(
            size.width < 760
                ? 'web-editor-bottom-properties'
                : 'web-editor-side-properties',
          ),
        ),
      );
      expect(canvas.overlaps(panel), isFalse);
      expect(canvas.width, greaterThan(240));
      expect(canvas.height, greaterThan(170));
      if (size.width < 760) {
        expect(panel.top, greaterThanOrEqualTo(canvas.bottom));
        expect(panel.width, closeTo(canvas.width, .1));
      } else {
        expect(panel.left, greaterThanOrEqualTo(canvas.right));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('inspector toggles preserve the current canvas view zoom', (
    tester,
  ) async {
    await _mount(tester, _editor(), size: const Size(390, 844));
    await tester.tap(find.byTooltip('화면 확대'));
    await tester.pumpAndSettle();
    expect(find.text('125%'), findsOneWidget);
    await tester.tap(find.byTooltip('속성 패널 보기'));
    await tester.pumpAndSettle();
    expect(find.text('125%'), findsOneWidget);
    await tester.tap(find.byTooltip('속성 패널 접기').last);
    await tester.pumpAndSettle();
    expect(find.text('125%'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'bottom properties drag preserves zoom and restores the preferred height',
    (tester) async {
      await _mount(
        tester,
        _editor(selectedLayerId: 'photo'),
        size: const Size(390, 1100),
      );
      final panel = find.byKey(const ValueKey('web-editor-bottom-properties'));
      final workspace = find.byKey(
        const ValueKey('web-editor-document-workspace'),
      );
      final handle = find.byKey(
        const ValueKey('web-editor-properties-resize-handle'),
      );
      final viewportState = tester.state(find.byType(WebEditorViewport));
      await tester.tap(find.byTooltip('화면 확대'));
      await tester.pumpAndSettle();
      final initialHeight = tester.getSize(panel).height;
      final initialCanvasHeight = tester.getSize(workspace).height;
      await tester.drag(handle, const Offset(0, -80));
      await tester.pumpAndSettle();
      final preferredHeight = tester.getSize(panel).height;
      expect(preferredHeight, greaterThan(initialHeight));
      expect(tester.getSize(workspace).height, greaterThanOrEqualTo(320));
      expect(tester.getSize(workspace).height, lessThan(initialCanvasHeight));
      expect(
        tester.getRect(panel).overlaps(tester.getRect(workspace)),
        isFalse,
      );
      expect(tester.state(find.byType(WebEditorViewport)), same(viewportState));
      expect(find.text('125%'), findsOneWidget);

      await tester.tap(find.byTooltip('속성 패널 접기').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('속성 패널 보기'));
      await tester.pumpAndSettle();
      expect(tester.getSize(panel).height, closeTo(preferredHeight, .1));

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.getSize(workspace).height, greaterThanOrEqualTo(320));
      expect(tester.getSize(panel).height, lessThan(preferredHeight));
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(tester.getSize(panel).height, closeTo(preferredHeight, .1));

      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(handle, findsNothing);
      expect(
        find.byKey(const ValueKey('web-editor-side-properties')),
        findsOneWidget,
      );
      tester.view.physicalSize = const Size(390, 1100);
      await tester.pumpAndSettle();
      expect(tester.getSize(panel).height, closeTo(preferredHeight, .1));
      expect(tester.state(find.byType(WebEditorViewport)), same(viewportState));
      expect(find.text('125%'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'bottom properties height is named and adjustable with keyboard and semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _mount(
          tester,
          _editor(selectedLayerId: 'photo'),
          size: const Size(390, 1100),
        );
        final panel = find.byKey(
          const ValueKey('web-editor-bottom-properties'),
        );
        final handle = find.byKey(
          const ValueKey('web-editor-properties-resize-handle'),
        );
        final initialHeight = tester.getSize(panel).height;
        final data = tester.getSemantics(handle).getSemanticsData();
        expect(data.label, '속성 패널 높이 조절');
        expect(data.flagsCollection.isSlider, isTrue);
        expect(data.hasAction(SemanticsAction.increase), isTrue);
        expect(data.hasAction(SemanticsAction.decrease), isTrue);
        expect(data.value, isNotEmpty);
        await tester.tap(handle);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(tester.getSize(panel).height, closeTo(initialHeight - 32, .1));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(tester.getSize(panel).height, closeTo(initialHeight, .1));
        await tester.sendKeyEvent(LogicalKeyboardKey.end);
        await tester.pump();
        expect(tester.getSize(panel).height, closeTo(480, .1));
        await tester.sendKeyEvent(LogicalKeyboardKey.home);
        await tester.pump();
        expect(tester.getSize(panel).height, closeTo(180, .1));
        final minimumData = tester.getSemantics(handle).getSemanticsData();
        expect(minimumData.hasAction(SemanticsAction.decrease), isFalse);
        final node = tester.getSemantics(handle);
        node.owner!.performAction(node.id, SemanticsAction.increase);
        await tester.pump();
        expect(tester.getSize(panel).height, closeTo(212, .1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      } finally {
        semantics.dispose();
      }
    },
  );

  for (final configuration in [
    (size: const Size(320, 568), keyboard: 0.0),
    (size: const Size(390, 844), keyboard: 300.0),
    (size: const Size(568, 320), keyboard: 0.0),
  ]) {
    testWidgets(
      'short bottom properties resize stays reachable at $configuration',
      (tester) async {
        await _mount(
          tester,
          _editor(selectedLayerId: 'photo'),
          size: configuration.size,
          textScale: 1.8,
          keyboardInset: configuration.keyboard,
        );
        expect(
          find.byKey(const ValueKey('web-editor-compact-workspace-scroll')),
          findsOneWidget,
        );
        final panel = find.byKey(
          const ValueKey('web-editor-bottom-properties'),
        );
        final canvas = find.byKey(
          const ValueKey('web-editor-document-workspace'),
        );
        final initialCanvas = tester.getSize(canvas).height;
        final initialPanel = tester.getSize(panel).height;
        final grow = find.byTooltip('속성 패널 크게');
        await tester.ensureVisible(grow);
        await tester.pumpAndSettle();
        expect(grow.hitTestable(), findsOneWidget);
        await tester.tap(grow);
        await tester.pumpAndSettle();
        expect(tester.getSize(panel).height, closeTo(initialPanel + 32, .1));
        expect(tester.getSize(canvas).height, closeTo(initialCanvas, .1));
        final shrink = find.byTooltip('속성 패널 작게');
        expect(shrink.hitTestable(), findsOneWidget);
        await tester.tap(shrink);
        await tester.pumpAndSettle();
        expect(tester.getSize(panel).height, closeTo(initialPanel, .1));
        await tester.ensureVisible(find.text('사진과 글의 속성'));
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.text('사진과 글의 속성')).bottom,
          lessThanOrEqualTo(configuration.size.height - configuration.keyboard),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('save status distinguishes confirmed times and local scope', (
    tester,
  ) async {
    await _mount(tester, _editor());
    final status = find.descendant(
      of: find.byKey(const ValueKey('web-editor-save-status')),
      matching: find.byType(Text),
    );
    expect(tester.widget<Text>(status).data, contains('이 브라우저에서만'));
    expect(tester.widget<Text>(status).data, isNot(contains('마지막 계정 저장')));
    await _mount(
      tester,
      _editor(
        accountSavedAt: DateTime(2026, 10, 20, 14, 32),
        draftSavedAt: DateTime(2026, 10, 20, 14, 34),
      ),
    );
    final text = tester.widget<Text>(status).data!;
    expect(text, contains('마지막 계정 저장 2026.10.20 14:32'));
    expect(text, contains('브라우저 보관 2026.10.20 14:34'));
    expect(text, contains('계정에 저장하지 않은 변경사항'));
    await tester.pumpWidget(const SizedBox());
  });

  for (final selected in [false, true]) {
    testWidgets(
      'keyboard leaves artwork and inspector reachable selected=$selected',
      (tester) async {
        await _mount(
          tester,
          _editor(selectedLayerId: selected ? 'photo' : null),
          size: const Size(320, 568),
          textScale: 1.3,
          keyboardInset: 220,
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byKey(const ValueKey('fixture-canvas'))).height,
          greaterThan(40),
        );
        if (selected) {
          await tester.ensureVisible(find.text('사진과 글의 속성'));
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.text('사진과 글의 속성')).bottom,
            lessThanOrEqualTo(568 - 220),
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
