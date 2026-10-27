import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/store/presentation/widgets/store_detail_gallery.dart';

Widget _app(
  Widget child, {
  bool dark = false,
  double textScale = 1,
  bool reduced = false,
}) => MaterialApp(
  theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
  home: Scaffold(
    body: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduced,
        ),
        child: SingleChildScrollView(child: child),
      ),
    ),
  ),
);

void main() {
  testWidgets('gallery choices announce selection and avoid repeated work', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final changes = <int>[];
      final feedback = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          feedback.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      var selected = 0;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, update) => StoreGalleryTabs(
              labels: const ['표지', '내지'],
              selected: selected,
              onChanged: (value) {
                changes.add(value);
                update(() => selected = value);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder choice(int value) =>
          find.byKey(ValueKey('store-gallery-view-$value'));
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('store-gallery-choice-0')))
            .hasFlag(SemanticsFlag.isSelected),
        true,
      );
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('store-gallery-choice-0')))
            .hasFlag(SemanticsFlag.isInMutuallyExclusiveGroup),
        true,
      );
      await tester.tap(choice(0));
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      await tester.tap(choice(1));
      await tester.pumpAndSettle();
      expect(changes, [1]);
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('store-gallery-choice-1')))
            .hasFlag(SemanticsFlag.isSelected),
        true,
      );
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('store-gallery-choice-0')))
            .hasFlag(SemanticsFlag.isSelected),
        false,
      );
      await tester.tap(choice(1));
      await tester.pumpAndSettle();
      expect(changes, [1]);
      expect(
        feedback.where((call) => call.method == 'HapticFeedback.vibrate'),
        hasLength(1),
      );
      expect(tester.binding.hasScheduledFrame, false);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('an unavailable secondary view remains disabled and readable', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _app(
          StoreGalleryTabs(
            labels: const ['표지', '내지'],
            selected: 0,
            secondaryEnabled: false,
            onChanged: (_) => fail('Unavailable view must not open'),
          ),
        ),
      );
      final choice = find.byKey(const ValueKey('store-gallery-view-1'));
      expect(tester.widget<TextButton>(choice).onPressed, isNull);
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('store-gallery-choice-1')))
            .hasFlag(SemanticsFlag.hasEnabledState),
        true,
      );
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('store-gallery-choice-1')))
            .hasFlag(SemanticsFlag.isEnabled),
        false,
      );
      expect(find.text('내지'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'gallery controls fit narrow large text: dark=$dark scale=$scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            _app(
              Padding(
                padding: const EdgeInsets.all(18),
                child: StoreGalleryTabs(
                  labels: const ['소재', '앨범 적용 예시'],
                  selected: 1,
                  onChanged: (_) {},
                ),
              ),
              dark: dark,
              textScale: scale,
              reduced: true,
            ),
          );
          await tester.pumpAndSettle();
          for (final button in find.byType(TextButton).evaluate()) {
            final finder = find.byWidget(button.widget);
            expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
            expect(
              tester.widget<TextButton>(finder).style!.animationDuration,
              Duration.zero,
            );
          }
          for (final text in ['소재', '앨범 적용 예시']) {
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(
                of: find.text(text),
                matching: find.byType(RichText),
              ),
            );
            expect(paragraph.didExceedMaxLines, false);
          }
          expect(tester.takeException(), isNull);
          expect(tester.binding.hasScheduledFrame, false);
        },
      );
    }
  }

  testWidgets('gallery choices support keyboard activation', (tester) async {
    final changes = <int>[];
    await tester.pumpWidget(
      _app(
        StoreGalleryTabs(
          labels: const ['표지', '내지'],
          selected: 0,
          onChanged: changes.add,
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(changes, [1]);
  });

  testWidgets(
    'collapsed summaries do not mount or retain their detail artwork',
    (tester) async {
      var builds = 0;
      await tester.pumpWidget(
        _app(
          StoreDetailSection(
            title: '함께 사용한 꾸밈 소재',
            summary: '12종 · 개별 이용 범위와 가격',
            child: Builder(
              builder: (context) {
                builds++;
                return const SizedBox(
                  key: ValueKey('test-material-artwork'),
                  height: 100,
                );
              },
            ),
          ),
          reduced: true,
          textScale: 2,
        ),
      );
      final artwork = find.byKey(const ValueKey('test-material-artwork'));
      expect(find.text('12종 · 개별 이용 범위와 가격'), findsOneWidget);
      expect(builds, 0);
      expect(artwork, findsNothing);
      final tile = tester.widget<ExpansionTile>(find.byType(ExpansionTile));
      expect(tile.expansionAnimationStyle!.duration, Duration.zero);
      await tester.tap(find.text('함께 사용한 꾸밈 소재'));
      await tester.pumpAndSettle();
      expect(artwork, findsOneWidget);
      expect(builds, 1);
      await tester.tap(find.text('함께 사용한 꾸밈 소재'));
      await tester.pumpAndSettle();
      expect(artwork, findsNothing);
      expect(builds, 1);
      expect(tester.binding.hasScheduledFrame, false);
      expect(tester.takeException(), isNull);
    },
  );
}
