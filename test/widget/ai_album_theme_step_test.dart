import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_theme_step.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('shows theme hints only inside AI creation flow', (tester) async {
    AlbumTheme? selectedTheme;
    var backTapped = false;

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        AiAlbumThemeStep(
          onThemeSelected: (theme) => selectedTheme = theme,
          onBack: () => backTapped = true,
        ),
      ),
    );

    expect(find.text('AI 초안'), findsOneWidget);
    expect(find.text('어떤 앨범으로 정리해볼까요?'), findsOneWidget);
    expect(find.text('선택한 주제는 AI가 사진 흐름과 제목을 제안할 때만 참고해요.'), findsOneWidget);
    expect(find.text('여행'), findsOneWidget);
    expect(find.text('가족'), findsOneWidget);
    expect(find.text('직접 입력'), findsOneWidget);
    expect(find.text('AI 초안 만들기 300P'), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('ai_theme_travel')),
      80,
    );
    await tester.tap(find.byKey(const Key('ai_theme_travel')));
    await tester.pump();
    expect(selectedTheme, AlbumTheme.travel);

    await tester.scrollUntilVisible(find.text('시작 방식 다시 고르기'), -120);
    await tester.tap(find.text('시작 방식 다시 고르기'));
    await tester.pump();
    expect(backTapped, isTrue);
  });
}
