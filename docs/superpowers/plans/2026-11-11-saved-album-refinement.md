# Saved Album Refinement Implementation Plan

> Root implements; one agent updates narrow regressions, another reviews the existing navigation contract. Native checks run serially.

**Goal:** 저장 후 화면에서 긴 설명을 줄이고 미완성 앨범의 이어서 편집을 바로 찾게 한다.
**Architecture:** 기존 저장 문서 화면과 HomeAlbumActions.onEditSelected를 재사용한다. 작은 이어서 편집 동작을 작성 상태 옆에 두며 새 편집기를 만들지 않는다.
**Tech Stack:** Flutter/Riverpod, existing repositories and native widget harness. No dependency/DB/build/deploy changes.
**Spec:** docs/verification/saved-album-followup-2026-11-11/README.md와 사용자의 ‘이어서 진행해줘’ 승인.

## Global Constraints

- 큰 앨범 미리보기·원래 비율·페이지 선택·모바일 1열/데스크톱 2열을 유지한다.
- 기존 감상 기본 버튼을 유지하고 큰 버튼을 추가하지 않는다. 제목24px, 짧은 저장 상태·작성 수만 보여준다. 긴 상단/공유 안내 문단은 제거한다.
- 편집 권한이 있는 명시적 미완성 앨범에만 이어서 편집을 표시한다. 최신 문서를 읽어 첫 미완성 내지부터 기존 PageEditorScreen으로 연다.
- 저장 후 원래 화면으로 돌아오며 닫힌 후 최신 문서/권한을 다시 읽는다. 계정 변경·중복 입력·늦은 준비 결과는 새 화면을 열거나 이전 내용을 표시하지 않는다.
- 모든 추가 HomeAlbumActions 옵션은 기본 동작을 유지한다. 기존 전역 준비 잠금은 편집기 진입 후 즉시 해제한다.
- 전체 앱 빌드/배포/운영 변경/Git 쓰기 없음. 무거운 작업 한 번에1개.

## Tasks

- [x] 기존 저장 화면의 실제 최신 캡처와 source를 확인한다.
- [x] 기능 회귀를 추가하고 RED 확인: incomplete editable→edit, viewer/complete 숨김, current owner/permission 재검사, 복귀 후 갱신.
- [x] HomeAlbumActions에 canContinue / returnToPreviousOnSave / onEditorClosed 선택 인자를 추가하고 기존 준비/해제 계약을 보존한다.
- [x] 저장 화면 상단 설명을 축소하고 상태 옆 이어서 편집을 연결한다.
- [x] 관련 저장/편집 진입 회귀, 정적 분석, 독립 리뷰와 실제 폰트·사진 캡처 확인.

## Review Focus

- Viewer 또는 로딩 중 edit 액션 미노출/비활성, prepare 중 owner 변경 시 무변경.
- 첫 미완성 내지 기준은 재조회한 문서이며 snapshot의 오래된 진행률이 아니다.
- onEditorClosed는 원래 화면이 살아 있고 같은 계정일 때만 문서를 다시 읽는다.
- 반복 저장 완료 화면을 쌓지 않으며 기존 다른 caller의 navigation 계약을 변경하지 않는다.

## 결과

관련 테스트30개와 변경 후 캡처4개 통과, 정적 분석 이상없음. 실제 화면과 범위는 `docs/verification/saved-album-refinement-2026-11-11/README.md`를 따른다.
