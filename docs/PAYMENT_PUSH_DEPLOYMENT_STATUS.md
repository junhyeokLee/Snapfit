# SnapFit 결제·푸시 적용 현황

2026-09-08 기준. 이번 적용 대상은 **Supabase `rrbhxdtriummqpztpjrk`와 Firebase `snapfit-c719d`**입니다. 다른 조직/프로젝트에는 접근하거나 변경하지 않았습니다.

결제 요구사항은 **구독 없는 스토어 소모성 포인트 구매**입니다. Android는 Google Play Billing, iOS는 Apple 인앱결제를 사용합니다. 마이페이지에서 충전하고, 선택한 템플릿·스티커·문구·프레임은 포인트로 한 번 구매해 같은 계정에서 계속 사용하도록 연결했습니다. 사용자 요청에 따라 잘못 추가했던 PortOne 연동 코드·웹훅·설정 경로를 제거하고 SnapFit 서버에도 반영했습니다. 고객용 인화 주문은 결제 준비 중 안내를 표시합니다. 포인트 구매에 외부 결제사를 연결하지 않습니다.

## 실제 적용 완료

- Supabase CLI의 기존 인증으로 SnapFit에 접근했습니다. Codex Supabase 커넥터는 여전히 권한 오류가 있었으나, CLI 인증은 이 프로젝트의 조회·배포를 허용했습니다. 다른 조직의 권한을 변경하거나 앱의 프로젝트 URL을 교체하지 않았습니다.
- 최초 DB migration 4개와 외부 결제 제거 migration `20260908105146_remove_external_print_payment_integration.sql` 적용 완료. 디지털 상품 구매 후속 반영 시점에는 전체 이력 29개를 확인했습니다.
- 포인트·푸시 및 퇴역 `billing-*` 함수 배포 완료. 후속 작업에서 `order-checkout`/`order-confirm-payment`를 변경 없는 종료 응답으로 교체하고, `order-payment-webhook`은 삭제했습니다. `admin-ops`의 기존 인화 이행은 provider 없는 일반 검증 증거를 확인하도록 바꿨습니다.
- Firebase 서비스 계정의 프로젝트 일치 여부와 OAuth/FCM `validate_only` 요청 HTTP 200 확인. 실제 알림은 발송하지 않았습니다.
- Firebase 및 두 worker 전용 비밀값을 SnapFit Supabase에 설정하고 Vault에 연동했습니다. 비밀값은 Git/문서/채팅에 기록하지 않았습니다.
- 푸시 매분, 환불 대사 5분마다 Cron 실행 등록. `PUSH_DELIVERY_ENABLED=true` 설정.
- 로그인한 임시 검증 계정으로 IAP 준비 상태·구독 차단·권한을 점검한 뒤 계정을 삭제했습니다. 남은 임시 검증 계정 0개 확인. 실제 스토어 거래/포인트 지급/주문 생성은 하지 않았습니다.
- JSON 자격 증명을 double-quoted dotenv로 등록할 때 PEM 줄바꿈이 손상되는 문제를 해결했습니다. single-quoted 값으로 재등록하고 저장된 SHA-256이 원본 JSON과 일치함을 확인했습니다. 설정 스크립트도 같은 방식으로 수정했습니다.
- 푸시 함수 오류에 비밀값을 포함하지 않는 처리 단계/오류 코드를 추가했습니다.

## 배포 후 검증

| 확인 항목 | 결과 |
| --- | --- |
| 로그인 없이 IAP 호출 | HTTP 401, 거절 |
| 로그인 후 구독 구매 요청 | HTTP 400 `point_purchases_only` |
| 일반 사용자 포인트 지급 RPC 직접 호출 | HTTP 403, SQLSTATE `42501` |
| 푸시 worker 정상 비밀값 | HTTP 200, 빈 큐 `sent=0`, 실패 0 |
| 푸시 worker 비밀값 없음 | HTTP 403 |
| 환불 worker 정상 비밀값 | HTTP 200, 조회/회수/실패 0 |
| 환불 worker 비밀값 없음 | HTTP 401 |
| Android IAP 준비 상태 | `UNAVAILABLE` — 운영 설정 보완 필요 |
| iOS IAP 준비 상태 | `UNAVAILABLE` — 검증 키 누락 |

외부 결제 제거 후 실제 서버 확인:

