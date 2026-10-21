import materials from "./composition-contract.json" with { type: "json" };
import typography from "./typography-contract.json" with { type: "json" };
import {
  validateEditorialBook,
  validateEditorialPage,
  validateEditorialPlan,
} from "./template-editorial-quality.ts";
import {
  type ArtDirection,
  type TypeRole,
  type TypeStyle,
  validateArtDirection,
} from "./template-art-direction.ts";
import {
  color,
  finite,
  luminance,
  object,
  shortText,
  type TemplateBrief,
  templateCanvasHeight,
} from "./template-design.ts";

export type OriginalBookPlan = ArtDirection & {
  intent: {
    understanding: string;
    mood: string[];
    avoid: string[];
    verbatim: string[];
    density: "quiet" | "balanced" | "layered";
  };
  materials: { frames: string[]; papers: string[] };
  compositions: string[];
};
export type CompositionElement = {
  id: string;
  kind: "photo" | "text" | "paper";
  x: number;
  y: number;
  width: number;
  height: number;
  color: string;
  style: string;
  rotation: number;
  zIndex: number;
  text: string | null;
  typography: TypeRole | null;
  align: "left" | "center" | "right" | null;
};
export type CompositionPage = {
  pageIndex: number;
  role: string;
  purpose: string;
  background: string;
  elements: CompositionElement[];
};
export type OriginalBook = {
  version: 3;
  concept: string;
  rationale: string;
  aspect: TemplateBrief["aspect"];
  printProduct?: TemplateBrief["printProduct"];
  artDirection: OriginalBookPlan;
  pages: CompositionPage[];
  generation: { strategy: "original_spread_batches_v1"; pageCount: number };
};

export class CompositionValidationError extends Error {
  constructor(
    code: string,
    readonly pageIndex: number,
    readonly elementIndex?: number,
  ) {
    super(code);
    this.name = "CompositionValidationError";
  }
}

function withCompositionContext<T>(
  pageIndex: number,
  elementIndex: number | undefined,
  validate: () => T,
): T {
  try {
    return validate();
  } catch (error) {
    if (error instanceof CompositionValidationError) throw error;
    if (error instanceof Error) {
      throw new CompositionValidationError(
        error.message,
        pageIndex,
        elementIndex,
      );
    }
    throw error;
  }
}

function texts(value: unknown, max: number, length: number): string[] {
  if (!Array.isArray(value) || value.length > max) {
    throw new Error("template_intent_invalid_list");
  }
  const result = value.map((v) => shortText(v, length));
  if (new Set(result).size !== result.length) {
    throw new Error("template_intent_duplicate");
  }
  return result;
}

