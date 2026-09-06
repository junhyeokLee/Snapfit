import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { adminClient } from "../_shared/supabase.ts";

type AiPhotoRange =
  | "recent30Days"
  | "dateRange"
  | "album"
  | "manualSelection"
  | "limitedLibrary";
type AlbumTheme =
  | "couple"
  | "travel"
  | "family"
  | "baby"
  | "birthday"
  | "friends"
  | "daily"
  | "custom";
type PhotoOrientation = "portrait" | "landscape" | "square";
type AiAlbumDraftProviderName = "metadata" | "advanced" | "hybrid";

export type PhotoCandidatePayload = {
  assetId: string;
  createdAt: string;
  width: number;
  height: number;
  orientation: PhotoOrientation;
  albumName?: string | null;
  isScreenshot?: boolean;
  previewStorageUri?: string;
};

export type AiAlbumDraftRequestPayload = {
  theme: AlbumTheme;
  range: AiPhotoRange;
  candidates: PhotoCandidatePayload[];
};

type AiCurationReasonPayload = {
  type: string;
  message: string;
};

type RecommendedPhotoPayload = {
  assetId: string;
  score: number;
  reasons: AiCurationReasonPayload[];
};

type ExcludedPhotoPayload = {
  assetId: string;
  reasons: AiCurationReasonPayload[];
};

type StorySectionPayload = {
  title: string;
  description: string;
  photoAssetIds: string[];
};

export type AiAlbumDraftResponsePayload = {
  draftId: string;
  title: string;
  pageCount: number;
  templateTone: string;
  summary: string;
  recommendedPhotos: RecommendedPhotoPayload[];
  excludedPhotos: ExcludedPhotoPayload[];
  storySections: StorySectionPayload[];
  curationNotes: string[];
  requiresUserReview: true;
  alreadyCreatedAlbum: false;
  reviewCtaLabel: string;
  provider?: AiAlbumDraftProviderName;
  fallbackUsed?: boolean;
  fallbackReason?: string;
};

export type AiAlbumDraftProvider = (
  request: AiAlbumDraftRequestPayload,
) => Promise<AiAlbumDraftResponsePayload> | AiAlbumDraftResponsePayload;

type Fetcher = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

type AiAlbumDraftProviders = Partial<
  Record<AiAlbumDraftProviderName, AiAlbumDraftProvider>
>;

export type AiAlbumDraftHandlerOptions = {
  env?: (key: string) => string | undefined;
  providers?: AiAlbumDraftProviders;
  fetch?: Fetcher;
};

const minCandidateCount = 3;
const maxRecommendedPhotos = 12;
const defaultProviderTimeoutMs = 8000;

async function logOperationalEvent(event: {
  eventType: string;
  requestId?: string;
  provider?: string;
  metadata?: Record<string, unknown>;
}) {
  try {
    if (
      !Deno.env.get("SUPABASE_URL") ||
      !Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
    ) {
      return;
    }
    const { error } = await adminClient().from("ai_album_operational_events")
      .insert({
        event_type: event.eventType,
        request_id: event.requestId ?? null,
        provider: event.provider ?? null,
        metadata: event.metadata ?? {},
      });
    if (error) console.warn("operational_event_log_failed", error.message);
  } catch (error) {
    console.warn(
      "operational_event_log_failed",
      error instanceof Error ? error.message : String(error),
    );
  }
}

function text(value: unknown) {
  return String(value ?? "").trim();
}

