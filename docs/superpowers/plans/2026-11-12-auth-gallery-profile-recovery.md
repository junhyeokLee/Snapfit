# 인증·사진 선택·프로필 복구 개선 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement task-by-task.

**Goal:** 확인된 인증 가독성·복귀, 사진 조회 오류 안내, 프로필 텍스트 이탈 문제를 해결한다.

**Architecture:** 기존 Flutter/Riverpod 계층과 화면을 유지한다. 인증은 UI 상태와 기존 인증 결과만 사용하고, 사진은 기존 상태 원인을 구분하며, 프로필은 텍스트 변경 여부를 이탈 시 확인한다. 서버·데이터베이스·새 의존성은 변경하지 않는다.

**Tech Stack:** Flutter, Dart, Riverpod, 기존 위젯·상태 테스트.

**Spec:** `docs/verification/remaining-flows-audit-2026-11-12/다음_개선_우선순위.md` 및 사용자 ‘진행해줘’ 승인.

## 공통 제약

- 기존 작업과 고객 데이터·권한·저장 상태를 보존한다. 전체 앱 빌드와 운영 서버 변경은 실행하지 않는다.
- 이 Mac의 무거운 컴파일·테스트·분석·렌더는 root가 한 프로세스씩 수행한다.
- 각 담당자가 회귀 테스트를 먼저 작성한다. root가 기존 코드에서 실패를 확인한 뒤 제품 구현을 진행한다.
- 최종 결과는 해당 영역 회귀 테스트, 실제 위젯 캡처, 정적 분석과 별도 코드 리뷰로 확인한다.

## 검토 초점

1. 영상 성공·실패·로딩과 밝은/어두운 테마의 입력 가독성.
2. 비밀번호 변경 성공이 인증을 만들어내지 않으며 실패는 입력을 보존할 것.
3. 발송 요청 주소와 수정된 입력을 혼동하지 않고 기존 재발송 제한을 유지할 것.
4. 사진 권한 거부·정상 빈 목록·조회 예외를 구분하면서 기존 재시도를 보존할 것.
5. 프로필 변경 복구·저장 성공·계정 전환·동시 뒤로가기가 불필요한 확인이나 다른 계정 노출을 만들지 않을 것.

## 작업 1: 로그인·계정 복구

Files: `lib/features/auth/presentation/views/login_screen.dart`, `test/widget/login_screen_test.dart`, 필요한 인증 전용 회귀 테스트/플랫폼 대역.

- [x] 영상 상태·테마, 성공 후 주 행동, 발송 주소 변경의 회귀 테스트 작성 및 RED 확인.
- [x] 영상 표시 여부와 배경 조건을 맞추고, 변경 성공 후 완료·복귀를 주 행동으로 한다.
- [x] 기존 인증 상태와 현재 route를 기준으로 복귀한다. 발송 주소 변경 시 이전 성공 안내를 정리하고 cooldown을 유지한다.
- [x] 인증 관련 회귀 및 밝은/어두운 화면 캡처 확인.

## 작업 2: 사진 선택 오류 안내

Files: `lib/shared/widgets/album_bottom_sheet.dart`, `lib/features/album/presentation/viewmodels/gallery_notifier.dart`와 직접 관련 테스트.

- [x] 권한·빈 목록·일반 예외를 구분하는 테스트 작성 및 RED 확인.
- [x] 오류 원인을 따라 최소 수정한다. 조회 실패는 ‘사진을 불러오지 못했어요’와 기존 재시도를 표시한다.
- [x] 기존 선택·날짜·페이징 흐름의 회귀와 실제 선택 시트 캡처 확인.

## 작업 3: 프로필 미저장 이탈 보호

Files: `lib/features/social/presentation/views/social_profile_edit_screen.dart`, `test/widget/social_profile_screens_test.dart`와 필요한 전용 테스트.

- [x] 변경·취소·폐기·원상복구·저장·계정 전환 테스트 작성 및 RED 확인.
- [x] 변경된 텍스트가 있을 때 ‘계속 수정 / 나가기’를 확인한다. 상단과 시스템 뒤로가기에 동일하게 적용한다.
- [x] 사진 별도 확인, 처리 중 이탈 방지, 계정 전환 초기화를 보존한다.
- [x] 프로필 회귀 테스트 및 확인창·작성 유지 캡처 확인.

## 통합 검증

- [x] 적절한 관련 회귀 테스트와 정적 분석 완료.
- [x] 독립 코드 리뷰의 결함 수정.
- [x] 결과·화면·검증 범위와 미확인 범위를 문서화. 임시 컴파일 산출물 정리.

완료 근거: `docs/verification/auth-gallery-profile-2026-11-12/verification.json` — 관련 회귀 180개, 신규 31개 포함. 캡처 9개 시나리오/17장, 정적 분석 10파일 이상 없음. 별도 코드 리뷰에서 범위 내 결함 없음. 실제 OS·메일·딥링크·앱 전체 빌드는 미확인.