| 확인 항목 | 결과 |
| --- | --- |
| `order-checkout`, `order-confirm-payment` | HTTP 410 `physical_order_payments_disabled` |
| 삭제한 `order-payment-webhook` | HTTP 404, 함수 목록에서도 제거 |
| 실행 중인 DB 함수의 PortOne 의존 | 0개 |
| 외부 결제 확인·환불 RPC | 두 함수 모두 제거 |
| 사용자/서비스 역할의 고객 주문 생성 RPC 권한 | 모두 없음 |
| 기존 주문/스토어 구매 건수 | 제거 전후 각각 0개, 행 삭제 없음 |
| 포인트 검증·환불 대사·푸시 함수 | 기존 버전/해시 유지, 작업 예약 활성 상태 유지 |

외부 결제 제거 시점에는 배포 소스를 따로 내려받아 필요한 제거만 적용했습니다. 인쇄 PDF·제작 계약 변경 및 `20260908104605_redprinting_fulfillment_contract.sql`은 별도 인화 작업에서 후속 적용했습니다. 이 문서의 디지털 상품 구매 배포는 해당 인화 소스를 수정하지 않았습니다.

## 디지털 상품 포인트 구매

- 마이페이지의 보유 포인트/충전 카드, 스토어·제작·편집기의 가격/보유 표시, 구매 확인, 부족한 포인트 충전 후 재확인을 연결했습니다. 확인 없이 차감하지 않으며, 가격이 바뀌면 다시 확인해야 합니다.
- 서버가 상품 가격과 잔액을 검사하고 지갑 차감·사용 내역·영구 소유권을 한 트랜잭션으로 기록합니다. 같은 계정의 중복 요청은 다시 차감하지 않습니다. 소유한 상품은 판매 중지 후에도 사용할 수 있습니다.
- 관리자 계정의 **마이페이지 → 포인트 상점 관리 → 상품 가격 관리**에서 현재 공개된 상품의 가격과 판매 상태를 저장합니다. 유료 상품이나 가격을 임의로 등록하지 않았습니다. 미등록 상품은 기존 무료 상태를 유지하며, 가격 없는 상품을 등록하면 판매 중지 상태입니다.
- 실제 서버에 상품/소유 테이블과 조회/구매 RPC를 반영했습니다. 공개 조회·무료 접근 HTTP 200 및 비로그인 구매 HTTP 401을 확인했습니다. 격리된 임시 데이터로 실제 authenticated/anon 역할의 구매·중복 차감 방지·875P 잔액·소유권 연결·관리자 사칭 차단·타 계정 데이터 격리를 검증하고 모두 롤백했습니다. 검증용 상품·사용자·포인트 변경은 남기지 않았습니다.
- 동시 인화 배포가 아직 비어 있던 `20260908111001_digital_point_shop.sql`을 먼저 이력에 기록한 것을 확인했습니다. 실제 테이블/RPC가 없음을 조회한 뒤, 이력을 되돌리지 않고 `20260908112124_complete_digital_point_shop_schema.sql`로 완성 스키마를 적용했습니다. 일반 신규 설치에서는 원본 migration이 생성한 스키마를 보존하고 보정 migration은 건너뜁니다. 부분 생성 상태는 오류로 중단합니다.
- Flutter 구매/편집/관리/충전 회귀 테스트 39개, SQL 통합/권한/중복 차감/전체 롤백/보정 migration 테스트 14개가 통과했고 변경 코드 20개 분석 대상에서 문제가 없었습니다. 이어 고정 무료 문구를 제거한 템플릿 적용·카탈로그 회귀 테스트 25개와 해당 변경 분석 8개 대상도 통과했습니다. 테스트 묶음에는 중복된 케이스가 있습니다.

