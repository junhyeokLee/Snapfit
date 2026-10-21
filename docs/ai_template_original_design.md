# Snapfit AI Template Design

## Free-only durable jobs (2026-10-20)

Production was activated on 2026-10-21 KST: safe jobs and the AI-only Cron are on,
the legacy raw v3 gate stays off, and the free-only worker is fixed to Gemini 3.8
Flash. Local evaluator defaults below remain historical. Actual production retry
and deployment evidence is in `verification/ai-free-resumable-production-2026-10-21.json`.

The customer route now uses `action=create/status/latest/cancel` and a closed
`safeDesign` v1 object. Topic, mood, palette and density are finite enums; page
count, aspect and the existing public print-product dimensions are validated.
Unknown keys and free text are rejected. Only server-authored public descriptions
reach Gemini. Private notes, local text edits, photographs, identities, dates and
Storage references never become model input. The former raw `designBrief` HTTP
route is closed regardless of the obsolete unpaid-data flag. Legacy photo
curation is metadata-only and cannot invoke vision providers.

Private seven-day jobs own their original intent, draft ID and server checkpoint.
Each worker invocation replays saved responses through the unchanged full-book
validators and performs at most one new model transport. The v2 identity binds
system instructions, model, safe input, schemas, materials, typography, quality
rubric and execution revision. Successful parsed responses, including responses
that need quality correction, are saved before validation. This preserves the
shared two-correction budget across restarts. A persistence error retains the
lease for recovery; it never starts another transport in the same invocation.

A private Cron worker uses its own Vault/Edge HMAC secret, fixed empty body,
purpose-specific signature and single-use DB nonce. Customer JWTs cannot start
worker execution. A project-wide fenced lease and at least 65 seconds between
starts serialize free requests. Quota and transient failures persist the next
attempt time and a project-wide cooldown; daily quota observes the Pacific civil
day reset, including daylight saving. Status polls never invoke Gemini. Invalid
JSON or truncated output stops rather than repeating a deterministic failure.
There is no paid-provider fallback or automatic billing upgrade.

Queueing, waiting, polling and cancellation never charge points or claim the
first-free credit. Only the existing acceptance RPC consumes the original READY
intent. Consumed-result recovery uses the same draft ID and its idempotent receipt.
The raw v3 gate stays closed; the safe job policy and AI-only Cron are activated
separately after deployment verification. Ready/checkpoint payloads expire within
seven days; billing records are preserved. No rendered preview files are created.

The older transport notes below describe the synthetic evaluation path; the
customer worker always disables in-memory retries and enforces Gemini free-only.

## Gemini And Model Adapters (2026-10-19)

Template generation now defaults to `gemini` / `gemini-3.6-flash` through
`template-model-provider.ts`. The matching server function is deployed and read
back as v34, including all 13 source files and unchanged JWT verification. A real
synthetic book (cover + 20 interiors) completed across two bounded sessions and
passed native rendering and agent visual inspection. The raw model output and an
explicitly refined review copy are retained separately; no fixtures replaced
failed live output. See the evaluation guide for exact reports and edits.

This is not a customer-wide release: `v3_enabled` and the unpaid-customer-data
approval flag remain false. Prices, balances, purchases, Home and Reader are
unchanged. The temporary protected synthetic evaluator was deleted after use.

The provider boundary accepts text messages, an optional JSON schema and a token
budget, then returns parsed design data. Gemini and explicit opt-in OpenAI use
that same boundary. The art-direction, complete-book composition, material and
readability validators are provider-independent. To add another provider, extend
its config/encode/decode/endpoint adapter and contract tests; never add provider
SDKs or API keys to Flutter. Model/provider selection is server-side, not a field
accepted from an HTTP caller.

The Gemini request explicitly asks for TEXT only, one candidate, JSON output and
no tools. Existing free frame/paper/material IDs and registered fonts are the
building blocks. The model decides fresh layouts, layer order, color and editable
copy; it does not generate photographs, sticker images or catalog copies. Users
add photographs later in the existing flow.

### Configuration And Free-Only Limits

