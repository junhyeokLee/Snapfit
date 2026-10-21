import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_template_paper_tone.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_recommendation_review_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_design_review.dart';
import '../fixtures/ai_template_local_edit_fixture.dart';

void main() {
  setUpAll(() async {
    // Browser runs verify structure and interaction; native runs retain the
    // actual bundled-font measurements without waiting on browser FontLoader.
    if (kIsWeb) return;
    await (FontLoader(
      'NotoSans',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))).load();
  });

  testWidgets(
    'paper and actual text edits reach acceptance with the same draft ID',
    (tester) async {
      final original = localEditDesign();
      var draft = localEditDraft(original);
      AlbumRecommendationDraft? accepted;
      await tester.pumpWidget(
        _screen(
          StatefulBuilder(
            builder: (context, setState) => AiAlbumRecommendationReviewStep(
              draft: draft,
              originalDesign: original,
              onDraftChanged: (value) => setState(() => draft = value),
              onAcceptDraft: (value) => accepted = value,
              onBack: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('종이 톤 조절'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ai-paper-tone-warm')));
      await tester.pumpAndSettle();
      final warm = draft.design!.pages.first.background;
      expect(warm, isNot(original.pages.first.background));
      await tester.tap(find.byTooltip('문구 수정'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('ai-text-edit-input')),
        '새로운 오후',
      );
      await tester.tap(find.byKey(const ValueKey('ai-text-apply')));
      await tester.pumpAndSettle();
      expect(draft.design!.pages.first.elements.last.text, '새로운 오후');
      expect(draft.design!.pages.first.background, warm);
      await tester.tap(find.text('이 디자인 사용'));
      await tester.pumpAndSettle();
      expect(accepted!.draftId, 'existing-active-draft');
      expect(accepted!.design!.pages.first.elements.last.text, '새로운 오후');
      expect(
        accepted!.design!.pages.first.elements.last.rect,
        original.pages.first.elements.last.rect,
      );
      expect(accepted!.design!.pages.first.background, warm);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'text overflow stays open and cancel preserves the actual result',
    (tester) async {
      final original = localEditDesign();
      var changes = 0;
      await tester.pumpWidget(
        _screen(
          AiTemplateDesignReview(
            design: original,
            originalDesign: original,
            onBack: () {},
            onAccept: () {},
            onDesignChanged: (_) => changes++,
            isAccepting: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('문구 수정'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('ai-text-edit-input')),
        List.filled(80, '기억').join(' '),
      );
      await tester.tap(find.byKey(const ValueKey('ai-text-apply')));
      await tester.pumpAndSettle();
      expect(find.textContaining('더 짧게 다듬어'), findsOneWidget);
      expect(changes, 0);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ai-text-edit-input')), findsNothing);
      expect(original.pages.first.elements.last.text, '함께한 오후');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'prior result is comparison only and accepting waits for current result',
    (tester) async {
      final original = localEditDesign();
      final current = withAiTemplatePaperTone(
        original,
        AiTemplatePaperTone.warm,
      );
      var accepts = 0;
      await tester.pumpWidget(
        _screen(
          AiTemplateDesignReview(
            design: current,
            previousDesign: original,
            onBack: () {},
            onAccept: () => accepts++,
            onDesignChanged: (_) {},
            isAccepting: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ai-design-compare')));
      await tester.pumpAndSettle();
      expect(find.text('이전 결과 · 비교 전용'), findsOneWidget);
      expect(find.text('이 디자인 사용'), findsNothing);
      expect(find.byTooltip('종이 톤 조절'), findsNothing);
      expect(find.byTooltip('문구 수정'), findsNothing);
      await tester.tap(find.text('현재 결과로 돌아가기'));
      await tester.pumpAndSettle();
      expect(accepts, 0);
      await tester.tap(find.text('이 디자인 사용'));
      expect(accepts, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('busy review disables edits, request changes and comparison', (
    tester,
  ) async {
    final design = localEditDesign();
    await tester.pumpWidget(
      _screen(
        AiTemplateDesignReview(
          design: design,
          previousDesign: design,
          onBack: () => throw StateError('busy'),
          onAccept: () => throw StateError('busy'),
          onDesignChanged: (_) => throw StateError('busy'),
          isAccepting: true,
        ),
      ),
    );
    await tester.pump();
    for (final label in ['종이 톤 조절', '문구 수정', '디자인 요청 수정']) {
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(
                IconButton,
                label == '종이 톤 조절'
                    ? Icons.palette_outlined
                    : label == '문구 수정'
                    ? Icons.edit_note_rounded
                    : Icons.edit_outlined,
              ),
            )
            .onPressed,
        isNull,
      );
    }
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('ai-design-compare')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disposing a review closes only its own text dialog', (
    tester,
  ) async {
    final design = localEditDesign();
    var showReview = true;
    late StateSetter update;
    await tester.pumpWidget(
      _screen(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return showReview
                ? AiTemplateDesignReview(
                    design: design,
                    onBack: () {},
                    onAccept: () {},
                    onDesignChanged: (_) => throw StateError('stale edit'),
                    isAccepting: false,
                  )
                : const Text('현재 계정 화면');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('문구 수정'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai-text-edit-input')), findsOneWidget);
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    final unrelated = DialogRoute<void>(
      context: tester.element(find.byType(AiTemplateDesignReview)),
      builder: (_) => const AlertDialog(content: Text('다른 화면')),
    );
    navigator.push(unrelated);
    await tester.pumpAndSettle();
    update(() => showReview = false);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai-text-edit-input')), findsNothing);
    expect(find.text('다른 화면'), findsOneWidget);
    expect(unrelated.isCurrent, isTrue);
    expect(find.text('현재 계정 화면'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a replaced result closes an older editor without applying its copy',
    (tester) async {
      final original = localEditDesign();
      var current = original;
      late StateSetter update;
      var changes = 0;
      await tester.pumpWidget(
        _screen(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return AiTemplateDesignReview(
                design: current,
                onBack: () {},
                onAccept: () {},
                onDesignChanged: (_) => changes++,
                isAccepting: false,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('문구 수정'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('ai-text-edit-input')),
        '이전 결과의 수정',
      );
      update(
        () => current = withAiTemplatePaperTone(
          original,
          AiTemplatePaperTone.cool,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ai-text-edit-input')), findsNothing);
      expect(current.pages.first.elements.last.text, '함께한 오후');
      expect(changes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large text in a narrow review keeps text editing reachable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final design = localEditDesign();
    await tester.pumpWidget(
      _screen(
        AiTemplateDesignReview(
          design: design,
          onBack: () {},
          onAccept: () {},
          onDesignChanged: (_) {},
          isAccepting: false,
        ),
        textScale: 2.4,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('문구 수정'));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('ai-text-edit-input'));
    await tester.ensureVisible(field);
    await tester.enterText(field, '오후');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('ai-text-apply')));
    await tester.tap(find.byKey(const ValueKey('ai-text-apply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai-text-edit-input')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _screen(Widget child, {double textScale = 1}) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, __) => MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(body: child),
  ),
);