function numberValue(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

function intValue(value: unknown, fallback: number) {
  const parsed = Number.parseInt(text(value), 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function parseBody(value: unknown): AiAlbumDraftRequestPayload {
  if (!value || typeof value !== "object") throw new Error("invalid_request");
  const body = value as Record<string, unknown>;
  const candidates = Array.isArray(body.candidates)
    ? body.candidates.map((item) => normalizeCandidate(item))
    : [];
  return {
    theme: normalizeTheme(body.theme),
    range: normalizeRange(body.range),
    candidates,
  };
}

function normalizeCandidate(value: unknown): PhotoCandidatePayload {
  if (!value || typeof value !== "object") throw new Error("invalid_candidate");
  const item = value as Record<string, unknown>;
  const assetId = text(item.assetId);
  if (!assetId) throw new Error("invalid_candidate");
  return {
    assetId,
    createdAt: text(item.createdAt) || new Date(0).toISOString(),
    width: numberValue(item.width),
    height: numberValue(item.height),
    orientation: normalizeOrientation(item.orientation),
    albumName: text(item.albumName) || null,
    isScreenshot: Boolean(item.isScreenshot),
    previewStorageUri: text(item.previewStorageUri) || undefined,
  };
}

function normalizeTheme(value: unknown): AlbumTheme {
  const theme = text(value) as AlbumTheme;
  const allowed = new Set<AlbumTheme>([
    "couple",
    "travel",
    "family",
    "baby",
    "birthday",
    "friends",
    "daily",
    "custom",
  ]);
  return allowed.has(theme) ? theme : "daily";
}

function normalizeRange(value: unknown): AiPhotoRange {
  const range = text(value) as AiPhotoRange;
  const allowed = new Set<AiPhotoRange>([
    "recent30Days",
    "dateRange",
    "album",
    "manualSelection",
    "limitedLibrary",
  ]);
  return allowed.has(range) ? range : "recent30Days";
}

function normalizeOrientation(value: unknown): PhotoOrientation {
  const orientation = text(value) as PhotoOrientation;
  return ["portrait", "landscape", "square"].includes(orientation)
    ? orientation
    : "square";
}

function normalizeProvider(value: unknown): AiAlbumDraftProviderName {
  const normalized = text(value).toLowerCase();
  if (normalized === "hybrid") return "hybrid";
  return normalized === "advanced" ? "advanced" : "metadata";
}

function isLowResolution(candidate: PhotoCandidatePayload) {
  return candidate.width < 900 || candidate.height < 900;
}

function themeTitle(theme: AlbumTheme) {
  const titles: Record<AlbumTheme, string> = {
    couple: "함께한 장면들",
    travel: "여행의 장면들",
    family: "가족의 장면들",
    baby: "아이의 장면들",
    birthday: "생일의 장면들",
    friends: "친구들과의 장면들",
    daily: "일상의 장면들",
    custom: "소중한 장면들",
  };
  return titles[theme];
}

function themeTone(theme: AlbumTheme) {
  const tones: Record<AlbumTheme, string> = {
    couple: "warm-romantic",
    travel: "warm-travel",
    family: "soft-family",
    baby: "gentle-baby",
    birthday: "bright-celebration",
    friends: "playful-friends",
    daily: "calm-daily",
    custom: "snapfit-custom",
  };
  return tones[theme];
}

function dateKey(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "앨범 흐름";
  return `${date.getMonth() + 1}월 ${date.getDate()}일`;
}

function groupSections(
  recommended: PhotoCandidatePayload[],
): StorySectionPayload[] {
  const grouped = new Map<string, string[]>();
  for (const candidate of recommended) {
    const key = dateKey(candidate.createdAt);
    grouped.set(key, [...(grouped.get(key) ?? []), candidate.assetId]);
  }
  return [...grouped.entries()].map(([title, photoAssetIds]) => ({
    title,
    description: "함께 보면 자연스러운 앨범 장면이에요",
    photoAssetIds,
  }));
}

export function buildDraftResponse(
  request: AiAlbumDraftRequestPayload,
): AiAlbumDraftResponsePayload {
  if (request.candidates.length < minCandidateCount) {
    throw new Error("insufficient_candidates");
  }

  const sorted = [...request.candidates].sort((a, b) =>
    text(a.createdAt).localeCompare(text(b.createdAt))
  );
  const recommended = sorted
    .filter((candidate) =>
      !candidate.isScreenshot && !isLowResolution(candidate)
    )
    .slice(0, maxRecommendedPhotos);
  const recommendedIds = new Set(
    recommended.map((candidate) => candidate.assetId),
  );
  if (recommended.length === 0) throw new Error("empty_recommended_photos");

  const excluded = sorted.filter((candidate) =>
    !recommendedIds.has(candidate.assetId)
  );
  return {
    draftId: `server-draft-${crypto.randomUUID()}`,
    title: themeTitle(request.theme),
    pageCount: Math.max(8, Math.min(24, recommended.length * 2 + 4)),
    templateTone: themeTone(request.theme),
    summary:
      "사진과 앨범 흐름을 먼저 정리했어요. 초안은 바로 확정되지 않고 편집 전에 확인할 수 있어요.",
    recommendedPhotos: recommended.map((candidate, index) => ({
      assetId: candidate.assetId,
      score: Math.max(0.6, 0.95 - index * 0.04),
      reasons: [
        {
          type: index === 0 ? "coverCandidate" : "dateFlow",
          message: index === 0
            ? "표지로 쓰기 좋은 대표 장면이에요"
            : "앨범 흐름을 자연스럽게 이어줘요",
        },
      ],
    })),
    excludedPhotos: excluded.map((candidate) => ({
      assetId: candidate.assetId,
      reasons: [
        {
          type: candidate.isScreenshot
            ? "screenshotExcluded"
            : isLowResolution(candidate)
            ? "lowResolutionExcluded"
            : "totalLimitExcluded",
          message: candidate.isScreenshot
            ? "스크린샷은 잠시 빼뒀어요"
            : isLowResolution(candidate)
            ? "작은 이미지는 출력 품질을 위해 잠시 빼뒀어요"
            : "초안이 너무 길어지지 않도록 잠시 빼뒀어요",
        },
      ],
    })),
    storySections: groupSections(recommended),
    curationNotes: [
      "서버 초안도 편집 전에 사용자가 확인해요.",
      request.range === "limitedLibrary"
        ? "허용된 사진 범위 안에서만 초안을 만들었어요."
        : "선택한 사진 범위 안에서 초안을 만들었어요.",
    ],
    requiresUserReview: true,
    alreadyCreatedAlbum: false,
    reviewCtaLabel: "이 구성으로 시작하기",
  };
}

function metadataProvider(request: AiAlbumDraftRequestPayload) {
  return buildDraftResponse(request);
}

function createAdvancedVisionProvider(
  env: (key: string) => string | undefined,
  fetcher: Fetcher,
): AiAlbumDraftProvider {
  return async (request) => {
    const apiKey = text(env("OPENAI_API_KEY"));
    const model = text(env("OPENAI_MODEL")) || "gpt-4o-mini";
    if (!apiKey) throw new Error("advanced_provider_not_configured");

    const previews = request.candidates
      .filter((candidate) => text(candidate.previewStorageUri))
      .slice(0, 8);
    if (previews.length === 0) throw new Error("advanced_preview_required");

    const imageContent = [] as Record<string, unknown>[];
    const previewUris = previews.map((candidate) =>
      candidate.previewStorageUri!
    );
    for (const candidate of previews) {
      imageContent.push({
        type: "text",
        text:
          `assetId=${candidate.assetId}; createdAt=${candidate.createdAt}; orientation=${candidate.orientation}; album=${
            candidate.albumName ?? ""
          }`,
      });
      imageContent.push({
        type: "image_url",
        image_url: {
          url: await previewDataUrl(candidate.previewStorageUri!, env, fetcher),
          detail: "low",
        },
      });
    }

    const modelResponse = await fetcher(
      "https://api.openai.com/v1/chat/completions",
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model,
          temperature: 0.35,
          response_format: { type: "json_object" },
          messages: [
            {
              role: "system",
              content:
                "You curate Korean photobook album drafts. Return only JSON. Never claim an album is created. Use only provided assetId values.",
            },
            {
              role: "user",
              content: [
                {
                  type: "text",
                  text: advancedPrompt(request),
                },
                ...imageContent,
              ],
            },
          ],
        }),
      },
    );
    if (!modelResponse.ok) throw new Error("advanced_model_failed");
    const payload = await modelResponse.json();
    const content = text(payload?.choices?.[0]?.message?.content);
    if (!content) throw new Error("advanced_model_empty_response");
    const draft = draftFromAdvancedJson(JSON.parse(content), request);
    await deletePreviewObjects(previewUris, env, fetcher);
    return draft;
  };
}

