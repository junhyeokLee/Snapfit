# 포인트 구매·환불 운영

현재 SnapFit 적용 결과 및 남은 콘솔 설정은 [배포 현황](PAYMENT_PUSH_DEPLOYMENT_STATUS.md)을 확인하세요.

SnapFit 결제는 스토어 소모성 포인트 구매만 지원합니다. 구독 상품은 `iap-verify`에서 거절하며, 마이그레이션은 유료 `billing_plans`를 비활성화합니다. 기존 구독·구매·포인트 원장을 삭제하지 않습니다.

## 검증과 지급

- Google: 고정된 `GOOGLE_PLAY_PACKAGE_NAME`의 `purchases.productsv2`를 조회합니다. `PURCHASED`, 정확한 포인트 SKU, 수량 1을 확인하고 구매 토큰 자체를 고유 거래 키로 사용합니다. 클라이언트 거래 ID로 중복 방지 키를 만들지 않습니다.
- Apple: 설정된 환경의 App Store Server API에서 요청 거래를 직접 조회합니다. 응답의 transaction ID, bundle ID, environment, Consumable 타입, 구매 소유 형태와 수량을 확인합니다. 클라이언트 JWS/receiptData를 증거로 사용하지 않으며, 신뢰 경계는 Apple의 인증된 HTTPS API 응답입니다.
- 신규 구매의 Google `obfuscatedExternalAccountId` 또는 Apple `appAccountToken`은 로그인한 Supabase 사용자 UUID와 일치해야 합니다.
- `grant_verified_point_purchase`는 service_role만 실행할 수 있습니다. 구매 소유권 확인, 구매 저장, 지급 원장, 지갑 잔액 변경이 한 DB 트랜잭션에서 처리됩니다. 오류가 발생하면 모두 롤백합니다. 같은 스토어 거래를 다시 보내도 한 번만 지급합니다.
- 판매가 끝난 포인트 SKU도 `point_products`에 남겨 두어 이미 결제한 상품을 지급할 수 있게 합니다. `is_active`는 카탈로그 표시 정책이며 스토어 판매 중단은 각 콘솔에서 설정합니다. 상품별 포인트 수량을 변경하려면 새 SKU를 사용하세요.
- mock verification 경로와 구독 활성화 경로는 제거했습니다. `SNAPFIT_IAP_MOCK_VERIFY`와 `SNAPFIT_IAP_PRODUCT_PLAN_MAP`은 더 이상 사용하지 않습니다.

기존 앱에서 계정 토큰 없이 구매한 건은 **동일 사용자에게 이미 검증·지급된 구매**만 자동 재처리합니다. 기존 Google 주문 ID와 원장 키는 보존하고 구매 토큰을 추가로 연결합니다. 계정 토큰이 없고 아직 지급되지 않은 구매, 여러 계정/거래에 중복 연결된 토큰, mock 이력은 자동으로 소유자를 추정하지 않습니다. 운영자가 스토어 영수증과 기존 사용자 이력을 확인한 뒤 별도 CS 복구해야 합니다.

성공 응답은 `status: VERIFIED`와 `pointPurchase`의 `productId`, `grantedPoints`, `remainingBalance`, `alreadyGranted`를 제공합니다. `purchase_pending`은 `retryable: true`, 환불·취소·소유권 불일치는 `retryable: false`로 반환합니다. 클라이언트는 서버 지급 성공 후에만 Android consume 및 StoreKit complete를 실행합니다.

## 환불과 이미 사용한 포인트

`iap-reconcile`은 지급 완료된 구매 이력을 DB에서 임대해 스토어 상태를 재조회합니다. 요청 body의 사용자 ID나 거래 ID는 사용하지 않습니다. 스토어가 확인한 취소·환불만 `revoke_verified_point_purchase`로 전달합니다.

환불은 상품의 현재 가격이나 포인트 수량이 아닌 **최초 지급 원장의 포인트 전액**을 역분개합니다. 역분개 원장은 한 번만 추가되며 구매 상태·원장·지갑 변경은 모두 원자적입니다. 예를 들어 2,500P 중 2,000P를 사용한 후 환불하면 잔액은 `500 - 2,500 = -2,000P`가 됩니다. 다음 2,500P 구매 후 잔액은 500P입니다. 음수를 0으로 잘라 이미 사용한 금액을 면제하지 않습니다. 관리자 조정도 같은 방식으로 정확한 증감을 보존합니다. 잔액이 부족하면 유료 AI 사용 RPC의 잔액 검사에서 거절됩니다.

Google `refundableQuantity`는 환불되지 않은 수량이고 `consumptionState`와 별개입니다. 정상 소비 완료 상품은 재검증·중복 확인이 가능합니다. 수량 1인 상품의 `refundableQuantity = 0` 또는 `CANCELLED` 상태가 환불 증거입니다. 비정상 수량 값은 회수 증거로 사용하지 않습니다. [Google ProductPurchaseV2 정의](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.productsv2).

