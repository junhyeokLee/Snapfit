# Album Creation Flow

## 기획 요약

생성 방식은 네 가지로 열어두되, 결과는 같은 편집 가능한 앨범으로 연결한다.
직접 만들기는 빈 앨범부터 시작하고, AI는 사용자가 요청한 새로운 디자인을 만든다.
무료·프리미엄 템플릿은 실제 디자인을 미리 본 뒤 선택한다.

공통 과정은 **디자인 선택 → 앨범 설정 → 사진 채우기 → 표지 확인 → 자유 편집**이다.
직접 만들기는 사진 채우기 단계를 생략한다. 사진을 덜 채워도 계속 편집할 수 있고,
템플릿으로 시작했더라도 사진·글·배치·장식을 자유롭게 수정할 수 있다.

프리미엄은 기존 구독 권한을 확인하며, 신규 결제가 준비 중인 상태를 숨기지 않는다.
AI 생성 실패를 기존 템플릿으로 대체하거나, 샘플 사진을 사용자 사진처럼 저장하지 않는다.

무료 목록에는 앱 번들 오리지널 3종(Petal Archive, Lost & Found, Good Things)이
포함된다. 서버 카탈로그가 갱신되어도 유지되며 AI 생성 결과로 취급하지 않는다.
규격별 전체 문서, 사진틀, 장식 레이어를 함께 전달한다.
[구성 및 검증](authored_template_collections.md)

## Product Direction

One entrance, four starting points, one editable album. The choice is the amount
of design help the user wants, not a permanent editing mode.

- **직접 만들기**: empty album, physical size and page count, cover editor, page editor.
- **AI 템플릿**: describe an original design, review generation cost, inspect the generated
  pages, use the design, name the album, fill photo slots, review the cover, edit pages.
- **무료 템플릿**: browse the actual catalog, inspect cover and inner pages, choose a
  supported format, fill photo slots, review the cover, edit pages.
- **프리미엄 템플릿**: the same preview and creation path, behind the existing subscription
  entitlement check. No invented prices or pretend checkout.

The AI path remains independent of the template catalog. Existing free/premium
designs are never used as a substitute when original AI generation fails.

## Screens

1. **Creation hub**: manual and AI actions, searchable catalog, All / Free / Premium
   segments. Covers are rendered from actual editable layers where available, not
   blurred illustration placeholders. Bundled templates appear before server refresh.
2. **Design preview**: cover alone; portrait inspects one page at a time, landscape
   inspects inner spreads. Arrows and swipes browse the full document. Existing store
   detail is still available from the store; creation has a focused selection view.
3. **Album setup**: title, original physical dimensions in cm, page count, current design
   provenance, change-design action. Only authored aspect variants are selectable.
   AI designs keep the aspect requested during generation. Added pages are explicitly blank.
4. **Photo fill**: tap a photo slot or add the next missing photo, using the existing
   gallery and permission handling. Replace images without changing layout, typography,
   frame geometry or decoration. Progress counts actual user photos. Skip unfilled slots
   and continue editing when desired. Photo selection is per slot, not bulk autofill.
5. **Cover and editor**: use the existing cover creation, backend save and page editor.
   The handoff retains the edited cover, chosen inner photos and additional blank pages.

## State And Safety

- Selecting from the creation catalog returns a typed selection to the same flow;
  it does not push another nested creation flow.
- Catalog sample photographs are removed from editable image slots. Stickers and
  decorative image assets are not removed.
- A separately stored cover is prepended exactly once, before inner pages.
- Template coordinates carry an explicit canvas and map proportionally to the physical
  album canvas. Missing aspect variants are not faked by stretching the design.
- Back from photo filling returns to setup with selected photos intact. Design changes
  after photo insertion require confirmation. Canceling the design picker returns to setup.
- Photo permission is requested only when the user adds a photo, never while browsing
  templates or submitting an AI design brief. Picker cancellation changes nothing.
- Premium access is not bypassed. Inactive users see the current payment-unavailable
  state; existing active subscribers can continue through the existing entitlement check.
- AI generation and point accounting retain their separate success/failure handling.

## Responsive Layout

