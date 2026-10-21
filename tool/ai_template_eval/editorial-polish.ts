import {
  compositionContract,
  type OriginalBook,
  validateCompositionBatch,
  validateOriginalBook,
  validateOriginalPlan,
} from "../../supabase/functions/ai-album-draft/template-composition.ts";
import {
  shortText,
  type TemplateBrief,
} from "../../supabase/functions/ai-album-draft/template-design.ts";

export type EditorialEdits = {
  reason: string;
  displayWeight?: number;
  frames?: Record<string, string>;
  texts?: Record<string, string>;
};

// Explicit post-generation edits, never presented as a new model response.
export function polishEditorialBook(
  source: OriginalBook,
  brief: TemplateBrief,
  edits: EditorialEdits,
): OriginalBook {
  shortText(edits.reason, 1000);
  const book = structuredClone(source);
  if (edits.displayWeight !== undefined) {
    book.artDirection.typography.display.weight = edits.displayWeight;
  }
  for (const [from, to] of Object.entries(edits.frames ?? {})) {
    if (
      !Object.hasOwn(compositionContract.frames, from) ||
      !Object.hasOwn(compositionContract.frames, to)
    ) throw Error("template_material_not_licensed");
  }
  book.artDirection.materials.frames = [
    ...new Set(
      book.artDirection.materials.frames.map((style) =>
        edits.frames?.[style] ?? style
      ),
    ),
  ];
  const remainingTexts = new Set(Object.keys(edits.texts ?? {}));
  for (const page of book.pages) {
    for (const element of page.elements) {
      if (element.kind === "photo") {
        element.style = edits.frames?.[element.style] ?? element.style;
      }
      if (
        element.kind === "text" && Object.hasOwn(edits.texts ?? {}, element.id)
      ) {
        element.text = shortText(edits.texts![element.id], 160);
        remainingTexts.delete(element.id);
      }
    }
  }
  if (remainingTexts.size) throw Error("template_editorial_unknown_element");
  const plan = validateOriginalPlan(book.artDirection, brief);
  const pages = validateCompositionBatch(
    { pages: book.pages },
    book.pages.map((p) => p.pageIndex),
    brief,
    plan,
  );
  return validateOriginalBook(pages, brief, plan);
}

if (import.meta.main) {
  const [source, destination, editsFile] = Deno.args;
  if (!source || !destination || !editsFile) {
    throw Error("Pass source run, output directory and explicit edits JSON");
  }
  const report = JSON.parse(await Deno.readTextFile(source));
  if (
    report.mode !== "live" || report.results.length !== 1 ||
    report.results[0].status !== "accepted"
  ) throw Error("An accepted actual model run is required");
  const edits = JSON.parse(
    await Deno.readTextFile(editsFile),
  ) as EditorialEdits;
  report.results[0].document = polishEditorialBook(
    report.results[0].document,
    report.results[0].brief,
    edits,
  );
  report.agentRefinements = { sourceRun: source, edits, humanApproval: false };
  report.summary.aestheticVerdict = "agent_refined_pending_human_review";
  report.id = destination.split("/").filter(Boolean).at(-1);
  await Deno.mkdir(destination, { recursive: true, mode: 0o700 });
  await Deno.writeTextFile(
    `${destination}/run.json`,
    JSON.stringify(report, null, 2),
    { mode: 0o600 },
  );
  console.log(`${destination}/run.json`);
}
