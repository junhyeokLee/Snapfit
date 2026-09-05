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

    await tester.ensureVisible(find.text('직접 구성하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('직접 구성하기'));
    await tester.pump();
    expect(manualStart, isTrue);
  });

  testWidgets('shows permission specific recovery copy and CTA', (
    tester,
  ) async {
    var primary = false;
    var manualStart = false;

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        AiAlbumDraftFailureStep(
          title: '사진을 볼 수 없어 초안을 만들지 못했어요',
          message: 'Snapfit은 허용한 사진 안에서만 앨범 후보를 고를 수 있어요.',
          primaryActionLabel: '사진 권한 열기',
          onRetryRange: () => primary = true,
          onManualStart: () => manualStart = true,
        ),
      ),
    );

    expect(find.text('사진을 볼 수 없어 초안을 만들지 못했어요'), findsOneWidget);
    expect(find.text('사진 권한 열기'), findsOneWidget);
    expect(find.text('직접 구성하기'), findsOneWidget);
    expect(find.textContaining('기기 안에서만 확인해요'), findsOneWidget);

    await tester.tap(find.text('사진 권한 열기'));
    await tester.pump();
    expect(primary, isTrue);

    await tester.ensureVisible(find.text('직접 구성하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('직접 구성하기'));
    await tester.pump();
    expect(manualStart, isTrue);
  });

  testWidgets(
    'shows server privacy copy on failure when server draft mode is enabled',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrap(
          AiAlbumDraftFailureStep(
            message: 'AI 초안을 준비하지 못했어요.',
            usesServerDraftProvider: true,
            onRetryRange: () {},
            onManualStart: () {},
          ),
        ),
      );

      expect(find.textContaining('선택한 사진 정보가 서버로 전송됐을 수 있어요'), findsOneWidget);
      expect(find.textContaining('사진은 업로드하지 않았어요'), findsNothing);
    },
  );
}