과거 Google/Apple 거래 조회가 404/410이거나 네트워크·자격 증명·계정 검증 오류가 나면 **환불로 추정하지 않습니다**. `reconcile_error`에 오류 코드를 저장하고 지연 재시도합니다. 더 이상 스토어에서 조회할 수 없는 오래된 거래는 스토어 보고서와 대조하는 수동 확인이 필요합니다. 정상 조회 후에는 24시간 뒤 다시 검사합니다. 워커는 20건씩 처리하고, 오류는 15분부터 최대 24시간까지 지연합니다. 임대가 만료되면 다시 처리할 수 있으며 역분개는 중복되지 않습니다.

## 필요한 환경 설정

| 설정 | 용도 |
| --- | --- |
| `GOOGLE_PLAY_PACKAGE_NAME` | 실제 Android applicationId |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Play Developer API 권한을 가진 서비스 계정 JSON |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL`, `GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY` | JSON 대신 사용할 수 있는 자격 증명 쌍 |
| `APP_STORE_ISSUER_ID`, `APP_STORE_KEY_ID`, `APP_STORE_PRIVATE_KEY` | App Store Server API 키 |
| `APP_STORE_BUNDLE_ID` | 실제 iOS bundle ID |
| `APP_STORE_ENVIRONMENT` | `production` 또는 `sandbox`; 기본값은 production, 자동 환경 전환 없음 |
| `SNAPFIT_IAP_RECONCILE_SECRET` | 대사 워커 전용 무작위 비밀값, 최소 32자 |
| `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ANON_KEY` | Supabase 함수 런타임 기본 환경 |

포인트 상품은 Google Play Console 및 App Store Connect에 consumable/one-time 상품으로 등록하고 수량 1로 판매합니다. 활성 상품은 `snapfit_points_2500`, `snapfit_points_8000`, `snapfit_points_18000`입니다. 구독 상품을 새로 판매하지 않도록 스토어 콘솔도 맞춰야 합니다. TestFlight와 샌드박스 검증은 sandbox 환경을 설정한 별도 테스트 백엔드에서 수행합니다.

## 배포 후에만 실행할 스케줄 활성화 예시

아래 설정은 후속 배포에서 SnapFit 프로젝트에 적용했습니다. 다른 환경에서는 해당 프로젝트의 마이그레이션과 함수 배포를 완료한 후 적용합니다. `iap-reconcile`은 gateway JWT 검증 대신 전용 bearer secret을 검증하며 일반 사용자 JWT로는 호출할 수 없습니다.

1. Supabase Vault에 `snapfit_iap_reconcile_url` 이름으로 해당 프로젝트의 `/functions/v1/iap-reconcile` URL을 저장합니다.
2. Vault의 `snapfit_iap_reconcile_secret`에 함수 환경 `SNAPFIT_IAP_RECONCILE_SECRET`과 동일한 값을 저장합니다. 서비스 역할 키를 이 값으로 재사용하지 않습니다.
3. Cron/pg_net을 활성화한 프로젝트에서 다음 작업을 등록합니다. 같은 이름의 작업이 이미 있다면 기존 작업을 업데이트하세요.

```sql
select cron.schedule(
  'snapfit-iap-reconcile',
  '*/5 * * * *',
  $job$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets
      where name = 'snapfit_iap_reconcile_url'),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets
        where name = 'snapfit_iap_reconcile_secret')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
  $job$
);
```

5분마다 20건, 정상 건별 24시간 간격인 기본값은 하루 약 5,760건을 처리할 수 있습니다. 지급된 거래 수가 이보다 많으면 워커의 배치 크기·주기·프로바이더 할당량을 함께 조정합니다. `store_purchases`의 `reconcile_after`, `reconcile_error`, `last_reconciled_at`과 Cron 실행 결과로 지연과 실패를 확인합니다. 자동 스토어 알림 webhook 대신 이 대사 방식으로 환불을 반영하므로 즉시 반영되는 구조는 아닙니다.

## 로컬 검증

Node 26.7과 Deno 2.9.6에서 검증했습니다. PGlite 0.3.14는 네트워크 없는 별도 메모리 DB로 사용했습니다.

```sh
node --test supabase/functions/iap-verify/point-purchase_test.mjs supabase/functions/iap-reconcile/reconcile_test.mjs
PGLITE_MODULE=/path/to/node_modules/@electric-sql/pglite/dist/index.js node --test supabase/tests/iap-points_test.mjs
deno check supabase/functions/iap-verify/index.ts supabase/functions/iap-reconcile/index.ts
```

테스트는 실제 결제 API 호출 없이 구매·환불·권한·중복·소유권·역분개·음수 잔액·재시도 및 실패 시 롤백을 검증합니다. PGlite는 연결을 직렬화하므로 다중 PostgreSQL 세션의 경쟁 부하 검증을 대신하지 않습니다. 운영 스키마 적용, 공급자 권한, 결제 후 consume/complete, 샌드박스 환불 및 스케줄 활성화는 올바른 프로젝트에서 별도 확인해야 합니다.
