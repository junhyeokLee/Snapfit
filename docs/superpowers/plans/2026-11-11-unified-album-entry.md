# Unified Album Entry Implementation Plan

> **For agentic workers:** Root implements entry and runs serial native checks. Bounded optional photo tools and test work are delegated. Use executing-plans without reopening settled user approvals.

**Goal:** 기존 편집기 UI를 유지하고 설정에서 표지·내지 통합 편집기로 바로 진입한다.

**Architecture:** 기존 reset/bind/create/recovery 계약을 부모의 공통 진입 메서드로 옮긴다. 서버ID와 연결된 내구성 있는 초안 저장이 끝난 뒤에만 기존 PageEditorScreen을 연다. 기존 TemplatePhotoFillStep은 더보기에서 선택하는 staging 도구로 재사용하고 명시적 적용 시 현재 VM의 변경 페이지별 히스토리를 보존한다.

**Tech Stack:** Flutter/Riverpod, existing repository/persistence APIs and local draft store. No dependency upgrade or DB change.

**Spec:** `docs/unified-album-editor-design-2026-11-11.md`, 최신 사용자 기존 편집기 유지/새3시안 제외와 실행 승인.

## Global Constraints

- 기존 PageEditorScreen/캔버스/페이지 rail/context dock의 배치·도구는 보존한다. 새3시안 미적용.
- 필수 사진 채우기·별도 표지·생성 전 전체 확인을 거치지 않는다. 디자인→간단 설정→기존 편집→저장.
- 첫 편집 페이지는 표지0. 복원 checkpoint는 저장된 페이지·좌표를 그대로 사용한다.
- 생성 전 immutable attempt를 저장하고, 응답 유실/재시도에 같은 request ID를 사용한다. ID/초안 연결 저장 실패 시 화면 전환 금지.
- 계정·초안·편집 세션이 달라지면 비동기 결과를 적용하지 않는다. 이전 앨범의 전역 VM 내용을 새 앨범 표지로 읽지 않는다.
- 이름50자/공백 차단, 공식5규격, 내지20~80쪽·2쪽 단위/콘텐츠 최소값, 실제 표지 문구·crop·사진·추가 빈 페이지·상품 키·보유권을 보존한다.
- 사진 여러 장/순차 배치는 선택 도구다. route 작업본은 원본과 격리하고 취소·실패·오래된 적용은 무변경이다. workspace 안의 batch undo와 main editor의 기존 페이지별 undo 계약을 각각 유지한다.
- 기존 생성 draft의 미배치 사진은 editor 선택 도구로 인계하고 계정/다른앨범에 섞지 않는다.
- 전체 앱 빌드·상시 서버·배포·DB 변경·Git 변경 없음. 무거운 테스트/렌더/분석은 한 번에1프로세스, concurrency1.

## Review Focus

- 이전 앨범 VM이 살아 있는 새 직접/템플릿 생성에서 표지·사진이 섞이지 않음.
- 생성 요청 중 중복 계속하기, owner 변경, 응답 유실에도 잘못된 이동/중복 생성 없음.
- 이미 ID가 있거나 로컬 checkpoint만 실패한 재시도는 reset/create를 반복하지 않음.
- 기존 showPhotoFill 초안·수정 표지·원본 canvas·AI 수락·상품 키의 인계 보존.
- optional photo route의 늦은 picker/preview 결과와 타 계정/문서/규격 변경을 거절하고 원래 페이지 ID/배경/텍스트/undo 보존.

## Tasks

### Task 1: 설정에서 기존 편집기로 진입

**Files:** parent `album_create_flow_screen.dart`, `album_create_step1.dart`; new `test/widget/unified_album_entry_test.dart`.

- [x] 기존 UI에서 실패하는 direct-entry 테스트 작성·RED 실행.
- [x] `_startAlbumEditing()`에서 입력/owner를 확정하고 최초에만 VM reset→bindCreationDraft→canvas→현재 표지 적용→saveAlbumToBackend.
- [x] 동일 VM 세션 재시도는 ID/attempt/pending save를 유지. revision conflict의 기존 keep/review 의미 유지.
- [x] `_handleAlbumCreated`를 재사용해 전체 문서/연결 checkpoint를 저장하고 표지0으로 이동. old created checkpoint는 기존 복원 경로 유지.
- [x] 설정 CTA는 `앨범 편집하기`, 준비 중 비활성/피드백. 원래 선택 콜백은 대기 중 잠금.
- [x] 네이티브/웹 단계 표시는 디자인·설정·편집만 남김. 기존 old-step 초안은 현재 설정에 내용 보존해 복원.
- [x] 신규 테스트 GREEN과 create/recovery/owner 회귀.

