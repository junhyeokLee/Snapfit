import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/free_template_material_policy.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/studio_photo_frame_catalog.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/ai_album/data/supabase_ai_album_draft_provider.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_draft_generation_service.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_template_composition.g.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_template_text_preflight.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_template_preview.dart';
import '../fixtures/ai_template_v3_fixture.dart';

class _Binding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

Map _element(Map doc, int page, int element) =>
    (doc['pages'] as List)[page]['elements'][element] as Map;

void main() {
  _Binding();
  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest.cast<Map>()) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in entry['fonts'] as List)
        loader.addFont(rootBundle.load(font['asset'] as String));
      await loader.load();
    }
  });

  test(
    'server/client material contract agrees and every listed material is free and renderable',
    () {
      expect(
        aiTemplateCompositionContract,
        jsonDecode(
          File(
            'supabase/functions/ai-album-draft/composition-contract.json',
          ).readAsStringSync(),
        ),
      );
      for (final key in (aiTemplateCompositionContract['frames'] as Map).keys) {
        if (key == 'none') continue;
        expect(studioPhotoFrames, contains(key));
        expect(freeTemplateMaterialProductKeys, contains('frame:$key'));
      }
      for (final key in (aiTemplateCompositionContract['papers'] as Map).keys) {
        if (key == 'rect') continue;
        expect(studioDecorations.map((e) => e.id), contains(key));
        expect(freeTemplateMaterialProductKeys, contains('sticker:$key'));
      }
    },
  );

  test(
    'v3 preserves frame, paper, stacking, rotation and typography through actual layer persistence',
    () {
      final design = AiTemplateDesign.fromJson(originalTemplateDesignJson(), 4);
      expect(design.version, 3);
      expect(design.layoutExpansion, isNull);
      expect(() => validateAiTemplateText(design), returnsNormally);
      final pages = design.buildLayers();
      final flat = pages.expand((p) => p).toList();
      final restored = flat
          .map(
            (layer) => LayerExportMapper.fromJson(
              LayerExportMapper.toJson(layer, canvasSize: design.canvasSize),
              canvasSize: design.canvasSize,
            ),
          )
          .toList();
      for (var i = 0; i < flat.length; i++) {
        expect(restored[i].imageBackground, flat[i].imageBackground);
        expect(restored[i].rotation, flat[i].rotation);
        expect(restored[i].zIndex, flat[i].zIndex);
        expect(restored[i].textFillMode, flat[i].textFillMode);
        expect(restored[i].position, flat[i].position);
        expect(restored[i].width, flat[i].width);
        expect(restored[i].height, flat[i].height);
      }
      expect(
        flat.firstWhere((e) => e.id == 'p1_photo').imageBackground,
        'studioDeckle',
      );
      expect(
        flat.firstWhere((e) => e.id == 'p3_paper').imageBackground,
        'atelierGridLeaf',
      );
      expect(
        flat.firstWhere((e) => e.id == 'p0_title').textFillMode,
        'outline',
      );
    },
  );

  for (final count in [20, 24, 36, 80]) {
    test('v3 accepts $count original pages without any expansion marker', () {
      final brief = AiTemplateBrief(prompt: '제주 산책', pageCount: count);
      final doc = originalTemplateDesignJson(brief: brief);
      final design = AiTemplateDesign.fromJson(doc, count);
      expect(design.pages, hasLength(count + 1));
      expect(design.layoutExpansion, isNull);
      expect(() => validateAiTemplateText(design), returnsNormally);
      doc['layoutExpansion'] = {
        'strategy': 'repeat_inner_layouts_v1',
        'sourcePageCount': 16,
        'finalPageCount': count,
      };
      expect(
        () => AiTemplateDesign.fromJson(doc, count),
        throwsFormatException,
      );
    });
  }

  test('v3 original book respects the selected physical landscape product', () {
    const brief = AiTemplateBrief(
      prompt: '제주 바다 사진집',
      pageCount: 20,
      aspect: AiTemplateAspect.landscape,
      printProductId: 'REDP_250X200_HARD',
    );
    final draft = originalTemplateDraft(brief);
    expect(inspectAiTemplateText(draft.design!), isEmpty);
    expect(
      () => draft.design!.compositionPlan!.validateRequest(
        brief,
        copy: draft.design!.pages
            .expand((p) => p.elements)
            .where((e) => e.kind == 'text')
            .map((e) => e.text!),
      ),
      returnsNormally,
    );
  });

  test(
    'v3 request checks preserve quoted copy and reject unprovided Korean dates',
    () {
      final plan = AiTemplateDesign.fromJson(
        originalTemplateDesignJson(),
        4,
      ).compositionPlan!;
      const brief = AiTemplateBrief(prompt: '산책, 제목은 「바람을 따라」.');
      expect(
        () => plan.validateRequest(brief, copy: ['바람을 따라', '2026년 10월 19일']),
        throwsFormatException,
      );
      expect(
        () => plan.validateRequest(
          const AiTemplateBrief(prompt: '산책, 제목은 「바람을 따라」. 2026년 10월 19일'),
          copy: ['바람을 따라', '2026년 10월 19일'],
        ),
        returnsNormally,
      );
      expect(
        () => plan.validateRequest(
          AiTemplateBrief(prompt: '제목은 「${'가' * 161}」'),
          copy: ['바람을 따라'],
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'v3 rejects unknown material keys, duplicate geometry, hidden text and illegal rotation',
    () {
      var doc = originalTemplateDesignJson();
      _element(doc, 1, 1)['style'] = 'signatureVowPocket';
      expect(() => AiTemplateDesign.fromJson(doc, 4), throwsFormatException);
      doc = originalTemplateDesignJson();
      final a = _element(doc, 1, 1), b = _element(doc, 2, 0);
      for (final key in ['x', 'y', 'width', 'height']) b[key] = a[key];
      b['rotation'] = a['rotation'];
      expect(() => AiTemplateDesign.fromJson(doc, 4), throwsFormatException);
      doc = originalTemplateDesignJson();
      _element(doc, 0, 1)['rotation'] = .2;
      expect(() => AiTemplateDesign.fromJson(doc, 4), throwsFormatException);
      doc = originalTemplateDesignJson();
      ((doc['pages'] as List)[0]['elements'] as List).add({
        ...Map.from(_element(doc, 0, 0)),
        'id': 'p0_covering',
        'kind': 'paper',
        'style': 'rect',
        'color': '#FFFFFF',
        'zIndex': 99,
      });
      expect(() => AiTemplateDesign.fromJson(doc, 4), throwsFormatException);
    },
  );

  test(
    'new requests require the original-book version and fail without making points chargeable',
    () async {
      const brief = AiTemplateBrief(prompt: '제주 산책', pageCount: 24);
      var requestCount = 0;
      final original = originalTemplateDesignJson(brief: brief);
      final provider = SupabaseAiAlbumDraftProvider(
        invokeFunction: (_, body) async {
          expect((body['designBrief'] as Map)['designVersion'], 3);
          expect(body['candidates'], isEmpty);
          requestCount++;
          return {
            'draftId': 'v3-contract-only',
            'pageCount': 24,
            'title': original['concept'],
            'recommendedPhotos': [],
            'templateSlots': [
              {
                'slotId': 'p0_photo',
                'pageIndex': 0,
                'role': 'cover',
                'hint': '표지',
              },
            ],
            'design': original,
          };
        },
      );
      final service = AiAlbumDraftGenerationService(
        collectCandidates: (_) async =>
            throw StateError('Must not access user photos'),
        draftProvider: provider,
      );
      final accepted = await service.generate(
        theme: AlbumTheme.custom,
        range: AiPhotoRange.manualSelection,
        designBrief: brief,
      );
      expect(accepted.shouldChargePoints, true);
      final missingCopy = await service.generate(
        theme: AlbumTheme.custom,
        range: AiPhotoRange.manualSelection,
        designBrief: const AiTemplateBrief(
          prompt: '제목은 "꼭 지켜줘"',
          pageCount: 24,
        ),
      );
      expect(missingCopy.shouldChargePoints, false);
      expect(requestCount, 2);
      expect(brief.toJson()['designVersion'], 3);
    },
  );

  for (final aspect in AiTemplateAspect.values) {
    for (final viewport in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(844, 390),
    ]) {
      testWidgets(
        'v3 real fonts, editable materials and ordinary-photo inspection ${aspect.name} $viewport',
        (tester) async {
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1;
          tester.view.padding = viewport.width > viewport.height
              ? const FakeViewPadding(left: 32, right: 48, bottom: 24)
              : const FakeViewPadding(top: 24, bottom: 34);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPadding);
          final doc = originalTemplateDesignJson()..['aspect'] = aspect.name;
          final design = AiTemplateDesign.fromJson(doc, 4);
          expect(
            inspectAiTemplateText(design),
            isEmpty,
            reason: jsonEncode(
              inspectAiTemplateText(design).map((e) => e.toJson()).toList(),
            ),
          );
          final empty = design.buildLayers();
          var photo = 0;
          const images = [
            'alpine_lake',
            'city_skyline',
            'forest_trail',
            'ocean_shore',
            'spring_flowers',
          ];
          // Photos are injected only by this inspection test, never by the generator.
          final pages = [
            for (final page in empty)
              [
                for (final e in page)
                  e.type == LayerType.image
                      ? e.copyWith(
                          imageUrl:
                              'asset:assets/frame_preview/${images[(photo++) % images.length]}.jpg',
                        )
                      : e,
              ],
          ];
          final boundary = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: SnapFitTheme.light(),
              builder: (context, child) =>
                  RepaintBoundary(key: boundary, child: child!),
              home: CreationTemplatePreview(
                title: design.concept,
                isPremium: false,
                pages: pages,
                canvas: design.canvasSize,
                preserveTypography: true,
                onUse: () {},
                onRetry: () {},
              ),
            ),
          );
          Future<void> capture(String page) async {
            await tester.pumpAndSettle();
            await tester.runAsync(() async {
              for (final element in find.byType(Image).evaluate())
                await precacheImage((element.widget as Image).image, element);
            });
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (!const bool.fromEnvironment('AI_ORIGINAL_BOOK_QA')) return;
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                'output/ai-template-engine-qa/v3-${aspect.name}-${viewport.width.toInt()}-$page.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }

          await capture('cover');
          for (var i = 0; i < (viewport.width > viewport.height ? 2 : 4); i++) {
            await tester.tap(find.byTooltip('다음 페이지'));
            await tester.pumpAndSettle();
            await capture(
              'page-${viewport.width > viewport.height ? 1 + i * 2 : i + 1}',
            );
          }
        },
      );
    }
  }
}
