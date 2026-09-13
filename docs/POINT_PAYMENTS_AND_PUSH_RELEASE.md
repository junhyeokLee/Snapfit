# 포인트 결제·푸시 수정 및 배포 안내

2026-09-08 수정 및 운영 안내입니다. 후속 작업에서 SnapFit DB/함수/worker 설정을 적용했습니다. **현재 배포 결과와 남은 필수 설정은 [적용 현황](PAYMENT_PUSH_DEPLOYMENT_STATUS.md)을 기준으로 확인하세요.** 실제 스토어 구매·기기 푸시 검증은 아직 완료되지 않았습니다.

요구 범위는 구독 없는 스토어 포인트 구매와 푸시입니다. 사용자 요청에 따라 PortOne과 외부 실물 주문 checkout을 제거하며 대체 결제사를 추가하지 않습니다. 과거 주문·결제 기록은 보존합니다. Apple 키 발급·상품 설정·샌드박스 검증은 공개 출시 전에 진행할 수 있습니다. [출시 전 준비 순서](PAYMENT_PUSH_DEPLOYMENT_STATUS.md#ios)

## 접근권한 오류와 변경할 위치

- 앱 `lib/config/env.dart` 및 `supabase/config.toml`의 대상은 `rrbhxdtriummqpztpjrk`입니다.
- 연결 계정에서 조회된 프로젝트 목록에는 이 프로젝트가 없었습니다. 조회된 조직은 `boao388's Org`였으며, SnapFit 대상 프로젝트의 관리 API 요청은 권한 오류로 거절됐습니다.
- **boao388's Org 프로젝트에는 변경하지 않았으며, 해당 조직에 접근하거나 변경하지 않습니다.** 프로젝트 목록 확인 외에 그 조직의 DB/함수/설정을 수정한 작업은 없습니다.
- 수정할 곳은 Codex의 Supabase 연결 계정/연결 범위입니다. Supabase 플러그인 또는 연결된 앱 관리 화면에서 **SnapFit 프로젝트를 소유한 계정**으로 다시 연결하고, 프로젝트/조직 선택이 나오면 SnapFit만 선택합니다. 기존 다른 조직의 프로젝트 설정을 바꾸는 작업은 필요하지 않습니다.
- 올바른 계정으로 로그인해도 SnapFit이 보이지 않는 경우에만 SnapFit 프로젝트 소유자가 **SnapFit 소속 조직의 Team 권한**을 확인해야 합니다. 다른 조직의 Team 권한을 변경하는 작업이 아닙니다.
- 이 진단은 Codex가 관리 API를 호출할 때의 권한 오류에 관한 것입니다. 앱 사용자의 RLS 오류가 있었다는 뜻은 아닙니다. 앱 URL/anon key를 다른 프로젝트 값으로 교체하거나 RLS를 해제하는 것으로 해결하지 않습니다.
- 로컬 secret 설정 스크립트도 `rrbhxdtriummqpztpjrk` 이외의 프로젝트를 거절하도록 제한했습니다. 스크립트는 이번 작업에서 실행하지 않았습니다.
- 후속 확인에서는 로컬 Supabase CLI 인증으로 SnapFit 접근·배포에 성공했습니다. 커넥터의 연결 권한 오류와 프로젝트 자체에 대한 CLI 권한은 서로 다른 상태였습니다.

공식 안내: [Supabase MCP 연결과 범위](https://supabase.com/docs/guides/ai-tools/mcp), [Codex 플러그인](https://learn.chatgpt.com/docs/plugins).

## 변경한 동작

### 디지털 결제는 소모성 포인트만

- 구독 모델, 구매 버튼, Pro/구독 상태 조회 및 프리미엄 구독 확인을 앱에서 제거했습니다. 마이페이지와 결제 화면은 보유 포인트·충전·내역을 표시합니다.
- 서버 `iap-verify`는 `point_products`에 등록된 소모성 포인트 상품만 처리합니다. 과거 구독 판매 항목은 비활성화하되 기존 결제/구독 기록은 삭제하지 않습니다. 이미 닫힌 외부 구독 결제 엔드포인트는 계속 HTTP 410으로 거절합니다.
- 구매 시작 시 앱 계정을 스토어 구매에 연결합니다. 서버가 Google/Apple 구매 사실, 상품, 수량, 계정, 앱/환경을 확인한 후 한 트랜잭션에서 구매 기록·원장·잔액을 반영합니다. 사용자 앱은 지급 RPC를 직접 실행할 수 없습니다.
- 서버 지급 성공 뒤에만 Android 소비/Apple 거래 완료를 수행합니다. 미완료 거래는 기기의 보안 저장소에 보관하며 화면 이동, 앱 재실행, 재로그인, 구매 복원에서 재확인합니다. 취소·대기·검증 실패는 포인트 지급으로 처리하지 않습니다.
- 이전에 판매한 포인트 SKU도 스토어 검증과 서버 상품 확인을 통과하면 복구할 수 있습니다. 과거 앱에서 계정 결합 없이 구매했고 서버에 검증된 소유권 기록도 없는 거래는 고객 지원에서 소유권을 확인해야 합니다.
- `iap-reconcile`이 이미 지급된 구매를 주기적으로 스토어에 대사합니다. 확인된 환불/취소만 최초 지급 금액 전체를 한 번 역분개합니다. 사용한 포인트는 음수 잔액으로 남아 다음 충전으로 정산됩니다. 네트워크 오류나 오래된 거래 조회 404만으로 회수하지 않습니다.
- 프리미엄 템플릿의 개별 판매 가격·제공 방식은 확정되지 않았으므로 구독 안내를 제거하고 기존 이용 준비 중 상태를 유지합니다. 임의의 포인트 가격은 만들지 않았습니다.

환불 대사 주기·Vault/Cron 설정·과거 거래 복구 세부사항: [POINT_PURCHASE_OPERATIONS.md](POINT_PURCHASE_OPERATIONS.md).

### 푸시와 알림함

- 개인 주문/초대 알림의 전체 토픽 발송을 중단하고 수신 사용자별 알림함과 기기별 발송 대기열로 전환했습니다.
- 권한 거부, APNs 토큰 대기, 로그인/로그아웃, 기기 토큰 갱신을 처리합니다. 전체 알림을 켜는 것만으로 마케팅 수신을 동의시키지 않습니다.
- 카테고리 설정과 야간 제한, 실패 재시도, 무효 토큰 정리, 계정별 알림 탭 이동을 적용했습니다. 댓글 기능이 없는 현재 앱에서는 댓글/반응 설정을 숨깁니다.
- iOS 푸시 entitlements와 빌드별 APNs 환경을 연결했습니다. 실제 Apple 서명 프로필과 Firebase APNs 키는 계정에서 별도 설정해야 합니다.
- 배포·스케줄·기기 점검 세부사항: [push_notifications.md](push_notifications.md).

### 외부 실물 주문 결제 퇴역

최초 점검 중 실물 주문에 추가했던 PortOne 구현을 사용자 요청에 따라 제거합니다. 설정 도구·준비 상태 점검에서 관련 옵션과 키 입력을 제거하고, 앱 결제 버튼 및 결제 웹훅도 퇴역시킵니다. 외부 checkout을 대체하는 연동은 없습니다. 과거 주문·결제·제작 이력과 이미 적용한 마이그레이션은 보존합니다.

로컬 변경 및 마이그레이션 이력은 [퇴역 기록](PRINT_ORDER_PAYMENT_SECURITY.md), 실제 서버 제거 결과는 [배포 현황](PAYMENT_PUSH_DEPLOYMENT_STATUS.md)을 확인합니다.

## SnapFit 계정 연결 후 필요한 적용 작업

아래는 적용 순서 안내입니다. 이미 적용한 단계와 남은 작업은 [적용 현황](PAYMENT_PUSH_DEPLOYMENT_STATUS.md)에 구분했습니다.

1. 스테이징에서 전체 마이그레이션과 신규 앱을 검증합니다. 구버전 앱의 외부 결제 요청에는 퇴역 응답을 유지합니다.
2. 최초 점검의 SQL 4개는 적용 이력을 유지합니다: `20260908094302_secure_print_order_payments.sql`, `20260908094449_point_only_iap_atomic_grants.sql`, `20260908094551_targeted_push_notifications.sql`, `20260908095746_point_purchase_refund_reconciliation.sql`. 이미 적용된 이력을 확인한 뒤 후속 제작 계약 마이그레이션 및 `20260908105146_remove_external_print_payment_integration.sql`까지 순서대로 적용합니다.
3. `iap-verify`, `iap-reconcile`, `push-dispatch`, `admin-ops`와 퇴역 `billing-*` 함수를 배포합니다. `order-checkout`/`order-confirm-payment`는 퇴역 응답으로 교체하고 `order-payment-webhook` 배포를 삭제합니다. 원격 삭제/교체 완료 여부는 적용 현황으로 확인합니다.
4. Supabase 함수 secrets에 아래 값을 설정합니다. 값은 채팅이나 Git에 넣지 않습니다. `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY`는 Supabase가 관리하는 서버 환경변수입니다.

| 기능 | 설정 이름 |
| --- | --- |
| Android 포인트 검증 | `GOOGLE_PLAY_PACKAGE_NAME`, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` 또는 이메일/개인키 쌍 |
| iOS 포인트 검증 | `APP_STORE_ISSUER_ID`, `APP_STORE_KEY_ID`, `APP_STORE_BUNDLE_ID`, `APP_STORE_PRIVATE_KEY`, `APP_STORE_ENVIRONMENT` (테스트 서버 `sandbox`, 판매 서버 `production`) |
| 환불 대사 | 32자 이상의 `SNAPFIT_IAP_RECONCILE_SECRET` |
| 푸시 | `FIREBASE_SERVICE_ACCOUNT_JSON`, 32자 이상의 `PUSH_DISPATCH_SECRET`, 검증 후 `PUSH_DELIVERY_ENABLED=true` |

5. Vault 설정 후 `supabase/setup/push_dispatch_schedule.sql`과 `supabase/setup/iap_reconcile_schedule.sql`로 푸시 발송 및 환불 대사 작업을 예약합니다. 함수 배포만으로 주기 실행되지 않습니다.
6. 스토어의 소모성 상품 ID와 Flutter `IAP_POINT_PRODUCT_IDS`를 일치시킵니다. 현재 기본값은 `snapfit_points_2500`, `snapfit_points_8000`, `snapfit_points_18000`입니다. 이 값은 Flutter 빌드 설정이며 서버 secret으로 넣어도 앱의 상품 목록은 바뀌지 않습니다.
7. 별도 테스트 환경에서 정상/취소/대기/네트워크 단절/앱 종료/중복 재전송/다른 계정 복원/환불을 검증합니다. iOS Sandbox는 별도 서버 환경에서 `APP_STORE_ENVIRONMENT=sandbox`를 사용합니다.
8. 전경·배경·앱 종료 상태의 푸시 수신과 탭, 권한 거부 후 재허용, 로그아웃 후 알림 차단, 야간 설정을 실제 Android/iOS 기기에서 확인합니다.

## 실행한 검증 범위

Flutter 단위·위젯 테스트, 주입한 HTTP 응답을 쓰는 서버 테스트, 실제 마이그레이션을 적용한 격리 PGlite SQL 테스트, 변경 Edge 함수의 Deno 타입 검사, Java 개인 알림 차단 테스트를 실행했습니다. 실제 스토어 구매·Firebase 발송·배포 상태는 검증하지 않았습니다. PGlite는 하나의 연결을 직렬화하므로 실운영 다중 연결 부하 시험을 대체하지 않습니다.

최초 점검 결과(후속 퇴역 변경 전): 관련 Flutter 테스트 47개, Node/SQL 테스트 66개, Java 개인정보 알림 테스트 2개 통과. 변경 Edge 진입점 7개의 Deno 타입 검사와 변경 Flutter 코드 분석도 통과했습니다. 반복 실행한 테스트는 중복 합산하지 않았습니다.

재현 예시(앱 저장소 루트):

```sh
flutter test --no-pub test/unit/point_purchase_service_test.dart test/unit/billing_repository_test.dart test/widget/billing_management_ai_return_test.dart
flutter test --no-pub test/unit/notification_policy_test.dart test/unit/fcm_notification_lifecycle_test.dart test/unit/fcm_notification_service_security_test.dart
node --test supabase/functions/iap-verify/point-purchase_test.mjs supabase/functions/iap-reconcile/reconcile_test.mjs
npm install --prefix /tmp/snapfit-payment-sql-test @electric-sql/pglite@0.3.14 --no-audit --no-fund
PGLITE_MODULE=/tmp/snapfit-payment-sql-test/node_modules/@electric-sql/pglite/dist/index.js node --test supabase/tests/iap-points_test.mjs test/server/*.test.mjs
python3 tool/supabase_readiness_check.py --skip-remote
```

Node 테스트는 TypeScript stripping을 지원하는 Node가 필요합니다(Node 26에서 검증). readiness 검사는 secret 이름/설정과 OPTIONS 응답만으로 실서비스 정상 동작을 보증하지 않습니다.

`tool/supabase_readiness_check.py`와 `scripts/configure_supabase_production_secrets.sh`에서 외부 실물 주문 결제 옵션과 키 설정 경로를 제거했습니다. 과거 옵션을 전달하면 실행 전에 거절합니다. [Android 공개 출시 전 준비](ANDROID_POINT_PURCHASE_CHECKLIST.md)를 따라 Play 상품·서비스 계정 권한·라이선스 테스트를 확인합니다.
