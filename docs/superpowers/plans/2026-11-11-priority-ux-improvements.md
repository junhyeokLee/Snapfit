# SnapFit Priority UX Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 승인된 실제 불편 3곳을 홈 → 주문 → 공개 확인 순서로 개선한다.

**Architecture:** 기존 Flutter/Riverpod 화면과 서버 응답을 유지한다. 월간 기록은 기존 달력 컴포넌트를 우선 재사용하고, 주문은 서버 readiness로 UI 진입을 판단하며, 공개는 선택 페이지·대표 페이지와 명시적 동의를 유지한 채 검토 목록을 압축한다.

**Tech Stack:** 기존 Flutter SDK, Riverpod, Material, 설치된 테스트 런타임. 신규 의존성 없음.

**Spec:** docs/verification/whole-ux-audit-2026-11-11/README.md 및 2026-11-11 사용자 승인.

## Global Constraints

- 홈의 오늘 기록·보상 1,000P·지난날 사진 추가 금지·사진 원래 비율·큰 내 앨범을 보존한다.
- 주문 준비 상태와 가격 승인 상태를 구분한다. 관리자 TEST와 이전 주문 복구를 보존한다.
- 공개 페이지 선택·순서·대표 페이지·동의·오류 복구·계정 격리를 보존한다.
- 대각선 화살표, 큰 추가 안내 카드, 불필요한 새 기능을 추가하지 않는다.
- 현재 작업 트리의 기존 변경을 보존하며 .git 변경, 앱 전체 빌드, 서버·DB·결제·공개 실행을 하지 않는다.
- 무거운 컴파일·테스트·렌더·분석은 root가 직렬로 실행한다.

## Review Focus

- 28·29·30·31일/월 첫 요일/큰 글자/다크에서도 날짜가 빠지거나 겹치지 않는지.
- 기록을 놓친 달에도 진행과 앨범 가치가 남고 미래·놓친 날짜 업로드를 유도하지 않는지.
- 가격 확정·주문 불가 조합, readiness 실패·변경, 관리자 TEST, 기존 주문 복구가 섞이지 않는지.
- 1쪽/20쪽/가로·세로 페이지, 순서 변경 뒤 대표 페이지와 공개 데이터가 일치하는지.
- 보이지 않는 페이지 미리보기를 불필요하게 전부 렌더링하지 않는지, 동의와 주요 버튼에 쉽게 도달하는지.

## Task 1: 홈 월 전체 기록판

**Files:** home_moment_summary_card.dart, 필요 시 moment_month_calendar.dart / home_moment_reward_summary.dart, 관련 위젯 테스트.

- [x] 월 전체 날짜·오늘·놓친 날·미래·보상 실패 후 진행 유지 회귀 테스트를 추가하고 RED 확인.
- [x] 주간 줄을 월 달력으로 교체하고 기존 오늘 기록과 월간 앨범 동선을 유지.
- [x] 다크·큰 글자·월 날짜 수 및 기존 사진 달력 회귀 확인.
- [x] 실제 폰트·사진의 전후 화면 비교.

## Task 2: 배송지 입력 전 주문 가능 여부

**Files:** print_order_preview_screen.dart, 필요 시 print_order_checkout_screen.dart, 관련 위젯 테스트.

- [x] 주문 불가 시 개인 정보 입력을 요구하지 않는 회귀를 추가하고 RED 확인.
- [x] 서버 상태를 가격 근처에서 알리고 일반 주문 불가 진입을 방지.
- [x] READY·재시도·직접 진입·기존 주문 복구·관리자 TEST 경로 보존 확인.
- [x] 정상·준비중·실패 상태 실제 화면 비교.

## Task 3: 공개 최종 확인 압축

**Files:** social_publish_screen.dart, 관련 공개 위젯 테스트.

- [x] 20쪽 검토의 버튼 접근·선택·순서·동의 회귀를 추가하고 RED 확인.
- [x] 큰 대표 미리보기와 작은 선택 목록으로 압축하고 선택한 쪽을 확인하도록 개선.
- [x] 실제 공개 시 데이터·동의·재시도·이탈·계정 격리 회귀 확인.
- [x] 20쪽 전후 스크롤 길이와 실제 화면 비교.

## Final Gate

- [x] 관련 테스트·분석·독립 코드리뷰 통과.
- [x] 승인된 세 변화가 실제 전후 화면에서 확인됨.
- [x] 검증 기록과 현재 범위를 설명하고 결과 전달.
