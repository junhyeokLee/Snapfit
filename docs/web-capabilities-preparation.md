# 웹 포인트 충전·푸시·테마 준비

2026-10-15 기준 소스 준비와 후속 서버 반영 상태입니다. 웹 푸시 공개키 설정, DB 변경과 Edge Functions 배포, PortOne TEST 웹훅과 복구 인증 설정을 완료했습니다. 복구 예약은 처음부터 비활성으로 등록했습니다. 앱·웹 실행, Flutter 웹 빌드, 결제·웹훅 호출 테스트, 알림 전송은 수행하지 않았습니다. 설정·배포 확인과 실제 사용자 동작 검증은 구분합니다.

## 준비 범위

| 기능 | 준비한 흐름 | 현재 상태 |
| --- | --- | --- |
| 웹 포인트 충전 | 서버 상품·금액 확인 → 전용 결제 준비 → PortOne V2 → 서버 재조회·검증 → 충전 내역/결과 복구 | 실결제 차단. TEST도 기본 비활성 |
| 충전 중복·환급 결과 반영 | 결제 ID/요청 ID 중복 방지, 검증 후 1회 반영, 웹훅 및 재조회 복구, PG 취소·환급 결과 반영 | 원격 함수·DB·TEST 웹훅·복구 인증 설정 완료. 복구 예약은 비활성, 결제 동작 미검증 |
| TEST 포인트 | 별도 TEST 원장과 내역 | 실제 포인트 잔액·상품 구매·AI 이용에 섞지 않음 |
| 웹 푸시 | 브라우저 지원·설정 확인 → 사용자가 권한 허용 → 회원별 수신 등록 → 전경/백그라운드 수신·알림 클릭 | 공개 VAPID 키·DB·전송 함수 반영 완료. 서비스 워커가 포함된 웹 빌드·HTTPS 호스팅과 수신 검증은 미수행 |
| 웹 알림 설정 | 이 브라우저 알림과 계정별 카테고리·야간 설정, 로그아웃·계정 전환 보호 | 실제 브라우저 권한/수신 검증 전 |
| 웹 테마 | 밝게·어둡게·시스템 선택, 브라우저 저장, 화면·양식·편집 도구 색, 브라우저 배경/테마 색 | 소스 반영, 실행 화면 검증 전 |

모바일의 네이티브 포인트 결제·테마·화면 디자인과 앨범의 실제 사진·배경·글·소재·인쇄 색상은 변경 대상이 아닙니다. 폐기된 `billing-*` 함수는 다시 열지 않으며, 앨범 인쇄 주문용 결제와 웹 포인트 충전은 별도 기록을 사용합니다.

## 완료한 검사와 서버 확인

- 전체 `lib`의 Dart 정적 분석: 오류·경고·안내 항목 없이 통과했습니다.
- 충전 함수·푸시 전송 파일·서비스 워커·초기 테마 스크립트: 실행하지 않는 문법 검사를 통과했습니다. 이 검사는 서버 TypeScript 전체 타입 검사나 배포 검증을 대신하지 않습니다.
- 빌드 도구의 Python 문법과 공개 JSON·함수 TOML 설정을 파싱했습니다. 빌드는 실행하지 않았습니다.
- 별도 소스 검토로 모바일 분기 유지, TEST 원장 격리, 실결제 차단, 소유자·금액 검증, 중복 지급·취소 반영 보호를 확인했습니다.

후속 반영에서는 아래 두 SQL 마이그레이션을 단일 트랜잭션으로 적용하고 마이그레이션 기록을 남겼습니다. 읽기 전용 원격 조회로 두 기록, 새 테이블의 RLS, 일반 사용자 직접 CRUD 차단, 일반 사용자의 충전 RPC 실행 차단과 `service_role` 실행 권한, RPC의 `security invoker`, DB 실결제 차단 함수의 `false` 반환을 확인했습니다.

