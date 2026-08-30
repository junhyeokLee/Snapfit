import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_point_confirmation_step.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('confirms point cost only before generating AI draft', (
    tester,
  ) async {
    var confirmed = false;
    var back = false;

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        AiAlbumPointConfirmationStep(
          theme: AlbumTheme.travel,
          range: AiPhotoRange.recent30Days,
          pointCost: 300,
          balance: 1200,
          onConfirm: () => confirmed = true,
          onBack: () => back = true,
        ),
      ),
    );

    expect(find.text('초안 생성'), findsOneWidget);
    expect(find.text('AI 초안을 만들어볼까요?'), findsNothing);
    expect(find.text('주제'), findsOneWidget);
    expect(find.text('여행'), findsOneWidget);
    expect(find.text('사용 포인트'), findsOneWidget);
    expect(find.text('300P'), findsOneWidget);
    expect(find.text('보유 포인트'), findsOneWidget);
    expect(find.text('1,200P'), findsOneWidget);
    expect(find.textContaining('실패하면'), findsNothing);

    await tester.scrollUntilVisible(find.text('초안 만들기'), 120);
    await tester.tap(find.text('초안 만들기'));
    await tester.pump();
    expect(confirmed, isTrue);

    await tester.scrollUntilVisible(find.text('이전'), -120);
    await tester.tap(find.text('이전'));
    await tester.pump();
    expect(back, isTrue);
  });
}
