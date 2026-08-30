import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_start_step.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('separates manual creation from AI-only theme selection', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var aiTapped = false;
    var manualTapped = false;

    await tester.pumpWidget(
      _wrap(
        AiAlbumStartStep(
          aiPointCost: 300,
          onAiStart: () => aiTapped = true,
          onManualStart: () => manualTapped = true,
        ),
      ),
    );

    expect(find.text('작은 책으로 남길 순간을 골라볼까요?'), findsOneWidget);
    expect(find.text('직접 구성하기'), findsOneWidget);
    expect(find.text('AI 초안으로 시작하기'), findsOneWidget);
    expect(find.text('AI 초안 만들기 300P'), findsNothing);
    expect(find.textContaining('포인트'), findsNothing);
    expect(find.textContaining('300P'), findsNothing);

    expect(find.text('어떤 앨범을 만들까요?'), findsNothing);
    expect(find.text('여행'), findsNothing);
    expect(find.text('커플'), findsNothing);
    expect(find.text('가족'), findsNothing);

    await tester.scrollUntilVisible(find.text('AI 초안 만들기'), 120);
    await tester.tap(find.text('AI 초안 만들기'));
    await tester.pump();
    expect(aiTapped, isTrue);

    await tester.scrollUntilVisible(find.text('직접 만들기'), -120);
    await tester.tap(find.text('직접 만들기'));
    await tester.pump();
    expect(manualTapped, isTrue);
  });
}
