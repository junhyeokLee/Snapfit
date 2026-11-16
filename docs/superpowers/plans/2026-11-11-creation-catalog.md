# Creation Catalogue Implementation Plan

> **For agentic workers:** Execute the bounded UI and metadata tasks in this workspace; root coordinates tests serially and performs a fresh final review.

**Goal:** 승인한 제작 시작과 통합 두 줄 카테고리 목록을 Flutter에 반영하고, 가로 스크롤 표시는 제거한다.

**Architecture:** 기존 `AiAlbumStartStep`의 진입/목록 두 상태와 기존 부모 콜백을 사용한다. 두 줄 표시 위젯과 메타데이터 목록 선택 함수만 분리하고 스토어의 추천·공개일·인기 순위 함수를 재사용한다. 실제 상품·앨범·이미지·임시 저장 로직은 기존 경로를 유지한다.

**Tech Stack:** Flutter, Riverpod, existing store/point-shop domain and providers; no new dependency.

**Spec:** `docs/album-creation-design-review-2026-11-11.md` 최신 요구와 승인 메시지.

## Global Constraints

- 승인한 진입 이미지 `exec-b576c1e2-4292-4765-9d17-b49031e22262.png`, 목록 `exec-6e62b216-381d-452a-917e-331c7c8ea444.png`. 목록의 스크롤 막대만 제외한다.
- 직접 만들기·디자인 시작은 동등한 상단 버튼, 실제 상품 원본·서체·규격을 사용한다. 시안의 가상 상품을 등록하거나 가격을 바꾸지 않는다.
- 전체·추천·인기와 동적 주제는 단일 선택, 두 줄이 같은 가로 위치로 이동. Scrollbar·그린 표시선 없이 스와이프/트랙패드로 탐색한다. 가격 전체·무료·유료는 별도다.
- 카테고리 변경은 검색·가격·즐겨찾기를 유지. 상세에서 복귀해도 목록 위치와 선택을 보존한다. 부모의 임시 저장/계정/새 작업 보호 콜백은 유지한다.
- 유료 보유는 무료로 분류하지 않으며, 서버 확인 중 필터를 확정하지 않는다. 미등록 유료를 무료로 표시하지 않는다.
- 검증된 서버 순위만 인기 우선에 사용, 집계가 없으면 최신순 대체임을 설명한다. 문서 제작 인덱스 `templateTopicOrder`는 변경하지 않는다.
- 320/390px·가로·다크·200% 글자·최소 48px 터치, 사진/책 비율을 보존한다.
- 앱 전체 빌드·상시 서버·운영 배포·DB 변경·커밋 없음. 무거운 테스트/렌더는 한 번에 하나, 동시성 1.

## Review Focus

- 제작 진입에서 직접 만들기/목록 열기와 뒤로가기, 기존 부모 콜백이 유지되어야 한다.
- 가격 서버값이 isPremium 메타데이터와 반대인 사례·미등록 유료·보유 유료가 올바른 필터와 배지를 가져야 한다.
- 추천/인기/주제 사이 전환은 과거 숨은 분류를 남기지 않으며, 즐겨찾기가 인기 순서를 덮어쓰지 않아야 한다.
- 목록 및 가격 조회 실패와 조합 필터 빈 결과는 입력을 유지하고 재시도/조건 해제가 가능해야 한다.
- 큰 글자와 외부 선택 복원에서도 양 행 이동, 화면 밖 항목 접근, 무표시 스크롤과 비율 보존이 유지되어야 한다.

## Tasks

- [x] 제작 진입/목록 기대를 기존 위젯에 먼저 추가하고 실패 확인.
- [x] `creation_category_rail.dart`: `CreationCategoryRail(topCategories, bottomCategories, selected, onSelected)`; 표시·공유 스크롤만 소유, 독립 테스트.
- [x] `creation_catalog_selection.dart`: `selectCreationCatalog(templates, category, price, query, favoritesOnly, favoriteIds, products, discovery, now, featuredIds)`; 서버 가격·추천·검증 인기·검색 조합의 순수 선택 함수와 의미 테스트.
- [x] `ai_album_start_step.dart`: 직접/디자인 시작 상태, 검색·카테고리·가격·즐겨찾기와 실제 카드 통합. 기존 상세 콜백과 원본 아트워크 재사용.
- [x] 필요하면 `album_create_flow_screen.dart`의 진입 헤더만 정리하고 나머지 생성/저장/복구 동작은 보존.
- [x] 영향 받은 생성 위젯 테스트·단독 컴포넌트/선택 테스트·범위 분석·실제 Flutter 렌더 비교·독립 리뷰.

## Rulings / Progress

- 사용자가 수정안을 승인하고 표시 막대 제거까지 지정했다. 추가 디자인 승인 질문 없이 구현한다.
- 현재 작업 폴더에는 이전 승인 작업과 큰 미커밋 변경이 존재하고 Git 메타데이터는 읽기 전용이다. 기존 상태를 보존하기 위해 대상 파일을 작업 전 복사하고 현재 허용된 작업 폴더에서 범위를 제한한다. 다른 변경을 되돌리거나 Git 상태를 재작성하지 않는다.
- Native Flutter CLI는 앞선 실행에서 캐시 쓰기/로컬 테스트 소켓이 막혔다. 기존 로컬 엔진·test_api 직렬 실행 경로로 테스트 본문을 실행하고, 실행되지 않은 검증은 완료로 보고하지 않는다.

## Completion evidence

- 통합 두 줄 카테고리의 스크롤 표시는 제거하고 스와이프·선택·복원은 유지했다.
- 새 제작 목록에서만 큰 표지와 간결한 가격/주제 푸터를 사용한다. 기존 스토어 서가는 기본값을 유지한다.
- 범위 테스트 49개 통과, 390×844 라이트/다크·스크롤 상태 네이티브 PNG 6개와 독립 코드 리뷰를 확보했다.
- 검증 로그: `docs/verification/creation-catalog-2026-11-11/`. 시각 비교: 루트 `design-qa.md`.
- 전체 앱 빌드·실기기·브라우저 실행·운영 배포는 미실행이다. 네이티브 컴포넌트 검증과 구분하며 브라우저 QA는 차단 상태로 기록한다.
