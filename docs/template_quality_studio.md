# Template Quality Studio

## 편집 가능한 신규 컬렉션

꽃처럼 피어난 날, 낯선 곳의 조각들, 좋아하는 순간들 3종을 앱의 무료 템플릿 선택에 추가했다.
각각 표지 + 내지 20쪽(10개 스프레드), 세로·정사각·가로 규격을 포함한다. 원형·타원·아치·라운드·
찢어진 사진·다이컷 스티커를 사용하며, 아래의 이전 검토 시안과는 별도 구성이다.
5개 챕터의 흐름과 편지·기록·사진 모음 구성을 넣고 샘플 사진 15장을 새로 연결했다.
현재 인터랙티브 미리보기의 팔레트 메뉴에서 볼 수 있다.
구현, 검증 및 사진 출처는 [신규 컬렉션 문서](authored_template_collections.md)를 참고한다.

## 이번 단계의 결과

동일한 제주 사진 세트로 서로 다른 세 디자인 방향을 새로 조판했다.
기존 템플릿 JSON, 배치 생성기, 템플릿 카탈로그를 읽거나 복제하지 않는다.
기존 프로젝트의 사진 원본과 번들 폰트, 공통 레이어 컴파일러/렌더러만 사용한다.

| 방향 | 시각 언어 | 대표 스프레드 |
| --- | --- | --- |
| 섬에서 보낸 시간 | 굵은 산세리프 표지, 짙은 녹색, 절제된 명조 | 큰 풍경 사진과 장 시작 페이지, 비대칭 사진 기록 |
| 제주에게 쓰는 편지 | 와인색, 명조, 엽서의 여백과 날짜 | 편지의 도입부와 날짜 기록, 노을 엽서와 추신 |
| 잠시 쉬어가는 날 | 선명한 블루/라임, 큰 숫자와 타이포그래피 | 그래픽 도입부와 전면 사진, 장면 수집과 마지막 인사 |

각 방향은 표지 1쪽 + 내지 4쪽(스프레드 2개)의 **검토용 샘플**이다.
세로 14.5×19.4cm, 정사각형 20×20cm, 가로 19.4×14.5cm를 각각 배치했다.
가로형은 제목/사진의 좌우 분할 등으로 재구성하며 사진이나 글을 늘이지 않는다.
합계 9개 문서, 45쪽이며, 이를 45개의 독립 템플릿이라고 세지 않는다.

이 결과는 AI 생성 결과가 아니다. 상용 컬렉션 완성, 인쇄 가능 판정,
미리캔버스보다 우수하다는 평가를 뜻하지 않는다. 사용자는 이 방향을 바탕으로
후속 작업 진행에 동의했으며, 상용 컬렉션/실제 AI 결과의 최종 승인을 뜻하지 않는다.

## 확인 방법

`output/template-studio/index.html`을 브라우저에서 연다. 서버가 필요하지 않다.
규격 선택, 표지/스프레드 탐색, 샘플 사진/빈 사진틀 비교, 한 쪽/펼침 확대,
로컬 선호 시안 저장을 제공한다. 모바일 확대는 한 쪽부터 보여준다.

화면 속 디자인은 CSS로 다시 그린 별도 시안이 아니다.
실제 `DataTemplateEngine`과 `TemplatePageRenderer`가 출력한 페이지 이미지다.
편집 가능한 원본은 `output/template-studio/documents/*.json`에 별도로 있다.
HTML 자체는 편집기가 아니며 원본은 개발 검토용 문서다.
최종 에디터의 저장/복원까지 동일하다는 픽셀 검증을 완료한 것은 아니다.

## 재현

### Interactive Flutter Preview

`tool/template_studio/preview_app.dart` is a separate developer entry point using
the actual production review/catalog widgets. It does not initialize the app's
backend, submit a generation request, save an album or run a payment. The header
and acceptance dialog explicitly identify the specimens and fixtures as test
data, not AI-generated output. These specimens are not published catalog items.

The menu selects the three existing authored directions or an AI-review contract
fixture, toggles sample photographs, changes the physical aspect and switches
light/dark themes. Photos in this web workbench use existing `images/resized/`
derivatives of the same source images. Authored documents and originals are not
rewritten. The five-page specimens remain review samples, not full collections.

```sh
flutter build web --release --no-web-resources-cdn --no-wasm-dry-run --target tool/template_studio/preview_app.dart --output build/template-preview
python3 -m http.server 4323 --bind 127.0.0.1 --directory build/template-preview
```

Open `http://127.0.0.1:4323`. Choose another available port when necessary.
The normal Flutter web plugin registration still runs; this is not a new
production build or an alternative way to obtain API credits.

`node tool/template_studio/verify_preview.cjs` verifies the running workbench at
390x844, 844x390, 320x568 and 1440x900 using Playwright and PNG pixel checks. Set
`TEMPLATE_PREVIEW_URL` for a different port. It checks photo pixels inside the
cover, navigation, thumbnails, zoom, rotation, information sheets, the no-save
dialog, dark mode, page errors and absence of AI/backend API requests. Captures
and the report are written to the ignored `output/template-preview/qa/` directory.

Widget tests separately cover all three physical aspects, 16-page documents,
both orientations, increased UI text scale, simulated system insets and native
system-back behavior. These checks do not replace live-device gesture testing
or real AI-output evaluation.