`supabase/ai-template.env.example` is a key-free example. For local evaluation,
use the ignored `supabase/.env.ai-template.local` file outside Flutter assets.
For the app server, enter the same settings under Edge Function Secrets.

- `AI_TEMPLATE_PROVIDER=gemini` is the default. `openai` requires explicit choice.
- `AI_TEMPLATE_MODEL=gemini-3.6-flash` overrides the provider default. The matching
  `GEMINI_MODEL` / `OPENAI_MODEL` variable is a secondary override only.
- `GEMINI_API_KEY` belongs to a Google project whose AI Studio billing tier is
  **Free**. Never paste keys into chat, source, launch arguments or reports.
- `AI_TEMPLATE_FREE_ONLY=true` allows only the reviewed free-capable Gemini model
  names. It blocks paid/unknown model names and paid provider fallback. It does
  **not** inspect or enforce the Google project's billing tier. A billing-enabled
  key can still incur charges for the same model; verify the project externally.
- `AI_TEMPLATE_MIN_CALL_INTERVAL_MS=1200` serializes and spaces calls within one
  Gemini book. It does not enforce project-wide Google RPM, TPM or daily limits.
  Quota failure stops queued calls immediately. There is no automatic quota retry,
  provider switch, grounding, image generation or paid upgrade.
- `AI_TEMPLATE_MAX_TRANSIENT_RETRIES=2` permits at most two shared transport
  retries per book invocation, only for free-only Gemini HTTP 502/503/504. The
  identical request is retried on the same model with bounded backoff, using
  `AI_TEMPLATE_RETRY_BASE_MS=1200` and the original deadline. It is not two retries
  per page. Auth, quota, invalid/blocked JSON and quality repairs do not use this
  transport-retry path. Paid modes default to no automatic retries.
- Gemini 3.x composition requests use LOW thinking; direction, review and legacy
  requests retain MEDIUM. Gemini 2.5 retains its 1024-token thinking budget. This
  reduces the requested reasoning depth, not the JSON output budget or quality
  checks. One complete synthetic book now has live evidence, but there is no
  controlled before/after speed comparison or production success-rate evidence.
- `AI_TEMPLATE_TIMEOUT_MS` defaults to 120000 for Gemini and 90000 for OpenAI,
  bounded at 130000 to leave room inside the 150-second hosted request limit.
- `AI_TEMPLATE_ALLOW_UNPAID_USER_DATA=false` keeps Gemini HTTP customer processing
  closed, including when `FREE_ONLY` is false. Only an explicit reviewed server
  approval can open it. A request-body override cannot enable it. The internal
  synthetic evaluator bypasses this customer path, but not provider/model gates.

Google's unpaid-service terms permit use of submitted content and responses for
product improvement and human review, with regional exceptions. A text-only brief
can still contain private names or personal stories. Do not enable customer use
just because no photos are uploaded; settle the privacy/consent and service-tier
policy first. Synthetic evaluations use fictional briefs only.

The existing count limits, request-ID cache, owner-bound READY result, acceptance
charge and first-free policy remain. Failures never complete a billable result;
quota errors return HTTP 429 and Retry-After, configuration/privacy errors 503,
incomplete model output 502 and a deadline 504. Provider error bodies and keys are
not returned. Client messages retain the request and explain the safe retry path.