- Fixed text sizes with scrollable forms, safe-area-aware footers and 48px action targets.
- Portrait: two-column template catalog, stacked form, single-page photo canvas,
  horizontal page thumbnails.
- Landscape: four-column catalog, side-by-side setup summary and fields, spread preview,
  vertical photo-page thumbnails.
- Verification viewports: 320x568, 390x844, 844x390. Golden captures use bundled fonts,
  icons and real template assets. AI preview fixtures test layout only, not generated quality.

## Document Preview Update: 2026-09-07

AI design review and catalog selection now share `CreationDocumentPreview`.
Portrait shows a single page and a horizontal thumbnail rail; landscape shows
facing inner pages and a separate right-hand rail. The cover remains a single
page. All thumbnails render the actual layers, not page-number chips.

Arrows, swipes and keyboard arrows navigate the document. Selecting the right
page of a spread keeps that exact page when returning to portrait. Selected
thumbnails scroll into view, and the page survives rotation and inspection.
Changing to a different document resets to its cover. Page transitions are
short slides, not the reader's BookFlip animation.

Tapping a page or the expand control opens a separate single-page inspection
route. Pinch/pan, double-tap, zoom controls and fit-to-screen are available there;
page navigation resets zoom. Closing, including system back, preserves the last
inspected page. No preview operation modifies layers, selects photos or calls AI.

AI review moves the acceptance action to the header in landscape. Full rationale,
physical size, palette, fonts and requirements are available in a scrollable
information sheet. On short portrait screens the physical-size subtitle lives
in that sheet to reserve more room for the page. Existing accept/refine callbacks,
generation and point accounting are unchanged.

The local interactive workbench is documented in `template_quality_studio.md`.
It contains authored specimens and contract fixtures, not generated results.

## Remaining Release Checks

- Production AI generation still requires the Edge Function deployment and a working
  model-provider quota. This UI work does not deploy backend functions or restore credits.
- New subscription purchases are currently disabled elsewhere in the product. Reopening
  billing requires a separate payment and server-entitlement release.
- Gallery permissions, cloud-only photographs and final upload/save need live-device
  verification. Widget tests cover photo insertion, picker cancellation, rotation, slot preservation and navigation;
  they do not substitute for OS permission or upload testing.

## Template Product Direction: 2026-09-07

아래는 미리캔버스를 비교 대상으로 추가한 이후의 **목표 기획**이다.
앞의 Screens에 적힌 구현 상태와 구분하며, 시안 비교·부분 재생성·생성 소재 등은
아직 구현된 기능으로 표시하지 않는다. 생성 화면의 완성과 템플릿 품질의 완성은 다르다.

### 두 가지 독립적인 제품

1. **템플릿 라이브러리**: 고르고 싶을 만큼 완성된 앨범 디자인을 충분히 제공한다.
   무료·프리미엄 모두 같은 기본 품질 기준을 통과해야 한다.
2. **AI 맞춤 디자인**: 사용자의 요청을 해석해 새로운 표지와 내지 구성을 만든다.
   라이브러리 검색, 기존 구성의 색상 변경, 사진 자동 배치를 새 디자인 생성으로
   표현하지 않는다. 생성 실패 시 라이브러리 결과로 몰래 대체하지 않는다.

두 경로의 결과는 같은 편집 가능한 문서와 에디터로 연결한다.
직접 만들기는 계속 독립적으로 제공하며, AI를 사용해야만 편집할 수 있게 하지 않는다.

### 라이브러리의 제작 단위

- 한 템플릿은 예쁜 표지 한 장이 아닌 **표지와 모든 내지가 완성된 앨범 컬렉션**이다.
- 여행·웨딩·성장 기록·커플·가족·포트폴리오 등 목적별로 시작하되, 각 목적 안에서도
  에디토리얼·필름·콜라주·타이포그래피 등 실제로 다른 표현을 제공한다.
- 크게 보는 사진, 작은 연속 사진, 기록을 읽는 페이지, 쉬어가는 페이지를
  앨범의 이야기에 맞게 배치한다. 모든 페이지에 사진을 강제로 넣을 필요는 없다.
