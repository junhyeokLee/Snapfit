import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';

Future<void> _loadGoldenFonts() async {
  final robotoLoader = FontLoader('Roboto')
    ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/NotoSansKR-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Bold.ttf'));
  await robotoLoader.load();
}

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('next button enabled only when title is provided', (
    tester,
  ) async {
    String title = '';
    final selectedCover = coverSizes.first;

    await tester.pumpWidget(
      _wrap(
        AlbumCreateStep1(
          albumTitle: title,
          selectedCover: selectedCover,
          selectedPageCount: 10,
          onTitleChanged: (value) => title = value,
          onCoverSelected: (_) {},
          onPageCountChanged: (_) {},
          onNext: () {},
        ),
      ),
    );

    final buttonFinder = find.byType(ElevatedButton);
    final button = tester.widget<ElevatedButton>(buttonFinder);
    expect(button.onPressed, isNull);

    await tester.enterText(find.byType(TextField), '테스트 앨범');
    await tester.pump();

    final enabledButton = tester.widget<ElevatedButton>(buttonFinder);
    expect(enabledButton.onPressed, isNotNull);
  });

  testWidgets('renders book atelier creation step without losing controls', (
    tester,
  ) async {
    var selectedCover = coverSizes.firstWhere((s) => s.name == '정사각형');
    var pageCount = 24;

    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return AlbumCreateStep1(
              albumTitle: '제주 여름 기록',
              templateTitle: '제주 가족 여행 룩북',
              selectedCover: selectedCover,
              selectedPageCount: pageCount,
              minPageCount: 12,
              onTitleChanged: (_) {},
              onCoverSelected: (cover) => setState(() => selectedCover = cover),
              onPageCountChanged: (count) => setState(() => pageCount = count),
              onNext: () {},
            );
          },
        ),
      ),
    );

    expect(find.text('1 / 3'), findsNothing);
    expect(find.text('앨범 기본 정보'), findsNothing);
    expect(find.text('제목, 책 비율, 분량만 정해요.'), findsNothing);
    expect(find.byKey(const Key('albumCreateStepHero')), findsOneWidget);
    expect(find.text('새 앨범'), findsOneWidget);
    expect(find.text('표지와 분량을 먼저 정해요.'), findsOneWidget);
    expect(find.text('표지'), findsOneWidget);
    expect(find.text('제주 가족 여행 룩북'), findsOneWidget);
    expect(find.text('앨범 제목'), findsOneWidget);
    expect(find.text('책 비율'), findsOneWidget);
    expect(find.text('분량'), findsOneWidget);
    expect(find.text('가로형'), findsOneWidget);
    expect(find.text('정사각형'), findsOneWidget);
    expect(find.text('세로형'), findsOneWidget);
    expect(find.text('24쪽'), findsWidgets);
    expect(find.text('다음'), findsOneWidget);
    expect(find.text('표지 확인하기'), findsNothing);

    expect(find.textContaining('추천'), findsNothing);
    expect(find.textContaining('가볍게 시작'), findsNothing);
    expect(find.textContaining('넉넉하게'), findsNothing);
    expect(find.text('CREATION COCKPIT'), findsNothing);
    expect(find.text('3분 완성 루트'), findsNothing);
    expect(find.text('AI 추천 구성'), findsNothing);
    expect(find.text('기능 유지'), findsNothing);
    expect(find.text('표지 먼저 확인하기'), findsNothing);
  });

  testWidgets('matches book atelier creation golden', (tester) async {
    await _loadGoldenFonts();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        AlbumCreateStep1(
          albumTitle: '제주 여름 기록',
          templateTitle: '제주 가족 여행 룩북',
          selectedCover: coverSizes.firstWhere((s) => s.name == '정사각형'),
          selectedPageCount: 24,
          minPageCount: 12,
          onTitleChanged: (_) {},
          onCoverSelected: (_) {},
          onPageCountChanged: (_) {},
          onNext: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AlbumCreateStep1),
      matchesGoldenFile('goldens/album_create_cockpit_390x844.png'),
    );
  });
}