공개 VAPID 키는 65바이트 공개키 형식과 소스·공개 설정 간 일치를 확인했고 `env.dart` 정적 분석도 통과했습니다. 배포한 함수 4개의 단일 ESM 번들은 문법 검사를 통과했습니다. 이 번들 생성은 서버 코드 배포 준비이며 Flutter 앱 빌드는 아닙니다. Supabase Security Advisor 재확인 결과는 오류 0·경고 28·정보 22였으며, 프로젝트 전체 결과이므로 경고가 모두 이번 작업과 무관하다고 판단하지 않습니다.

후속 설정 조회로 복구 예약의 비활성 상태·실행 기록 없음, 웹훅 주소 일치, Vault와 서버 복구 인증의 일치, 실제 결제 차단, 기존 푸시 예약의 활성 상태를 확인했습니다. 인증값 자체는 이 문서에 기록하지 않습니다.

실제 UI, 브라우저 권한, 결제, 웹훅 수신·처리, 푸시 수신은 아직 검증하지 않았습니다. 웹훅 호출 테스트나 예약 작업의 직접 실행도 하지 않았습니다.

## 공개 웹 설정

템플릿은 `config/web.development.example.json`입니다. 여기에 들어가는 값은 브라우저에 공개되는 설정뿐입니다.

- `WEB_PUSH_VAPID_KEY`: Firebase 프로젝트 `snapfit-c719d`에서 사용자 승인 후 생성한 웹 푸시 인증서 **공개키**를 `Env.webPushVapidKey` 기본값과 공개 설정 JSON에 반영했습니다. `firebase_options.dart`와 같은 프로젝트이며, Firebase Cloud Messaging V1·FCM Registration API가 이미 사용 설정된 것도 확인했습니다. 비공개키는 앱 설정에 넣지 않습니다.
- `WEB_POINT_TOPUP_TEST_ENABLED`: 기본 `false`입니다. `true`도 실제 결제를 열지 않습니다. 서버의 같은 TEST 설정과 서버에서 확인한 관리자 권한이 모두 있어야 TEST 경로를 사용할 수 있습니다.
- `AUTH_WEB_REDIRECT_URL`: 빈 값이면 기존의 현재 사이트 복귀 방식을 유지합니다. 실제 도메인이 확정되면 기존 OAuth 허용 목록과 일치시킵니다.

PortOne API Secret, 웹훅 비밀키, Firebase 서비스 계정, Supabase 비밀키는 이 파일이나 Dart 정의에 넣지 않습니다.

나중에 빌드가 허용된 단계에서는 기존 `tool/build_web.py`에 `--dart-define-from-file=<공개 설정 JSON 경로>`를 전달할 수 있습니다. 이 옵션을 소스에 추가했으며 이번 작업에서 빌드 도구를 실행하지는 않았습니다.

## 반영한 서버 파일과 현재 차단 상태

DB 변경은 CLI로 생성한 아래 파일에서 검토한 내용을 기존 Supabase 프로젝트 `rrbhxdtriummqpztpjrk`에 적용했습니다. `schema_migrations`에 버전·이름·내용 기록도 남겼습니다.

- `supabase/migrations/20261015101945_web_push_device_platform.sql`
- `supabase/migrations/20261015101953_web_point_topup_preparation.sql`

웹 충전용 `web-point-topup`, `web-point-topup-webhook`, `web-point-topup-reconcile`을 새로 배포하고 기존 `push-dispatch`를 업데이트했습니다. 충전 함수의 구형 JWT 게이트는 끄고 각 함수 내부의 회원 인증·웹훅 서명·작업용 인증을 유지합니다. 신규 결제 테이블은 브라우저가 금액·소유자·지급 상태를 직접 쓰지 못하도록 합니다.

검토한 서버 코드를 `esbuild@0.25.12`로 단일 ESM 파일에 묶어 공식 관리 화면에서 배포했습니다. 기존 푸시 함수 원본을 보존하고 변경 내용을 비교했으며, 웹 플랫폼 조회·전달과 웹 전용 data-only 메시지 분기 외에 네이티브 메시지 구조는 유지됩니다. Google 인증·진단 코드는 같고 공통 서버 클라이언트의 기본 동작도 유지합니다.