function createHybridProvider(
  env: (key: string) => string | undefined,
  fetcher: Fetcher,
): AiAlbumDraftProvider {
  return async (request) => {
    const openAiKey = text(env("OPENAI_API_KEY"));
    const anthropicKey = text(env("ANTHROPIC_API_KEY"));
    const openAiModel = text(env("OPENAI_MODEL")) || "gpt-4o";
    const anthropicModel = text(env("ANTHROPIC_MODEL")) || "claude-sonnet-4-5";
    if (!openAiKey || !anthropicKey) {
      throw new Error("hybrid_provider_not_configured");
    }

    const previews = request.candidates
      .filter((candidate) => text(candidate.previewStorageUri))
      .slice(0, 8);
    if (previews.length === 0) throw new Error("advanced_preview_required");
    const previewUris = previews.map((candidate) =>
      candidate.previewStorageUri!
    );

    const imageContent = [] as Record<string, unknown>[];
    for (const candidate of previews) {
      imageContent.push({
        type: "text",
        text:
          `assetId=${candidate.assetId}; createdAt=${candidate.createdAt}; orientation=${candidate.orientation}; album=${
            candidate.albumName ?? ""
          }`,
      });
      imageContent.push({
        type: "image_url",
        image_url: {
          url: await previewDataUrl(candidate.previewStorageUri!, env, fetcher),
          detail: "low",
        },
      });
    }

    const visionResponse = await fetcher(
      "https://api.openai.com/v1/chat/completions",
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${openAiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: openAiModel,
          temperature: 0.2,
          response_format: { type: "json_object" },
          messages: [
            {
              role: "system",
              content:
                "Return JSON photoInsights for Korean photobook curation. Use only provided assetId values.",
            },
            {
              role: "user",
              content: [
                {
                  type: "text",
                  text:
                    "For each preview, describe scene, mood, face/group feel if visible, print suitability, and cover/story potential as JSON {photoInsights:[...]}. Do not include private speculation.",
                },
                ...imageContent,
              ],
            },
          ],
        }),
      },
    );
    if (!visionResponse.ok) throw new Error("hybrid_vision_failed");
    const visionPayload = await visionResponse.json();
    const visionContent = text(visionPayload?.choices?.[0]?.message?.content);
    if (!visionContent) throw new Error("hybrid_vision_empty_response");
    const visionJson = JSON.parse(visionContent);

    const finalResponse = await fetcher(
      "https://api.anthropic.com/v1/messages",
      {
        method: "POST",
        headers: {
          "x-api-key": anthropicKey,
          "anthropic-version": "2023-06-01",
          "content-type": "application/json",
        },
        body: JSON.stringify({
          model: anthropicModel,
          max_tokens: 1400,
          temperature: 0.45,
          system:
            "You are a Korean photobook editor for Snapfit. Create emotionally strong, album-first draft JSON. Never claim the album is created. Use only provided assetId values.",
          messages: [
            {
              role: "user",
              content: JSON.stringify({
                instruction:
                  "Use the OpenAI vision photoInsights plus candidate metadata to choose a premium editable album draft. Return only the required JSON shape.",
                requiredJsonShape:
                  JSON.parse(advancedPrompt(request)).requiredJsonShape,
                theme: request.theme,
                range: request.range,
                candidates: request.candidates.map((candidate) => ({
                  assetId: candidate.assetId,
                  createdAt: candidate.createdAt,
                  width: candidate.width,
                  height: candidate.height,
                  orientation: candidate.orientation,
                  albumName: candidate.albumName,
                  isScreenshot: candidate.isScreenshot,
                })),
                photoInsights: visionJson.photoInsights ?? visionJson,
              }),
            },
          ],
        }),
      },
    );
    if (!finalResponse.ok) throw new Error("hybrid_finalizer_failed");
    const finalPayload = await finalResponse.json();
    const finalText = text(
      Array.isArray(finalPayload?.content)
        ? finalPayload.content.find((item: Record<string, unknown>) =>
          item?.type === "text"
        )?.text
        : "",
    );
    if (!finalText) throw new Error("hybrid_finalizer_empty_response");
    const draft = draftFromAdvancedJson(JSON.parse(finalText), request);
    await deletePreviewObjects(previewUris, env, fetcher);
    return draft;
  };
}

