import {
  type AiAlbumDraftHandlerOptions,
  handleAiAlbumDraftRequest as guarded,
} from "./index.ts";
import type { GenerationGuard } from "./generation-guard.ts";
import { editorialCriteria } from "./template-editorial-quality.ts";

// Explicit mock approval, never a real model or human quality verdict.
export function fixtureEditorialChecks(pageIndexes = [0]) {
  return editorialCriteria.map((criterion) => ({
    criterion,
    satisfied: true,
    evidencePageIndexes: pageIndexes,
    reason: `Synthetic fixture contract evidence for ${criterion}.`,
  }));
}

export function openAiContractEnv(apiKey: string) {
  const values: Record<string, string> = {
    AI_TEMPLATE_PROVIDER: "openai",
    AI_TEMPLATE_FREE_ONLY: "false",
    OPENAI_API_KEY: apiKey,
  };
  return (key: string) => values[key];
}

// Only provider-contract tests inject this fake. Production always verifies Auth/DB.
export const contractTestGuard: GenerationGuard = {
  authenticate: () => Promise.resolve("user"),
  reserve: () =>
    Promise.resolve({ id: "test-reservation", draftId: "guarded-test-draft" }),
  complete: () => Promise.resolve(),
  fail: () => Promise.resolve(),
};
export function handleAiAlbumDraftRequest(
  req: Request,
  options: AiAlbumDraftHandlerOptions = {},
) {
  return guarded(req, { guard: contractTestGuard, ...options });
}
