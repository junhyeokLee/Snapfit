import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_draft_failure_step.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('shows no-charge recovery actions when AI draft fails', (
    tester,
  ) async {
    var retryRange = false;
    var manualStart = false;

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        AiAlbumDraftFailureStep(
          message: 'AI 초안을 만들려면 사진이 조금 더 필요해요.',
          onRetryRange: () => retryRange = true,
          onManualStart: () => manualStart = true,
        ),
      ),
    );

    expect(find.text('초안을 만들지 못했어요'), findsOneWidget);
    expect(find.text('AI 초안을 만들려면 사진이 조금 더 필요해요.'), findsOneWidget);
    expect(find.text('포인트는 차감되지 않았어요.'), findsOneWidget);
    expect(find.textContaining('기기 안에서만 확인해요'), findsOneWidget);
    expect(find.text('사진 범위 다시 고르기'), findsOneWidget);
    expect(find.text('직접 구성하기'), findsOneWidget);
    expect(find.textContaining('300P'), findsNothing);

    await tester.tap(find.text('사진 범위 다시 고르기'));
    await tester.pump();
    expect(retryRange, isTrue);

    await tester.tap(find.text('직접 구성하기'));
    await tester.pump();
    expect(manualStart, isTrue);
  });
}
