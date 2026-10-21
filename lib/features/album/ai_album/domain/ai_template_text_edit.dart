import 'ai_album_models.dart';
import 'ai_template_paper_tone.dart';
import 'ai_template_text_preflight.dart';

/// Replaces one actual text element without altering its typography or geometry.
/// The current directed designs use bundled fonts validated by the same
/// preflight as generation. Legacy designs have no reliable typography contract.
AiTemplateDesign? withAiTemplateText(
  AiTemplateDesign design, {
  required int pageIndex,
  required String elementId,
  required String text,
}) {
  if (design.artDirection == null ||
      pageIndex < 0 ||
      pageIndex >= design.pages.length ||
      text.trim().isEmpty ||
      text.length > 2000)
    return null;
  final matches = design.pages[pageIndex].elements
      .where((element) => element.id == elementId && element.kind == 'text')
      .toList(growable: false);
  if (matches.length != 1) return null;
  final original = matches.single;
  final replacement = AiTemplateDesignElement(
    id: original.id,
    kind: original.kind,
    rect: original.rect,
    color: original.color,
    text: text.trim(),
    fontSize: original.fontSize,
    weight: original.weight,
    align: original.align,
    fontFamily: original.fontFamily,
    lineHeight: original.lineHeight,
    typographyRole: original.typographyRole,
    style: original.style,
    rotation: original.rotation,
    zIndex: original.zIndex,
  );
  final updated = copyAiTemplateDesign(
    design,
    pages: [
      for (final (index, page) in design.pages.indexed)
        if (index != pageIndex)
          page
        else
          AiTemplateDesignPage(
            background: page.background,
            purpose: page.purpose,
            elements: [
              for (final element in page.elements)
                if (identical(element, original)) replacement else element,
            ],
          ),
    ],
  );
  return inspectAiTemplateText(updated).isEmpty ? updated : null;
}
