# SnapFit — 에이전트 사용 가이드

> Cursor에서 특정 작업 시 **어떤 에이전트를 부를지** 참고용.

## 에이전트 목록

| 에이전트 | 용도 | 호출 시점 |
|----------|------|-----------|
| **full-stack-sync-master** | Spring Boot ↔ Flutter API·DTO 동기화 | 백엔드 API/엔드포인트/DTO 수정 시, 새 API 추가 시 |
| **riverpod-architect** | MVVM·Riverpod, ref.listen·AsyncValue·ref.select | ViewModel/상태 플로우 구현·검토, UI-로직 분리 점검 시 |
| **security-quality-auditor** | 보안·코드 품질 (토큰, 저장소, API 키) | 인증·저장소·외부 연동 추가/수정 시 |

## 작업별 추천

- **새 REST API 추가 (BackEnd + Flutter)** → full-stack-sync-master
- **화면에서 Snackbar/Navigator 등 사이드 이펙트** → riverpod-architect (ref.listen 사용 여부 확인)
- **로그인/토큰/환경 변수/보안 설정** → security-quality-auditor
- **테스트 작성** → `TESTING.md` + 규칙 `snapfit-testing.mdc` 참고

## 규칙과의 관계

- 에이전트는 **역할별 심화 검토**용.
- 일상적인 코드 스타일·구조는 `.cursor/rules/` 의 규칙이 적용됨.
