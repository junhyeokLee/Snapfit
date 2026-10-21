import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_brief_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_design_review.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import '../fixtures/ai_template_design_fixture.dart';

void main() {
  setUp(() async {
    final loader = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/NotoSansKR-SemiBold.ttf'));
    await loader.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final surface in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(320, 568),
  ]) {
    testWidgets('brief form at $surface retains prompt, ratio and page count', (
      tester,
    ) async {
      tester.view.physicalSize = surface;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      AiTemplateBrief? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiTemplateBriefStep(
              onContinue: (value) => submitted = value,
              onBack: () {},
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('ai_template_brief_continue')),
            )
            .onPressed,
        isNotNull,
      );
      expect(find.text('20쪽'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == '2쪽 줄이기',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('AI가 최대 16쪽'), findsNothing);
      expect(find.textContaining('내지는 20~80쪽'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('ai_template_brief')),
        '여백은 넓게, 글은 짧게',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      expect(find.text('세로형'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('print-cover-hard')),
      );
      await tester.tap(find.byKey(const ValueKey('print-cover-hard')));
      await tester.pump();
      final size = find.byKey(const ValueKey('print-size-REDP_250X200_SOFT'));
      await tester.ensureVisible(size);
      await tester.tap(size);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('2쪽 늘리기'));
      await tester.tap(find.byTooltip('2쪽 늘리기'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('ai_template_brief_continue')),
      );
      await tester.tap(find.byKey(const Key('ai_template_brief_continue')));
      await tester.pumpAndSettle();
      expect(submitted!.prompt, '여백은 넓게, 글은 짧게');
      expect(submitted!.aspect, AiTemplateAspect.landscape);
      expect(submitted!.printProductId, 'REDP_250X200_HARD');
      expect(submitted!.coverSize.ratio, 1.25);
      expect(submitted!.pageCount, 22);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'brief preserves legacy input but new selection stays20..80even',
    (tester) async {
      AiTemplateBrief? submitted;
      Future<void> render(int pageCount) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiTemplateBriefStep(
              key: ValueKey(pageCount),
              initialBrief: AiTemplateBrief(prompt: '여행', pageCount: pageCount),
              onContinue: (value) => submitted = value,
              onBack: () {},
            ),
          ),
        ),
      );
      await render(4);
      expect(find.text('20쪽'), findsOneWidget);
      await render(78);
      await tester.ensureVisible(find.byTooltip('2쪽 늘리기'));
      await tester.tap(find.byTooltip('2쪽 늘리기'));
      await tester.pump();
      expect(find.text('80쪽'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == '2쪽 늘리기',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(
        find.byKey(const Key('ai_template_brief_continue')),
      );
      await tester.tap(find.byKey(const Key('ai_template_brief_continue')));
      expect(submitted!.pageCount, 80);
      await render(81);
      expect(find.text('80쪽'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final aspect in AiTemplateAspect.values) {
    for (final landscape in [false, true]) {
      testWidgets(
        'review $aspect landscape=$landscape navigates all pages without overflow',
        (tester) async {
          tester.view.physicalSize = landscape
              ? const Size(844, 390)
              : const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          final design = templateDesignDraft(
            brief: AiTemplateBrief(prompt: '제주', aspect: aspect),
          ).design!;
          await tester.pumpWidget(
            ScreenUtilInit(
              designSize: const Size(390, 844),
              builder: (_, __) => MaterialApp(
                home: Scaffold(
                  body: AiTemplateDesignReview(
                    design: design,
                    onBack: () {},
                    onAccept: () {},
                    isAccepting: false,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          Finder stagePages() => find.descendant(
            of: find.byKey(const ValueKey('creation_document_stage')),
            matching: find.byType(TemplatePageRenderer),
          );
          // The curved spine and front cover render the same source artwork.
          expect(stagePages(), findsNWidgets(2));
          final coverCopies = tester
              .widgetList<TemplatePageRenderer>(stagePages())
              .toList();
          expect(
            coverCopies.where((page) => page.wrapSpineArtwork),
            hasLength(1),
          );
          expect(coverCopies.first.layers, coverCopies.last.layers);
          await tester.tap(find.byKey(const Key('ai_design_page_1')));
          await tester.pumpAndSettle();
          expect(stagePages(), landscape ? findsNWidgets(2) : findsOneWidget);
          await tester.tap(find.byTooltip('다음 페이지'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(AiTemplateDesignReview),
            matchesGoldenFile(
              'goldens/ai_template_${aspect.name}_${landscape ? 'landscape' : 'portrait'}.png',
            ),
          );
        },
      );
    }
  }
}
