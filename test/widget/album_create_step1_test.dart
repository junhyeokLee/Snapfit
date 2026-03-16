import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('next button enabled only when title is provided', (tester) async {
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
}
