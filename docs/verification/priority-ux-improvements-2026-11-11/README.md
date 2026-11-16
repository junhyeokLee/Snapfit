# 승인된 우선 UX 개선 3곳 — 반영 및 검증

2026-11-11 사용자 승인에 따라 홈 → 주문 → 앨범 공개 확인 순서로 반영했다. 기존 Flutter/Riverpod 구조, 사진 비율과 편집 흐름을 유지했다. 제품 6파일과 관련 테스트 9파일을 변경했다.

## 실제 달라진 점

| 우선 | 이전 | 반영 후 |
| --- | --- | --- |
| 1. 홈 기록 | 주간 7일만 표시, 보상 불가 시 누적 일수 대신 실패 문장 | 월 전체 사진 달력. 기록 사진·오늘·미래·놓친 날 잠금을 구분. 보상 불가여도 누적 진행 유지 |
| 2. 주문 | 서버 주문 불가여도 배송지 입력 후 막힘 | 미리보기 금액 옆에 주문 상태 표시. 준비 중이면 배송지 진입 차단. 직접 진입도 폼 대신 안내·재확인·계속 편집 |
| 3. 공개 확인 | 큰 페이지 20장을 모두 세로 나열 | 한 장 미리보기 + 작은 가로 목록. 선택한 쪽 확대, 첫 순서가 대표 페이지, 재정렬 시 동의 재확인 |

공개 최종 확인에서 같은 20쪽·390×844 화면·실제 폰트/사진 기준으로 버튼까지 스크롤이 **8,694px(11.50화면) → 205px(0.27화면)**으로 줄었다. 공개 버튼은 누르지 않고 위치만 측정했다.

## 홈 전후

중순 상태를 확인하기 위한 11월 18일 예시 데이터다. 1,000P, 한국 시간 당일 사진, 해당 월 전체 날짜 완주, 지난날 사진 추가 금지 조건은 변경하지 않았다. 보상 지급 상태와 인정 일수는 서버 응답만 표시한다.

| 이전: 이번 주만 표시 | 반영 후: 월 전체 사진 기록판 |
| --- | --- |
| ![홈 이전](sandbox:/Users/devsheep/SnapFit/SnapFit/docs/verification/priority-ux-improvements-2026-11-11/before/home/01-home-on-track-390x844.png) | ![홈 개선](sandbox:/Users/devsheep/SnapFit/SnapFit/docs/verification/priority-ux-improvements-2026-11-11/after/home/01-home-on-track-390x844.png) |

놓친 8일은 잠금으로 표시된다. 오늘 실제 사진이 있으면 해당 날짜를 열고, 사진이 없으면 오늘 기록을 시작한다. 같은 날 글만 있는 기록과 사진 기록이 섞인 경우도 확인했다. 달력 날짜의 명시적 접근성 탭을 연결했다.

![놓친 날짜와 진행 유지](sandbox:/Users/devsheep/SnapFit/SnapFit/docs/verification/priority-ux-improvements-2026-11-11/after/home/02-home-missed-day-390x844.png)

기존 월간 사진 달력을 compact 옵션으로 재사용했다. 주간 전용 위젯은 제거했다. 일반 기록 화면의 기존 사진 달력 기본 동작을 보존한다. 다크·320px 큰 글자(2배)에서 날짜와 오늘 기록 행동에 접근하는 화면도 확인했다.

## 주문 전후

canPay=false / PREPARING을 반환하는 메모리 저장소와 예시 가격 49,900원을 사용했다. 운영 주문 가능 상태나 실제 가격을 조회한 결과가 아니다. 가격 승인 여부와 실제 주문 가능 여부를 구분한다.

| 이전: 배송지 입력 후 주문 준비 중 | 반영 후: 입력 전에 주문 안내 |
| --- | --- |
| ![주문 이전](sandbox:/Users/devsheep/SnapFit/SnapFit/docs/verification/priority-ux-improvements-2026-11-11/before/print/print-04-blocked-after-address.png) | ![주문 개선](sandbox:/Users/devsheep/SnapFit/SnapFit/docs/verification/priority-ux-improvements-2026-11-11/after/print/print-05-direct-blocked.png) |

미리보기에서도 가격 옆에 준비 상태를 표시하고, 배치를 확인해도 주문 불가 상태의 배송지 버튼은 활성화하지 않는다. READY 상태이면 기존 폼으로 이어지고, 재확인 후 READY가 되면 입력을 다시 시작할 수 있다. 이전에 입력한 컨트롤러 값은 보존한다.

| 미리보기에서 먼저 안내 | 배치 확인 후에도 준비 중 유지 |
| --- | --- |
| ![미리보기 주문 상태](sandbox:/Users/devsheep/SnapFit/SnapFit/docs/verification/priority-ux-improvements-2026-11-11/after/print/print-01-blocked-preview-top.png) | ![배송지 진입 차단](sandbox:/Users/devsheep/SnapFit/SnapFit/docs/verification/priority-ux-improvements-2026-11-11/after/print/print-07-blocked-action.png) |

