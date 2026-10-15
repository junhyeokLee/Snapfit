import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_bottom_navigation_bar.dart';
import 'package:snap_fit/shared/widgets/experience_icon.dart';
import 'package:snap_fit/shared/widgets/experience_style.dart';
import 'package:snap_fit/shared/widgets/experience_form_style.dart';

void main() {
  for (final rail in [false, true]) {
    for (final currentIndex in [0, 2, 5]) {
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
            ['House', 'Layers2', 'Bookmark', 'UserRound'],
          );
          expect(find.text('홈'), findsOneWidget);
          final icons = tester
              .widgetList<ExperienceIcon>(find.byType(ExperienceIcon))
              .toList();
          expect(
            icons[currentIndex == 0 ? 0 : 1].color,
            ExperienceFormStyle.selectionInk(
              tester.element(find.byType(HomeBottomNavigationBar)),
            ),
          );
          expect(
            tester
                .widgetList<Material>(find.byType(Material))
                .any((m) => m.color == Colors.white),
            isTrue,
          );
          await tester.tap(find.text('홈'));
          expect(selected, 0);
          expect(find.text('알림'), findsNothing);
          await tester.tap(find.text('마이'));
          expect(selected, 4);
          expect(find.text('소재'), findsNothing);
          await tester.tap(find.text('스토어'));
          expect(selected, 2);
          await tester.tap(find.text('보관함'));
          expect(selected, 6);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
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
