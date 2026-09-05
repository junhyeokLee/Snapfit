import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

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
type AiAlbumDraftProviderName = "metadata" | "advanced";

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

type AiAlbumDraftProviders = Partial<
  Record<AiAlbumDraftProviderName, AiAlbumDraftProvider>
>;

export type AiAlbumDraftHandlerOptions = {
  env?: (key: string) => string | undefined;
  providers?: AiAlbumDraftProviders;
};

const minCandidateCount = 3;
const maxRecommendedPhotos = 12;
const defaultProviderTimeoutMs = 8000;

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
  return text(value).toLowerCase() === "advanced" ? "advanced" : "metadata";
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

function advancedProviderNotConfigured(): never {
  throw new Error("advanced_provider_not_configured");
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

function assertAlbumFirstContract(draft: AiAlbumDraftResponsePayload) {
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
}

async function createDraftWithProvider(
  request: AiAlbumDraftRequestPayload,
  options: AiAlbumDraftHandlerOptions = {},
): Promise<AiAlbumDraftResponsePayload> {
  const env = options.env ?? ((key: string) => Deno.env.get(key) ?? undefined);
  const selectedProvider = normalizeProvider(env("AI_ALBUM_DRAFT_PROVIDER"));
  const providers: Required<AiAlbumDraftProviders> = {
    metadata: options.providers?.metadata ?? metadataProvider,
    advanced: options.providers?.advanced ?? advancedProviderNotConfigured,
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
      Promise.resolve(providers.advanced(request)),
      providerTimeout<AiAlbumDraftResponsePayload>(timeoutMs),
    ]);
    assertAlbumFirstContract(draft);
    return markProvider(draft, "advanced");
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
    return jsonResponse(draft);
  } catch (error) {
    const code = error instanceof Error ? error.message : "server_error";
    const status =
      code === "insufficient_candidates" || code === "invalid_request" ||
        code === "invalid_candidate"
        ? 400
        : 500;
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