스토어에서 충전한 포인트는 디지털 상품과 AI 제작에 사용합니다. 실제 인쇄·배송 앨범 주문에 이 포인트를 쓰는 결제는 구현하지 않았습니다. 실물 상품은 스토어 인앱결제 외 결제 수단을 사용해야 하므로 주문 의미와 결제 방식이 별도로 정해져야 합니다. [Apple 지침](https://developer.apple.com/app-store/review/guidelines/#goods-and-services-outside-of-the-app), [Google 결제 정책](https://support.google.com/googleplay/android-developer/answer/9858738).

상품 운영 및 실기기 점검: [디지털 포인트 상품 운영](POINT_SHOP.md). 비밀값을 제외한 검증 기록은 `/Users/devsheep/SnapFit/release-artifacts/2026-09-08-point-shop`에 보관합니다. 실제 Apple/Google 스토어 충전은 아래 남은 설정을 완료한 뒤 테스트해야 합니다.

결제 전 서버 준비 상태를 확인하는 로직을 추가했습니다. 새 앱은 `UNAVAILABLE` 상태에서 스토어 결제창을 열지 않습니다. 준비 상태는 설정 존재/형식 검사이므로 `READY`로 바뀐 후에도 스토어 권한·샌드박스 구매 검증이 필요합니다.

전체 migration을 함께 적용한 격리 PostgreSQL 테스트에서 포인트 지급/중복/환불 부채, 주문 상태 변경→사용자 알림→기기 outbox, 두 worker의 독립적인 임대와 권한 차단을 확인했습니다. Flutter/서버 회귀 테스트 및 변경 코드 분석/타입 검사도 통과했습니다. 기존 스키마의 일부 함수 search_path/공개 실행 경고와 Auth 설정 경고가 보안 advisor에 남아 있어 앱 전체 보안 점검 완료를 의미하지는 않습니다.

## 남은 설정: 스토어 포인트 구매·푸시 테스트 준비

아직 출시 전이므로 아래 항목은 준비할 설정과 미검증 범위를 나타냅니다. 앱을 공개 출시해야만 Apple 결제 키를 발급하거나 샌드박스 구매를 테스트할 수 있는 것은 아닙니다.

### Android

1. SnapFit Google Cloud 프로젝트에서 [Google Play Android Developer API](https://console.cloud.google.com/apis/library/androidpublisher.googleapis.com?project=snapfit-c719d)를 활성화합니다. 실제 조회 응답은 `403 SERVICE_DISABLED`였습니다. 보유 서비스 계정으로 API 활성화도 요청했지만 `403 PERMISSION_DENIED`여서 설정이 변경되지 않았습니다.
2. SnapFit Google Play Console의 사용자 및 권한에서 구매 검증용 서비스 계정에 해당 앱의 필요한 주문/구매 조회 권한을 부여합니다. 다른 앱/조직의 권한은 변경하지 않습니다.
3. [SnapFit 함수 Secrets](https://supabase.com/dashboard/project/rrbhxdtriummqpztpjrk/functions/secrets)에 유효한 `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`과 `GOOGLE_PLAY_PACKAGE_NAME=com.devsheep.snap_fit`을 등록합니다. 기존 Android 설정은 이름이 있으나 준비 상태 검사에서 유효한 설정으로 인식되지 않았습니다. 확인되지 않은 키로 임의 교체하지 않았습니다.
4. 세 포인트 상품 `snapfit_points_2500`, `snapfit_points_8000`, `snapfit_points_18000`을 일회성 소모성 상품으로 확인하고 테스트 트랙·라이선스 테스터로 구매/취소/대기/복구/환불을 검증합니다.

Android도 공개 출시 전에 테스트할 수 있습니다. 내부 트랙 참여와 별개로 **라이선스 테스터** 등록이 있어야 테스트 결제수단으로 실제 청구 없이 검증할 수 있습니다. 패키지·상품·권한·서명·테스트 순서는 [Android 포인트 구매 점검표](ANDROID_POINT_PURCHASE_CHECKLIST.md)에 정리했습니다. [Google 공식 테스트 안내](https://developer.android.com/google/play/billing/test)

### iOS

- `APP_STORE_ISSUER_ID`, `APP_STORE_KEY_ID`, `APP_STORE_PRIVATE_KEY`가 서버에 없습니다. `APP_STORE_BUNDLE_ID=com.devsheep.snapFit` 및 환경 값도 해당 스토어 앱/테스트 환경과 맞춰야 합니다.
- App Store Server API 키, 소모성 상품, Apple 배포 서명/Push Notifications 프로필, Firebase APNs 키 설정이 필요합니다.
- 실제 iPhone이 연결되지 않아 APNs 수신·앱 종료 후 탭·스토어 구매를 확인하지 못했습니다.

출시 전 준비 순서:

1. App Store Connect에서 SnapFit 앱과 포인트 **소모성** 상품을 등록하고 상품 ID를 앱/서버와 맞춥니다. 샌드박스 구매에는 유료 앱 계약이 Active여야 합니다. [Apple 설정 안내](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases)
2. 계정 소유자 또는 관리자 권한으로 **사용자 및 액세스 → 통합 → 키 → 앱 내 구입**에서 키를 발급합니다. Issuer ID, Key ID, 내려받은 `.p8` 개인키를 SnapFit 서버의 위 세 설정에 연결합니다. 앱 공개 출시는 선행 조건이 아닙니다. [Apple 키 발급 안내](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/generate-keys-for-in-app-purchases)
3. 테스트 서버의 `APP_STORE_ENVIRONMENT=sandbox`를 맞추고 샌드박스 계정/개발 서명 앱 또는 TestFlight로 검증합니다. 실제 금액은 청구되지 않습니다. [Apple 샌드박스 안내](https://developer.apple.com/help/app-store-connect/test-in-app-purchases/overview-of-testing-in-sandbox)

App Store Connect 설정 전에도 Xcode StoreKit 로컬 테스트를 사용할 수 있습니다. 다만 현재 SnapFit은 서버의 Apple 거래 검증을 거쳐 지급하므로, 로컬 StoreKit 테스트만으로 서버 검증·포인트 지급까지 검증했다고 판단하지 않습니다.

## 외부 실물 주문 결제 제거

조회·승인·웹훅 서명 코드와 설정 입력/점검 옵션을 제거했습니다. Supabase의 관련 비밀값은 원래 없었음을 재확인했습니다. 고객 앱에서 외부 결제창, 배송정보 수집, 주문 생성, 결제 성공/실패 복귀 링크를 제거했습니다. 이전 앱의 생성·승인 요청도 서버에서 종료 응답을 받습니다.

기존 주문 조회·검증된 주문의 제작 관리와 포인트/푸시는 보존했습니다. 과거에 적용한 SQL migration과 배포 백업은 변경 이력으로 남기고, 새 migration으로 현재 DB의 의존성과 권한을 제거했습니다. [제거 기록](PRINT_ORDER_PAYMENT_SECURITY.md)

## 모바일 산출물

- Android release AAB: `build/app/outputs/bundle/release/app-release.aab`, 약 463.5MB, **디지털 상품 구매·마이페이지 충전·최종 템플릿 가격 안내를 반영해 재빌드 성공**, **무서명**. 실제 upload key를 `android/key.properties`에 설정해야 합니다. 기존 debug 키로 release를 서명하던 기본값은 제거했습니다. 최신 크기·SHA-256·서명 확인 기록은 `release-artifacts/2026-09-08-point-shop/android-build.json`에 있습니다(앱 저장소의 상위 작업 폴더 기준).
- iOS release: `build/ios/iphoneos/Runner.app`, 약 488.8MB, **무서명**, 외부 결제 UI 제거 이전 산출물입니다. 새 앱 코드를 배포하려면 재빌드해야 합니다. 의존성 요구에 맞춰 iOS 최소 15.0 및 CocoaPods lock/workspace 설정을 반영했습니다.
- 컴파일 성공은 스토어 제출·설치·실결제 완료를 뜻하지 않습니다. 연결된 Android 기기에 설치하거나 실제 결제/푸시를 실행하지 않았습니다.
- 앱 표시 이름 `스냅핏`, 아이콘·스플래시 등 기존 브랜드 작업은 유지했습니다. Android 64비트 native 라이브러리의 16KB 이상 정렬을 확인했습니다.

배포 전 서버 소스와 DB 구조 정보, 비밀값을 제외한 검증 결과는 `/Users/devsheep/SnapFit/release-artifacts/2026-09-08-payments-push`에 보관했습니다.

외부 결제 제거의 소스/검증/배포 기록은 `/Users/devsheep/SnapFit/release-artifacts/2026-09-08-remove-external-payments`에 보관했습니다. 관련 Flutter 34개, IAP·환불 Node 22개, 제거 관련 Node/PGlite 10개, 설정 도구 Python 7개가 통과했습니다. 현재 운영 admin bundle도 기존 결제 증거 확인과 종료 응답을 별도로 검증했습니다.

운영 절차: [전체 수정/배포 안내](POINT_PAYMENTS_AND_PUSH_RELEASE.md), [포인트 구매/환불](POINT_PURCHASE_OPERATIONS.md), [푸시](push_notifications.md).