function advancedPrompt(request: AiAlbumDraftRequestPayload) {
  return JSON.stringify({
    instruction:
      "Pick a small set of photos for an editable Snapfit album draft. Keep Korean copy short, warm, album-first, and non-technical.",
    requiredJsonShape: {
      title: "string",
      pageCount: "number between 4 and 24",
      templateTone: "string",
      summary: "string",
      recommendedPhotos: [{
        assetId: "provided assetId",
        score: 0.0,
        reasons: [{
          type: "coverCandidate|dateFlow|themeOrientation",
          message: "Korean",
        }],
      }],
      excludedPhotos: [{
        assetId: "provided assetId",
        reasons: [{
          type:
            "screenshotExcluded|lowResolutionExcluded|weakThemeFitExcluded|totalLimitExcluded",
          message: "Korean",
        }],
      }],
      storySections: [{
        title: "Korean",
        description: "Korean",
        photoAssetIds: ["recommended assetId only"],
      }],
      curationNotes: ["Korean"],
    },
    theme: request.theme,
    range: request.range,
    candidates: request.candidates.map((candidate) => ({
      assetId: candidate.assetId,
      createdAt: candidate.createdAt,
      width: candidate.width,
      height: candidate.height,
      orientation: candidate.orientation,
      albumName: candidate.albumName,
      isScreenshot: candidate.isScreenshot,
      hasPreview: Boolean(candidate.previewStorageUri),
    })),
  });
}

