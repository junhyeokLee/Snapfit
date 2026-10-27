import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/store/presentation/widgets/store_topic_shelf.dart';

void main() {
  for (final direction in TextDirection.values) {
    for (final scale in [1.0, 2.5]) {
      testWidgets(
        'category reveal stays local, bounded and disposable: $direction scale=$scale',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final outer = ScrollController();
          addTearDown(outer.dispose);
          var categories = [
            '전체',
            '추천',
            '일상',
            '여행',
            '가족·친구',
            '동아리',
            '스포츠·도전',
            '커플·기념일',
            '성장·육아',
            '웨딩',
          ];
          var selected = '전체';
          var active = true;
          var width = 320.0;
          var textScale = scale;
          var shelfDirection = direction;
          late StateSetter change;
          await tester.pumpWidget(
            MaterialApp(
              theme: scale == 1 ? SnapFitTheme.light() : SnapFitTheme.dark(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: Directionality(textDirection: direction, child: child!),
              ),
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    change = setState;
                    return TickerMode(
                      enabled: active,
                      child: SingleChildScrollView(
                        controller: outer,
                        child: Column(
                          children: [
                            const SizedBox(height: 320),
                            SizedBox(
                              width: width,
                              child: MediaQuery(
                                data: MediaQuery.of(context).copyWith(
                                  textScaler: TextScaler.linear(textScale),
                                ),
                                child: Directionality(
                                  textDirection: shelfDirection,
                                  child: StoreTopicShelf(
                                    categories: categories,
                                    templates: const [],
                                    selected: selected,
                                    onSelect: (category) =>
                                        change(() => selected = category),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 1600),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final shelf = find.byKey(const ValueKey('store-topic-filters'));
          final horizontal = tester
              .widget<SingleChildScrollView>(shelf)
              .controller!;
          void expectSelectionVisible() {
            final viewport = tester.getRect(shelf);
            final chip = tester.getRect(
              find.byKey(ValueKey('store-topic-$selected')),
            );
            expect(chip.left, greaterThanOrEqualTo(viewport.left - .5));
            expect(chip.right, lessThanOrEqualTo(viewport.right + .5));
          }

          outer.jumpTo(200);
          await tester.pumpAndSettle();
          final outerOffset = outer.offset;
          expectSelectionVisible();
          if (scale == 1) {
            final offset = horizontal.offset;
            change(() => selected = '추천');
            await tester.pumpAndSettle();
            expectSelectionVisible();
            expect(
              horizontal.offset,
              offset,
              reason: 'Visible chips should not move',
            );
          }
          change(() => selected = '웨딩');
          await tester.pumpAndSettle();
          expectSelectionVisible();
          expect(outer.offset, outerOffset);
          expect(horizontal.offset, greaterThan(0));
          change(() => selected = '전체');
          change(() => selected = '동아리');
          change(() => selected = '전체');
          await tester.pumpAndSettle();
          expectSelectionVisible();
          expect(outer.offset, outerOffset);

          // Merely hiding/resuming the shelf must not undo manual browsing.
          horizontal.jumpTo(horizontal.position.maxScrollExtent);
          await tester.pumpAndSettle();
          final manualOffset = horizontal.offset;
          for (var visit = 0; visit < 3; visit++) {
            change(() => active = false);
            await tester.pumpAndSettle();
            change(() => active = true);
            await tester.pumpAndSettle();
            expect(horizontal.offset, manualOffset);
            expect(outer.offset, outerOffset);
          }

          change(() => selected = '추천');
          await tester.pumpAndSettle();
          expectSelectionVisible();
          change(() => active = false);
          await tester.pumpAndSettle();
          final hiddenOffset = horizontal.offset;
          change(() => selected = '웨딩');
          await tester.pumpAndSettle();
          expect(horizontal.offset, hiddenOffset);
          change(() => active = true);
          await tester.pumpAndSettle();
          expectSelectionVisible();
          expect(outer.offset, outerOffset);
          change(() => width = 260);
          await tester.pumpAndSettle();
          expectSelectionVisible();
          expect(outer.offset, outerOffset);
          change(() {
            textScale = scale == 1 ? 2.5 : 1;
            shelfDirection = direction == TextDirection.ltr
                ? TextDirection.rtl
                : TextDirection.ltr;
          });
          await tester.pumpAndSettle();
          expectSelectionVisible();
          expect(outer.offset, outerOffset);
          change(() => active = false);
          await tester.pumpAndSettle();
          final beforeHiddenResize = horizontal.offset;
          change(() {
            width = 300;
            textScale = scale;
          });
          await tester.pumpAndSettle();
          // Layout can clamp an offset, but hidden work must not reveal a chip.
          expect(
            horizontal.offset,
            closeTo(
              beforeHiddenResize.clamp(
                horizontal.position.minScrollExtent,
                horizontal.position.maxScrollExtent,
              ),
              .5,
            ),
          );
          change(() => active = true);
          await tester.pumpAndSettle();
          expectSelectionVisible();
          expect(outer.offset, outerOffset);
          change(() {
            categories = ['전체', '추천'];
            selected = '전체';
          });
          await tester.pumpAndSettle();
          expectSelectionVisible();
          expect(find.byType(ChoiceChip), findsNWidgets(2));
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          expect(horizontal.hasClients, isFalse);
          expect(tester.binding.transientCallbackCount, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
