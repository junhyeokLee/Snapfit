import { evaluationCases, originalBookCases, suiteVersion } from "./cases.ts";
import { type CaseResult, evaluateSuite, summarize } from "./evaluate.ts";
import {
  resolveTemplateModelConfig,
  type TemplateModelProviderName,
} from "../../supabase/functions/ai-album-draft/template-model-provider.ts";

type Mode = "live" | "fixture" | "list";
export function parseArgs(args: string[]) {
  let mode: Mode = "list", chosen: string | undefined, limit = 1;
  let modeSet = false, engine = 3;
  let provider: TemplateModelProviderName = "gemini", allowPaid = false;
  for (let i = 0; i < args.length; i++) {
    const flag = args[i];
    if (["--live", "--fixture", "--list"].includes(flag)) {
      if (modeSet) throw new Error("Choose one mode");
      mode = flag.slice(2) as Mode;
      modeSet = true;
    } else if (flag === "--provider") {
      const value = args[++i];
      if (value !== "gemini" && value !== "openai") {
        throw new Error("Provider must be gemini or openai");
      }
      provider = value;
    } else if (flag === "--allow-paid") {
      allowPaid = true;
    } else if (flag === "--engine") {
      const value = args[++i];
      if (value !== "2" && value !== "3") {
        throw new Error("Engine must be 2 or 3");
      }
      engine = Number(value);
    } else if (flag === "--case") {
      chosen = args[++i];
      if (!chosen) throw new Error("Missing case id");
    } else if (flag === "--max-cases") {
      const value = args[++i];
      if (!/^\d+$/.test(value ?? "")) throw new Error("Invalid case limit");
      limit = Number(value);
    } else throw new Error(`Unknown argument: ${flag}`);
  }
  if (limit < 1 || limit > evaluationCases.length) {
    throw new Error("Case limit must be 1..18");
  }
  if (chosen && !evaluationCases.some((c) => c.id === chosen)) {
    throw new Error("Unknown case id");
  }
  if (mode !== "live" && (chosen || limit !== 1)) {
    throw new Error("Case selection applies to live mode only");
  }
  if (provider !== "gemini" && mode === "live" && !allowPaid) {
    throw new Error(
      "Paid providers require explicit --allow-paid; no calls made",
    );
  }
  return { mode, chosen, limit, engine, provider, allowPaid };
}
async function fingerprint() {
  const files = [
    "supabase/functions/ai-album-draft/index.ts",
    "supabase/functions/ai-album-draft/template-art-direction.ts",
    "supabase/functions/ai-album-draft/template-design.ts",
    "supabase/functions/ai-album-draft/typography-contract.json",
    "supabase/functions/ai-album-draft/composition-contract.json",
    "supabase/functions/ai-album-draft/template-composition.ts",
    "supabase/functions/ai-album-draft/template-book-engine.ts",
    "supabase/functions/ai-album-draft/template-editorial-quality.ts",
    "supabase/functions/ai-album-draft/template-model-provider.ts",
    "tool/ai_template_eval/cases.ts",
  ];
  const bytes = new TextEncoder().encode(
    (await Promise.all(
      files.map(async (p) => p + "\n" + await Deno.readTextFile(p)),
    )).join("\n"),
  );
  return [...new Uint8Array(await crypto.subtle.digest("SHA-256", bytes))].map(
    (n) => n.toString(16).padStart(2, "0"),
  ).join("");
}
async function main() {
  const args = parseArgs(Deno.args);
  const suite = args.engine === 3 ? originalBookCases : evaluationCases;
  if (args.mode === "list") {
    console.log(JSON.stringify(suite, null, 2));
    return;
  }
  const fixture = args.mode === "fixture"
    ? await import("./fixtures.ts")
    : null;
  const config = resolveTemplateModelConfig((key) => {
    if (key === "AI_TEMPLATE_PROVIDER") {
      return fixture ? "openai" : args.provider;
    }
    if (key === "AI_TEMPLATE_FREE_ONLY") {
      return String(!fixture && !args.allowPaid);
    }
    if (fixture) {
      if (key === "OPENAI_API_KEY") return "fixture-key";
      if (key === "AI_TEMPLATE_MODEL") return "fixture-no-model";
      return undefined;
    }
    return Deno.env.get(key);
  });
  const cases = fixture?.fixtureCases ??
    (args.chosen
      ? suite.filter((c) => c.id === args.chosen)
      : suite.slice(0, args.limit));
  const id = `${args.mode}-${new Date().toISOString().replace(/[:.]/g, "-")}-${
    crypto.randomUUID().slice(0, 8)
  }`;
  const out = `output/ai-template-evaluations/${id}`;
  await Deno.mkdir(out, { recursive: true, mode: 0o700 });
  const report = {
    schemaVersion: 1,
    id,
    mode: args.mode,
    engine: fixture ? 2 : args.engine,
    suiteVersion,
    createdAt: new Date().toISOString(),
    provider: fixture ? "fixture" : config.provider,
    model: config.model,
    freeOnly: config.freeOnly,
    dataScope: "synthetic_briefs_only",
    sourceFingerprint: await fingerprint(),
    plannedCaseIds: cases.map((c) => c.id),
    results: [] as CaseResult[],
    summary: summarize([]),
  };
  const persist = async () => {
    report.summary = summarize(report.results);
    await Deno.writeTextFile(
      `${out}/run.tmp.json`,
      JSON.stringify(report, null, 2),
      { mode: 0o600 },
    );
    await Deno.rename(`${out}/run.tmp.json`, `${out}/run.json`);
  };
  await persist();
  await evaluateSuite(cases, {
    apiKey: config.apiKey,
    model: config.model,
    provider: config.provider,
    freeOnly: config.freeOnly,
    env: fixture ? () => undefined : (key) => Deno.env.get(key),
    fetchFor: (entry) => fixture ? fixture.fixtureFetcher(entry) : fetch,
    onResult: async (result) => {
      report.results.push(result);
      await persist();
      console.log(
        `${result.id}: ${result.status}${
          result.reason ? ` (${result.reason})` : ""
        }`,
      );
    },
  });
  console.log(`Report: ${out}/run.json`);
  if (
    args.mode === "live" && report.results.some((r) => r.status !== "accepted")
  ) Deno.exitCode = 1;
}
if (import.meta.main) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : "Evaluation failed");
    Deno.exitCode = 1;
  });
}