function parsePreviewStorageUri(uri: string) {
  const prefix = "supabase://ai-album-previews/";
  if (!uri.startsWith(prefix)) throw new Error("invalid_preview_storage_uri");
  const path = uri.slice(prefix.length);
  if (!path || path.includes("..")) {
    throw new Error("invalid_preview_storage_uri");
  }
  return path;
}

function storageObjectUrl(baseUrl: string, path: string) {
  const encodedPath = path.split("/").map(encodeURIComponent).join("/");
  return `${
    baseUrl.replace(/\/$/, "")
  }/storage/v1/object/authenticated/ai-album-previews/${encodedPath}`;
}

async function previewDataUrl(
  uri: string,
  env: (key: string) => string | undefined,
  fetcher: Fetcher,
) {
  const supabaseUrl = text(env("SUPABASE_URL"));
  const serviceRoleKey = text(env("SUPABASE_SERVICE_ROLE_KEY"));
  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error("advanced_storage_not_configured");
  }
  const response = await fetcher(
    storageObjectUrl(supabaseUrl, parsePreviewStorageUri(uri)),
    {
      headers: new Headers({ Authorization: `Bearer ${serviceRoleKey}` }),
    },
  );
  if (!response.ok) throw new Error("advanced_preview_download_failed");
  const contentType = response.headers.get("content-type") || "image/jpeg";
  const bytes = new Uint8Array(await response.arrayBuffer());
  if (bytes.length === 0) throw new Error("advanced_preview_empty");
  return `data:${contentType};base64,${base64(bytes)}`;
}

async function deletePreviewObjects(
  uris: string[],
  env: (key: string) => string | undefined,
  fetcher: Fetcher,
) {
  const supabaseUrl = text(env("SUPABASE_URL"));
  const serviceRoleKey = text(env("SUPABASE_SERVICE_ROLE_KEY"));
  if (!supabaseUrl || !serviceRoleKey) return;
  await Promise.allSettled(
    uris.map(async (uri) => {
      const response = await fetcher(
        storageObjectUrl(supabaseUrl, parsePreviewStorageUri(uri)),
        {
          method: "DELETE",
          headers: new Headers({ Authorization: `Bearer ${serviceRoleKey}` }),
        },
      );
      if (!response.ok && response.status !== 404) {
        throw new Error("advanced_preview_cleanup_failed");
      }
    }),
  );
}

