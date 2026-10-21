import {
  object,
  parseTemplateBrief,
  type TemplateBrief,
} from "./template-design.ts";

export const safeDesignChoices = {
  topic: [
    "travel",
    "family",
    "baby",
    "couple",
    "friends",
    "daily",
    "celebration",
  ],
  mood: ["editorial", "warm", "minimal", "playful", "elegant"],
  palette: ["neutral", "warm", "cool", "pastel", "vivid"],
  density: ["quiet", "balanced", "layered"],
} as const;
export type SafeTemplateOptions = {
  version: 1;
  topic: typeof safeDesignChoices.topic[number];
  mood: typeof safeDesignChoices.mood[number];
  palette: typeof safeDesignChoices.palette[number];
  density: typeof safeDesignChoices.density[number];
  pageCount: number;
  aspect: TemplateBrief["aspect"];
  printProduct?: TemplateBrief["printProduct"];
};

function onlyKeys(value: Record<string, unknown>, keys: string[]) {
  if (Object.keys(value).some((key) => !keys.includes(key))) {
    throw new Error("ai_generation_private_input_forbidden");
  }
}

// No free text crosses this boundary, including apparently harmless labels.
// The provider receives only descriptions authored here from finite enums.
export function parseSafeTemplateOptions(value: unknown): SafeTemplateOptions {
  const raw = object(value);
  onlyKeys(raw, [
    "version",
    "topic",
    "mood",
    "palette",
    "density",
    "pageCount",
    "aspect",
    "printProduct",
  ]);
  if (raw.version !== 1) throw new Error("ai_generation_invalid_request");
  for (const [key, choices] of Object.entries(safeDesignChoices)) {
    if (
      typeof raw[key] !== "string" ||
      !(choices as readonly string[]).includes(raw[key] as string)
    ) {
      throw new Error("ai_generation_invalid_request");
    }
  }
  if (raw.printProduct != null) {
    onlyKeys(object(raw.printProduct), ["id", "trimWidthMm", "trimHeightMm"]);
  }
  const brief = parseTemplateBrief({
    prompt: "공개 디자인 선호",
    pageCount: raw.pageCount,
    aspect: raw.aspect,
    designVersion: 3,
    ...(raw.printProduct == null ? {} : { printProduct: raw.printProduct }),
  });
  if (brief.pageCount < 20) throw new Error("ai_generation_invalid_request");
  return {
    version: 1,
    topic: raw.topic as SafeTemplateOptions["topic"],
    mood: raw.mood as SafeTemplateOptions["mood"],
    palette: raw.palette as SafeTemplateOptions["palette"],
    density: raw.density as SafeTemplateOptions["density"],
    pageCount: brief.pageCount,
    aspect: brief.aspect,
    ...(brief.printProduct ? { printProduct: brief.printProduct } : {}),
  };
}

const descriptions = {
  topic: {
    travel: "여행 사진집: 풍경과 이동, 쉬어 가는 순간을 담는 보편적인 이야기",
    family:
      "가족 사진집: 함께하는 평범한 하루와 따뜻한 관계를 담는 보편적인 이야기",
    baby: "성장 사진집: 작은 변화와 일상의 발견을 담는 보편적인 이야기",
    couple: "둘의 사진집: 함께 걷고 쉬는 순간을 담는 보편적인 이야기",
    friends: "친구 사진집: 함께 웃고 나누는 일상을 담는 보편적인 이야기",
    daily: "일상 사진집: 익숙한 장면 속 작은 발견을 담는 보편적인 이야기",
    celebration: "기념 사진집: 축하와 감사의 순간을 담는 보편적인 이야기",
  },
  mood: {
    editorial: "에디토리얼: 분명한 타이포 위계, 장면을 엮는 인쇄 잡지의 리듬",
    warm: "따뜻함: 부드러운 종이와 편안한 간격, 자연스러운 문장",
    minimal: "미니멀: 절제된 요소와 충분한 여백, 사진 중심의 선명한 위계",
    playful: "경쾌함: 다양한 사진 크기와 의도적인 겹침, 읽기 쉬운 즐거운 리듬",
    elegant: "차분한 우아함: 세심한 정렬과 절제된 소재, 섬세한 타이포 대비",
  },
  palette: {
    neutral: "중성색: 아이보리·회색·짙은 먹색 중심",
    warm: "따뜻한 색: 크림·테라코타·차분한 갈색 중심",
    cool: "시원한 색: 옅은 청색·세이지·짙은 남색 중심",
    pastel: "파스텔: 부드러운 밝은 바탕에 읽기 쉬운 짙은 글자",
    vivid: "선명한 색: 제한된 강조색과 읽기 쉬운 짙은 글자",
  },
  density: {
    quiet: "quiet: 넉넉한 여백과 간결한 글, 사진의 크기와 호흡으로 변주",
    balanced: "balanced: 사진·글·소재의 균형과 다양한 펼침면 구성",
    layered: "layered: 의도적인 소재 겹침과 풍성한 구성, 글의 가독성 유지",
  },
};

export function safeTemplateBrief(options: SafeTemplateOptions): TemplateBrief {
  // Revalidate even a DB-loaded object before constructing a provider prompt.
  const safe = parseSafeTemplateOptions(options);
  return {
    prompt: [
      "개인정보 없는 공용 사진집 디자인. 자연스러운 한국어 문구로 구성하세요.",
      descriptions.topic[safe.topic],
      descriptions.mood[safe.mood],
      descriptions.palette[safe.palette],
      descriptions.density[safe.density],
      "특정 사람의 이름·주소·연락처·날짜·장소나 실제 있었던 사건을 지어내지 마세요. 사진은 빈 편집 슬롯으로 두고 사용자가 나중에 기기에서 채웁니다. 기존 유료 레이아웃을 복사하지 말고 각 펼침면을 독창적으로 구성하세요.",
    ].join("\n"),
    pageCount: safe.pageCount,
    aspect: safe.aspect,
    designVersion: 3,
    ...(safe.printProduct ? { printProduct: safe.printProduct } : {}),
  };
}

export function assertSafeJobBody(body: Record<string, unknown>) {
  const action = body.action;
  const keys = action === "create"
    ? ["action", "generationRequestId", "expectedPointCost", "safeDesign"]
    : ["action", "generationRequestId"];
  onlyKeys(body, keys);
  if (!["create", "status", "latest", "cancel"].includes(String(action))) {
    throw new Error("ai_generation_invalid_request");
  }
  if (
    action !== "latest" && (typeof body.generationRequestId !== "string" ||
      !/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(
        body.generationRequestId,
      ))
  ) {
    throw new Error("ai_generation_invalid_request");
  }
}
