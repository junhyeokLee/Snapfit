import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_generating_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_draft_failure_step.dart';

Widget _wrap(Widget child, {bool reduced = false, double scale = 1}) =>
    ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (_, __) => MaterialApp(
        builder: (context, content) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduced,
          ),
          child: content!,
        ),
        home: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets(
    'waiting never presents timed model stages or a fake percentage',
    (tester) async {
      await tester.pumpWidget(_wrap(const AiTemplateGeneratingStep()));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 3));
        expect(find.text('AI 디자인 요청 중'), findsNWidgets(2));
        expect(find.textContaining('팔레트'), findsNothing);
        expect(find.textContaining('서체와'), findsNothing);
        expect(find.textContaining('다듬어 완성'), findsNothing);
        expect(find.textContaining('%'), findsNothing);
      }
      expect(find.textContaining('요청만으로 포인트를 차감하지 않아요'), findsOneWidget);
      await tester.pump(const Duration(seconds: 16));
      expect(find.text('응답이 늦어지고 있어요'), findsOneWidget);
      expect(find.textContaining('새 요청을 보내지 않고'), findsOneWidget);
      final status = tester.widget<Semantics>(
        find.byKey(const ValueKey('ai-generation-status')),
      );
      expect(status.properties.liveRegion, isTrue);
      expect(find.byType(FilledButton), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'request owner timestamp preserves the wait notice after remount',
    (tester) async {
      final started = DateTime.now().subtract(const Duration(seconds: 35));
      await tester.pumpWidget(
        _wrap(AiTemplateGeneratingStep(requestStartedAt: started)),
      );
      expect(find.text('응답이 늦어지고 있어요'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _wrap(AiTemplateGeneratingStep(requestStartedAt: started)),
      );
      expect(find.text('응답이 늦어지고 있어요'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final size in [const Size(320, 568), const Size(648, 320)]) {
    testWidgets('reduced motion and large waiting text remain readable $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _wrap(
          AiTemplateGeneratingStep(
            requestStartedAt: DateTime.now().subtract(
              const Duration(seconds: 35),
            ),
            innerPageCount: 24,
          ),
          reduced: true,
          scale: 2.4,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      await tester.ensureVisible(
        find.byKey(const ValueKey('ai-generation-wait-detail')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('ai-generation-wait-detail')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'unconfirmed point result is honest and recoverable at large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(648, 320));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var retries = 0;
      await tester.pumpWidget(
        _wrap(
          AiAlbumDraftFailureStep(
            title: '포인트 처리 결과를 확인하지 못했어요',
            message: '같은 디자인으로 처리 결과를 다시 확인해 주세요.',
            primaryActionLabel: '같은 디자인으로 다시 확인',
            requestSummary: '제주 바다 사진집\n내지 20쪽',
            pointUsageUnconfirmed: true,
            showManualStart: false,
            isTemplateDesign: true,
            onRetryRange: () => retries++,
            onManualStart: () =>
                fail('A pending point operation must not start another design'),
          ),
          reduced: true,
          scale: 2.4,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('포인트는 차감되지 않았어요.'), findsNothing);
      expect(find.text('직접 구성하기'), findsNothing);
      final primary = find.byKey(const ValueKey('ai-failure-primary'));
      await tester.ensureVisible(primary);
      await tester.pumpAndSettle();
      expect(primary.hitTestable(), findsOneWidget);
      await tester.tap(primary);
      expect(retries, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