- 세로·정사각형·가로는 각각 조판하고 검수한다. 한 디자인을 늘리거나 압축해서
  다른 규격을 지원한다고 표시하지 않는다.
- 표지·대표 스프레드·전체 내지 미리보기는 실제 편집 문서에서 렌더링한다.
  샘플 사진과 빈 사진틀 상태를 모두 검수하고, 사진 교체 후에도 구성이 유지되어야 한다.
- 색상만 다른 파생본이나 비율 변환본은 별도 독창적 디자인 수로 세지 않는다.
- 무료의 완성도를 의도적으로 낮추지 않는다. 프리미엄은 독자적인 아트워크,
  풍부한 내지 구성과 컬렉션 범위 등 실제 차이로 설명한다. 가격은 별도 결정한다.

운영 과정은 제작 → 실제 렌더링 → 편집/인쇄 검수 → 승인 → 공개로 둔다.
상태, 작성자, 버전, 지원 규격, 소재 출처와 사용 범위를 기록하고, 승인된 컬렉션만
노출한다. 초기에는 서로 다른 소수 컬렉션으로 기준을 검증한 뒤 제작량을 늘린다.
단순한 대량 생성이나 등록 개수는 품질의 대체 지표로 쓰지 않는다.

### AI의 목표 사용자 흐름

1. **요청**: 원하는 분위기·앨범 목적·사진/글의 비중을 자유롭게 적는다.
   규격과 페이지 수를 함께 받는다. 예시 문장은 입력 보조이며 고정 레이아웃이 아니다.
   참고 이미지 입력은 추후 지원하며, 사용자가 선택한 자료만 전달한다.
2. **디자인 방향 비교**: 우선 서로 다른 2~3개 방향의 표지와 대표 스프레드를 보여준다.
   단순 색상 차이가 아닌 사진 크기, 글꼴 조합, 여백, 구성과 장식의 차이가 있어야 한다.
   이 단계는 샘플 시안임을 표시하고 완성된 전체 앨범인 것처럼 보여주지 않는다.
3. **방향 확정**: 사용자가 고른 시안과 수정 요청을 바탕으로 전체 앨범을 구성한다.
   선택한 시안이 전체 생성에서 임의로 바뀌지 않도록 디자인 기준을 유지한다.
4. **부분 수정**: "표지는 그대로, 3~4페이지만 사진을 크게"처럼 요청한다.
   선택 범위 밖의 페이지·사진·텍스트는 보존하고, 변경 미리보기와 되돌리기를 제공한다.
5. **사진 채우기**: 디자인 확정 후 사진을 넣는다. 사진 교체는 배치나 글꼴을 바꾸지 않는다.
   사진 선택·자르기를 사용자가 통제하며, 자동 채우기는 향후 별도 선택 기능으로 둔다.
6. **자유 편집**: AI 결과를 일반 레이어로 편집한다. 표지와 글을 한 장의 이미지로
   합쳐서 편집할 수 없는 가짜 템플릿을 만들지 않는다.

방향 비교와 전체 생성의 비용·진행 상태는 구분해서 보여줘야 한다.
취소·재시도·이전 시안으로 돌아가기가 기존 결과를 지우거나 중복 과금하지 않아야 한다.
가격과 차감 시점은 서버 계약을 정한 뒤 연결하며, 현재 과금 동작을 임의로 확장하지 않는다.

### 생성 엔진의 개선 순서

현재는 전체 문서를 한 번에 생성하며 사진틀·글·사각형만 표현한다. 다음은 목표 구조다.

1. **디자인 계획**: 사용자 요청을 색상·글꼴 계층·여백·사진 비중·장식 방향·
   스프레드별 역할로 명시한다. 금지 사항과 반드시 지킬 요구도 별도로 보존한다.
2. **표현 능력**: 실제 편집기에서 지원하는 글꼴·프레임·도형부터 검증해 확장한다.
   소재 생성은 별도 기능으로 추가하고, 생성 장식과 사용자의 실제 사진을 구분한다.
   폰트와 소재의 사용 범위·출처를 관리한다.
3. **문서 생성**: 계획을 기반으로 새로운 레이어 배치를 만든다. 공통 렌더러와
   타이포그래피 규칙은 재사용할 수 있지만 기존 카탈로그의 완성 배치를 가져오지 않는다.