References: [Gemini pricing](https://ai.google.dev/gemini-api/docs/pricing),
[structured output](https://ai.google.dev/gemini-api/docs/structured-output),
[generateContent contract](https://ai.google.dev/api/generate-content),
[quota](https://ai.google.dev/gemini-api/docs/rate-limits),
[data terms](https://ai.google.dev/gemini-api/terms),
[server secrets](https://supabase.com/docs/guides/functions/secrets).

### API Key Setup

1. Open [Google AI Studio](https://aistudio.google.com/apikey), create a key for a
   new project and verify its Free tier. Do not connect paid billing for this test.
2. In the Snapfit project's Edge Function Secrets, add `GEMINI_API_KEY`. Keep the
   key in the secret value field only. Set the non-secret provider settings from
   the example at deployment time; do not enable the customer-data flag yet.
3. For local synthetic generation, enter the key in the ignored local env file
   as well, then follow the evaluation guide. Never commit that file or include
   it in client assets. Server-only secrets cannot be read back for local tests.
4. Generate and visually review several full books before opening the separate DB
   v3 release gate. Mock transport tests and the one actual completed square book
   remain separate evidence; neither establishes production-wide design quality.
   Key registration alone is not approval to process personal briefs.

## Original-book engine v3 (2026-10-19)

New template briefs default to `designVersion: 3`. Home and Reader are not changed.
V1/V2 documents remain readable; their historical behavior is documented below.
The matching Gemini-capable `ai-album-draft` function has been deployed as v34
and its source read back. The client rejects a legacy response to a v3 request
rather than silently accepting repeated pages. One real complete book now passes
validation and rendering, but the v3 and unpaid-customer-data gates remain closed
pending broader evaluation and privacy review. See the
[latest evaluation evidence](ai_template_evaluation.md#completed-gemini-book-2026-10-19).

### Generation

1. Interpret the user's actual story, aesthetic, exclusions, density and exact
   requested copy, then plan every physical page of the book. No catalog layouts
   or their coordinates are read. Material IDs identify building blocks only.
2. Compose the cover and inner 1-4 together, then batches of up to eight interiors,
   preserving facing pairs. At most two composition requests run concurrently.
   V3 never calls `expandTemplatePages` or substitutes existing templates.
3. Validate geometry, typography and materials; repair only failed batches.
   A separate semantic review checks the original brief and requirement evidence,
   then can request targeted page corrections. It is not a rendered-image critic.
4. Return the complete book, or fail. A shared budget permits at most two repairs,
   at most `bookBatches(pageCount).length + 7` model requests, and one shared
   provider deadline (Gemini 120s, OpenAI 90s by default). Exhausted or
   non-transient provider failures stop scheduling and abort outstanding work.
   The transport's two shared transient retries are not extra quality repairs.
   Real 20-80-page latency/pass rates still need broader measurement.

The strict structured-output schemas are in `template-book-engine.ts`.
`template-composition.ts` validates the plan, each composition batch and full book.
The same code path is used by the local evaluation runner, not a separate demo.

Geometry is consistently normalized to page fractions: x/y in 0..1, widths and
heights no larger than 1. Only font sizes use the 500-unit typography reference.
This distinction is explicit in composition schemas and prompts. Validation
failures preserve their original error code and identify the precise page and
element for bounded model corrections, rather than silently clamping bad output.

`template-model-checkpoint.ts` optionally records completed model JSON responses
by exact request fingerprint, binding the original brief and model context. A
resume replays these responses through the ordinary engine and all validators;
they are not trusted prevalidated pages. Response size/count and three resume
attempts are bounded, including attempts that fail before another response.
Checkpoint callbacks are serialized. This feature is currently internal to
controlled evaluation: the customer HTTP endpoint neither accepts checkpoints
nor persists durable resumable customer jobs. Do not advertise automatic app
resume based on the synthetic book's successful continuation.

### Editable visual vocabulary

`composition-contract.json` defines 12 free photo-frame options (including none),
eight free paper/panel options, and plain/outline editable type. A concept selects
at most five of each material family rather than using every decoration everywhere.
`tool/generate_ai_composition.dart` generates the client contract. Tests verify
every allowed ID against the editor's real catalogs and free-material policy.
Paid/unknown/remote materials and arbitrary injected fields are rejected.

The new document supports slight rotation (+/-0.12 radians), explicit layer order,
photo overlap and paper backing. All remain native editable layers; no text is
baked into images. The user adds photos later. No library permissions or photo
uploads are requested by this generation path.

### Acceptance gates

- Every requested page, selected physical product and aspect must match; no
  16-page cap or repeated middle-page expansion is accepted for v3.
- Every inner page must have a distinct quantized photo geometry, or text geometry
  for text-only pages. Color/frame swaps, small nudges and horizontal mirrors are
  not sufficient variation. This is not proof of absolute originality.
- Rotated bounds stay inside the physical page; at least 75% of each photo remains
  visible. Occlusion uses conservative rotated bounding rectangles.
- Nothing can cover text. Plain type over photos/patterns requires a fully opaque
  panel; flat backdrops need contrast >=4.5. Large outline titles may overlay
  photos, but real-photo legibility still requires visual inspection.
- Explicit quoted copy is preserved as complete editable text, with at most eight
  distinct phrases of 160 characters each. Longer quotes are rejected, not lost.
  Unprovided numeric dates (including Korean year/month forms) are rejected.
  Other invented personal details are checked semantically, not guaranteed absent.
- The existing actual-font client preflight rejects overflow before successful
  handoff/point eligibility. Fonts are never silently shrunk to pass.
- Frame, paper, z-order, rotation and text style survive the actual save/load path.

### Verification And Release Gate

The shared v3 JSON fixture and 20/24/36/80-page synthetic tests are hand-authored
contract data, not model outputs or saleable templates. Native captures exercise
three aspects at 320x568, 390x844 and 844x390 with inspection photos. They establish
rendering/editability, not AI taste quality or suitability for every phone photo.

```sh
dart run tool/generate_ai_composition.dart --check
deno test --allow-read --allow-env supabase/functions/ai-album-draft/template-book-engine_test.ts tool/ai_template_eval/evaluate_test.ts
flutter test test/design/ai_template_v3_test.dart --dart-define=AI_ORIGINAL_BOOK_QA=true
deno run --allow-read tool/ai_template_eval/run.ts --list
```

The evaluation runner now defaults to v3 with 18 planned 20-36-page brief/aspect
cases; `--engine 2` retains legacy comparison. Live API runs remain opt-in and
were not executed during this change. Inspect success and failure renders before
claiming aesthetic superiority or reliable preference matching.

Release of v3 remains blocked on actual live evaluations. Gemini free-tier tests
do not require OpenAI credit, but do require a usable Gemini key and available
quota. The earlier 2026-10-19 OpenAI live
`travel-square` attempt returned `credit_balance_exhausted`, with no generated
document. No later cases or automatic retries were run. This is the local test
credential's result, not a claim about the separate production key's balance.

Billing protection is deployed in `ai-album-draft` v29 with `verify_jwt: true`:
Auth server verification rejects anonymous sessions; only service-owned generation
records can become reviewable; successful acceptance is owner-bound and idempotent.
The record fixes the nominal price using `ai_album_draft_point_cost()` (unchanged
at 700P). A client amount is an expectation check, never authority to set a price.
V3 also requires the expected actual cost before admission, including first-free
eligibility. A changed price/free status fails before a model call. First-free
UI reads the actual user's claim rather than hardcoding eligibility.

`private.ai_template_generation_policy` admits at most six attempts per user in a
rolling day, two per minute, 100 project-wide per rolling day, four concurrent
generations, and one active generation per user. These are count-based safeguards,
not a verified USD spending ceiling. The model/deadline/repair budgets still apply.
Same request ID + hash replays a server-cached result instead of calling the model;
changed-body reuse fails. A new request supersedes an older unaccepted result.
The lease is three minutes and result replay/acceptance expires after 24 hours.
Expired result payloads are cleared on subsequent admission; this is not a timed
purge guarantee. Wallet debit/free-credit consumption only occurs on acceptance,
not admission, generation failure or rendering rejection.

The private policy's `v3_enabled` is deliberately false pending real visual
evaluation. Deploying protection did not enable unreviewed v3 generation. Existing
legacy requests keep their versioned behavior behind the same admission gate.
Unknown, expired, superseded and cross-user draft IDs cannot be charged. Preview
paths in the legacy photo path must belong to the authenticated actor before any
service-key storage access. The 64KiB request cap applies before admission.

Actual PostgreSQL tests exercise privileges, reservations, completion, free claims,
idempotence, wallet spending races, expiry, policy limits and client-price tampering.
Production postflight compared complete wallet/ledger/usage/free-claim fingerprints:
all unchanged (wallet total 12,000P, five historical usage records). No production
customer was charged or test album created. Existing catalog/purchase prices are
untouched. The private RLS/no-policy informational notices are intentional deny-all;
the authenticated definer charging function is intentional and checks `auth.uid()`.
Other pre-existing project advisor warnings are outside this migration's scope.

## Legacy V1/V2 Reference

## Product contract

The user describes a photobook, selects its physical aspect and requests 4-16
inner pages. The generator returns an original composition for the cover and
every inner page. Photos are added by the user later. The brief-only path does
not request library permissions, collect candidates or upload previews.

The distinguishing product behavior is album-wide art direction: facing-page
relationships, varied pacing, editable typography and a coherent palette.
Originality means we do not retrieve or reuse catalog layouts in this path.
It does not mean that an LLM can guarantee absolute visual novelty or that
Snapfit has trained a proprietary image/design model.

## Implemented flow

1. Write a design brief. Suggested sentences are editable prompts, not layouts.
2. Select portrait / square / landscape and the number of inner pages.
3. Review the request and point policy. Only the text request leaves the device.
4. Plan the art direction, validate it, then generate a complete document against
   that plan. Both stages share one corrective request when needed.
5. Preview every page. Landscape shows facing pages; portrait shows one page.
6. Return to the retained brief to request another complete design, or accept.
7. Existing billing records successful acceptance, then the generated layers
   populate the real album setup and editor, with the requested cover size.

"Request refinement" currently creates a new complete design. It does not lock
pages, preserve an accepted design, or perform selective conversational edits.

## Generation and rendering

`designBrief` on `ai-album-draft` selects the new generator before the legacy
provider/fallback path. It uses `AI_TEMPLATE_MODEL`, then `OPENAI_MODEL`, then
`gpt-4o`. API credentials remain server-side. Existing photo-curation requests
remain backward compatible; new app template requests always use the new path.

New clients send `designBrief.designVersion: 2`. Missing or explicit version 1
retains the previous one-stage generator. Clients accept both document versions,
so deploying the app and function separately does not invalidate old results.

Version 2 first creates an explicit plan: user requirements, 2-6 palette colors,
four typography roles (display/heading/body/caption), and every page's role,
intent and photo count. The second call generates fresh geometry using that
validated plan. A correction keeps the plan; the geometry response cannot
replace it. The plan is metadata, not an extra printable page. Users do not yet
choose between plans before generation; this is an internal two-stage process.

Each page owns a background and normalized photo/text/shape elements. Text
references a typography role instead of overriding its font. Shapes are flat
rectangles behind content. There are no catalog IDs, remote assets or automatic
photo assignments. Text is editable, not embedded in a bitmap. Neither prompt
reads the manually authored quality-studio layouts or their coordinates.

`typography-contract.json` is the shared source for five bundled font families,
their actually registered weights and Hangul support. Its Dart mirror is
generated by `dart run tool/generate_ai_typography.dart`; use `--check` in CI.
Registered weights are checked against Flutter's built FontManifest in tests,
not inferred from font filenames. A document uses no more than three families.

Preview and handoff share the same document-to-LayerModel conversion. Reference
width is 500. Height uses existing CoverSize physical dimensions; handoff maps
directly to coverCanvasBaseSize, avoiding source-canvas inference distortions.

New AI previews and the photo-fill step preserve proportional typography rather
than silently shrinking it to fit. Canvas text does not follow UI accessibility
text scaling; surrounding controls still do. Text family, weight, relative size
and dimensionless line height survive the layer save/load path. Legacy previews
keep their previous fitting behavior.

The existing editor remains responsible for adding/replacing photos. Generated
documents do not yet contain original illustrations, richer vector primitives,
image masks, per-frame crop policies or printer-specific margins. These are
deliberate schema limits, not claims of a finished premium design engine.

## Automated acceptance gate

- Exact requested page count and aspect, unique layer IDs, bounded elements.
- Finite normalized geometry, no content outside the page.
- Exact planned photo count, maximum four per page, with at least two photo-bearing
  inner pages. Text-only opener/story/closing pages are supported.
- Text/content overlap rejection; shapes remain behind content.
- Text contrast >= 4.5 against the visible backdrop. Full-cover panels override
  the paper; partial coverage and later overpainting are checked.
- Server text-fit estimate using planned size/line height and explicit newlines.
- Client TextPainter preflight using the actual bundled font before success and
  point-charge eligibility. Overflow is rejected, not auto-shrunk or charged.
- At least min(3, photo-bearing inner pages) distinct photo compositions using
  quantized geometry; text-only pages are excluded from that count.
- Supported families/registered weights, type hierarchy, Hangul compatibility,
  palette consistency and 4% text safe-area checks.
- Normally two model calls (plan + layout), at most three including one shared
  correction, all within one 90-second deadline. Version 1 retains one plus repair.
- Failure returns no substitute template and does not authorize point charging.

These rules catch structural defects. They do not establish aesthetic quality,
intent fidelity, professional print readiness, or absolute originality. Client
font preflight is not yet fed back to the server for a targeted repair. A failed
client preflight asks the user to retry; it does not salvage or bill the result.
Trim and spine margins still require printer-specific preflight.

The API remains on JSON mode, which guarantees neither schema compliance nor
visual quality; validation and repair remain necessary. See the official
[structured outputs guide](https://developers.openai.com/api/docs/guides/structured-outputs).
The shared timeout fits within the hosted [Edge Function limits](https://supabase.com/docs/guides/functions/limits),
but two-call latency and pass rate must be measured with real credentials.

## Verification and release

Unit tests cover geometry, malformed responses, failed correction, absent
credentials, no-photo requests, normalized rendering and billing handoff.
Widget tests cover three album aspects in both orientations and a narrow phone.
Golden screenshots use explicit test fixtures, not AI-generated samples.

The shared `test/fixtures/ai_template_v2.json` is hand-authored solely for the
server/client contract tests. It is not a live generated result or a catalog item.
Version 2 tests cover a typography-only page, covered-panel contrast, script/weight
rejection, retained plans during correction, shared repair budget, actual font fit,
precise thumbnail scaling, photo-free requests and layer persistence. Existing
version 1 and photo-curation tests remain in the regression suite.

```sh
dart run tool/generate_ai_typography.dart --check
deno test --allow-env --allow-read supabase/functions/ai-album-draft/index_test.ts supabase/functions/ai-album-draft/template-design_test.ts supabase/functions/ai-album-draft/template-art-direction_test.ts
flutter test test/design/ai_template_v2_test.dart test/unit/ai_template_design_test.dart test/unit/layer_export_mapper_test.dart
```

The local live generation check on 2026-09-07 received HTTP 429 with
`credit_balance_exhausted` / `insufficient_quota`. No real model output was
obtained, so visual quality and live validation pass rate remain unverified.
This says nothing about the separate production Supabase account's balance.
No production function deployment is performed by this change.

Before release, deploy the updated function with funded server credentials and
run a real evaluation set: three aspects x several distinct briefs, including
minimal photo books, colorful celebrations and text-heavy stories. Record
latency, model cost, first-pass/corrected success, brief fidelity, spread rhythm,
actual rendered text overflow and editor parity. Save failed results for
inspection instead of weakening validation silently.

Next quality work should follow these results: selective page regeneration with
locks, richer editable type/shape primitives, render-based critique and repair,
and printer-specific preflight. Do not add a stock-template fallback to improve
the apparent success rate.

The next product target, including independent catalog production, design-direction
comparison, selective revision and a real-output quality evaluation, is specified in
[Album Creation Flow](album_creation_flow.md#template-product-direction-2026-09-07).
Plan selection, selective revision and live-output evaluation remain future work;
the internal art-direction plan and typography contract are implemented in version 2.

The local [AI Template Evaluation](ai_template_evaluation.md) pipeline is now
implemented: 18 planned brief/aspect cases, per-attempt records, actual Flutter
rendering, full text-overflow diagnostics and a separate human review workspace.
Its offline fixtures are verified; live visual-quality evaluation still requires
working API quota. The existing production generation/billing flow is unchanged.