### Task 2: 선택 사진 도구 연결

**Files:** new album_photo_fill_draft.dart / editor_photo_fill_screen.dart; album_editor_view_model.dart; editor_more_tools_sheet.dart; editor_context_dock.dart; page_editor_screen.dart; template_photo_fill_step.dart; new photo-fill entry/draft tests.

- [x] 현재 MoreToolsSheet에서 `사진 여러 장 넣기`가 없어서 실패하는 RED 실행.
- [x] beginPhotoFill/isPhotoFillCurrent/applyPhotoFill로 계정/세션/문서/규격과 작업본을 격리. 현재 값과 불일치하면 거절.
- [x] 기존 More 액션 handoff로 workspace 열기. 명시 `편집기에 적용`만 반영하고 닫기/취소는 무변경.
- [x] 변경 페이지마다 기존 page undo1개를 기록하고, 순차 배치 preview/취소/undo는 workspace에서 그대로 사용. 적용 후 미배치 큐는 현재 editor세션에 유지하며 연결된 생성 초안에도 함께 기록.
- [x] 신규 단위/위젯·단독 batch/history 회귀 GREEN.

### Task 3: 검증·다음 화면 점검

**Files:** 관련 creation/AI/draft/recovery/size/cover-copy tests, docs verification.

- [x] 기존 부모 테스트의 사라진 단계 가정만 새 entry에 맞춰 변경. 원래 데이터/권한/실패/복원 assertions 보존.
- [x] 범위 테스트·정적 분석·독립 리뷰. baseline 미커밋 변경은 유지.
- [x] 실제 native entry와 기존 편집기 표지/내지/optional 사진 도구 capture 확인. 새mock사진으로 실제 원본을 교체하지 않음.
- [x] 이어서 저장 직후 화면을 캡처해 필요한 후속 개선만 제안. 기존 주문 커버 선택 이동은 주문 흐름을 확인한 뒤 별도 범위로 구체화한다.

## Execution Rulings

- Task 2 Ruling: 선택 사진 workspace는 소유 Navigator로 갤러리·하위 시트·crop을 함께 제거하며, Browser 사진 선택도 가장 가까운 Navigator를 쓴다. 미배치 큐는 적용 시 편집 초안에 함께 기록하고, 저장 안 함은 진입 당시 문서와 큐를 함께 복원한다.

- Task 2 Ruling: 일반·과거 로드 앨범의 표지/내지는 모두 500×H 참조 좌표로 읽으며 state의 canvas 값은 화면 측정값이므로, 선택 사진 도구에 기존 `editorReferenceCanvasSize()`의 단일 `canvasSize`를 전달한다. crop·순차 배치 미리보기·썸네일도 같은 좌표를 사용하고, 기존 제작 호출의 물리 캔버스 기본값은 보존한다.

사용자가 기존 UI 보존과 진입 단축을 승인했으므로 계획/실행 방법을 다시 묻지 않는다. 읽기 전용 Git과 큰 작업 폴더를 보존하고 `/tmp/snapfit-unified-entry-before/`에 수정 대상 시작 상태를 복사한다. 일반 Flutter CLI의 캐시/소켓 제한이 계속되면 설치된 엔진/test_api로 동일 테스트 본문을 직렬 실행하며 한계를 기록한다.

## 최종 검증 기록

- `docs/verification/unified-album-entry-2026-11-11/verification.md`: 네이티브217개, 캡처6개 통과. 원래 편집기 UI와 문서 보존, 중복 재시도, 사진 큐·계정·취소·저장 실패를 확인했다.
- 제품 분석 오류/경고0, 기존 폰트 진입 info2. 테스트/helper 분석 이상없음. 독립 검토 완료.
- 웹 AI19개는 네이티브에서 명시 제외하며 실제 브라우저·IO fixture 호환 검증은 후속으로 남긴다. 전체 앱 빌드·배포·운영 API 실행 없음.
- 선택 도구의 별도 페이지 배경색도 미리보기에 전달하고 기존 기본 렌더링 보존을 검증했다. 주문 단계 커버 선택 이동은 후속 범위로 남긴다.
