# AI Template Evaluation

## Current Status

### Free-only durable production jobs (2026-10-21 KST)

Customer safeDesign jobs, the isolated Cron worker and the web UI are deployed.
The raw customer brief and legacy external photo analysis paths are closed.
`ai-album-draft` v43 retains JWT/Auth checks; `ai-template-worker` v2 requires its
own purpose-specific HMAC and a single-use private nonce. All 17/16 runtime files
match the local source. Original-book quality gates and shared corrections remain.

A production synthetic account exercised four real model-invocation attempts:
three on Gemini 3.6 Flash and one on free-capable Gemini 3.8 Flash after its Free
tier was checked against Google's current pricing. No accepted model response or
complete book was returned (`template_provider_unavailable`). The three scheduled
retries preserved the same intent, increased backoff and kept charges/first-free
claims at zero. The synthetic job/account/wallet/ledger were removed afterward.
Production remains fixed to free-only Gemini 3.8 Flash; no paid fallback, key
rotation, quota reset or cooldown bypass was used. No current premium visual
comparison is claimed from this failed synthetic run.

Server 148, SQL 22, native 97 and Chrome 20 checks pass. Counts overlap between
platforms and are not summed as unique tests. No preview, screenshot, gallery,
video or PDF was saved. The release and cleanup record is
`docs/verification/ai-free-resumable-production-2026-10-21.json`.

### Live Follow-up and Production Deployment (2026-10-20)

The latest source was deployed to customer `ai-album-draft` **v39**, with all 14
runtime files read back byte-for-byte and JWT verification retained. The web UI
was also published to `https://snapfit-c719d.web.app`; remote entrypoint hashes
match the tested release build. This does not publish a new native app-store
binary or open customer AI generation.

Actual Gemini 3.6/3.8 synthetic travel-book experiments made **23 transport
calls**: six HTTP 200 responses, thirteen 503 responses, one 429 and three
aborted/unknown transport results. **No new complete book was accepted.**
After `RESOURCE_EXHAUSTED`, model calls stopped; no key/provider switching or
further checkpoint continuation was used. The exhausted continuation chain was
not reset. A separate fresh experiment used the newly corrected text-fit source
and stopped at the quota response. This evidence does not establish premium
visual parity or reliable completion inside the 120-second customer deadline.

Observed defects informed production improvements: explicit role-specific font
and line-height schema bounds (1.7 remains invalid), calculated 4.5:1 palette
text/backdrop pairs, and shared text-height guidance accounting for automatic
wrapping and explicit newlines. Natural Korean wording and semantic connections
are checked without overriding exact user copy. The validator, font sizes,
contrast threshold, token ceilings, deadline and repair limits are unchanged.
The final typed server/evaluation suite passes **132 tests**.

Current paid reference products were verified read-only: `luminous-edition`
(2,500P) and `shore-days` (1,800P), both active. The new in-memory native comparison
harness passes against the historical unmodified 21-page live result: actual
bundle fonts, decoded local photos and saved layer geometry are preserved. That
control run validates the harness, not the new generator's aesthetic quality.
No new complete accepted result exists to render through it. No screenshot,
PNG, video, PDF, gallery or golden file was written.

