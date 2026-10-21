import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/album/ai_album/data/ai_template_device_store.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_template_paper_tone.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_template_text_edit.dart';
import '../fixtures/ai_template_local_edit_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (kIsWeb) return;
    await (FontLoader(
      'NotoSans',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))).load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'private memo survives reopening only for its account and has no photo cache',
    () async {
      final store = AiTemplateDeviceStore();
      const memo = '  개인 메모 원문\n이름·주소  ';
      await store.save('owner-A', {
        'memo': memo,
        'requestId': 'same-server-id',
        'safeDesign': const AiTemplateBrief(
          prompt: memo,
          pageCount: 24,
        ).toSafeDesignJson(),
      });
      expect((await AiTemplateDeviceStore().load('owner-A'))!['memo'], memo);
      expect(await store.load('owner-B'), isNull);
      final saved = (await store.load('owner-A'))!;
      expect(
        saved.keys,
        unorderedEquals(['version', 'memo', 'requestId', 'safeDesign']),
      );
      await store.remove('owner-A');
      expect(await store.load('owner-A'), isNull);
    },
  );
  test(
    'ordered saves retain the latest memo rather than an earlier debounce',
    () async {
      final store = AiTemplateDeviceStore();
      final writes = [
        store.save('owner', {'memo': 'first'}),
        store.save('owner', {'memo': 'latest'}),
      ];
      await Future.wait(writes);
      expect((await store.load('owner'))!['memo'], 'latest');
    },
  );
  test(
    'remove followed immediately by save preserves the new session',
    () async {
      final store = AiTemplateDeviceStore();
      await store.save('owner', {'memo': 'old'});
      final removal = store.remove('owner');
      final replacement = store.save('owner', {'memo': 'new'});
      await Future.wait([removal, replacement]);
      expect((await store.load('owner'))!['memo'], 'new');
    },
  );

  test(
    'text and paper edits restore against the same original without artwork changes',
    () {
      final original = localEditDesign();
      final text = withAiTemplateText(
        original,
        pageIndex: 0,
        elementId: 'text-0',
        text: '함께 걷던 날',
      )!;
      final edited = withAiTemplatePaperTone(
        original,
        AiTemplatePaperTone.warm,
        current: text,
      );
      final restored = restoreAiTemplateLocalEdits(
        original,
        aiTemplateLocalEdits(original, edited),
      );
      expect(restored.pages.first.elements.last.text, '함께 걷던 날');
      expect(restored.pages.first.background, edited.pages.first.background);
      for (var i = 0; i < original.pages.length; i++) {
        expect(
          restored.pages[i].elements.first,
          same(original.pages[i].elements.first),
        );
        expect(
          restored.pages[i].elements.last.rect,
          original.pages[i].elements.last.rect,
        );
        expect(
          restored.pages[i].elements.last.fontFamily,
          original.pages[i].elements.last.fontFamily,
        );
      }
      expect(restored.printProduct, same(original.printProduct));
      expect(
        restoreAiTemplateLocalEdits(original, {
          'paperTone': 'original',
          'texts': aiTemplateLocalEdits(original, edited)['texts'],
        }).pages.first.elements.last.text,
        '함께 걷던 날',
      );
    },
  );
  test(
    'wrong element identities and overflowing cached copy cannot alter a design',
    () {
      final original = localEditDesign();
      expect(
        () => restoreAiTemplateLocalEdits(original, {
          'texts': [
            {'page': 0, 'id': 'other-id', 'text': '새 문구'},
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => restoreAiTemplateLocalEdits(original, {
          'texts': [
            {
              'page': 0,
              'id': 'text-0',
              'text': List.filled(1000, '너무 긴 문구').join(),
            },
          ],
        }),
        throwsFormatException,
      );
      expect(original.pages.first.elements.last.text, '함께한 오후');
    },
  );
  test('oversized local sessions fail without writing preview data', () async {
    final store = AiTemplateDeviceStore();
    expect(
      () => store.save('owner', {'memo': 'x' * (4 * 1024 * 1024 + 1)}),
      throwsFormatException,
    );
    expect(await store.load('owner'), isNull);
  });
}