관리자 300 하드커버·80쪽 TEST 권한은 별도 capability 확인 후만 허용하며, 거절된 권한이 일반 주문 폼으로 우회하지 않게 했다. 기존 미결제 주문 확인·복구·취소와 TEST 진행 상태는 신규 주문 가용 여부와 분리해 유지했다. 서버 응답 실패·내용 변경 시 이전 준비 완료 상태를 무효화한다.

## 공개 확인 전후

| 이전: 페이지 20장 세로 나열 | 반영 후: 큰 미리보기와 작은 전체 목록 |
| --- | --- |
| ![공개 이전](sandbox:/Users/devsheep/SnapFit/SnapFit/docs/verification/priority-ux-improvements-2026-11-11/before/publish/social-publish-review-top.png) | ![공개 개선](sandbox:/Users/devsheep/SnapFit/SnapFit/docs/verification/priority-ux-improvements-2026-11-11/after/publish/social-publish-review-action.png) |

현재 선택한 페이지의 실제 비율을 보존한다. 작은 목록은 필요한 항목만 렌더링하며, 순서를 바꿔도 같은 페이지를 보고 있게 한다. 선택한 순서와 대표 페이지는 기존 공개 payload와 일치한다. 제목·주제·공개 범위·명시적 동의·실패 재시도 키·계정 격리는 유지했다. 썸네일의 명시적 접근성 선택 동작도 검증했다.

## 검증

| 범위 | 통과 |
| --- | ---: |
| 홈 날짜·실제 월 길이·로그아웃·다크·큰 글자 | 14 |
| 보상·월간 앨범 연결 | 7 |
| 인쇄 미리보기·가격·규격·관리자 권한 | 25 |
| 배송지·동의·준비 상태·복구 | 24 |
| 고객 TEST 주문 | 4 |
| 공개 흐름·순서·비율·동의·접근성 | 8 |
| 공개 재시도·격리 | 5 |
| 주문 반응형·키보드·확인·완료 | 46 |
| 사진·편집 지면 비율·디코딩 예산 | 8 |
| 최근 기록·메모·개인정보 격리 | 7 |
| **네이티브 테스트 합계** | **148** |
| 실제 폰트·사진 캡처 시나리오 | 8 |

- 변경 제품 6파일 + 테스트 9파일 정적 분석: **No issues found**. diff 공백 검사 통과.
- 독립 코드 리뷰에서 혼합된 오늘 기록의 사진 판정, 달력 접근성 탭 두 가지를 보완한 뒤 추가 blocker가 없음을 확인했다.
- 최초 RED는 월 날짜 미노출, 보상 불가 후 진행 미노출, 준비 중 배송지 노출, 공개 확인의 긴 스크롤을 재현했다.
- 중간 실패 중 이미지 전체 개수·옛 버튼 문구 기대는 새 구조에 맞게 검증 대상을 좁혔다. 접근성 테스트의 핸들은 테스트 본문에서 finally로 정리해 실제 동작 검증과 자원 정리가 모두 통과했다.
- 캡처 원본 14장 중 헤더가 불완전하게 기록된 중복 주문 캡처 2장은 비교에서 제외했다. `after/`의 12장은 모두 열어 확인했고, 제외한 두 장은 `rejected/`에 분리했다.
- 일반 Flutter CLI가 쓰는 환경 대신 설치된 Flutter frontend compiler와 flutter_tester로 같은 위젯 테스트 본문을 직렬 실행했다. M1 메모리 조건에 맞춰 컴파일·테스트·캡처·분석을 겹치지 않았다.

## 검증 범위와 남은 확인

홈 캡처는 실제 기록 요약·모아둔 순간·월간 앨범 연결 구간이며 앱 내비게이션·개인 앨범 선반을 포함한 전체 HomeScreen 캡처는 아니다. 주문·공개는 실제 화면 클래스와 실제 번들 템플릿을 사용했으며 소유자·가격·기록은 합성 데이터다.

웹 전용 테스트 21개는 네이티브 실행에서 명시적으로 건너뛰었다. 웹 테스트 소스는 새 READY/준비중 동작에 맞게 갱신하고 컴파일·정적 분석했으나 브라우저 실행 검증은 남아 있다. 실기기 설치·앱 전체 빌드·배포·스크린리더 기기 실행·접근성 전체 인증은 수행하지 않았다.

운영 DB 변경, 실제 업로드·피드 공개·결제·주문 생성·문의 발송은 하지 않았다. 기존 작업 트리의 다른 변경은 보존했다.

## 파일

- `verification.json`: 결과 수치·PNG 목록·소스 SHA-256.
- `logs/`: 최초 RED와 최종 실행·분석 로그.
- `before/`, `after/`: 전후 화면.
- `after/publish/social-publish-scroll-metrics.json`: 최종 버튼 거리 측정 원본.
