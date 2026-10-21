import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_template_art_direction.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_template_paper_tone.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_template_text_edit.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_template_text_preflight.dart';
import '../fixtures/ai_template_local_edit_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Browser runs verify structure and interaction; native runs retain the
    // actual bundled-font measurements without waiting on browser FontLoader.
    if (kIsWeb) return;
    await (FontLoader(
      'NotoSans',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))).load();
  });

  test('paper adjustment preserves roles, artwork, metadata and original', () {
    final original = localEditDesign();
    final edited = withAiTemplatePaperTone(original, AiTemplatePaperTone.warm);
    expect(
      edited.pages.first.background,
      isNot(original.pages.first.background),
    );
    expect(
      edited.artDirection!.palette.length,
      original.artDirection!.palette.length,
    );
    expect(
      edited.artDirection!.palette.skip(1),
      original.artDirection!.palette.skip(1),
    );
    expect(edited.pages.first.elements, same(original.pages.first.elements));
    expect(edited.printProduct, same(original.printProduct));
    expect(original.pages.first.background, Colors.white);
    expect(
      withAiTemplatePaperTone(original, AiTemplatePaperTone.original),
      same(original),
    );
    final draft = localEditDraft(original);
    final adjustedDraft = withAiTemplateDesign(draft, edited);
    expect(adjustedDraft.draftId, draft.draftId);
    expect(adjustedDraft.templateSlots, same(draft.templateSlots));
    expect(adjustedDraft.curationNotes, same(draft.curationNotes));
    expect(adjustedDraft.requiresUserReview, isTrue);
    expect(adjustedDraft.alreadyCreatedAlbum, isFalse);
  });

  test('dark and deeper backgrounds are not recolored', () {
    final dark = localEditDesign(background: const Color(0xFF203D35));
    expect(withAiTemplatePaperTone(dark, AiTemplatePaperTone.warm), same(dark));
    final shared = localEditDesign(background: const Color(0xFFD4DEDC));
    expect(
      withAiTemplatePaperTone(shared, AiTemplatePaperTone.cool),
      same(shared),
    );
  });

  test(
    'shared white photo color stays original while paper gets a new palette entry',
    () {
      final original = _sharedWhitePhotoDesign();
      final current = withAiTemplateText(
        original,
        pageIndex: 0,
        elementId: 'text-0',
        text: '새로운 오후',
      )!;
      final edited = withAiTemplatePaperTone(
        original,
        AiTemplatePaperTone.warm,
        current: current,
      );
      expect(edited.pages.first.background, isNot(Colors.white));
      expect(
        edited.pages.first.elements.first,
        same(original.pages.first.elements.first),
      );
      expect(edited.pages.first.elements.first.color, Colors.white);
      expect(edited.pages.first.elements.last.text, '새로운 오후');
      expect(
        edited.pages.first.elements.last.color,
        original.pages.first.elements.last.color,
      );
      expect(
        edited.artDirection!.palette.take(
          original.artDirection!.palette.length,
        ),
        original.artDirection!.palette,
      );
      final palette = edited.artDirection!.palette;
      expect(palette.length, original.artDirection!.palette.length + 1);
      expect(palette, contains('#FFFFFF'));
      expect(palette.toSet().length, palette.length);
      expect(palette.length, lessThanOrEqualTo(6));
      expect(original.pages.first.background, Colors.white);
    },
  );

  test(
    'a full palette refuses shared-background recoloring without dropping edited copy',
    () {
      final original = _sharedWhitePhotoDesign(fullPalette: true);
      final current = withAiTemplateText(
        original,
        pageIndex: 0,
        elementId: 'text-0',
        text: '새로운 오후',
      )!;
      final edited = withAiTemplatePaperTone(
        original,
        AiTemplatePaperTone.warm,
        current: current,
      );
      expect(edited, same(current));
      expect(edited.pages.first.background, Colors.white);
      expect(edited.pages.first.elements.first.color, Colors.white);
      expect(edited.pages.first.elements.last.text, '새로운 오후');
      expect(edited.artDirection!.palette.length, 6);
    },
  );

  test('an unavailable paper role never drops previously edited copy', () {
    final original = localEditDesign(background: const Color(0xFF203D35));
    final text = withAiTemplateText(
      original,
      pageIndex: 0,
      elementId: 'text-0',
      text: '새로운 오후',
    )!;
    final unchanged = withAiTemplatePaperTone(
      original,
      AiTemplatePaperTone.warm,
      current: text,
    );
    expect(unchanged, same(text));
    expect(unchanged.pages.first.elements.last.text, '새로운 오후');
  });

  test(
    'text targets only the actual page and element, retaining all layout',
    () {
      final original = localEditDesign();
      final edited = withAiTemplateText(
        original,
        pageIndex: 1,
        elementId: 'text-1',
        text: '오늘의 기억',
      )!;
      expect(inspectAiTemplateText(edited), isEmpty);
      expect(edited.pages.first, same(original.pages.first));
      expect(
        edited.pages[1].elements.first,
        same(original.pages[1].elements.first),
      );
      final before = original.pages[1].elements.last,
          after = edited.pages[1].elements.last;
      expect(after.text, '오늘의 기억');
      expect(after.id, before.id);
      expect(after.rect, before.rect);
      expect(after.color, before.color);
      expect(after.fontFamily, before.fontFamily);
      expect(after.fontSize, before.fontSize);
      expect(after.weight, before.weight);
      expect(after.lineHeight, before.lineHeight);
      expect(after.align, before.align);
      expect(after.style, before.style);
      expect(after.rotation, before.rotation);
      expect(after.zIndex, before.zIndex);
    },
  );

  test('invalid IDs, empty and overflowing text are refused', () {
    final original = localEditDesign();
    expect(
      withAiTemplateText(
        original,
        pageIndex: 1,
        elementId: 'text-0',
        text: '문구',
      ),
      isNull,
    );
    expect(
      withAiTemplateText(
        original,
        pageIndex: 0,
        elementId: 'photo-0',
        text: '문구',
      ),
      isNull,
    );
    expect(
      withAiTemplateText(
        original,
        pageIndex: -1,
        elementId: 'text-0',
        text: '문구',
      ),
      isNull,
    );
    expect(
      withAiTemplateText(
        original,
        pageIndex: 0,
        elementId: 'text-0',
        text: '   ',
      ),
      isNull,
    );
    expect(
      withAiTemplateText(
        original,
        pageIndex: 0,
        elementId: 'text-0',
        text: List.filled(80, '기억').join(' '),
      ),
      isNull,
    );
    expect(original.pages.first.elements.last.text, '함께한 오후');
  });

  test('changing and restoring paper keeps independently edited copy', () {
    final original = localEditDesign();
    final text = withAiTemplateText(
      original,
      pageIndex: 0,
      elementId: 'text-0',
      text: '새로운 오후',
    )!;
    final warm = withAiTemplatePaperTone(
      original,
      AiTemplatePaperTone.warm,
      current: text,
    );
    final cool = withAiTemplatePaperTone(
      original,
      AiTemplatePaperTone.cool,
      current: warm,
    );
    final restored = withAiTemplatePaperTone(
      original,
      AiTemplatePaperTone.original,
      current: cool,
    );
    expect(warm.pages.first.elements.last.text, '새로운 오후');
    expect(cool.pages.first.elements.last.text, '새로운 오후');
    expect(restored.pages.first.elements.last.text, '새로운 오후');
    expect(restored.pages.first.background, original.pages.first.background);
    expect(restored.artDirection!.palette, original.artDirection!.palette);
  });
}

AiTemplateDesign _sharedWhitePhotoDesign({bool fullPalette = false}) {
  final source = localEditDesign();
  final direction = source.artDirection!;
  return copyAiTemplateDesign(
    source,
    pages: [
      for (final page in source.pages)
        AiTemplateDesignPage(
          background: page.background,
          purpose: page.purpose,
          elements: [
            AiTemplateDesignElement(
              id: page.elements.first.id,
              kind: 'photo',
              rect: page.elements.first.rect,
              color: Colors.white,
            ),
            ...page.elements.skip(1),
          ],
        ),
    ],
    artDirection: AiTemplateArtDirection(
      concept: direction.concept,
      rationale: direction.rationale,
      requirements: direction.requirements,
      palette: [
        ...direction.palette,
        if (fullPalette) ...['#0A0B0C', '#CCAA88', '#998877'],
      ],
      typography: direction.typography,
      pages: direction.pages,
    ),
  );
}
