import type { TemplateBrief } from "../../supabase/functions/ai-album-draft/template-design.ts";

export type EvaluationCase = {
  id: string;
  label: string;
  brief: TemplateBrief;
  expectations: string[];
};
export const suiteVersion = 1;
const requests = [
  {
    id: "travel",
    label: "조용한 여행 사진집",
    pages: 4,
    prompt:
      "바다 여행 사진집. 화이트와 짙은 초록, 넉넉한 여백과 짧은 한국어 문장. 사진을 크게 쓰되 양쪽이 늘 같은 배치면 싫어요. 장소나 날짜는 지어내지 마세요.",
    checks: [
      "큰 사진과 여백의 균형",
      "마주 보는 페이지의 서로 다른 역할",
      "가상의 장소·날짜 없음",
    ],
  },
  {
    id: "wedding",
    label: "타이포그래피 웨딩",
    pages: 8,
    prompt:
      "현대적인 웨딩 사진집. 버건디와 화이트, 명조와 산세리프를 절제해 조합해줘. 첫 표지는 사진 없이 '우리의 시작'이라는 문장만. 꽃 장식, 가상의 이름과 날짜는 넣지 마세요.",
    checks: [
      "표지에 사진이 없음",
      "표지 문구 '우리의 시작' 유지",
      "명조·산세리프 조합",
      "꽃 장식·가상 인물 정보 없음",
    ],
  },
  {
    id: "family",
    label: "가족의 일상",
    pages: 8,
    prompt:
      "가족의 평범한 하루를 담는 밝은 사진집. 크림이나 갈색 대신 흰색에 빨강과 청록을 소량 사용해줘. 여러 작은 사진만 반복하지 말고 한 장에 집중하는 페이지도. 문구는 한국어, 가상의 이름은 쓰지 말아줘.",
    checks: [
      "크림·갈색 배제",
      "단일 큰 사진과 여러 사진의 리듬",
      "짧고 자연스러운 한국어",
    ],
  },
  {
    id: "growth",
    label: "경쾌한 성장 기록",
    pages: 12,
    prompt:
      "아이 성장 기록을 위한 그래픽 사진집. 라임과 코발트 블루를 포인트로 경쾌하지만 유치하지 않게. 장면 사이에 사진 없이 짧은 문장만 있는 페이지도 넣어줘. 아기 이름, 월령, 생일은 아직 정하지 않았으니 지어내지 마세요.",
    checks: [
      "사진 없는 쉬어가는 내지",
      "라임·블루의 절제된 강조",
      "이름·월령·생일을 발명하지 않음",
    ],
  },
  {
    id: "essay",
    label: "문장과 사진",
    pages: 8,
    prompt:
      "산책을 기록하는 에세이 사진집. 검정과 흰색 위주, 한국어 명조 본문과 간결한 제목. '천천히 걸으면 익숙한 길에서도 새로운 장면을 만난다.'라는 문장을 그대로 포함하고 사진 없는 도입부를 만들어줘. 과한 장식이나 영어는 필요 없어.",
    checks: [
      "지정 문장의 정확한 보존",
      "한국어 명조와 편안한 행간",
      "사진 없는 도입 페이지",
      "불필요한 영어·장식 없음",
    ],
  },
  {
    id: "editorial",
    label: "긴 영문 매거진",
    pages: 16,
    prompt:
      "Make a 16-page editorial travel photobook plus cover, with crisp black, white and electric blue. English copy only. Cover title: OFF THE GRID. Alternate full-scale photographs, asymmetric galleries and quiet typography pages. No invented names, places or dates. Facing pages should feel composed together, not repeated grids.",
    checks: [
      "영어 문구만 사용",
      "OFF THE GRID 표지 제목",
      "16쪽 전체의 변화와 일관성",
      "서로 호응하는 스프레드",
    ],
  },
];
export const evaluationCases: EvaluationCase[] = requests.flatMap((r) =>
  (["portrait", "square", "landscape"] as const).map((aspect) => ({
    id: `${r.id}-${aspect}`,
    label: r.label,
    brief: { prompt: r.prompt, pageCount: r.pages, aspect, designVersion: 2 },
    expectations: r.checks,
  }))
);