서버 설정 이름만 정리한 파일은 `config/web-server.example.env`입니다. 원격에 `WEB_POINT_TOPUP_TEST_ENABLED=false`, `WEB_POINT_TOPUP_LIVE_ENABLED=false`를 명시적으로 저장했습니다. 기존 `PRINT_PORTONE_ENVIRONMENT=test`, `PUSH_DELIVERY_ENABLED=true`는 비밀값이 아닌 설정의 다이제스트 일치로 확인했고 값을 변경하지 않았습니다. API Secret·서비스 계정 등 기존 비밀값은 교체하지 않았습니다. 실제 결제는 클라이언트·서버·DB의 독립된 차단을 유지합니다.

사용자 승인 후 PortOne V2 TEST 웹훅 서명키를 최초 발급해 서버 `WEB_POINT_TOPUP_WEBHOOK_SECRET`에 저장하고 일치를 확인했습니다. 승인된 TEST 상점의 기본 웹훅 주소는 `https://rrbhxdtriummqpztpjrk.supabase.co/functions/v1/web-point-topup-webhook`, 본문 형식은 `application/json`, 버전은 `2024-04-25`로 저장·확인했습니다. 호출 테스트·재전송은 실행하지 않았습니다. 기존 인쇄 결제의 상태 확인·개발 발주는 계속 기존 서버 조회 경로를 사용하며, 포인트 웹훅은 인쇄 결제 식별자를 처리하지 않습니다.

전용 복구 인증을 서버 `WEB_POINT_TOPUP_RECONCILE_SECRET`과 Vault의 `snapfit_web_point_topup_reconcile_secret`에 저장하고 정확히 일치하는 것을 확인했습니다. Vault의 `snapfit_web_point_topup_reconcile_url`도 해당 프로젝트 복구 함수 주소로 확인했습니다. `supabase/setup/web_point_topup_reconcile_prepare.sql`을 적용해 `snapfit-web-point-topup-reconcile`을 5분 주기 정의·소유자 `postgres`·`active=false`로 등록했습니다. 예약 생성 시부터 비활성이며 실행 기록은 없습니다. 웹훅·복구 인증이 설정됐다는 사실과 결제 결과 처리가 실제 검증됐다는 것은 구분합니다.

향후 운영용 연결 코드는 별도의 `WEB_POINT_TOPUP_LIVE_ENABLED`와 `WEB_POINT_TOPUP_LIVE_STORE_ID`, `WEB_POINT_TOPUP_LIVE_CHANNEL_KEY`, `WEB_POINT_TOPUP_LIVE_API_SECRET`, `WEB_POINT_TOPUP_LIVE_WEBHOOK_SECRET`을 사용하도록 준비합니다. 활성화 값은 서버에서도 `false`로 유지하며, LIVE 웹훅·PG 인증정보는 새로 등록하지 않았고 예시 파일의 운영용 나머지 값도 비워 둡니다. TEST 채널·인증정보와 섞지 않으며, 환경값만 바꾸어서는 클라이언트·서버·DB의 실결제 차단을 열 수 없습니다. 운영 결제의 서버 검증과 실제 포인트 원장 반영 경로도 차단 뒤에 준비하되 이번에는 사용하지 않습니다.

웹 충전 결제창은 PC 브라우저용 팝업 경로로 준비합니다. 모바일 앱은 기존 IAP를 그대로 사용하며, 모바일 브라우저의 충전 결제창은 준비되지 않은 경로로 열지 않습니다.

## 창을 닫은 뒤의 처리

웹 충전의 클라이언트 성공 표시는 포인트 지급 증거로 사용하지 않습니다. 서버가 PortOne에서 결제와 금액·통화·채널·거래 식별자를 다시 확인합니다. 웹훅과 별도 재조회 작업은 브라우저가 닫혀 있어도 서버에 남은 충전 요청을 대상으로 처리하도록 준비합니다.

