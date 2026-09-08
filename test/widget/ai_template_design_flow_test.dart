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
        isNull,
      );
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
      expect(submitted!.pageCount, 10);
      expect(tester.takeException(), isNull);
    });
  }

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
          expect(stagePages(), findsOneWidget);
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
