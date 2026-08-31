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
    expect(find.text('분위기'), findsOneWidget);
    expect(find.text('어떤 앨범으로 정리해볼까요?'), findsNothing);
    expect(find.textContaining('선택한 주제는'), findsNothing);
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

    await tester.tap(find.text('이전'));
    await tester.pump();
    expect(backTapped, isTrue);
  });
}
