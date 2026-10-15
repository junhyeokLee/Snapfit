import { MAX_AI_DESIGN_PAGES, type TemplateDesign } from "./template-design.ts";
import type { DirectedTemplateDesign } from "./template-art-direction.ts";

/** Expand only a validated design. No extra model requests or invented artwork. */
export function expandTemplatePages(
  design: TemplateDesign | DirectedTemplateDesign,
  finalPageCount: number,
): TemplateDesign | DirectedTemplateDesign {
  const sourcePageCount = design.pages.length - 1;
  if (finalPageCount === sourcePageCount) return design;
  if (
    sourcePageCount < 4 || sourcePageCount > MAX_AI_DESIGN_PAGES ||
    sourcePageCount % 2 !== 0 || !Number.isInteger(finalPageCount) ||
    finalPageCount < 20 || finalPageCount > 80 || finalPageCount % 2 !== 0
  ) {
    throw new Error("template_expansion_invalid_page_count");
  }
  // Retain the cover, opener and initial reading sequence. Insert complete
  // pairs from the middle before the original closing page, preserving parity.
  const indexes = Array.from({ length: sourcePageCount }, (_, index) => index);
  const middleCount = sourcePageCount - 2;
  for (let extra = 0; extra < finalPageCount - sourcePageCount; extra++) {
    indexes.push(2 + extra % middleCount);
  }
  indexes.push(sourcePageCount);
  const layoutExpansion = {
    strategy: "repeat_inner_layouts_v1" as const,
    sourcePageCount,
    finalPageCount,
  };
  // Rename all elements, including originals, so arbitrary model IDs cannot
  // collide with generated IDs. Every photo frame remains independently editable.
  const pages = indexes.map((sourceIndex, pageIndex) => ({
    ...design.pages[sourceIndex],
    elements: design.pages[sourceIndex].elements.map((
      element,
      elementIndex,
    ) => ({
      ...element,
      id: `expanded_p${pageIndex}_e${elementIndex}`,
    })),
  }));
  if (design.version === 2) {
    return {
      ...design,
      layoutExpansion,
      pages: pages as DirectedTemplateDesign["pages"],
      artDirection: {
        ...design.artDirection,
        pages: indexes.map((index) => ({
          ...design.artDirection.pages[index],
        })),
      },
    };
  }
  return { ...design, layoutExpansion, pages };
}