4. **렌더링 검수와 보정**: JSON 구조뿐 아니라 실제 글꼴로 렌더링한 페이지와
   스프레드를 검사한다. 문제가 생긴 부분만 수정하고 검사 결과를 다시 확인한다.
5. **의도 보존 편집**: 안정적인 페이지/요소 ID, 잠금 범위, 변경 이력과 원자적 적용으로
   마음에 드는 디자인을 보존하면서 고친다.

새로운 기반 AI 모델을 보유했다는 의미가 아니다. 앨범 설계, 실제 편집 문서 변환,
검수·보정, 규격 대응과 수정 의도 보존을 결합하는 것이 SnapFit의 기술 개발 범위다.

### 품질 승인 기준

**필수 통과 조건**: 저장/재편집 가능, 실제 폰트의 글자 잘림 없음, 사진 교체 후
레이아웃 유지, 요청 규격/페이지 수 일치, 권한과 소재 출처 확인, 미리보기/에디터 일치.
인쇄 준비 완료 표시는 인쇄 업체의 재단·안전 여백·제본 규격 검수까지 통과한 경우만 쓴다.

**시각 평가 초안**: 요청 반영, 타이포그래피, 사진 배치, 스프레드의 흐름,
전체 통일감, 다른 결과와의 다양성을 각각 1~5점으로 평가한다.
1점은 재설계 필요, 3점은 주요 수정 필요, 5점은 공개 가능 수준으로 정의한다.
초기 운영 기준은 모든 항목 4점 이상으로 두고 실제 평가자 간 일치도를 확인해 보정한다.
자동 검사와 AI 평가만으로 공개하지 않고 실제 렌더링을 사람이 검토한다.

첫 평가 묶음은 목적 6개 × 물리 규격 3개 × 서로 다른 요청 2개 = 36개 요청으로 둔다.
텍스트 중심, 사진 중심, 장식이 많은 구성과 절제된 구성을 함께 포함한다.
실제 생성 결과, 사용한 요청/모델/문서 버전, 시도 횟수, 지연시간, 비용,
실패 사유와 위 평가 결과를 보관한다. 실패를 제외하고 성공률을 계산하지 않는다.
실제 생성 평가와 수작업 시안·테스트 fixture는 별도로 표시한다.

### 바로 다음 작업의 완료 조건

첫 디자인 기준 시안과 검증 범위는 [Template Quality Studio](template_quality_studio.md)에
기록한다. 이는 제작 시안이며 실제 AI 생성 성능과 구분한다.

- 서로 다른 디자인 방향으로 표지와 대표 스프레드를 먼저 제작해 눈으로 품질 기준을 정한다.
- 이를 앱의 실제 레이어와 폰트로 표현할 수 있는지 확인하고 부족한 표현 기능부터 추가한다.
- 실제 AI 생성 결과가 그 기준을 충족하는지 평가한다. 현재 테스트 통과를 미적 품질의
  증거로 사용하지 않는다. 로컬 AI 호출은 앞서 잔액 부족으로 실패해 실제 품질은 미검증이다.
- 품질 기준을 검증한 뒤 시안 비교/부분 수정 UI와 라이브러리 확대를 진행한다.
  현재 카탈로그가 이미 높은 품질로 교체되었다고 설명하지 않는다.

## Reference

The decision to converge on an editable document is informed by the template-to-editor
workflow in [Canva's mobile photo-book guide](https://www.canva.com/learn/make-free-photo-books-mobile-tablet/).
The UI and the original AI-template behavior above are SnapFit product decisions, not
a claim that a particular visual style is universally the latest trend.

MiriCanvas's official [AI presentation workflow](https://www.miricanvas.com/ko/features/ai-presentation-maker)
combines topic/outline development, theme selection and editable slide generation.
Its [AI image tool](https://www.miricanvas.com/ko/features/image-generator) provides
prompt-driven visual assets. These inform the distinction between editable document
design and asset generation; they are not evidence that SnapFit currently matches
or exceeds its quality. The comparison does not authorize copying its templates or assets.
