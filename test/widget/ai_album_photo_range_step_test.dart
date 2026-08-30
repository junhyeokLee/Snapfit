import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_photo_range_step.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('explains permission and returns selected photo range', (
    tester,
  ) async {
    AiPhotoRange? selectedRange;

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        AiAlbumPhotoRangeStep(
          theme: AlbumTheme.travel,
          onRangeSelected: (range) => selectedRange = range,
          onBack: () {},
        ),
      ),
    );

    expect(find.text('어디까지 살펴볼까요?'), findsOneWidget);
    expect(find.text('허용한 사진 안에서만 초안을 준비해요.'), findsOneWidget);
    expect(find.text('최근 30일'), findsOneWidget);
    expect(find.text('날짜 선택'), findsOneWidget);
    expect(find.text('앨범 선택'), findsOneWidget);
    expect(find.text('직접 고르기'), findsOneWidget);
    expect(find.text('전체 사진첩이 부담스럽다면 일부 사진만 선택할 수 있어요.'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('최근 30일'), 120);
    await tester.tap(find.text('최근 30일'));
    await tester.pump();

    expect(selectedRange, AiPhotoRange.recent30Days);
  });
}
