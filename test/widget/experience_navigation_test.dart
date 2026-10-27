import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_bottom_navigation_bar.dart';
import 'package:snap_fit/shared/widgets/experience_icon.dart';
import 'package:snap_fit/shared/widgets/experience_style.dart';
import 'package:snap_fit/core/constants/snapfit_colors.dart';

void main() {
  for (final rail in [false, true]) {
    for (final currentIndex in [0, 1, 2, 4, 5, 6, 7]) {
      testWidgets(
        'experience navigation has icons and keeps every destination: rail=$rail index=$currentIndex',
        (tester) async {
          var selected = -1;
          await tester.pumpWidget(
            ScreenUtilInit(
              designSize: const Size(390, 844),
              builder: (_, __) => MaterialApp(
                home: Scaffold(
                  body: HomeBottomNavigationBar(
                    currentIndex: currentIndex,
                    rail: rail,
                    onTap: (i) => selected = i,
                  ),
                ),
              ),
            ),
          );
          expect(
            tester
                .widgetList<ExperienceIcon>(find.byType(ExperienceIcon))
                .map((i) => i.name),
            ['BookOpen', 'Compass', 'Layers2', 'Bookmark', 'UserRound'],
          );
          expect(find.text('내 앨범'), rail ? findsOneWidget : findsNothing);
          for (final label in ['내 앨범', '피드', '스토어', '내 디자인', '마이']) {
            expect(find.byTooltip(label), findsOneWidget);
            if (!rail) expect(find.text(label), findsNothing);
            final target = tester.getSize(find.byTooltip(label));
            expect(target.width, greaterThanOrEqualTo(44));
            expect(target.height, greaterThanOrEqualTo(44));
          }
          final icons = tester
              .widgetList<ExperienceIcon>(find.byType(ExperienceIcon))
              .toList();
          expect(
            icons[switch (currentIndex) {
                  0 || 1 => 0,
                  7 => 1,
                  2 || 5 => 2,
                  6 => 3,
                  _ => 4,
                }]
                .color,
            SnapFitColors.onAccent,
          );
          final navigation = tester.element(
            find.byType(HomeBottomNavigationBar),
          );
          expect(
            tester
                .widget<Material>(
                  find.byKey(const ValueKey('home-navigation-surface')),
                )
                .color,
            currentIndex == 0 || currentIndex == 1
                ? SnapFitColors.backgroundOf(navigation).withValues(alpha: .86)
                : SnapFitColors.backgroundOf(navigation),
          );
          expect(
            tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
            currentIndex == 0 || currentIndex == 1,
          );
          final selectedDestination = currentIndex == 1
              ? 0
              : currentIndex == 5
              ? 2
              : currentIndex;
          for (final (index, label) in const [
            (0, '내 앨범'),
            (7, '피드'),
            (2, '스토어'),
            (6, '내 디자인'),
            (4, '마이'),
          ]) {
            final semantics = tester
                .widget<Semantics>(
                  find.byKey(ValueKey('home-navigation-destination-$index')),
                )
                .properties;
            expect(semantics.label, label);
            expect(semantics.button, isTrue);
            expect(semantics.selected, index == selectedDestination);
          }
          expect(
            tester
                .widget<AnimatedContainer>(
                  find.byKey(
                    ValueKey('home-navigation-indicator-$selectedDestination'),
                  ),
                )
                .decoration,
            isA<BoxDecoration>().having(
              (decoration) => decoration.color,
              'selected background',
              SnapFitColors.actionAccent,
            ),
          );
          await tester.tap(find.byTooltip('내 앨범'));
          expect(selected, 0);
          await tester.tap(find.byTooltip('피드'));
          expect(selected, 7);
          expect(find.text('알림'), findsNothing);
          await tester.tap(find.byTooltip('마이'));
          expect(selected, 4);
          expect(find.text('소재'), findsNothing);
          await tester.tap(find.byTooltip('스토어'));
          expect(selected, 2);
          await tester.tap(find.byTooltip('내 디자인'));
          expect(selected, 6);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'icon-only bottom navigation stays compact with large text on a narrow phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var selected = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 568),
                textScaler: TextScaler.linear(2.4),
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: HomeBottomNavigationBar(
                  currentIndex: 7,
                  onTap: (index) => selected = index,
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(HomeBottomNavigationBar),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      expect(tester.getSize(find.byType(HomeBottomNavigationBar)).height, 68);
      for (final label in ['내 앨범', '피드', '스토어', '내 디자인', '마이']) {
        final rect = tester.getRect(find.byTooltip(label));
        expect(rect.width, greaterThanOrEqualTo(44));
        expect(rect.height, greaterThanOrEqualTo(44));
        expect(rect.right, lessThanOrEqualTo(320));
      }
      await tester.tap(find.byTooltip('피드'));
      expect(selected, 7);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('header uses a 60px toolbar, back and the original bell', (
    tester,
  ) async {
    var destination = -1;
    var back = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ExperienceNavigationScope(
          onNavigate: (i) => destination = i,
          onBack: () => back = true,
          child: const Scaffold(appBar: ExperienceHeader(title: '마이')),
        ),
      ),
    );
    expect(
      tester
          .widget<ExperienceHeader>(find.byType(ExperienceHeader))
          .preferredSize
          .height,
      60,
    );
    await tester.tap(find.byTooltip('알림'));
    expect(destination, 3);
    await tester.tap(find.byTooltip('뒤로가기'));
    expect(back, true);
    expect(
      tester
          .widgetList<ExperienceIcon>(find.byType(ExperienceIcon))
          .map((i) => i.name),
      ['ArrowLeft', 'Bell'],
    );
  });
}
