import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_start_step.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('shows AI and manual album start options with theme cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    AlbumTheme? selectedTheme;
    var manualTapped = false;

    await tester.pumpWidget(
      _wrap(
        AiAlbumStartStep(
          onThemeSelected: (theme) => selectedTheme = theme,
          onManualStart: () => manualTapped = true,
        ),
      ),
    );

    expect(find.text('새 앨범 만들기'), findsOneWidget);
    expect(find.text('AI가 먼저 골라주는 앨범'), findsOneWidget);
    expect(find.text('직접 구성하기'), findsOneWidget);
    expect(find.text('어떤 앨범을 만들까요?'), findsOneWidget);
    expect(find.text('여행'), findsOneWidget);
    expect(find.text('커플'), findsOneWidget);
    expect(find.text('가족'), findsOneWidget);
    expect(find.text('아기'), findsOneWidget);
    expect(find.text('생일'), findsOneWidget);
    expect(find.text('일상'), findsOneWidget);
    expect(find.text('직접입력'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('여행'), 120);
    await tester.tap(find.text('여행'));
    await tester.pump();
    expect(selectedTheme, AlbumTheme.travel);

    await tester.scrollUntilVisible(find.text('직접 만들기'), -80);
    await tester.tap(find.text('직접 만들기'));
    await tester.pump();
    expect(manualTapped, isTrue);
  });
}
