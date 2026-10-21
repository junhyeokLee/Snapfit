import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_draft_generation_service.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_draft_template_builder.dart';
import 'package:snap_fit/features/album/ai_album/data/supabase_ai_album_draft_provider.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import '../fixtures/ai_template_design_fixture.dart';
import '../fixtures/ai_template_v3_fixture.dart';

void main() {
  for (final pageCount in [20, 22, 52, 80]) {
    test(
      'expanded$pageCount interiors parse and remain independently editable',
      () {
        final draft = templateDesignDraft(
          brief: AiTemplateBrief(prompt: '여행', pageCount: pageCount),
        );
        final design = draft.design!;
        expect(design.layoutExpansion!.sourcePageCount, 16);
        expect(design.layoutExpansion!.finalPageCount, pageCount);
        final pages = const AiAlbumDraftTemplateBuilder().build(draft);
        expect(pages, hasLength(pageCount + 1));
        final ids = pages
            .expand((page) => page)
            .map((layer) => layer.id)
            .toList();
        expect(ids.toSet(), hasLength(ids.length));
        expect(
          const AiAlbumDraftTemplateBuilder().isEditorReady(draft),
          isTrue,
        );
      },
    );
  }

  test('large documents reject missing or inconsistent expansion metadata', () {
    final json = templateDesignJson(pageCount: 80);
    json.remove('layoutExpansion');
    expect(() => AiTemplateDesign.fromJson(json, 80), throwsFormatException);
    for (final expansion in [
      {
        'strategy': 'repeat_inner_layouts_v1',
        'sourcePageCount': 18,
        'finalPageCount': 80,
      },
      {
        'strategy': 'repeat_inner_layouts_v1',
        'sourcePageCount': 16,
        'finalPageCount': 20,
      },
      {'strategy': 'invented', 'sourcePageCount': 16, 'finalPageCount': 80},
    ]) {
      json['layoutExpansion'] = expansion;
      expect(() => AiTemplateDesign.fromJson(json, 80), throwsFormatException);
    }
    for (final pageCount in [18, 21, 82]) {
      expect(
        () => AiTemplateDesign.fromJson(
          templateDesignJson(pageCount: pageCount),
          pageCount,
        ),
        throwsFormatException,
      );
    }
  });

  test(
    'provider accepts full80 response but refuses a truncated16 response',
    () async {
      const brief = AiTemplateBrief(prompt: '여행', pageCount: 80);
      var returnedCount = 80;
      final provider = SupabaseAiAlbumDraftProvider(
        invokeFunction: (_, body) async {
          expect((body['designBrief'] as Map)['pageCount'], 80);
          return {
            'draftId': 'expanded-80',
            'title': '여행',
            'pageCount': returnedCount,
            'recommendedPhotos': [],
            'templateSlots': [
              {
                'slotId': 'photo-0',
                'pageIndex': 0,
                'role': 'cover',
                'hint': '표지',
              },
            ],
            'design': templateDesignJson(pageCount: returnedCount),
          };
        },
      );
      final result = await provider.createTemplate(brief);
      expect(result.pageCount, 80);
      expect(result.design!.pages, hasLength(81));
      returnedCount = 16;
      await expectLater(
        provider.createTemplate(brief),
        throwsA(
          isA<SupabaseAiAlbumDraftProviderException>().having(
            (error) => error.code,
            'code',
            'template_page_count_mismatch',
          ),
        ),
      );
    },
  );

  for (final size in coverSizes.expand(
    (size) => PrintCoverType.values.map(size.withCoverType),
  )) {
    test('AI request and generated result preserve ${size.productId}', () {
      final aspect = size.ratio > 1
          ? AiTemplateAspect.landscape
          : AiTemplateAspect.square;
      final brief = AiTemplateBrief(
        prompt: '여행',
        aspect: aspect,
        printProductId: size.productId,
      );
      expect(brief.toJson()['printProduct'], size.printProduct);
      final json = templateDesignJson();
      json['aspect'] = aspect.name;
      json['printProduct'] = size.printProduct;
      final design = AiTemplateDesign.fromJson(json, 8);
      expect(design.coverSize.productId, size.productId);
      expect(design.canvasSize.aspectRatio, closeTo(size.ratio, .0001));
      expect(
        design.buildLayers().first.first.height,
        closeTo(500 / size.ratio, .0001),
      );
    });
  }

  for (final aspect in AiTemplateAspect.values) {
    test(
      '$aspect retains page geometry, color, editable text and empty photo frames',
      () {
        final draft = templateDesignDraft(
          brief: AiTemplateBrief(prompt: '제주', aspect: aspect),
        );
        final design = draft.design!;
        final pages = const AiAlbumDraftTemplateBuilder().build(draft);
        expect(pages, hasLength(9));
        final photo = pages.first.firstWhere((e) => e.type == LayerType.image);
        expect(photo.position, Offset(40, .08 * design.canvasSize.height));
        expect(photo.width, 420);
        expect(photo.asset, isNull);
        expect(photo.imageUrl, isNull);
        expect(pages.first.first.decorationFillColor, '#ffffff');
        expect(pages.first.last.text, design.pages.first.elements.last.text);
        expect(
          const AiAlbumDraftTemplateBuilder().isEditorReady(draft),
          isTrue,
        );
        expect(draft.copyWith(title: '다른 제목').design, same(design));
        final scaled = design.buildLayers(targetSize: design.canvasSize * .6);
        expect(scaled.first.last.textStyle!.fontSize, closeTo(13.2, .001));
      },
    );
  }

  test(
    'rejects corrupt generated document instead of replacing it with a legacy template',
    () {
      final json = templateDesignJson();
      final pages = json['pages'] as List;
      final e = (pages.first as Map)['elements'] as List;
      (e.first as Map)['width'] = double.nan;
      expect(() => AiTemplateDesign.fromJson(json, 8), throwsFormatException);
      expect(
        () => AiTemplateDesign.fromJson(templateDesignJson(), 6),
        throwsFormatException,
      );
    },
  );

  test(
    'brief-only request bypasses photo permissions and preview upload',
    () async {
      const brief = AiTemplateBrief(prompt: '여백이 넓은 초록 사진집');
      final provider = SupabaseAiAlbumDraftProvider(
        invokeFunction: (_, body) async {
          expect(body['designBrief'], brief.toJson());
          expect(body['candidates'], isEmpty);
          return {
            'draftId': 'generated-1',
            'title': '제주',
            'pageCount': 8,
            'recommendedPhotos': [],
            'templateSlots': [
              {
                'slotId': 'photo-0',
                'pageIndex': 0,
                'role': 'cover',
                'hint': '표지',
              },
            ],
            'design': originalTemplateDesignJson(brief: brief),
          };
        },
      );
      final service = AiAlbumDraftGenerationService(
        collectCandidates: (_) async =>
            throw StateError('Photo access must not occur'),
        prepareAdvancedPreviews: (_) async =>
            throw StateError('Upload must not occur'),
        draftProvider: provider,
      );
      final result = await service.generate(
        theme: AlbumTheme.custom,
        range: AiPhotoRange.manualSelection,
        designBrief: brief,
      );
      expect(result.status, AiAlbumDraftGenerationStatus.success);
      expect(result.draft!.design!.pages, hasLength(9));
    },
  );

  test('missing generated design never reaches point charging', () async {
    final provider = SupabaseAiAlbumDraftProvider(
      invokeFunction: (_, __) async => {
        'pageCount': 8,
        'recommendedPhotos': [],
        'templateSlots': [
          {'slotId': 'x', 'pageIndex': 0, 'role': 'cover', 'hint': '표지'},
        ],
      },
    );
    final result =
        await AiAlbumDraftGenerationService(
          collectCandidates: (_) async => [],
          draftProvider: provider,
        ).generate(
          theme: AlbumTheme.custom,
          range: AiPhotoRange.manualSelection,
          designBrief: const AiTemplateBrief(prompt: '여백'),
        );
    expect(result.shouldChargePoints, isFalse);
    expect(result.status, AiAlbumDraftGenerationStatus.failed);
  });
}
