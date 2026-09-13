import fixture from "../../test/fixtures/ai_template_v2.json" with {
  type: "json",
};
import { parseTemplateBrief } from "../../supabase/functions/ai-album-draft/template-design.ts";
import type { EvaluationCase } from "./cases.ts";

export const fixtureCases: EvaluationCase[] = [
  ...(["portrait", "square", "landscape"] as const).map((aspect) => ({
    id: `fixture-${aspect}`,
    label: "수동 계약 문서",
    brief: parseTemplateBrief({ ...fixture.brief, aspect }),
    expectations: [
      "실제 AI 생성 결과가 아님",
      "사진틀과 실제 글꼴의 렌더링 확인",
    ],
  })),
  ...["repair", "reject", "font-overflow"].map((kind) => ({
    id: `fixture-${kind}`,
    label: kind === "repair"
      ? "수정 경로 테스트"
      : kind === "reject"
      ? "배치 거부 테스트"
      : "실제 폰트 넘침 테스트",
    brief: parseTemplateBrief(fixture.brief),
    expectations: ["의도적으로 만든 검증 사례 · AI 결과 아님"],
  })),
];
export function fixtureFetcher(entry: EvaluationCase) {
  return async (_: string | URL | Request, init?: RequestInit) => {
    const request = JSON.parse(String(init?.body));
    const planning = !JSON.parse(request.messages[1].content).artDirection;
    const plan = structuredClone(fixture.plan);
    const output = {
      ...structuredClone(fixture.output),
      aspect: entry.brief.aspect,
    };
    if (entry.id === "fixture-font-overflow") {
      plan.typography.display.fontSize = 104;
      Object.assign(output.pages[0].elements[0], {
        text: "WWW",
        width: .42,
        height: .24,
      });
    }
    const invalid = !planning &&
      (entry.id === "fixture-reject" ||
        (entry.id === "fixture-repair" && request.messages.length === 2));
    if (invalid) output.pages[0].elements[0].x = .98;
    return new Response(
      JSON.stringify({
        choices: [{
          finish_reason: "stop",
          message: { content: JSON.stringify(planning ? plan : output) },
        }],
        usage: { prompt_tokens: 100, completion_tokens: 200 },
      }),
    );
  };
}
