import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snap_fit/features/album/ai_album/data/supabase_ai_album_draft_provider.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_draft_generation_service.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_template_text_preflight.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_template_typography.g.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_design_review.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import 'package:snap_fit/core/constants/cover_size.dart';

Map<String, dynamic> _fixture() =>
    jsonDecode(File('test/fixtures/ai_template_v2.json').readAsStringSync())
        as Map<String, dynamic>;

// Attach the canonical plan just as the server does; the shared fixture is not AI output.
Map<String, Object?> _document({
  AiTemplateAspect aspect = AiTemplateAspect.square,
}) {
  final fixture = _fixture();
  final plan = fixture['plan'] as Map;
  final output = fixture['output'] as Map;
  return {
    ...Map<String, Object?>.from(output),
    'aspect': aspect.name,
    'concept': plan['concept'],
    'rationale': plan['rationale'],
    'artDirection': plan,
    'pages': [
      for (final (index, page) in (output['pages'] as List).indexed)
        {
          ...page as Map,
          'role': plan['pages'][index]['role'],
          'purpose': plan['pages'][index]['intent'],
        },
    ],
  };
}

Map _element(Map<String, Object?> doc, int page, int element) =>
    ((doc['pages'] as List)[page] as Map)['elements'][element] as Map;

Future<void> _loadFonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  final fonts = aiTemplateTypographyContract['fonts']! as Map;
  for (final entry in manifest.cast<Map>()) {
    if (!fonts.containsKey(entry['family']) &&
        entry['family'] != 'MaterialIcons')
      continue;
    final loader = FontLoader(entry['family'] as String);
    for (final asset in entry['fonts'] as List) {
      loader.addFont(rootBundle.load(asset['asset'] as String));
    }
    await loader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  test(
    'generated typography contract agrees with server and registered font weights',
    () async {
      final contract = jsonDecode(
        File(
          'supabase/functions/ai-album-draft/typography-contract.json',
        ).readAsStringSync(),
      );
      expect(aiTemplateTypographyContract, contract);
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      for (final font in (contract['fonts'] as Map).entries) {
        final entry = manifest.cast<Map>().singleWhere(
          (entry) => entry['family'] == font.key,
        );
        final weights = (entry['fonts'] as List).map((e) => e['weight'] ?? 400);
        expect(
          weights.toSet(),
          (font.value['weights'] as List).toSet(),
          reason: font.key as String,
        );
      }
    },
  );

  for (final aspect in AiTemplateAspect.values) {
    test(
      'v2 $aspect fits real fonts and preserves editable type through handoff and save',
      () {
        final design = AiTemplateDesign.fromJson(_document(aspect: aspect), 4);
        expect(() => validateAiTemplateText(design), returnsNormally);
        expect(
          design.pages[1].elements.every((e) => e.kind != 'photo'),
          isTrue,
        );
        final target = coverCanvasBaseSize(design.coverSize);
        final pages = AlbumCreationTemplate.preparePages(
          design.buildLayers(),
          sourceCanvas: design.canvasSize,
          cover: design.coverSize,
        );
        final source = design.buildLayers()[1].firstWhere(
          (e) => e.type == LayerType.text,
        );
        final text = pages[1].firstWhere((e) => e.type == LayerType.text);
        expect(text.textStyle!.fontFamily, 'Eulyoo');
        expect(text.textStyle!.height, 1.3);
        expect(
          text.textStyle!.fontSize,
          closeTo(source.textStyle!.fontSize! * target.width / 500, .001),
        );
        final saved = LayerExportMapper.toJson(text, canvasSize: target);
        final restored = LayerExportMapper.fromJson(
          saved,
          canvasSize: target * .8,
        );
        expect(restored.textStyle!.fontFamily, text.textStyle!.fontFamily);
        expect(restored.textStyle!.height, 1.3);
        expect(restored.textStyle!.fontWeight, text.textStyle!.fontWeight);
        expect(
          restored.textStyle!.fontSize,
          closeTo(text.textStyle!.fontSize! * .8, .001),
        );
        expect(
          pages
              .expand((p) => p)
              .where((e) => e.type == LayerType.image)
              .every((e) => e.imageUrl == null && e.asset == null),
          isTrue,
        );
      },
    );
  }

  test(
    'v2 rejects type overrides, incompatible scripts, changed palette and photo plan',
    () {
      final overrides = _document();
      _element(overrides, 0, 0)['fontSize'] = 12;
      expect(
        () => AiTemplateDesign.fromJson(overrides, 4),
        throwsFormatException,
      );
      final script = _document();
      _element(script, 0, 0)['text'] = '한글 제목';
      expect(() => AiTemplateDesign.fromJson(script, 4), throwsFormatException);
      final palette = _document();
      _element(palette, 0, 0)['color'] = '#ABCDEF';
      expect(
        () => AiTemplateDesign.fromJson(palette, 4),
        throwsFormatException,
      );
      final photos = _document();
      (((photos['pages'] as List)[2] as Map)['elements'] as List).removeAt(0);
      expect(() => AiTemplateDesign.fromJson(photos, 4), throwsFormatException);
    },
  );

  test(
    'font inspection reports all affected page and element IDs with dimensions',
    () {
      final document = _document();
      _element(document, 0, 0)['height'] = .01;
      _element(document, 1, 0)['height'] = .01;
      final design = AiTemplateDesign.fromJson(document, 4);
      final issues = inspectAiTemplateText(design);
      expect(issues.map((e) => e.pageIndex), [0, 1]);
      expect(issues.map((e) => e.elementId), ['cover-title', 'opener-heading']);
      expect(issues.every((e) => e.requiredHeight > e.availableHeight), isTrue);
      expect(issues.first.toJson()['availableHeight'], closeTo(5, .001));
      expect(() => validateAiTemplateText(design), throwsFormatException);
    },
  );

  test(
    'a typography-only cover and full-length planned intent remain compatible',
    () {
      final document = _document();
      final coverPlan = (document['artDirection'] as Map)['pages'][0] as Map;
      coverPlan['photoCount'] = 0;
      coverPlan['intent'] = List.filled(120, 'a').join();
      final cover = (document['pages'] as List)[0] as Map;
      cover['purpose'] = coverPlan['intent'];
      (cover['elements'] as List).removeAt(1);
      final design = AiTemplateDesign.fromJson(document, 4);
      expect(design.pages[0].purpose.length, 120);
      expect(() => validateAiTemplateText(design), returnsNormally);
      expect(
        design.buildLayers()[0].any((layer) => layer.type == LayerType.image),
        isFalse,
      );
    },
  );

  test(
    'v2 actual-font overflow fails before point charging; valid text-only pages pass',
    () async {
      for (final overflow in [false, true]) {
        final document = _document();
        if (overflow) _element(document, 1, 0)['height'] = .01;
        final provider = SupabaseAiAlbumDraftProvider(
          invokeFunction: (_, body) async {
            expect((body['designBrief'] as Map)['designVersion'], 2);
            return {
              'draftId': 'v2-fixture',
              'pageCount': 4,
              'title': document['concept'],
              'recommendedPhotos': [],
              'templateSlots': [
                {
                  'slotId': 'cover-photo',
                  'pageIndex': 0,
                  'role': 'cover',
                  'hint': '표지',
                },
              ],
              'design': document,
            };
          },
        );
        final service = AiAlbumDraftGenerationService(
          collectCandidates: (_) async =>
              throw StateError('Do not access photos'),
          draftProvider: provider,
        );
        final result = await service.generate(
          theme: AlbumTheme.custom,
          range: AiPhotoRange.manualSelection,
          designBrief: const AiTemplateBrief(prompt: '산책', pageCount: 4),
        );
        expect(
          result.status,
          overflow
              ? AiAlbumDraftGenerationStatus.failed
              : AiAlbumDraftGenerationStatus.success,
        );
        expect(result.shouldChargePoints, !overflow);
      }
    },
  );

  testWidgets(
    'exact type scales with the page instead of clamping or following UI text scale',
    (tester) async {
      final design = AiTemplateDesign.fromJson(_document(), 4);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Center(
              child: TemplatePageRenderer(
                layers: design.buildLayers()[0],
                width: 100,
                height: 100,
                designCanvasSize: design.canvasSize,
                preserveTypography: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final title = tester.widget<Text>(find.text('SLOW WALK'));
      final caption = tester.widget<Text>(find.text('산책의 기록'));
      expect(title.style!.fontSize, closeTo(9.6, .001));
      expect(caption.style!.fontSize, closeTo(2.4, .001));
      expect(title.textScaler, TextScaler.noScaling);
      expect(tester.takeException(), isNull);
    },
  );

  for (final aspect in AiTemplateAspect.values) {
    for (final landscape in [false, true]) {
      testWidgets(
        'v2 $aspect review landscape=$landscape shows planned type and navigates text-only pages',
        (tester) async {
          tester.view.physicalSize = landscape
              ? const Size(844, 390)
              : const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          final design = AiTemplateDesign.fromJson(
            _document(aspect: aspect),
            4,
          );
          await tester.pumpWidget(
            ScreenUtilInit(
              designSize: const Size(390, 844),
              builder: (_, __) => MaterialApp(
                theme: ThemeData(fontFamily: 'NotoSans'),
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
          for (var page = 0; page < design.pages.length; page++) {
            final target = find.byKey(ValueKey('ai_design_page_$page'));
            await tester.ensureVisible(target);
            await tester.tap(target);
            await tester.pumpAndSettle();
            expect(
              tester
                  .widgetList<TemplatePageRenderer>(
                    find.byType(TemplatePageRenderer),
                  )
                  .every((e) => e.preserveTypography),
              isTrue,
            );
            expect(tester.takeException(), isNull);
            if (page == 1) {
              await expectLater(
                find.byType(AiTemplateDesignReview),
                matchesGoldenFile(
                  'goldens/v2_${aspect.name}_${landscape ? 'landscape' : 'portrait'}.png',
                ),
              );
            }
          }
        },
      );
    }
  }
}
