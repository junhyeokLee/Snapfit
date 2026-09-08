import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_document_preview.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_design_review.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_template_preview.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

import '../fixtures/ai_template_design_fixture.dart';
import 'ai_album_start_step_test.dart' show loadCreationFonts;

Finder get _stage => find.byKey(const ValueKey('creation_document_stage')).last;
Finder get _stagePages =>
    find.descendant(of: _stage, matching: find.byType(TemplatePageRenderer));
String _position(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('creation_document_position')).last)
    .data!;

void main() {
  setUpAll(loadCreationFonts);

  void surface(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  for (final aspect in AiTemplateAspect.values) {
    testWidgets(
      '$aspect keeps the chosen page through rotation, inspection and swipes',
      (tester) async {
        surface(tester, const Size(390, 844));
        final design = templateDesignDraft(
          brief: AiTemplateBrief(
            prompt: '개발 테스트',
            aspect: aspect,
            pageCount: 16,
          ),
        ).design!;
        final pages = design.buildLayers();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SafeArea(
                child: CreationDocumentPreview(
                  pages: pages,
                  canvas: design.canvasSize,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(_stagePages, findsOneWidget);
        final coverRenderer = tester.widget<TemplatePageRenderer>(_stagePages);
        expect(
          coverRenderer.imageDecodeWidth,
          greaterThanOrEqualTo((coverRenderer.height * 2).ceil()),
          reason: 'Portrait photo crops must not upscale a width-only decode.',
        );
        expect(coverRenderer.imageDecodeWidth, lessThanOrEqualTo(2048));
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (w) => w is IconButton && w.tooltip == '이전 페이지',
                ),
              )
              .onPressed,
          isNull,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('creation_preview_page_12')),
        );
        await tester.tap(
          find.byKey(const ValueKey('creation_preview_page_12')),
        );
        await tester.pumpAndSettle();
        expect(_position(tester), '12 / 16쪽');
        expect(
          tester.widget<TemplatePageRenderer>(_stagePages).layers,
          same(pages[12]),
        );

        tester.view.physicalSize = const Size(844, 390);
        await tester.pumpAndSettle();
        expect(_position(tester), '11–12 / 16쪽');
        expect(_stagePages, findsNWidgets(2));
        final rendered = tester
            .widgetList<TemplatePageRenderer>(_stagePages)
            .toList();
        expect(rendered.first.layers, same(pages[11]));
        expect(rendered.last.layers, same(pages[12]));
        expect(
          rendered.first.imageDecodeWidth,
          greaterThanOrEqualTo((rendered.first.height * 2).ceil()),
        );
        expect(
          rendered.first.width / rendered.first.height,
          closeTo(design.canvasSize.aspectRatio, .0001),
        );
        final canvas = tester.getRect(
          find.byKey(const ValueKey('creation_document_canvas')),
        );
        final rail = tester.getRect(
          find.byKey(const ValueKey('creation_document_rail')),
        );
        expect(canvas.right, lessThan(rail.left));

        await tester.tap(find.byTooltip('페이지 확대'));
        await tester.pumpAndSettle();
        expect(_stagePages, findsOneWidget);
        expect(_position(tester), '12 / 16쪽');
        await tester.tap(find.byTooltip('확대'));
        await tester.pumpAndSettle();
        final viewer = tester.widget<InteractiveViewer>(
          find.byType(InteractiveViewer),
        );
        expect(
          viewer.transformationController!.value.getMaxScaleOnAxis(),
          closeTo(1.5, .001),
        );
        await tester.tap(find.byTooltip('다음 페이지'));
        await tester.pumpAndSettle();
        expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);
        expect(_position(tester), '13 / 16쪽');
        await tester.tap(find.byTooltip('확대 보기 닫기'));
        await tester.pumpAndSettle();
        expect(_position(tester), '13–14 / 16쪽');
        tester.view.physicalSize = const Size(390, 844);
        await tester.pumpAndSettle();
        expect(_position(tester), '13 / 16쪽');
        await tester.drag(_stage, const Offset(-110, 0));
        await tester.pumpAndSettle();
        expect(_position(tester), '14 / 16쪽');
        await tester.drag(_stage, const Offset(110, 0));
        await tester.pumpAndSettle();
        expect(_position(tester), '13 / 16쪽');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(_position(tester), '14 / 16쪽');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'new document resets selection and cover never gains a blank page',
    (tester) async {
      surface(tester, const Size(844, 390));
      final first = templateDesignDraft().design!;
      final second = templateDesignDraft(
        brief: const AiTemplateBrief(prompt: '새 문서', pageCount: 4),
      ).design!;
      final firstPages = first.buildLayers();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreationDocumentPreview(
              pages: firstPages,
              canvas: first.canvasSize,
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('다음 페이지'));
      await tester.pumpAndSettle();
      expect(_position(tester), '1–2 / 8쪽');
      await tester.tap(find.byTooltip('이전 페이지'));
      await tester.pumpAndSettle();
      expect(_stagePages, findsOneWidget);
      expect(_position(tester), '표지');
      await tester.tap(find.byTooltip('다음 페이지'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreationDocumentPreview(
              pages: second.buildLayers(),
              canvas: second.canvasSize,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_position(tester), '표지');
      expect(_stagePages, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('safe areas, large text and plan details at $size', (
      tester,
    ) async {
      surface(tester, size);
      final json =
          jsonDecode(
                File('test/fixtures/ai_template_v2.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final plan = json['plan'] as Map;
      final output = json['output'] as Map;
      final design = AiTemplateDesign.fromJson({
        ...Map<String, Object?>.from(output),
        'concept': plan['concept'],
        'rationale': plan['rationale'],
        'artDirection': plan,
        'pages': [
          for (final (i, page) in (output['pages'] as List).indexed)
            {
              ...page as Map,
              'role': plan['pages'][i]['role'],
              'purpose': plan['pages'][i]['intent'],
            },
        ],
      }, 4);
      var accepted = 0, refined = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'NotoSans'),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(1.5),
              padding: size.width > size.height
                  ? const EdgeInsets.only(left: 36, right: 48, bottom: 20)
                  : const EdgeInsets.only(top: 24, bottom: 48),
            ),
            child: child!,
          ),
          home: Scaffold(
            appBar: AppBar(title: const Text('앨범 만들기')),
            body: AiTemplateDesignReview(
              design: design,
              onBack: () => refined++,
              onAccept: () => accepted++,
              isAccepting: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final page = tester.widget<TemplatePageRenderer>(_stagePages);
      expect(page.height, greaterThan(100));
      expect(
        page.height,
        lessThanOrEqualTo(tester.getSize(_stage).height - 32),
      );
      expect(
        tester.getRect(find.byTooltip('다음 페이지')).bottom,
        lessThan(size.height - 20),
      );
      await tester.tap(find.byTooltip('디자인 정보'));
      await tester.pumpAndSettle();
      expect(find.text(design.rationale), findsOneWidget);
      expect(
        find.byTooltip(design.artDirection!.palette.first),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('디자인 정보 닫기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('디자인 요청 수정'));
      await tester.tap(find.text('이 디자인 사용'));
      expect(accepted, 1);
      expect(refined, 1);
      await tester.tap(find.byTooltip('페이지 확대'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TemplatePageRenderer>(_stagePages).height,
        greaterThan(200),
      );
      await tester.tap(find.byTooltip('확대'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_position(tester), '표지');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty catalog retries without permitting use', (tester) async {
    surface(tester, const Size(390, 844));
    var retries = 0, uses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CreationTemplatePreview(
          title: '템플릿',
          isPremium: true,
          pages: const [],
          canvas: const Size(500, 500),
          onUse: () => uses++,
          onRetry: () => retries++,
        ),
      ),
    );
    await tester.tap(find.text('다시 불러오기'));
    await tester.tap(find.text('이 디자인 선택'));
    expect(retries, 1);
    expect(uses, 0);
    expect(tester.takeException(), isNull);
  });
}
