import 'dart:convert';
import 'dart:io';

import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';

// Contract-only synthetic fixtures; never used by production generation.
Map<String, Object?> originalTemplateDesignJson({AiTemplateBrief? brief}) {
  final fixture =
      jsonDecode(File('test/fixtures/ai_template_v3.json').readAsStringSync())
          as Map;
  final source = fixture['brief'] as Map;
  final count = brief?.pageCount ?? source['pageCount'] as int;
  final plan = fixture['plan'] as Map;
  final raw = (fixture['output'] as Map)['pages'] as List;
  if (brief != null) {
    final quotes = RegExp(
      '["“「『‘]([^"”」』’\\n]{1,160})["”」』’]',
    ).allMatches(brief.prompt).map((m) => m[1]!.trim()).toSet().toList();
    plan['concept'] = quotes.firstOrNull ?? '제주의 느린 오후';
    (plan['intent'] as Map)['verbatim'] = quotes;
    (plan['intent'] as Map)['understanding'] = brief.prompt.length <= 400
        ? brief.prompt
        : brief.prompt.substring(0, 400);
    final title = (((raw.first as Map)['elements'] as List)[1] as Map);
    title['text'] = plan['concept'];
    plan['pages'] = List.generate(
      count + 1,
      (i) => {
        'role': i == 0
            ? 'cover'
            : i == count
            ? 'closing'
            : 'story',
        'intent': 'Synthetic contract page $i',
        'photoCount': 1,
      },
    );
    plan['compositions'] = List.generate(
      count + 1,
      (i) => 'Synthetic geometry case $i',
    );
  }
  final planned = plan['pages'] as List;
  final pages = brief == null
      ? raw
      : [
          raw.first,
          for (var i = 1; i <= count; i++)
            {
              'pageIndex': i,
              'background': '#FFFFFF',
              'elements': [
                {
                  'id': 'p${i}_photo',
                  'kind': 'photo',
                  'x': .05 + (i % 6) * .05,
                  'y': .05 + (i ~/ 6) * .025,
                  'width': .3 + (i % 5) * .07,
                  'height': .22 + ((i ~/ 5) % 4) * .06,
                  'color': '#DDECE4',
                  'style': 'none',
                  'rotation': 0,
                  'zIndex': 10,
                  'text': null,
                  'typography': null,
                  'align': null,
                },
              ],
            },
        ];
  return {
    'version': 3,
    'concept': plan['concept'],
    'rationale': plan['rationale'],
    'aspect': brief?.aspect.name ?? source['aspect'],
    if (brief?.printProductId != null)
      'printProduct': brief!.coverSize.printProduct,
    'generation': {
      'strategy': 'original_spread_batches_v1',
      'pageCount': count,
    },
    'artDirection': plan,
    'pages': [
      for (final (i, page) in pages.indexed)
        {
          ...Map<String, Object?>.from(page as Map),
          'role': (planned[i] as Map)['role'],
          'purpose': (planned[i] as Map)['intent'],
        },
    ],
  };
}

AlbumRecommendationDraft originalTemplateDraft(AiTemplateBrief brief) {
  final design = AiTemplateDesign.fromJson(
    originalTemplateDesignJson(brief: brief),
    brief.pageCount,
  );
  return AlbumRecommendationDraft(
    draftId: 'original-v3-test-only',
    theme: AlbumTheme.custom,
    title: design.concept,
    pageCount: brief.pageCount,
    templateTone: design.concept,
    summary: design.rationale,
    design: design,
    recommendedPhotos: const [],
    excludedPhotos: const [],
    storySections: const [],
    templateSlots: [
      for (final (i, page) in design.pages.indexed)
        for (final e in page.elements.where((e) => e.kind == 'photo'))
          AiTemplateSlot(
            slotId: e.id,
            pageIndex: i,
            role: i == 0 ? 'cover' : 'photo',
            hint: page.purpose,
          ),
    ],
    reviewCtaLabel: '이 디자인 사용',
  );
}
