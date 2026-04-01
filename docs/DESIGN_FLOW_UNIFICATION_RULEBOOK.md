# SnapFit 디자인/플로우 통일 규칙 (실서비스 운영본)

## 1. 폰트 규칙
- 앱 공통 본문: `NotoSans`
- 앱 공통 강조/헤드라인: `Raleway`
- 템플릿 내부 장식 폰트(커버/페이지): 템플릿 JSON 정의를 따르되, 앱 UI(네비/버튼/폼)에는 사용 금지
- 금지: 앱 UI에서 `Inter` 직접 하드코딩

## 2. 색상 규칙
- 앱 UI 색상은 `SnapFitColors`, `SnapFitStylePalette` 토큰만 사용
- 화면 레벨에서 `Color(0x...)` 직접 사용은 지양
- 예외: 템플릿 렌더러(의도된 아트워크 색상)만 허용

## 3. 간격/라운드/모션 규칙
- 간격: `SnapFitSpace` (`xs/sm/md/lg/xl/xxl`)
- 라운드: `SnapFitRadius` (`sm/md/lg/pill`)
- 모션: `SnapFitMotion` (`fast/normal`)

## 4. 화면 플로우 규칙
- 결제 플로우:
  - 주문 생성 -> 결제창 진입 -> 승인 콜백 -> 상태 전이
  - `PAYMENT_PENDING -> PAYMENT_COMPLETED -> IN_PRODUCTION -> SHIPPING -> DELIVERED`
- 알림 플로우:
  - 홈 배지 표시 -> 알림 화면 진입 시 읽음 처리 -> 정책 기간 경과 시 자동 정리
- 탈퇴 플로우:
  - 확인 모달 -> 서버 삭제 -> 디바이스 FCM 토큰/토픽 해제 -> 로컬 세션 제거

## 5. 운영 게이트
- 템플릿 게이트:
  - `dart run tool/template_release_gate.dart`
- UI 일관성 게이트:
  - `dart run tool/ui_consistency_gate.dart`

## 6. 이번 반영 범위
- 공용 토큰 추가: `lib/core/theme/snapfit_design_tokens.dart`
- 테마 토큰 연동: `lib/core/theme/snapfit_theme.dart`
- 핵심 화면 일부 적용:
  - `MyPageScreen`, `OrderHistoryScreen`
  - `AlbumReaderInnerDetailScreen`의 Inter 제거

