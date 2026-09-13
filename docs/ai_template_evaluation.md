# AI Template Evaluation

## Current Status

The local evaluation pipeline is implemented. It calls the same
`createOriginalTemplate` function used by the app's server, then renders accepted
documents with Flutter's actual fonts and `TemplatePageRenderer`.

On 2026-09-07 a single minimal API availability request again returned HTTP 429,
`credit_balance_exhausted` / `insufficient_quota`. No live template batch was
started. This is the local runtime credential's result, not a statement about
the production Supabase account. No function was deployed, no album was created,
and no app points were charged.

The included review workspace uses **explicit hand-authored contract fixtures**.
It tests the evaluation machinery; it is not evidence of real AI design quality.
There is no fallback from a failed live run to these fixtures.

## Evaluation Set

`tool/ai_template_eval/cases.ts` contains six synthetic briefs, each generated
independently for portrait, square and landscape: 18 planned cases.

| Brief | Inner Pages | Main Review Questions |
| --- | --- | --- |
| Quiet travel | 4 | Large images, restraint, facing-page variation |
| Typographic wedding | 8 | Photo-free cover, exact title, no invented names |
| Family day | 8 | Color exclusions, single-photo/gallery rhythm |
| Growth record | 12 | Quiet text pages, no invented ages or birthdays |
| Walking essay | 8 | Exact Korean sentence, readable serif, no English |
| English editorial | 16 | Long-book rhythm, English-only copy, exact title |

These are a starting evaluation set, not a representative production dataset.
Do not place catalog layouts or quality-studio coordinates into the generator.
Future evaluation should add real consented briefs, edge cases and multiple
independent runs per brief rather than overfitting to these examples.

## Run Locally

Run from the repository root. Deno 2 is used. The default command only lists
cases; it never calls the API. Live generation is opt-in and defaults to one
case, at most three model calls. A selected case runs only that case.

```sh
deno run --allow-read tool/ai_template_eval/run.ts --list
deno run --allow-read --allow-env=OPENAI_API_KEY,AI_TEMPLATE_MODEL,OPENAI_MODEL --allow-write=output/ai-template-evaluations --allow-net=api.openai.com tool/ai_template_eval/run.ts --live --case travel-square
```

Use `--live --max-cases 18` only when deliberately running the full evaluation.
The tool has no unbounded repeat or retry switch. Model selection uses the same
`AI_TEMPLATE_MODEL`, `OPENAI_MODEL`, then `gpt-4o` precedence as the server.
Keys belong in the shell's environment, never in source, arguments or reports.

Each run creates a new private directory under `output/ai-template-evaluations/`.
The CLI prints its `run.json` path. Use that exact run path in the next commands:

```sh
flutter test test/design/ai_template_eval_render_test.dart --dart-define=AI_TEMPLATE_EVAL_RUN=output/ai-template-evaluations/RUN_ID/run.json --reporter expanded
node tool/ai_template_eval/build.cjs output/ai-template-evaluations/RUN_ID
```

The last command prints an offline `index.html`. No web server is needed.
The builder requires the already-installed Node `lucide` package; verification
also uses `playwright`, `pngjs` and installed Chrome. In Codex's bundled runtime,
set `NODE_PATH` to its dependency `node_modules` directory before these commands.

For a fully offline pipeline check:

```sh
deno run --allow-read --allow-env=OPENAI_API_KEY,AI_TEMPLATE_MODEL,OPENAI_MODEL --allow-write=output/ai-template-evaluations tool/ai_template_eval/run.ts --fixture
# Render and build using the fixture run path printed above, then:
node tool/ai_template_eval/verify.cjs output/ai-template-evaluations/FIXTURE_RUN_ID
```

Fixture mode uses the shared contract test document in three physical aspects,
plus deliberately repaired, rejected and actual-font-overflow cases. Its token
counts and responses are mocked and must never be interpreted as model cost,
latency or success-rate evidence.

## Records and Gates

- `run.json`: brief, checks for human review, model, source fingerprint,
  plan/layout attempts, returned model content, validation errors, duration,
  and token usage when the provider supplies it.
- `render.json`: actual-font overflow by page and element ID, measured versus
  available size, line count, decoded photo count, and layer save/load drift.
- `renders/`: actual Flutter PNGs with empty frames and local inspection photos.
- `index.html`: cover/spread/single-page browsing, enlargement, status filters,
  original prompts/plans, model trace inspection and a human review form.

The server's one-correction/90-second limit is unchanged. A quota, credential,
transport or other non-quality failure stops the remaining suite immediately.
A quality rejection is recorded and the next independent case can continue.
Partial results are persisted after every case. No silent stock-template fallback.

Missing usage stays marked incomplete; USD cost is `null`, not fabricated from
an outdated price. JSON acceptance, font/render acceptance and aesthetic verdict
are separate. A live rendering run exits with a failing test if accepted model
output fails font or rendering checks, while preserving its inspection images.
Rejected server output remains available as JSON traces, not rendered as an
accepted template.

Photo inspection uses five existing bundled Jeju images with deterministic
placement **only inside the evaluator**, after generation. No images are sent to
the model or assigned in the generated document. They test frame geometry and
actual pixels, not automatic subject selection or real customer photo suitability.
Their redistribution rights are not independently verified; do not publish them.

## Human Review

The rubric has four 1-5 ratings: request fidelity, typography, facing-page
composition, and distinctiveness. Use 1 for a clear failure, 3 for a coherent but
revision-needed design, and 5 for a polished result meeting the brief. Scores
2 and 4 represent the intermediate levels. Distinctiveness is a human assessment,
not proof of absolute originality or an infringement clearance.

For a provisional review pass, all automated gates must pass, all four scores
must be at least 4, and a reviewer and written rationale are required. The numeric
threshold is an initial project rubric, not a validated industry standard.
Calibrate it with multiple human reviewers and real generated examples.

Reviews are stored locally in the browser and can be exported as JSON. They are
bound to the run and a hash of the rendered output; changed renders do not inherit
old reviews. Browser storage may be unavailable for local files; the UI reports
that and export remains available. Review JSON is not a publishing, payment or
album-acceptance API and is not automatically imported into production.

The separation of task-specific checks and human judgment follows
[OpenAI's evaluation guidance](https://developers.openai.com/api/docs/guides/evaluation-best-practices).
The server test harness uses the existing fetch injection point, consistent with
[Supabase's network-boundary testing approach](https://supabase.com/docs/guides/functions/unit-test).

## Privacy and Verification

Reports are excluded from Git, output directories use restrictive permissions,
and HTTP headers/API keys are not recorded. Error bodies are reduced to known
codes. Model content and synthetic briefs remain local; do not serve or share a
report containing personal information without reviewing it first.

The viewer creates text nodes for untrusted content and accepts only local
generated PNG paths. Browser checks cover four viewport sizes, photo pixels,
physical aspect, all page groups, filters, enlargement, review persistence,
export and HTML-injection resistance. Automated browser review records live in
isolated test browser contexts and are labeled test-only.

```sh
deno test --allow-env --allow-read tool/ai_template_eval/evaluate_test.ts
flutter test test/design/ai_template_v2_test.dart test/unit/ai_template_design_test.dart test/unit/layer_export_mapper_test.dart
```

Next: obtain successful **live** generations, run this pipeline, and review both
passing and failing designs. Tune generation only against those observations.
Render-feedback repair, selective editing with locks and multi-plan selection
remain future product work, not capabilities established by fixture tests.
