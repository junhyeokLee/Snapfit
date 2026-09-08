# Android 포인트 구매 출시 전 준비

Android는 Google Play의 일회성 소모성 포인트 상품을 사용합니다. 공개 출시 전에도 라이선스 테스트와 내부 테스트 트랙으로 구매를 검증할 수 있습니다. 이번 확인은 로컬 코드와 Google 공식 문서만 대상으로 했으며 Play Console, 서비스 계정 권한 또는 실제 구매 상태는 조회하지 않았습니다. SnapFit 서버의 실제 적용 결과는 [배포 현황](PAYMENT_PUSH_DEPLOYMENT_STATUS.md)을 확인합니다.

## 로컬에서 확인한 경로

| 항목 | 확인한 구현 |
| --- | --- |
| Android 앱 ID | `android/app/build.gradle.kts`: `com.devsheep.snap_fit` |
| 기본 상품 ID | `lib/config/env.dart`: `snapfit_points_2500`, `snapfit_points_8000`, `snapfit_points_18000` |
| Play Billing | `in_app_purchase_android` 0.5.2, 로컬 플러그인의 Billing Library 8.0.0 의존성 |
| 구매 전 확인 | 로그인 → 서버 `availability` 확인 → `buyConsumable` |
| 계정 결합 | Supabase 사용자 UUID를 `applicationUserName`으로 전달; Android 플러그인이 구매 계정 식별자에 연결 |
| 서버 검증 | 고정 패키지의 `purchases.productsv2` 조회, 상품·수량·계정·상태 확인, 구매 토큰으로 중복 지급 방지 |
| 지급 후 완료 | `autoConsume=false`; 서버 지급 성공 후 `consumePurchase`, 재전달 복구 |

로컬 release merged manifest에 `com.android.vending.BILLING` 권한과 Billing Library 8.0.0 메타데이터가 포함된 것을 확인했습니다. 2026-09-08 확인 당시 `android/key.properties`가 없었고, 현재 Gradle은 이 경우 release 서명을 생략합니다. Play에 업로드할 AAB는 `android/key.properties.example`을 따라 로컬 업로드 키를 설정하거나 승인된 CI 서명 설정으로 서명해야 합니다. 키 내용은 저장소에 넣지 않습니다.

## Play Console과 서버에서 확인할 항목

1. Play Console의 앱 패키지가 `com.devsheep.snap_fit`인지 확인합니다. 서버 `GOOGLE_PLAY_PACKAGE_NAME`도 동일해야 합니다.
2. 위 세 SKU를 **one-time product의 buy 구매 옵션**으로 등록하고 가격·판매 국가·활성 상태를 확인합니다. Draft/Inactive 구매 옵션은 일반 상품 조회에 제공되지 않습니다. 현재 앱은 단일 상품·수량 1을 지급하므로 다중 수량 판매와 다중 상품 추천은 활성화하지 않습니다. 이는 현재 구현의 지원 범위입니다. [Google 일회성 상품 설정](https://support.google.com/googleplay/android-developer/answer/16430488?hl=en), [수량 처리 안내](https://developer.android.com/google/play/billing/integrate).
3. 서비스 계정의 Google Cloud 프로젝트에서 Google Play Developer API를 활성화하고, 그 계정 이메일을 Play Console의 사용자 및 권한에 등록합니다. Google Billing API 안내의 권한 이름은 `View financial data, orders, and cancellation survey responses`와 `Manage orders and subscriptions`입니다. 뒤 권한 이름에 구독이 포함돼 있어도 SnapFit에서 구독 상품을 판매한다는 뜻은 아닙니다. 접근 범위는 SnapFit 앱으로 제한합니다. [Google API 설정 안내](https://developers.google.com/android-publisher/getting_started).
4. Supabase에 `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` 또는 이메일/개인키 쌍을 설정합니다. 앱에 서비스 계정 키를 넣지 않습니다. 서버는 `androidpublisher` OAuth scope로 거래 토큰을 조회합니다. [일회성 구매 조회 API](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.productsv2/getproductpurchasev2).
5. `iap-verify`의 인증된 `availability` 응답을 확인합니다. `READY`는 환경변수 형식 확인이며 실제 API 권한·키 유효성·상품 판매 가능성을 보증하지 않습니다. 라이선스 구매의 서버 검증 성공으로 확인해야 합니다.

## 공개 출시 전 라이선스 구매 검증

Play Console에 테스트 Google 계정을 **라이선스 테스터**로 등록합니다. 내부 테스트 트랙을 쓰는 경우 테스터 초대와 참여 링크 동의도 완료합니다. 내부 트랙 참여만으로 무료 테스트 결제가 되는 것은 아닙니다. 결제창에서 테스트 계정과 테스트 결제수단을 확인합니다. 라이선스 테스터는 패키지가 일치하면 debug 서명/sideload 빌드로도 테스트할 수 있습니다. [Google 결제 테스트](https://developer.android.com/google/play/billing/test), [테스트 트랙 안내](https://support.google.com/googleplay/android-developer/answer/9845334).

- 승인 테스트: 1회 지급, 소비 완료, 같은 상품 재구매를 확인합니다.
- 거절·취소·지연 승인 테스트: 승인 전에는 미지급, 승인 후에는 1회 지급을 확인합니다.
- 네트워크 단절·앱 종료·재전달·다른 계정 복원 테스트: 구매 유실/중복/다른 계정 지급이 없어야 합니다.
- 테스트 환불과 대사 실행: 최초 지급분을 1회 회수하고 이미 사용한 포인트는 음수 잔액으로 보존합니다.

라이선스 테스트 구매는 인정 처리가 늦으면 약 3분 후 환불될 수 있습니다. 서버 지급 뒤 소비까지 성공하고, 미완료 구매가 재시도되는지 확인합니다. [Google 소모성 구매 테스트](https://developer.android.com/google/play/billing/test#test-consumable-products).

현재 미확인 항목은 Play 상품/가격/판매 국가, 서비스 계정 API 권한·실제 키 유효성, 테스트 계정/트랙, 업로드 서명, 실기기 구매·복구·환불입니다. 설정 이름이 존재하거나 단위 테스트가 통과한 것만으로 이 항목들을 완료로 표시하지 않습니다.
