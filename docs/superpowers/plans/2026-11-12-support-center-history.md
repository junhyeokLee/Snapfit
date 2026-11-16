# 고객센터 문의 내역 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Root owns every heavy verification process; helpers work on disjoint files.

**Goal:** 고객센터에서 보낸 문의와 접수 상태를 다시 확인하고, 새 문의 접수 후 해당 목록으로 돌아온다. 편집 저장 후 앞쪽 미완성 페이지로 이동하는 안내도 정리한다.

**Architecture:** 기존 문의 작성 화면과 Supabase 저장 테이블을 보존한다. Repository에 본인 범위 조회와 ID 기반 20개 페이지를 추가한다. 새 고객센터 화면에서 내역을 보여주고 행을 펼쳐 본문을 확인한다. 새 문의는 기존 작성 화면을 열며 확인된 접수 후 목록을 갱신한다. 계정 경계는 SDK 이벤트와 화면의 사용자 정보를 함께 확인한다.

**Tech Stack:** Flutter, Riverpod, 설치된 Supabase Flutter 2.17.2 / Postgrest 2.9.1. 의존성 업그레이드 없음.

**Spec:** `docs/verification/next-redesign-priorities-2026-11-12/다음_개편_우선순위.md`, 사용자 ‘응 진행해줘’ 승인.

## Global Constraints

- 기존 대규모 dirty 변경을 보존한다. 새 앱 빌드·설치·상시 서버는 실행하지 않는다.
- 무거운 컴파일·테스트·분석·캡처는 root가 한 번에 한 프로세스만 실행한다.
- 신규 DB 필드·답변 본문·이메일 발송·답변 알림을 가정하지 않는다. 실제 상태를 ‘답변 완료’로 바꾸어 표시하지 않는다.
- `createInquiry`의 기존 `Future<void>` 계약은 유지한다. 새 읽기는 명시적인 본인 필터와 기존 RLS를 함께 사용한다.
- 실제 문의 발송 없이 HTTP/메모리 fixture로 검증한다. 운영 스키마 검증 가능 여부는 별도 기록한다.

## Review Focus

1. 로그아웃·A→B→A 이후 대기 응답이나 펼친 본문·작성 중 내용이 다시 나타나지 않아야 한다.
2. 추가 조회 실패·새로고침 실패에서도 이미 확인된 문의와 다음 페이지 커서를 보존해야 한다.
3. 접수 성공 후 목록 조회가 실패해도 실패한 접수로 취급하거나 자동 재전송하지 않는다.
4. 잘못된 서버 행·타인 자료·반복 커서가 빈 목록이나 무한 추가 조회로 이어지지 않아야 한다.
5. 좁은 화면·큰 글씨·가로 화면에서도 작성·갱신·더 보기와 내용 확인이 가능해야 한다.

### Task 1: 본인 문의 조회

**Files:** `domain/support_inquiry.dart`, `data/support_inquiry_repository.dart`, `test/unit/support_inquiry_repository_test.dart` (모두 profile 기능 아래).

**Interfaces:** `SupportInquiry`, `SupportInquiryPage(items,hasMore)`, `nextBeforeId`; Repository `currentUserId`, `authChanges`, `fetchMyInquiries({required String ownerId,int? beforeId,int limit=20})`.

- [x] 실제 HTTP 쿼리, 20+1 ID 커서, 소유자·인증·늦은 응답·서버 실패 테스트를 먼저 작성하고 RED 확인.
- [x] 필요한 고객용 열만 조회하고 전후 소유자와 SDK 세션 변경을 검사한다.
- [x] 운영 상태와 로컬 구현을 구분해 결과를 기록한다.

### Task 2: 고객센터 목록과 기존 작성 연결

**Files:** `presentation/views/support_center_screen.dart`, `presentation/widgets/support_inquiry_owner_guard.dart`, `presentation/views/my_page_screen.dart`, `presentation/views/support_inquiry_screen.dart`, `test/widget/support_center_screen_test.dart`.

**Interfaces:** `const SupportCenterScreen()`; 문의 행 `support-inquiry-{id}`, 펼친 본문 `support-inquiry-body-{id}`; 액션 키 `support-history-new`, `support-history-refresh`, `support-history-more`, `support-history-retry`, `support-history-more-retry`.

- [x] 첫 대기·오류·빈 목록, 본문 펼치기, 추가 조회와 재시도, 새 문의 접수 후 목록 갱신, 계정 교체·A→B→A·큰 글씨 테스트 RED 확인.
- [x] 기존 앱 테마로 제목·유형·접수일·상태를 간결한 목록에 표시하고 행을 펼쳐 본문을 확인한다.
- [x] 설정의 고객센터를 목록으로 연결한다. 기존 문의 작성의 입력·종료 보호·주문 fallback은 보존한다.
- [x] 접수 결과를 호출자에게 전달하고 미검증 답변 시간 약속을 제거한다.

### Task 3: 편집 저장 후 이어가기

**Files:** `page_editor_screen.dart`, `test/widget/one_page_saved_flow_test.dart`.

- [x] 실제 2쪽 저장 뒤 미완성 1쪽으로 이동하는 테스트를 먼저 작성하고 RED 확인.
- [x] 완료 시 버튼을 ‘n쪽 이어 채우기’로 변경한다. 미완성인 현재 쪽의 ‘이 쪽 계속 채우기’는 유지한다.

### Task 4: 최종 확인

- [x] 관련 회귀를 한 프로세스씩 실행하고 결과·실패 이름을 기록한다.
- [x] 실제 위젯의 목록·펼친 내용·접수 후 복귀·오류·큰 글씨 화면을 캡처해 직접 확인한다.
- [x] 독립 코드 리뷰, 범위 내 정적 분석, diff 공백 검사를 수행한다.
- [x] 최종 수정 내용과 운영·실기 검증 한계를 간결하게 전달한다.
