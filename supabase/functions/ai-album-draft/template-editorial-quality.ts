import type {
  CompositionPage,
  OriginalBookPlan,
} from "./template-composition.ts";

/** Editorial targets, not an aesthetic score or a claim of print approval. */
export const editorialQuality = {
  version: "editable_editorial_v1",
  criteria: {
    typography_hierarchy:
      "Deliberate display/heading/body/caption hierarchy, natural Korean line breaks, restrained weights and enough breathing room. Quiet books should favor regular display weight unless the actual brief needs bold lettering.",
    spread_rhythm:
      "Cover, opening, development and ending form one book. Facing pages work together; alternate photographic scale, text-led pauses and galleries to suit this story. No numbered filler, mirror clones or merely shifted boxes.",
    photo_text_balance:
      "Photos and words each have a clear role. Keep editable photo windows useful for replacement, leave intentional negative space, and give the lead photograph prominence. Avoid text on likely faces; no photos are available to judge actual crops.",
    material_palette_coherence:
      "Every frame and paper supports the chosen mood and palette. Fixed material colors do not inherit the palette. A red/teal postcard is unsuitable for strictly green/white quiet direction; use neutral free materials rather than adding decoration to imply quality.",
    story_specificity:
      "Original copy responds to this particular brief, with one consistent voice and a meaningful ending. Avoid interchangeable slogans or repeated sentences. Preserve exact requested words, language and exclusions; never invent personal facts, names or dates.",
  },
  minimumTypeRatios: { displayToBody: 1.8, headingToBody: 1.2 },
  minimumBodyLineHeight: 1.2,
  // Rect panels/lines may be functional; patterned paper is more visually dense.
  paperBudget: {
    quiet: { all: 3, patterned: 1 },
    balanced: { all: 5, patterned: 2 },
    layered: { all: 8, patterned: 4 },
  },
  limits:
    "These are composition safeguards, not proof of premium quality. Respect an explicitly layered or typographic brief; do not convert every concept into minimalism. Never copy catalog geometry, add paid assets, flatten text into images, or claim rendered/physical inspection.",
} as const;

export type EditorialCriterion = keyof typeof editorialQuality.criteria;
export const editorialCriteria = Object.keys(
  editorialQuality.criteria,
) as EditorialCriterion[];

export class EditorialQualityError extends Error {
  constructor(code: string, readonly pageIndexes: number[]) {
    super(code);
    this.name = "EditorialQualityError";
  }
}

function hue(hex: string): number | undefined {
  const [r, g, b] = [1, 3, 5].map((i) =>
    parseInt(hex.slice(i, i + 2), 16) / 255
  );
  const max = Math.max(r, g, b), min = Math.min(r, g, b), delta = max - min;
  if (delta < .12) return undefined;
  const h = max === r
    ? (g - b) / delta
    : max === g
    ? (b - r) / delta + 2
    : (r - g) / delta + 4;
  return ((h * 60) % 360 + 360) % 360;
}

// These are the actual fixed airmail inks in studio_material.dart, not chosen
// colors. Check hue compatibility instead of pretending the frame is recolored.
const postcardInks = ["#BD524E", "#3D727A"];
export function validateEditorialPlan(plan: OriginalBookPlan): void {
  const type = plan.typography;
  if (
    type.display.fontSize / type.body.fontSize <
      editorialQuality.minimumTypeRatios.displayToBody ||
    type.heading.fontSize / type.body.fontSize <
      editorialQuality.minimumTypeRatios.headingToBody
  ) throw new Error("template_editorial_type_hierarchy");
  if (type.body.lineHeight < editorialQuality.minimumBodyLineHeight) {
    throw new Error("template_editorial_body_leading");
  }
  if (
    plan.intent.density === "quiet" &&
    plan.materials.frames.includes("studioPostcard")
  ) {
    const paletteHues = plan.palette.map(hue).filter((h) => h !== undefined);
    if (
      postcardInks.some((ink) => {
        const inkHue = hue(ink)!;
        return !paletteHues.some((h) =>
          Math.min(Math.abs(h - inkHue), 360 - Math.abs(h - inkHue)) <= 30
        );
      })
    ) throw new Error("template_editorial_fixed_material_palette");
  }
}

export function validateEditorialPage(
  page: CompositionPage,
  plan: OriginalBookPlan,
): void {
  const paper = page.elements.filter((e) => e.kind === "paper");
  const budget = editorialQuality.paperBudget[plan.intent.density];
  if (
    paper.length > budget.all ||
    paper.filter((e) => e.style !== "rect").length > budget.patterned
  ) {
    throw new EditorialQualityError("template_editorial_material_density", [
      page.pageIndex,
    ]);
  }
}

export function validateEditorialBook(
  pages: CompositionPage[],
  plan: OriginalBookPlan,
): void {
  const seen = new Map<string, Set<number>>();
  const exactCopy = new Set(plan.intent.verbatim.map(normalizeCopy));
  for (const page of pages) {
    for (const element of page.elements) {
      if (element.kind !== "text" || !element.text) continue;
      const runningLabel = element.typography === "caption" &&
        element.height <= .06 &&
        (element.y <= .08 || element.y + element.height >= .92);
      if (runningLabel) continue;
      const copy = normalizeCopy(element.text);
      // Short folios, running labels and an explicitly requested repeated title
      // remain valid. Long generic filler cannot be hidden by changing numbers.
      if ([...copy].length < 14 || exactCopy.has(copy)) continue;
      const indexes = seen.get(copy) ?? new Set<number>();
      indexes.add(page.pageIndex);
      seen.set(copy, indexes);
      if (indexes.size > 2) {
        throw new EditorialQualityError(
          "template_editorial_repeated_copy",
          [
            ...indexes,
          ].slice(1),
        );
      }
    }
  }
}

function normalizeCopy(value: string): string {
  return value.normalize("NFKC").toLocaleLowerCase("ko-KR")
    .replace(/[\p{P}\p{Z}\s\d]/gu, "");
}
