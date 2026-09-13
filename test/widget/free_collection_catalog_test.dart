import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import '../../tool/template_studio/preview_app.dart';
import 'ai_album_start_step_test.dart' show loadCreationFonts;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCreationFonts);

  test(
    'expanded collections are free, full length, and retain baseline IDs',
    () {
      expect(bundledCreationTemplates.length, 37);
      expect(bundledCreationTemplates.take(3).map((t) => t.id), [
        -9301,
        -9302,
        -9303,
      ]);
      expect(bundledCreationTemplates.take(3).map((t) => t.title), [
        '빛으로 엮은 우리',
        '여행의 결',
        '작은 날의 기록',
      ]);
      for (final template in bundledCreationTemplates) {
        expect(template.isPremium, false);
        final pageCount = template.id == windAtlasBundledId ? 32 : 24;
        expect(template.pageCount, pageCount);
        expect(isBundledCreationTemplate(template), true);
        final doc = jsonDecode(template.templateJson!) as Map;
        for (final variant in (doc['variants'] as Map).values) {
          expect(variant['accessTier'], 'free');
          expect(variant['publicationStatus'], 'bundled');
          expect(variant['catalogPublishable'], false);
          expect(variant['aiGenerated'], false);
          expect((variant['pages'] as List).length, pageCount);
        }
      }
    },
  );

  test(
    'retired IDs and cloned documents stay hidden after catalog refresh',
    () {
      final old = [
        for (final c in retiredAuthoredCollections)
          bundledCreationTemplates.first.copyWith(
            id: c.bundledId,
            title: c.title,
            templateJson: jsonEncode(c.catalogDocument()),
          ),
      ];
      final clones = [
        for (var i = 0; i < old.length; i++) old[i].copyWith(id: 600 + i),
      ];
      // All other public products are retired, regardless of their title.
      final unrelated = bundledCreationTemplates.first.copyWith(
        id: 700,
        title: retiredAuthoredCollections.first.title,
        isPremium: true,
      );
      final malformed = unrelated.copyWith(id: 701, templateJson: '{broken');
      final input = [
        ...old,
        ...clones,
        ...bundledCreationTemplates,
        unrelated,
        malformed,
      ];
      final before = input.map((t) => t.templateJson).toList();
      final visible = withBundledCreationTemplates(input);
      expect(
        visible.map((t) => t.id),
        authoredCollections.map((c) => c.bundledId),
      );
      expect(input.map((t) => t.templateJson), before);
      expect(old.every(isBundledCreationTemplate), true);
      expect([...old, ...clones].every(isRetiredAuthoredTemplate), true);
    },
  );

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets(
      '$size: preview only offers current free collections and retained tools',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(const TemplatePreviewWorkbench());
        await tester.pumpAndSettle();
        expect(find.text('무료 · 표지 + 내지 24쪽'), findsOneWidget);
        for (final title in ['여행의 결', '작은 날의 기록', '빛으로 엮은 우리']) {
          await tester.tap(find.byTooltip('시안 선택'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widgetList<PopupMenuItem<String>>(
                  find.byType(PopupMenuItem<String>),
                )
                .map((item) => item.value),
            unorderedEquals([
              for (final collection in authoredCollections) '/${collection.id}',
              '/premium-studies',
              '/luminous-edition',
              '/travel-keepsake-20',
              '/frames',
              '/materials',
              '/atelier',
            ]),
          );
          for (final retired in retiredAuthoredCollections) {
            expect(find.text(retired.title), findsNothing);
          }
          expect(find.text('AI 결과 화면 · 테스트 문서'), findsNothing);
          expect(find.text('사진 프레임'), findsOneWidget);
          expect(find.text('종이·스티커'), findsOneWidget);
          final item = find.descendant(
            of: find.byType(PopupMenuItem<String>),
            matching: find.text(title),
          );
          await tester.tap(item);
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.text(title),
            ),
            findsOneWidget,
          );
          expect(find.byTooltip('문구 편집'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