### Static Quality Studio

리포지터리 루트에서 실행한다. 앱 실행, 로그인, 외부 API, 서버 배포는 필요 없다.

```sh
flutter test test/design/template_studio_test.dart --reporter expanded
flutter test test/design/template_studio_test.dart --dart-define=EXPORT_TEMPLATE_STUDIO=true --reporter expanded
node tool/template_studio/verify.cjs
```

마지막 명령은 Node의 `playwright`, `pngjs`, `lucide` 패키지가 필요하다.
번들 의존성을 사용할 때는 해당 `node_modules` 경로를 `NODE_PATH`로 지정한다.
브라우저는 설치된 Chrome을 사용하며 다른 채널은 `PLAYWRIGHT_CHANNEL`로 지정한다.
검증 스크립트는 설치된 Lucide를 로컬 출력 폴더에 복사해 오프라인 아이콘을 제공한다.
HTML/JSON/PNG는 위 명령에서 재생성한다. 생성 결과를 직접 수정하지 않는다.

## 검증 범위

- 실제 번들 폰트로 모든 텍스트의 높이와 의도하지 않은 줄바꿈 검사.
- 레이어 경계, ID 중복, 물리 비율, 표지 중복과 데이터 컴파일 검사.
- 사진 제거 후 프레임/문구/글꼴 보존, 실제 물리 캔버스 변환 검사.
- 실제 렌더러로 45쪽 각각의 사진 상태와 빈 상태를 출력.
- 각 사진의 디코딩 완료 및 사진/빈 상태의 실제 PNG 픽셀 차이 검사.
- 1440×1000, 390×844, 320×568, 844×390의 브라우저 레이아웃과 탐색 검사.
- 세 방향 × 세 규격 × 모든 스프레드, 확대, 사진 토글, 로컬 선택 보존 검사.

초기 검수에서 전체 고해상도 이미지를 선로딩하면 캐시 퇴출로 일부 사진이
캡처 시 빠지는 경우를 발견했다. 현재는 각 페이지의 이미지 구독을 유지한 상태에서
디코딩 완료를 기다리고 RawImage 존재도 검사한다. 단순 렌더 예외 없음으로 통과시키지 않는다.

시각 확인용 화면은 `output/template-studio/qa/`, 검사 보고서는 `qa/report.json`에 생성한다.
구조 검사 통과가 미적 품질 승인이나 실제 인쇄 검증을 대신하지 않는다.

## 소재와 공개 범위

사진은 `assets/templates/jeju_travel/images/sources/`의 기존 로컬 원본 5장이다.
새 AI 사진이거나 사용자 개인 사진이라고 표현하지 않는다.
기존 로컬 매니페스트만으로 원저작자/재배포 범위를 확인할 수 없어 공개 전 별도 검수가 필요하다.
폰트의 템플릿 배포 및 인쇄 사용 범위도 함께 검수한다.
공개 카탈로그, 구독/결제, AI 프롬프트, 홈/리더 UI에는 이번 문서를 연결하지 않았다.

## AI 엔진에 드러난 간극

기존 v1 AI 스키마는 글꼴 조합/계층과 사진 없는 도입 페이지를 표현하지 못했다.
후속 v2 구현은 다음 1, 2번의 기반을 연결했다. 이 시안의 레이아웃을 프롬프트나
폴백으로 사용하지 않으며, 계획을 사용자에게 먼저 비교 제안하는 UX는 아직 없다.

다음 구현 범위는 다음 순서로 제한한다.

1. **검증된 글꼴 표현 (구현)**: 번들 폰트 5종의 실제 지원 굵기/한글 지원 계약,
   4단계 글꼴 역할, 실제 폰트 크기 검사와 행간 저장/복원. 새 미리보기와 사진 채우기에서
   글자를 임의 축소하지 않는다. 기존 결과와 기존 카탈로그 렌더링은 호환한다.
2. **명시적 디자인 계획 (구현)**: 먼저 색상, 글꼴 역할, 사용자 요청과 페이지별
   역할/사진 수를 생성·검증한 뒤 새 좌표를 만든다. 중간 계획은 서버 내부 단계이며
   부분 수정 기능은 아니다. 사용자 시안 선택과 정교한 스프레드 품질 판정은 후속이다.
3. **실제 생성 평가**: 생성 문서를 위와 같은 실제 렌더링 검사에 연결한다.
   구조 검사와 사람의 시각 평가를 분리하고 실패 결과도 남긴다.
4. **시안 비교와 부분 수정**: 생성 결과가 기준을 충족하는 것을 확인한 뒤 연결한다.
   페이지/요소 ID와 잠금 범위를 보존하며 수정 전후 비교와 되돌리기를 지원한다.

이번 시안은 품질을 논의할 기준이며, AI가 이미 이 수준을 안정적으로 만든다는 증거가 아니다.
앞선 로컬 AI 호출은 잔액 부족으로 실패했으므로 실제 생성 품질 평가는 별도로 필요하다.
이번 v2는 서버/앱 계약과 수동 테스트 문서로 검증했으며 서버 배포나 실생성 검수를
완료한 상태가 아니다. 상세 계약과 재현 명령은 `ai_template_original_design.md`를 참고한다.