The owner confirmed the Google project is unpaid. Customer privacy approval and
the unvalidated v3 release gate remain closed; production retains Gemini 3.6,
free-only mode, pacing, token/deadline/retry policy and point pricing. See the
[Google data-use terms](https://ai.google.dev/gemini-api/terms#unpaid-services).
The temporary JWT-protected synthetic evaluation function was deleted and its
absence confirmed. Original model JSON and a small rollback source snapshot are
retained. Per-run outcomes, source hashes, deployment readback and cache cleanup
are recorded in `docs/verification/ai-gemini-live-production-2026-10-20.json`.
The entries below are historical checkpoints, not claims about this live run.

### Editorial Quality and Local Result Editing (2026-10-20)

The original-book Gemini request path now shares an editorial rubric across
direction, composition and review: typography hierarchy, spread rhythm,
photo/text balance, material/palette coherence and story-specific copy. Structural
gates and five evidence-backed review checks reject weak or incomplete results
and use the existing bounded correction budget for the affected pages. The
criteria preserve deliberately bold/layered work, explicit repeated copy and
functional running labels; catalog geometry or paid asset rights are not copied.

The app adds local paper-tone and text-element editing with original restoration.
These edits retain the active draft identity, typography, geometry, photos and
print format; text must pass the existing actual-font overflow preflight. Editing
a request can return to the original draft before starting a new generation.
After a new generation expires the old server draft, its retained result is for
comparison only and cannot be accepted again.

The historical 21-page synthetic Gemini document is also retained as a small,
self-contained JSON test fixture with its original report hash. Native tests
verify real-font text preflight, the six-color palette limit and identical saved
artwork layers after paper-tone changes, including backgrounds shared with photo
or text colors. This is an editing regression, not a new generation evaluation.
The rubric adds request text, so unchanged pricing and token ceilings do not
guarantee identical input-token usage.

This update is verified with local fixture and mocked Gemini request/response
tests. No new live model evaluation, screenshot/export, production deployment,
release-gate change, model switch or billing-policy change is performed. It does
not establish visual parity with the paid catalog. Final checks, source hashes
and temporary-cache cleanup are recorded in
`docs/verification/ai-result-quality-2026-10-20.json`. The live evaluations below
remain historical evidence for their original sources and dates.

The local evaluation pipeline is implemented. It calls the same
`createOriginalTemplate` function used by the app's server, then renders accepted
documents with Flutter's actual fonts and `TemplatePageRenderer`.

### Completed Gemini Book (2026-10-19)

A real `gemini-3.6-flash` / free-only `travel-square` book has now passed the
complete-book validators and native rendering: **one cover and 20 interiors**.
The unmodified model result is retained at
`output/ai-template-evaluations/live-server-2026-10-19T06-27-20-213Z-travel-square/run.json`.
The inspected, explicitly refined review copy is
`output/ai-template-evaluations/gemini-completed-book/index.html`.
No catalog or fixture pages were substituted for model output.

This book completed across two bounded sessions, not one uninterrupted request.
The first session's successful direction and composition responses were replayed
from an exact-request checkpoint; all responses still passed the normal engine,
including its unchanged correction and whole-book validation gates. One bounded
composition repair was required. Across both sessions there were 10 actual model
calls, with at least 21,967 input and 15,053 output tokens (5,096 reported thinking
tokens included in output). Failed-request usage is unknown; these are incomplete
totals, not a billing statement or proof of zero charges. No paid model/provider
fallback, image generation, app-point charge or purchase mutation was used.

Both the raw book and the refined copy passed native rendering for all 21 pages:
actual fonts, decoded inspection photos, editable-layer save/load geometry and
no detected text overflow. Every page and the complete spread contact sheet were
visually inspected. The refined copy lightens the display weight, replaces fixed
red/teal airmail accents with a neutral gallery mat, corrects a Korean phrase and
improves the cover/closing copy. Generated geometry and photo-slot counts are
unchanged. `agentRefinements`, `sourceRun` and `agent-review.json` disclose these
post-generation edits; human approval remains explicitly false. Five local Jeju
photos are inspection inputs only, not newly generated or AI-selected assets.

The matching customer function was deployed and read back as **v34**; all 13
source files match the local dependency graph, and JWT verification remains on.
Server configuration now explicitly selects `gemini-3.6-flash`, free-only mode,
1200ms serialized pacing, a 120-second per-invocation deadline, and at most two
shared transient retries. Only free-only Gemini 502/503/504 responses are retried
with the identical request and bounded backoff. Quota/auth/invalid-output failures
are not transport-retried. Coordinate schemas and prompts now consistently use
0..1 page fractions; typography alone retains its 500-unit reference canvas.

Checkpoint context binds the original brief, model and normalized geometry
contract. It stores completed model responses rather than trusted finished pages,
caps resume attempts at three and revalidates the whole book. **This checkpoint
path is internal/evaluation-only: the ordinary customer HTTP endpoint does not
accept checkpoints and has no durable customer-job persistence/resume yet.**
The protected temporary `ai-template-eval-20261019c` function was deleted.

The DB `v3_enabled` gate and `AI_TEMPLATE_ALLOW_UNPAID_USER_DATA` remain false.
One synthetic square book does not establish production reliability, all-aspect
quality, print readiness or permission to process private customer stories.
Home, Reader, prices, balances and purchase history were not changed by this work.

### Earlier Evaluation History

As of 2026-10-19 the runner defaults to original-book engine v3. Its 18 planned
cases cover 20, 24, 32 and 36 interiors in all three aspects. Stage traces record
direction, each composition batch, targeted corrections and semantic review.
`--engine 2` preserves the earlier V2 comparison set. Offline `--fixture` mode
still exercises the explicitly hand-authored V2 pipeline fixtures; new V3
contract/render fixtures are verified by `test/design/ai_template_v3_test.dart`.
On 2026-10-19 a live v3 `travel-square` attempt was made and rejected with
`credit_balance_exhausted`. At that earlier checkpoint there were no complete
generated designs to visually approve; no fixture was substituted as live evidence.
That failure paused further OpenAI taste cases. Gemini is now the default local
provider; the prior OpenAI credit error does not establish
anything about Gemini's quota. The billing
guard was deployed as function v29, but its `v3_enabled` policy remains false until
successful real-output evaluation. The local evaluator still requires `--live`
and runs independently of customer billing and storage.

The Gemini adapter and safe provider switching are implemented. Initial server
secret registration was confirmed on 2026-10-19; the local env file still has an
empty key. The registered server key was tested without reading or exporting it,
using an expiring, JWT-protected synthetic-only function with a separate random
credential. This temporary function was removed after evaluation.

Two actual Gemini attempts are recorded under `output/ai-template-evaluations/`:

- `live-server-2026-10-19T04-49-32-087Z/run.json`: `gemini-3.8-flash` returned
  HTTP 200 / STOP for direction and composition batches covering pages 0-12.
  Those responses passed the server's per-stage validators without correction.
  The next batch exceeded the shared 120-second deadline. No complete book was
  accepted or rendered. The original trace labels its aborted request
  `request_failed`; the evaluator now distinguishes `template_generation_timeout`.
- `live-server-2026-10-19T04-50-39-672Z/run.json`: the latency-tuned candidate
  received HTTP 503 / `UNAVAILABLE` on its first direction call. No further model
  calls or paid fallback were made. Its real-output latency and quality are not
  yet verified.

The first run reported at least 6,863 input and 15,778 output tokens, including
9,082 thinking tokens. Usage from its aborted call is unknown, so these are
incomplete totals, not a billing statement or proof of zero cost. Composition
calls now use LOW thinking on Gemini 3.x; direction/review retain MEDIUM and all
validators, token ceilings, serialized pacing and deadlines remain unchanged.
This is a candidate optimization, not a measured speedup.

### Server Connection Follow-up (2026-10-19)

At this earlier checkpoint the customer function was deployed and read back as
**v32**, including the
Gemini adapter. All 12 deployed source files match the local dependency graph and
JWT verification remains enabled. Server settings explicitly select Gemini,
`gemini-3.8-flash`, free-only mode, 1200ms serialized pacing and a 120-second shared
deadline. The existing Gemini key was retained without reading or exporting it.
No image-generation model, paid fallback, price change or wallet operation was used.

Three bounded synthetic 20-interior travel-book evaluations were attempted:

- `live-server-2026-10-19T06-06-59-379Z-travel-square/run.json`: Gemini 3.8 Flash
  accepted the direction response, then composition returned 503 / `UNAVAILABLE`.
- `live-server-2026-10-19T06-08-45-075Z-travel-square/run.json`: an explicitly
  selected Gemini 2.5 Flash experiment returned 404 / `NOT_FOUND`. A free-capable
  allowlist entry is not evidence that a model is available to this project.
- `live-server-2026-10-19T06-09-50-602Z-travel-square/run.json`: the separately
  selected Gemini 3.6 Flash experiment accepted direction, received a composition
  rejected by the geometry validator, then its bounded repair received 503 /
  `UNAVAILABLE`. No failed geometry was accepted or silently repaired locally.

The initial probe-only 400 response is separately recorded under
`live-server-2026-10-19T06-05-31-745Z-curation-followup`; it made no model calls.
The probe now accepts the hosted runtime's empty POST stream while rejecting
all nonempty customer payloads. Its JWT, independent random credential, expiry,
case allowlist and duplicate-call checks have automated tests. The temporary
`ai-template-eval-20261019b` function was deleted after these attempts.

**At this earlier checkpoint no complete book was accepted or rendered.** API
connection was verified, but production quality and reliability were not. Both the DB `v3_enabled`
release gate and `AI_TEMPLATE_ALLOW_UNPAID_USER_DATA` remain false. Do not turn
these on based on key registration, partial responses or fixture screenshots.
The reported token totals omit unknown usage from failed requests and are not
proof of zero charges. The adapter and setup are described in
[the model guide](ai_template_original_design.md).

On 2026-09-07 a single minimal API availability request again returned HTTP 429,
`credit_balance_exhausted` / `insufficient_quota`. No live template batch was
started. This is the local runtime credential's result, not a statement about
the production Supabase account. No function was deployed, no album was created,
and no app points were charged.

The included review workspace uses **explicit hand-authored contract fixtures**.
It tests the evaluation machinery; it is not evidence of real AI design quality.
There is no fallback from a failed live run to these fixtures.

## Evaluation Set

`tool/ai_template_eval/cases.ts` contains six synthetic briefs, each planned
independently for portrait, square and landscape: 18 cases per engine. The table
below describes the retained V2 suite. V3 uses the same topics with full-book
counts (20, 24, 24, 32, 24, 36 respectively), and its editorial brief explicitly
requests 36 interiors so the prompt and physical count do not conflict.

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
case. V3 uses direction + bounded composition batches + semantic review, with
two shared repairs and a shared provider deadline (Gemini 120s, OpenAI 90s by
default). V2 retains at most three calls.
A selected case runs only that case. No automatic full-suite retry is performed.

```sh
deno run --allow-read tool/ai_template_eval/run.ts --list
deno run --env-file=supabase/.env.ai-template.local --allow-read --allow-env --allow-write=output/ai-template-evaluations --allow-net=generativelanguage.googleapis.com tool/ai_template_eval/run.ts --live --case travel-square
```

Use `--live --max-cases 18` only when deliberately running the full evaluation.
The tool has no unbounded repeat or retry switch. Model selection uses the same
`AI_TEMPLATE_MODEL`, the selected provider's model variable, then its default.
The CLI defaults to `--provider gemini` and free-only mode, even when an OpenAI
key is inherited. Switching to OpenAI requires both `--provider openai` and
`--allow-paid`; no switch occurs on failure. Do not run a full book suite until
the active limits in AI Studio are checked. One book uses several model calls.
Quota exhaustion stops the remaining suite rather than claiming it can finish
for free. Keys belong in the server/local environment, never in source,
arguments, reports or Flutter assets.

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
deno run --allow-read --allow-write=output/ai-template-evaluations tool/ai_template_eval/run.ts --fixture
# Render and build using the fixture run path printed above, then:
node tool/ai_template_eval/verify.cjs output/ai-template-evaluations/FIXTURE_RUN_ID
```

Fixture mode uses the shared contract test document in three physical aspects,
plus deliberately repaired, rejected and actual-font-overflow cases. Its token
counts and responses are mocked and must never be interpreted as model cost,
latency or success-rate evidence.

## Records and Gates

- `run.json`: brief, checks for human review, provider/model, source fingerprint,
  plan/layout attempts, returned model content, validation errors, duration,
  and token usage when the provider supplies it.
- `render.json`: actual-font overflow by page and element ID, measured versus
  available size, line count, decoded photo count, and layer save/load drift.
- `renders/`: actual Flutter PNGs with empty frames and local inspection photos.
- `index.html`: cover/spread/single-page browsing, enlargement, status filters,
  original prompts/plans, model trace inspection and a human review form.

The provider deadline bounds the complete book; V3 permits two shared repairs,
while V2 permits one. A quota, credential,
transport or other non-quality failure stops the remaining suite immediately.
A quality rejection is recorded and the next independent case can continue.
Partial results are persisted after every case. No silent stock-template fallback.

Missing usage stays marked incomplete; USD cost is `null`, not fabricated from
an outdated price. Gemini's output count includes reported thinking tokens,
recorded separately as well. A free-capable model name is not evidence of an
account's billing tier or a measured zero-cost run. JSON acceptance, font/render acceptance and aesthetic verdict
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
V3 implements structural/semantic targeted correction during generation.
Render-feedback repair, user-directed selective editing with locks and multi-plan
selection remain future product work, not capabilities established by fixtures.
