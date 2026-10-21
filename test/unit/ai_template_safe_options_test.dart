import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';

void main() {
  test('safe design contains only finite choices, format and page count', () {
    const brief = AiTemplateBrief(
      prompt: '  사용자 원문·주소·이름 그대로\n  ',
      pageCount: 24,
      aspect: AiTemplateAspect.landscape,
      printProductId: 'REDP_250X200_HARD',
      safeOptions: AiTemplateSafeOptions(
        topic: AiDesignTopic.family,
        mood: AiDesignMood.warm,
        palette: AiDesignPalette.pastel,
        density: AiDesignDensity.layered,
      ),
    );
    final safe = brief.toSafeDesignJson();
    expect(
      safe.keys,
      unorderedEquals([
        'version',
        'topic',
        'mood',
        'palette',
        'density',
        'pageCount',
        'aspect',
        'printProduct',
      ]),
    );
    expect(jsonEncode(safe), isNot(contains('사용자')));
    final restored = AiTemplateBrief.fromSafeDesign(
      safe,
      localMemo: brief.prompt,
    );
    expect(restored.prompt, brief.prompt);
    expect(restored.pageCount, 24);
    expect(restored.safeOptions.toJson(), brief.safeOptions.toJson());
    expect(restored.printProductId, brief.printProductId);
    expect(brief.publicBrief.prompt, brief.safeOptions.publicDescription);
    expect(brief.publicBrief.prompt, isNot(contains('사용자 원문·주소·이름 그대로')));
    expect(brief.publicBrief.expectedPointCost, brief.expectedPointCost);
  });
  test(
    'every finite option has a public description with no private input',
    () {
      for (final topic in AiDesignTopic.values) {
        for (final mood in AiDesignMood.values) {
          final options = AiTemplateSafeOptions(topic: topic, mood: mood);
          expect(
            AiTemplateSafeOptions.fromJson(options.toJson()).toJson(),
            options.toJson(),
          );
          expect(options.publicDescription, contains('개인정보 없는 공용 사진집'));
          expect(options.summary, isNotEmpty);
        }
      }
    },
  );
  test(
    'invalid count, unknown enum and mismatched print format are rejected',
    () {
      final safe = const AiTemplateBrief(
        prompt: '',
        pageCount: 20,
      ).toSafeDesignJson();
      for (final count in [8, 19, 21, 82]) {
        expect(
          () =>
              AiTemplateBrief(prompt: '', pageCount: count).toSafeDesignJson(),
          throwsFormatException,
        );
        expect(
          () => AiTemplateBrief.fromSafeDesign({...safe, 'pageCount': count}),
          throwsFormatException,
        );
      }
      expect(
        () => AiTemplateBrief.fromSafeDesign({
          ...safe,
          'topic': 'private arbitrary prompt',
        }),
        throwsA(anything),
      );
      expect(
        () => const AiTemplateBrief(
          prompt: '',
          pageCount: 20,
          printProductId: 'unrecognized',
        ).toSafeDesignJson(),
        throwsFormatException,
      );
      expect(
        () => const AiTemplateBrief(
          prompt: '',
          pageCount: 20,
          printProductId: 'REDP_250X200_HARD',
        ).toSafeDesignJson(),
        throwsFormatException,
      );
    },
  );
}
