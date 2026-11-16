import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_category_rail.dart';

const _top = ['전체', '추천', '인기', '웨딩', '커플', '가족·친구'];
const _bottom = ['일상', '여행', '동아리', '성장·육아', '반려동물', '졸업·학교'];

Finder _chip(String label) => find.byKey(ValueKey('creation-category-$label'));

Finder get _rail => find.byKey(const ValueKey('creation-category-rail'));

Widget _app(
  Widget child, {
  double width = 390,
  bool dark = false,
  double scale = 1,
}) => MaterialApp(
  theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
  // Desktop normally supplies an automatic scrollbar. The rail must opt out.
  scrollBehavior: const MaterialScrollBehavior().copyWith(
    platform: TargetPlatform.linux,
  ),
  home: Scaffold(
    body: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  ),
);

Widget _categoryRail({
  String selected = '전체',
  ValueChanged<String>? onSelected,
}) => CreationCategoryRail(
  topCategories: _top,
  bottomCategories: _bottom,
  selected: selected,
  onSelected: onSelected ?? (_) {},
);

void _expectVisible(WidgetTester tester, Finder target) {
  final viewport = tester.getRect(_rail);
  final chip = tester.getRect(target);
  expect(chip.left, greaterThanOrEqualTo(viewport.left - 1));
  expect(chip.right, lessThanOrEqualTo(viewport.right + 1));
}

void main() {
  testWidgets('preserves both row orders and moves the rows together', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_categoryRail()));
    await tester.pumpAndSettle();

    final topY = tester.getTopLeft(_chip('전체')).dy;
    final bottomY = tester.getTopLeft(_chip('일상')).dy;
    expect(bottomY, greaterThan(topY));
    for (final row in [_top, _bottom]) {
      var previousX = double.negativeInfinity;
      for (final label in row) {
        final position = tester.getTopLeft(_chip(label));
        expect(position.dy, row == _top ? topY : bottomY);
        expect(position.dx, greaterThan(previousX));
        previousX = position.dx;
      }
    }

    final beforeTop = tester.getTopLeft(_chip('전체')).dx;
    final beforeBottom = tester.getTopLeft(_chip('일상')).dx;
    await tester.drag(_rail, const Offset(-170, 0));
    await tester.pumpAndSettle();
    final topDelta = tester.getTopLeft(_chip('전체')).dx - beforeTop;
    final bottomDelta = tester.getTopLeft(_chip('일상')).dx - beforeBottom;
    expect(topDelta, lessThan(0));
    expect(bottomDelta, closeTo(topDelta, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'every label is reachable and selection stays mutually exclusive',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        var selected = '전체';
        await tester.pumpWidget(
          _app(
            StatefulBuilder(
              builder: (context, setState) => _categoryRail(
                selected: selected,
                onSelected: (value) => setState(() => selected = value),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final label in [..._top, ..._bottom]) {
          await tester.ensureVisible(_chip(label));
          await tester.pumpAndSettle();
          _expectVisible(tester, _chip(label));
          await tester.tap(_chip(label));
          await tester.pumpAndSettle();
          expect(selected, label);
          final selectedNode = tester.getSemantics(_chip(label));
          expect(selectedNode.hasFlag(SemanticsFlag.isSelected), isTrue);
          expect(
            selectedNode.hasFlag(SemanticsFlag.isInMutuallyExclusiveGroup),
            isTrue,
          );
          expect(
            tester
                .widgetList<Semantics>(
                  find.descendant(of: _rail, matching: find.byType(Semantics)),
                )
                .where((node) => node.properties.selected == true),
            hasLength(1),
          );
        }
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'external selection reveals an offscreen category after rebuild',
    (tester) async {
      var selected = '전체';
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return _categoryRail(selected: selected);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(_chip('졸업·학교')).left,
        greaterThan(tester.getRect(_rail).right),
      );

      update(() => selected = '졸업·학교');
      await tester.pumpAndSettle();
      _expectVisible(tester, _chip('졸업·학교'));
      update(() => selected = '전체');
      await tester.pumpAndSettle();
      _expectVisible(tester, _chip('전체'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'desktop scrolling has no scrollbar and supports mouse dragging',
    (tester) async {
      await tester.pumpWidget(_app(_categoryRail()));
      await tester.pumpAndSettle();
      expect(find.byType(Scrollbar), findsNothing);
      expect(find.byType(RawScrollbar), findsNothing);
      final before = tester.getTopLeft(_chip('전체')).dx;
      await tester.drag(
        _rail,
        const Offset(-150, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(_chip('전체')).dx, lessThan(before));
      expect(find.byType(Scrollbar), findsNothing);
      expect(find.byType(RawScrollbar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 390.0]) {
    for (final dark in [false, true]) {
      testWidgets('fits $width px with 200% text, dark=$dark', (tester) async {
        await tester.pumpWidget(
          _app(_categoryRail(), width: width, dark: dark, scale: 2),
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(_rail).width, width);
        for (final label in [..._top, ..._bottom]) {
          final size = tester.getSize(_chip(label));
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
          await tester.ensureVisible(_chip(label));
          await tester.pumpAndSettle();
          _expectVisible(tester, _chip(label));
        }
        expect(find.byType(Scrollbar), findsNothing);
        expect(find.byType(RawScrollbar), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