function base64(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function objectList(value: unknown) {
  return Array.isArray(value)
    ? value.filter((item): item is Record<string, unknown> =>
      Boolean(item) && typeof item === "object"
    )
    : [];
}

function stringList(value: unknown) {
  return Array.isArray(value) ? value.map(text).filter(Boolean) : [];
}

function draftFromAdvancedJson(
  value: unknown,
  request: AiAlbumDraftRequestPayload,
): AiAlbumDraftResponsePayload {
  if (!value || typeof value !== "object") {
    throw new Error("advanced_model_malformed_json");
  }
  const json = value as Record<string, unknown>;
  const fallback = buildDraftResponse(request);
  const candidateIds = new Set(
    request.candidates.map((candidate) => candidate.assetId),
  );
  const recommendedPhotos = objectList(json.recommendedPhotos)
    .map((item, index) => ({
      assetId: text(item.assetId),
      score: Math.max(
        0.5,
        Math.min(1, Number(item.score) || 0.85 - index * 0.03),
      ),
      reasons: objectList(item.reasons).map((reason) => ({
        type: text(reason.type) || "themeOrientation",
        message: text(reason.message) || "앨범 흐름에 어울려 골랐어요",
      })),
    }))
    .filter((photo) => candidateIds.has(photo.assetId))
    .slice(0, maxRecommendedPhotos);
  if (recommendedPhotos.length === 0) {
    throw new Error("advanced_model_empty_recommended_photos");
  }
  const recommendedIds = new Set(
    recommendedPhotos.map((photo) => photo.assetId),
  );

  const excludedPhotos = objectList(json.excludedPhotos)
    .map((item) => ({
      assetId: text(item.assetId),
      reasons: objectList(item.reasons).map((reason) => ({
        type: text(reason.type) || "weakThemeFitExcluded",
        message: text(reason.message) || "이번 초안에서는 잠시 빼뒀어요",
      })),
    }))
    .filter((photo) =>
      candidateIds.has(photo.assetId) && !recommendedIds.has(photo.assetId)
    );

  return {
    draftId: `advanced-draft-${crypto.randomUUID()}`,
    title: text(json.title) || fallback.title,
    pageCount: Math.max(
      4,
      Math.min(24, intValue(json.pageCount, fallback.pageCount)),
    ),
    templateTone: text(json.templateTone) || fallback.templateTone,
    summary: text(json.summary) || "작은 미리보기로 앨범 흐름을 정리했어요.",
    recommendedPhotos,
    excludedPhotos,
    storySections: objectList(json.storySections).map((section) => ({
      title: text(section.title) || "앨범 흐름",
      description: text(section.description) ||
        "함께 보면 자연스러운 장면이에요",
      photoAssetIds: stringList(section.photoAssetIds).filter((id) =>
        recommendedIds.has(id)
      ),
    })).filter((section) => section.photoAssetIds.length > 0),
    curationNotes: stringList(json.curationNotes).length > 0
      ? stringList(json.curationNotes)
      : ["작은 미리보기로 분위기와 대표 장면을 살펴봤어요."],
    requiresUserReview: true,
    alreadyCreatedAlbum: false,
    reviewCtaLabel: "이 구성으로 시작하기",
  };
}

function providerTimeout<T>(timeoutMs: number): Promise<T> {
  return new Promise((_, reject) => {
    setTimeout(() => reject(new Error("advanced_provider_timeout")), timeoutMs);
  });
}

function markProvider(
  draft: AiAlbumDraftResponsePayload,
  provider: AiAlbumDraftProviderName,
  fallbackUsed = false,
  fallbackReason?: string,
): AiAlbumDraftResponsePayload {
  return {
    ...draft,
    provider,
    fallbackUsed,
    ...(fallbackReason ? { fallbackReason } : {}),
    requiresUserReview: true,
    alreadyCreatedAlbum: false,
  };
}

function assertAlbumFirstContract(
  draft: AiAlbumDraftResponsePayload,
  request: AiAlbumDraftRequestPayload,
) {
  if (draft.requiresUserReview !== true) {
    throw new Error("provider_contract_requires_user_review");
  }
  if (draft.alreadyCreatedAlbum !== false) {
    throw new Error("provider_contract_already_created_album");
  }
  if (
    !Array.isArray(draft.recommendedPhotos) ||
    draft.recommendedPhotos.length === 0
  ) {
    throw new Error("provider_contract_empty_recommended_photos");
  }
  const candidateIds = new Set(
    request.candidates.map((candidate) => candidate.assetId),
  );
  const recommendedIds = new Set<string>();
  for (const photo of draft.recommendedPhotos) {
    if (!candidateIds.has(photo.assetId)) {
      throw new Error("provider_contract_unknown_asset");
    }
    if (recommendedIds.has(photo.assetId)) {
      throw new Error("provider_contract_duplicate_asset");
    }
    recommendedIds.add(photo.assetId);
  }
  for (const section of draft.storySections ?? []) {
    for (const assetId of section.photoAssetIds ?? []) {
      if (!recommendedIds.has(assetId)) {
        throw new Error("provider_contract_story_asset_not_recommended");
      }
    }
  }
}

async function createDraftWithProvider(
  request: AiAlbumDraftRequestPayload,
  options: AiAlbumDraftHandlerOptions = {},
): Promise<AiAlbumDraftResponsePayload> {
  const env = options.env ?? ((key: string) => Deno.env.get(key) ?? undefined);
  const selectedProvider = normalizeProvider(env("AI_ALBUM_DRAFT_PROVIDER"));
  const fetcher = options.fetch ?? fetch;
  const providers: Required<AiAlbumDraftProviders> = {
    metadata: options.providers?.metadata ?? metadataProvider,
    advanced: options.providers?.advanced ??
      createAdvancedVisionProvider(env, fetcher),
    hybrid: options.providers?.hybrid ?? createHybridProvider(env, fetcher),
  };

  if (selectedProvider === "metadata") {
    return markProvider(await providers.metadata(request), "metadata");
  }

  const timeoutMs = Math.max(
    1,
    intValue(env("AI_ALBUM_DRAFT_TIMEOUT_MS"), defaultProviderTimeoutMs),
  );
  try {
    const draft = await Promise.race([
      Promise.resolve(providers[selectedProvider](request)),
      providerTimeout<AiAlbumDraftResponsePayload>(timeoutMs),
    ]);
    assertAlbumFirstContract(draft, request);
    return markProvider(draft, selectedProvider);
  } catch (error) {
    const reason = error instanceof Error && error.message
      ? error.message
      : "advanced_provider_failed";
    return markProvider(
      await providers.metadata(request),
      "metadata",
      true,
      reason === "advanced_provider_timeout"
        ? reason
        : "advanced_provider_failed",
    );
  }
}

export async function handleAiAlbumDraftRequest(
  req: Request,
  options: AiAlbumDraftHandlerOptions = {},
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({
      error: "method_not_allowed",
      message: "POST 요청만 지원해요.",
    }, 405);
  }

  try {
    const request = parseBody(await req.json());
    const draft = await createDraftWithProvider(request, options);
    await logOperationalEvent({
      eventType: "AI_DRAFT_PROVIDER_RESULT",
      requestId: draft.draftId,
      provider: draft.provider,
      metadata: {
        fallbackUsed: Boolean(draft.fallbackUsed),
        fallbackReason: draft.fallbackReason ?? null,
        theme: request.theme,
        range: request.range,
        candidateCount: request.candidates.length,
        recommendedCount: draft.recommendedPhotos.length,
      },
    });
    return jsonResponse(draft);
  } catch (error) {
    const code = error instanceof Error ? error.message : "server_error";
    const status =
      code === "insufficient_candidates" || code === "invalid_request" ||
        code === "invalid_candidate"
        ? 400
        : 500;
    await logOperationalEvent({
      eventType: "AI_DRAFT_PROVIDER_ERROR",
      metadata: { code, status },
    });
    return jsonResponse(
      {
        error: code,
        message: status === 400
          ? "AI 앨범 초안 요청 형식을 확인해 주세요."
          : "AI 앨범 초안을 준비하지 못했어요.",
      },
      status,
    );
  }
}

if (import.meta.main) {
  Deno.serve((req) => handleAiAlbumDraftRequest(req));
}