export function quotedPhrases(prompt: string): string[] {
  const phrases = [...prompt.matchAll(/["“「『‘]([^"”」』’\n]+)["”」』’]/gu)]
    .map((m) => m[1].trim()).filter(Boolean);
  if (phrases.some((text) => text.length > 160) || new Set(phrases).size > 8) {
    throw new Error("template_intent_verbatim_limit");
  }
  return [...new Set(phrases)];
}

export function validateOriginalPlan(
  value: unknown,
  brief: TemplateBrief,
): OriginalBookPlan {
  const raw = object(value), base = validateArtDirection(raw, brief);
  const intent = object(raw.intent), kit = object(raw.materials);
  const verbatim = texts(intent.verbatim, 8, 160);
  const requestedCopy = quotedPhrases(brief.prompt);
  if (
    verbatim.some((v) => !brief.prompt.includes(v)) ||
    requestedCopy.some((v) => !verbatim.includes(v))
  ) {
    throw new Error("template_intent_verbatim_drift");
  }
  if (!["quiet", "balanced", "layered"].includes(String(intent.density))) {
    throw new Error("template_intent_density");
  }
  const frames = texts(kit.frames, materials.limits.maxPlanMaterials, 40);
  const papers = texts(kit.papers, materials.limits.maxPlanMaterials, 40);
  if (
    frames.some((f) => !Object.hasOwn(materials.frames, f)) ||
    papers.some((p) => !Object.hasOwn(materials.papers, p))
  ) {
    throw new Error("template_material_not_licensed");
  }
  const compositions = texts(raw.compositions, brief.pageCount + 1, 180);
  if (compositions.length !== brief.pageCount + 1) {
    throw new Error("template_plan_incomplete");
  }
  const plan: OriginalBookPlan = {
    ...base,
    intent: {
      understanding: shortText(intent.understanding, 400),
      mood: texts(intent.mood, 6, 60),
      avoid: texts(intent.avoid, 8, 120),
      verbatim,
      density: intent.density as OriginalBookPlan["intent"]["density"],
    },
    materials: { frames, papers },
    compositions,
  };
  validateEditorialPlan(plan);
  return plan;
}

type Box = { x: number; y: number; width: number; height: number };
function right(b: Box) {
  return b.x + b.width;
}
function bottom(b: Box) {
  return b.y + b.height;
}
function intersects(a: Box, b: Box) {
  return Math.min(right(a), right(b)) - Math.max(a.x, b.x) > .001 &&
    Math.min(bottom(a), bottom(b)) - Math.max(a.y, b.y) > .001;
}
function contains(a: Box, b: Box) {
  return a.x <= b.x + .0001 && a.y <= b.y + .0001 &&
    right(a) >= right(b) - .0001 && bottom(a) >= bottom(b) - .0001;
}
function bounds(e: CompositionElement, brief: TemplateBrief): Box {
  const ratio = templateCanvasHeight(brief) / 500;
  const c = Math.cos(e.rotation), s = Math.abs(Math.sin(e.rotation));
  const w = e.width * c + e.height * ratio * s;
  const h = e.height * c + e.width / ratio * s;
  return {
    x: e.x + (e.width - w) / 2,
    y: e.y + (e.height - h) / 2,
    width: w,
    height: h,
  };
}
function contrast(a: string, b: string) {
  const x = luminance(a), y = luminance(b);
  return (Math.max(x, y) + .05) / (Math.min(x, y) + .05);
}

export const compositionCharacterWidthUnits = {
  space: .32,
  ascii: .62,
  otherIncludingHangul: 1,
} as const;

/** Same conservative reference metrics used by the generation prompt and gate. */
export function compositionTextMetrics(
  text: string,
  width: number,
  style: Pick<TypeStyle, "fontSize" | "lineHeight">,
  brief: TemplateBrief,
) {
  const units = (line: string) =>
    [...line].reduce(
      (n, c) =>
        n + (c === " "
          ? compositionCharacterWidthUnits.space
          : /[\x00-\x7f]/.test(c)
          ? compositionCharacterWidthUnits.ascii
          : compositionCharacterWidthUnits.otherIncludingHangul),
      0,
    );
  const capacityUnitsPerLine = width * 500 / style.fontSize;
  const lineCount = text.split("\n").reduce(
    (n, line) => n + Math.max(1, Math.ceil(units(line) / capacityUnitsPerLine)),
    0,
  );
  const requiredHeightPixels = lineCount * style.fontSize * style.lineHeight;
  return {
    capacityUnitsPerLine,
    lineCount,
    lineHeightNormalized: style.fontSize * style.lineHeight /
      templateCanvasHeight(brief),
    requiredHeightPixels,
    requiredHeightNormalized: requiredHeightPixels /
      templateCanvasHeight(brief),
  };
}

function coveredFraction(photo: Box, overlays: Box[]): number {
  const clipped = overlays.filter((o) => intersects(photo, o));
  if (!clipped.length) return 0;
  const xs = [
    ...new Set([
      photo.x,
      right(photo),
      ...clipped.flatMap(
        (o) => [Math.max(photo.x, o.x), Math.min(right(photo), right(o))],
      ),
    ]),
  ].sort((a, b) => a - b);
  const ys = [
    ...new Set([
      photo.y,
      bottom(photo),
      ...clipped.flatMap(
        (o) => [Math.max(photo.y, o.y), Math.min(bottom(photo), bottom(o))],
      ),
    ]),
  ].sort((a, b) => a - b);
  let area = 0;
  for (let x = 1; x < xs.length; x++) {
    for (let y = 1; y < ys.length; y++) {
      const cx = (xs[x - 1] + xs[x]) / 2, cy = (ys[y - 1] + ys[y]) / 2;
      if (
        clipped.some((o) =>
          cx >= o.x && cx <= right(o) && cy >= o.y && cy <= bottom(o)
        )
      ) {
        area += (xs[x] - xs[x - 1]) * (ys[y] - ys[y - 1]);
      }
    }
  }
  return area / (photo.width * photo.height);
}

export function compositionSignature(page: CompositionPage): string {
  const photos = page.elements.filter((e) => e.kind === "photo");
  const content = photos.length
    ? photos
    : page.elements.filter((e) => e.kind === "text");
  // Color, material swaps and tiny coordinate jitter cannot disguise a duplicate layout.
  const signature = (mirror: boolean) =>
    content.map((e) =>
      [mirror ? 1 - e.x - e.width : e.x, e.y, e.width, e.height]
        .map((v) => Math.round(v * 20)).join(",")
    ).sort().join(";");
  return [signature(false), signature(true)].sort()[0];
}

export function validateCompositionBatch(
  value: unknown,
  indexes: number[],
  brief: TemplateBrief,
  plan: OriginalBookPlan,
): CompositionPage[] {
  const raw = object(value);
  if (!Array.isArray(raw.pages) || raw.pages.length !== indexes.length) {
    throw new Error("template_batch_incomplete");
  }
  const ids = new Set<string>();
  return raw.pages.map((value, offset) => {
    const index = indexes[offset];
    return withCompositionContext(index, undefined, () => {
      const page = object(value),
        planned = plan.pages[index];
      if (page.pageIndex !== index) {
        throw new Error("template_batch_page_order");
      }
      const background = color(page.background);
      if (!plan.palette.includes(background)) {
        throw new Error("template_design_palette_drift");
      }
      if (
        !Array.isArray(page.elements) || !page.elements.length ||
        page.elements.length > materials.limits.maxElements
      ) {
        throw new Error("template_design_element_count");
      }
      const elements = page.elements.map((
        value,
        elementIndex,
      ): CompositionElement =>
        withCompositionContext(index, elementIndex, () => {
          const e = object(value), id = shortText(e.id, 64);
          const allowed = [
            "id",
            "kind",
            "x",
            "y",
            "width",
            "height",
            "color",
            "style",
            "rotation",
            "zIndex",
            "text",
            "typography",
            "align",
          ];
          if (
            Object.keys(e).some((k) => !allowed.includes(k)) ||
            !id.startsWith(`p${index}_`) || ids.has(id)
          ) {
            throw new Error("template_design_element_identity");
          }
          ids.add(id);
          if (!["photo", "text", "paper"].includes(String(e.kind))) {
            throw new Error("template_design_element_kind");
          }
          const result: CompositionElement = {
            id,
            kind: e.kind as CompositionElement["kind"],
            x: finite(e.x, 0, 1),
            y: finite(e.y, 0, 1),
            width: finite(e.width, .01, 1),
            height: finite(e.height, .005, 1),
            color: color(e.color),
            style: shortText(e.style, 40),
            rotation: finite(
              e.rotation,
              -materials.limits.maxRotation,
              materials.limits.maxRotation,
            ),
            zIndex: finite(e.zIndex, 1, 99),
            text: null,
            typography: null,
            align: null,
          };
          if (!Number.isInteger(result.zIndex)) {
            throw new Error("template_design_stacking");
          }
          const box = bounds(result, brief);
          if (
            box.x < -.0001 || box.y < -.0001 || right(box) > 1.0001 ||
            bottom(box) > 1.0001
          ) {
            throw new Error("template_design_out_of_bounds");
          }
          if (result.kind === "photo") {
            if (
              !plan.materials.frames.includes(result.style) ||
              result.width < .18 ||
              result.height < .14
            ) {
              throw new Error("template_design_photo_frame");
            }
          } else if (!plan.palette.includes(result.color)) {
            throw new Error("template_design_palette_drift");
          }
          if (
            result.kind === "paper" &&
            !plan.materials.papers.includes(result.style)
          ) {
            throw new Error("template_material_not_licensed");
          }
          if (result.kind === "text") {
            const role = shortText(e.typography, 16) as TypeRole;
            const style = plan.typography[role];
            if (
              !style || !materials.textStyles.includes(result.style) ||
              result.rotation !== 0 ||
              !["left", "center", "right"].includes(String(e.align))
            ) throw new Error("template_design_typography_role");
            result.text = shortText(e.text, 160);
            result.typography = role;
            result.align = e.align as CompositionElement["align"];
            if (
              box.x < .04 || box.y < .04 || right(box) > .96 ||
              bottom(box) > .96
            ) throw new Error("template_design_text_safe_area");
            if (
              /[\u1100-\u11ff\u3130-\u318f\uac00-\ud7a3]/u.test(result.text) &&
              !typography.fonts[style.fontFamily].hangul
            ) {
              throw new Error("template_design_font_script");
            }
            const metrics = compositionTextMetrics(
              result.text,
              result.width,
              style,
              brief,
            );
            if (
              metrics.requiredHeightPixels >
                result.height * templateCanvasHeight(brief) + 1
            ) throw new Error("template_design_text_overflow");
          } else if (
            e.text != null || e.typography != null || e.align != null
          ) {
            throw new Error("template_design_nontext_content");
          }
          return result;
        })
      ).sort((a, b) => a.zIndex - b.zIndex);
      if (new Set(elements.map((e) => e.zIndex)).size !== elements.length) {
        throw new Error("template_design_stacking");
      }
      const photos = elements.filter((e) => e.kind === "photo"),
        texts = elements.filter((e) => e.kind === "text");
      if (
        photos.length !== planned.photoCount ||
        (!photos.length && !texts.length)
      ) throw new Error("template_design_photo_plan_drift");
      for (const text of texts) {
        const box = bounds(text, brief);
        if (
          elements.some((e) =>
            e.zIndex > text.zIndex && intersects(box, bounds(e, brief))
          )
        ) throw new Error("template_design_text_occluded");
        const behind = elements.filter((e) =>
          e.zIndex < text.zIndex && intersects(box, bounds(e, brief))
        );
        const uncertain = behind.some((e) =>
          e.kind === "photo" || (e.kind === "paper" && e.style !== "rect")
        );
        const backing = behind.findLast((e) =>
          e.kind === "paper" && e.style === "rect" && e.rotation === 0 &&
          contains(e, box)
        );
        const backingOnTop = backing &&
          behind.every((e) => e === backing || e.zIndex < backing.zIndex);
        const outlinedTitle = text.style === "outline" &&
          plan.typography[text.typography!].fontSize >= 32;
        if (uncertain && !backingOnTop && !outlinedTitle) {
          throw new Error("template_design_text_needs_backing");
        }
        if (!uncertain || backingOnTop) {
          for (
            const color of [
              backingOnTop ? backing.color : background,
              ...behind.filter((e) =>
                e.kind === "paper" && e.style === "rect" &&
                (!backingOnTop || e.zIndex >= backing.zIndex)
              ).map((e) => e.color),
            ]
          ) {
            if (contrast(text.color, color) < 4.5) {
              throw new Error("template_design_low_contrast");
            }
          }
        }
      }
      for (const photo of photos) {
        const overlays = elements.filter((e) => e.zIndex > photo.zIndex).map(
          (e) => bounds(e, brief),
        );
        if (
          coveredFraction(bounds(photo, brief), overlays) >
            1 - materials.limits.minimumVisiblePhoto + .0001
        ) {
          throw new Error("template_design_photo_occluded");
        }
      }
      const composed = {
        pageIndex: index,
        role: planned.role,
        purpose: planned.intent,
        background,
        elements,
      };
      validateEditorialPage(composed, plan);
      return composed;
    });
  });
}

export function validateOriginalBook(
  pages: CompositionPage[],
  brief: TemplateBrief,
  plan: OriginalBookPlan,
): OriginalBook {
  if (
    pages.length !== brief.pageCount + 1 ||
    Array.from({ length: brief.pageCount + 1 }, (_, i) => pages[i])
      .some((p, i) => !p || p.pageIndex !== i)
  ) throw new Error("template_book_incomplete");
  const signatures = new Map<string, number>();
  for (const page of pages.slice(1)) {
    const signature = compositionSignature(page),
      previous = signatures.get(signature);
    if (previous !== undefined) {
      throw new Error(
        `template_book_repeated_page:${page.pageIndex}:${previous}`,
      );
    }
    signatures.set(signature, page.pageIndex);
  }
  const copy = pages.flatMap((p) =>
    p.elements.filter((e) => e.kind === "text").map((e) => e.text!)
  );
  if (plan.intent.verbatim.some((text) => !copy.includes(text))) {
    throw new Error("template_book_missing_verbatim");
  }
  const dates = copy.flatMap((text) =>
    [...text.matchAll(
      /\b20\d{2}(?:[.\/-]\d{1,2}(?:[.\/-]\d{1,2})?\b|년\s*\d{1,2}월(?:\s*\d{1,2}일)?)/gu,
    )].map(
      (m) => m[0],
    )
  );
  if (dates.some((date) => !brief.prompt.includes(date))) {
    throw new Error("template_book_invented_date");
  }
  validateEditorialBook(pages, plan);
  return {
    version: 3,
    concept: plan.concept,
    rationale: plan.rationale,
    aspect: brief.aspect,
    ...(brief.printProduct ? { printProduct: brief.printProduct } : {}),
    artDirection: plan,
    pages,
    generation: {
      strategy: "original_spread_batches_v1",
      pageCount: brief.pageCount,
    },
  };
}

export { materials as compositionContract };
