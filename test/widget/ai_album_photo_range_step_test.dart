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
  testWidgets('uses AI-specific range choices without tutorial copy', (
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

    expect(find.text('사진 범위'), findsOneWidget);
    expect(find.text('어디까지 살펴볼까요?'), findsNothing);
    expect(find.text('원본 사진은 서버로 보내지 않고, 기기 안에서만 살펴봐요.'), findsOneWidget);
    expect(find.text('최근 30일'), findsOneWidget);
    expect(find.text('날짜 선택'), findsOneWidget);
    expect(find.text('앨범 선택'), findsOneWidget);
    expect(find.text('직접 고르기'), findsOneWidget);
    expect(find.textContaining('전체 사진첩이 부담스럽다면'), findsNothing);

    await tester.scrollUntilVisible(find.text('최근 30일'), 120);
    await tester.tap(find.text('최근 30일'));
    await tester.pump();

    expect(selectedRange, AiPhotoRange.recent30Days);
  });

  testWidgets('shows server privacy copy when server draft mode is enabled', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        AiAlbumPhotoRangeStep(
          theme: AlbumTheme.travel,
          usesServerDraftProvider: true,
          onRangeSelected: (_) {},
          onBack: () {},
        ),
      ),
    );

    expect(
      find.textContaining('선택한 사진의 날짜·크기 같은 정보가 서버로 전송돼요'),
      findsOneWidget,
    );
    expect(find.textContaining('원본 사진은 서버로 보내지 않고'), findsNothing);
  });

  testWidgets('shows advanced server preview copy when enabled', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        AiAlbumPhotoRangeStep(
          theme: AlbumTheme.travel,
          usesServerDraftProvider: true,
          usesAdvancedServerAnalysis: true,
          onRangeSelected: (_) {},
          onBack: () {},
        ),
      ),
    );

    expect(find.textContaining('작은 미리보기 이미지를 서버에서 살펴봐요'), findsOneWidget);
    expect(find.textContaining('날짜·크기 같은 정보'), findsNothing);
  });
}