PG에서 확인된 완전 취소는 지급 전 취소 또는 지급한 포인트의 1회 회수로 반영하며, 부분 취소와 확인되지 않은 결제는 자동 지급·해제하지 않고 확인 대상으로 남깁니다. 새로 PG에 취소를 요청하는 기능이나 고객 셀프 부분 환불 화면을 추가한 것은 아닙니다. 운영 전 환불 정책과 처리 창구를 정해야 하며, 불명확한 결제는 식별번호로 확인할 수 있습니다.

웹훅 실패 등을 보완할 복구 예약은 `supabase/setup/web_point_topup_reconcile_prepare.sql`로 등록을 완료하고 비활성으로 유지합니다. 이미 저장한 Vault URL·전용 인증을 참조하지만 실행하거나 함수를 호출하지 않습니다. `supabase/setup/web_point_topup_reconcile_schedule.sql`은 향후 별도 활성화 단계의 파일로 이번에는 적용하지 않았습니다. 기존 인쇄·IAP·푸시 스케줄도 변경하지 않았습니다.

기존 `snapfit-push-dispatch`는 매분 활성 상태였으며 그대로 유지했습니다. 알림 발송이나 해당 작업의 수동 실행은 하지 않았습니다. 기존 발송 설정을 유지했다는 사실과 새 웹 브라우저에서 수신을 확인했다는 것은 구분해야 합니다.

푸시는 허용된 브라우저의 서비스 워커가 백그라운드 수신을 처리합니다. 브라우저의 완전 종료·OS 절전·지원 범위에 따라 수신 시점은 달라질 수 있으므로 ‘모든 브라우저에서 종료 즉시 수신’을 보장하지 않습니다. 로그아웃이나 계정 변경 뒤 다른 사용자의 알림 내용이 표시되지 않도록 수신 대상과 현재 계정을 구분합니다.

## 실제 사용 전에 남은 설정과 확인

1. 실제 서비스 HTTPS 주소가 정해지고 빌드가 허용되면, 공개키·서비스 워커가 포함된 웹 빌드를 호스팅에 반영합니다. 공개키 재발급이나 두 마이그레이션·서버 함수의 재준비는 필요하지 않습니다. 브라우저 알림 권한은 각 사용자가 알림 설정에서 직접 선택합니다.
2. TEST 결제 검증이 허용되면 현재 닫힌 TEST 설정과 비활성 복구 예약을 검증 계획에 맞춰 별도로 활성화합니다. TEST 웹훅·복구 비밀·Vault 설정은 완료했으므로 다시 발급할 필요가 없습니다. 기존 서버 비밀값과 인쇄·IAP·푸시 스케줄은 유지합니다.
3. 이후 별도 검증에서 테마 저장·시스템 전환, 푸시 허용/거절·전경/백그라운드·계정 전환, TEST 충전 성공/취소/중복·창 종료 복구·TEST 원장 격리를 확인합니다. 결제창을 열기 전 비동기 준비가 PC 브라우저의 팝업 허용 조건을 만족하는지도 확인해야 합니다. 이번에는 수행하지 않았습니다.
4. 실제 포인트 충전과 실제 앨범 결제는 계속 닫아둡니다. 실판매는 사업자/PG 계약과 운영 설정·검증이 끝난 별도 단계에서만 검토합니다.

현재 반영 증빙과 비밀값 없는 배포 기록은 `docs/verification/web-2026-10-15/rollout.json` 및 같은 폴더의 화면 기록에 보관했습니다. 기존 알림 함수 원본은 `push-dispatch-before.zip`에 보존했습니다.

참고한 공식 자료: [PortOne 결제 검증](https://developers.portone.io/opi/ko/integration/start/v2/checkout?v=v2), [웹훅](https://developers.portone.io/opi/ko/integration/webhook/readme-v2?v=v2), [Firebase 웹 푸시 설정](https://firebase.google.com/docs/cloud-messaging/web/get-started), [백그라운드 메시지 수신](https://firebase.google.com/docs/cloud-messaging/web/receive-messages), [Supabase 서버 비밀 설정](https://supabase.com/docs/guides/functions/secrets), [데이터 접근 제한](https://supabase.com/docs/guides/database/postgres/row-level-security).
