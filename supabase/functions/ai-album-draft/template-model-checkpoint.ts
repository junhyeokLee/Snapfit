import type { TemplateBrief } from "./template-design.ts";
import { bookBatches, type BookModelRequest } from "./template-book-engine.ts";

export type TemplateModelCheckpoint = {
  version: 1;
  context: string;
  briefHash: string;
  resumeCount: number;
  responses: { fingerprint: string; output: unknown }[];
};

export async function templateCheckpointHash(value: unknown): Promise<string> {
  const bytes = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(JSON.stringify(value)),
  );
  return [...new Uint8Array(bytes)].map((n) => n.toString(16).padStart(2, "0"))
    .join("");
}

// Replay exact model responses through the full engine again. This preserves
// quality-repair budgets and review decisions instead of trusting cached pages.
export async function createTemplateModelCheckpoint(
  brief: TemplateBrief,
  modelContext: string,
  resume?: TemplateModelCheckpoint,
  onCheckpoint?: (checkpoint: TemplateModelCheckpoint) => void | Promise<void>,
  onReplay?: () => void,
) {
  const context = `normalized-original-book-v1:${modelContext}`;
  const briefHash = await templateCheckpointHash(brief);
  const limit = bookBatches(brief.pageCount).length + 7;
  if (
    resume && (
      resume.version !== 1 || resume.context !== context ||
      resume.briefHash !== briefHash ||
      !Number.isInteger(resume.resumeCount) || resume.resumeCount < 0 ||
      resume.resumeCount >= 3 ||
      !Array.isArray(resume.responses) || resume.responses.length > limit ||
      JSON.stringify(resume).length > 2_000_000 ||
      resume.responses.some((entry) =>
        !/^[a-f0-9]{64}$/.test(entry.fingerprint)
      ) ||
      new Set(resume.responses.map((entry) => entry.fingerprint)).size !==
        resume.responses.length
    )
  ) throw new Error("template_checkpoint_invalid");
  const responses = new Map(
    (resume?.responses ?? []).map((
      entry,
    ) => [entry.fingerprint, structuredClone(entry.output)]),
  );
  const resumeCount = resume ? resume.resumeCount + 1 : 0;
  let persistence = Promise.resolve();
  if (resume) {
    await onCheckpoint?.({
      ...structuredClone(resume),
      resumeCount,
    });
  }
  return async (
    job: BookModelRequest,
    generate: () => Promise<unknown>,
  ): Promise<unknown> => {
    const fingerprint = await templateCheckpointHash(job);
    if (responses.has(fingerprint)) {
      onReplay?.();
      return structuredClone(responses.get(fingerprint));
    }
    const output = await generate();
    responses.set(fingerprint, structuredClone(output));
    const checkpoint: TemplateModelCheckpoint = {
      version: 1,
      context,
      briefHash,
      resumeCount,
      responses: [...responses].map(([fingerprint, output]) => ({
        fingerprint,
        output,
      })),
    };
    if (
      checkpoint.responses.length > limit ||
      JSON.stringify(checkpoint).length > 2_000_000
    ) {
      throw new Error("template_checkpoint_limit");
    }
    persistence = persistence.then(() =>
      onCheckpoint?.(structuredClone(checkpoint))
    );
    await persistence;
    return output;
  };
}
