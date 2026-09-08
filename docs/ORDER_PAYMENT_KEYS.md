# 포인트 결제 운영 키

SnapFit의 결제 상품은 Google Play와 App Store의 소모성 포인트 충전입니다. `iap-verify`가 스토어 원본 거래와 구매 계정을 검증한 뒤 포인트를 한 번만 지급합니다. 구독 및 외부 실물 주문 결제는 지원하지 않습니다. PortOne 설정 경로를 제거했으며 대체 결제사를 추가하지 않았습니다.

설정 대상은 SnapFit 프로젝트 `rrbhxdtriummqpztpjrk`입니다. 비밀값은 채팅이나 저장소에 기록하지 말고 해당 프로젝트의 Supabase secrets에 설정합니다. 실제 적용 여부는 [배포 현황](PAYMENT_PUSH_DEPLOYMENT_STATUS.md)을 확인합니다.

## 필요한 설정

| 기능 | 서버 설정 |
| --- | --- |
| Android 포인트 | `GOOGLE_PLAY_PACKAGE_NAME`, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` 또는 `GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL` + `GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY` |
| iOS 포인트 | `APP_STORE_ISSUER_ID`, `APP_STORE_KEY_ID`, `APP_STORE_BUNDLE_ID`, `APP_STORE_PRIVATE_KEY`, `APP_STORE_ENVIRONMENT` |
| 환불 대사 | `SNAPFIT_IAP_RECONCILE_SECRET`, `iap-reconcile` 배포와 예약 실행 |

Android 패키지 기본값은 `com.devsheep.snap_fit`입니다. 서비스 계정에는 해당 앱의 Play Developer API 조회 권한이 필요합니다. [Android 출시 전 준비](ANDROID_POINT_PURCHASE_CHECKLIST.md)를 확인합니다.

포인트 상품 ID는 Flutter `IAP_POINT_PRODUCT_IDS`, 스토어 상품, 서버 `point_products`와 일치해야 합니다. 과거에 판매한 포인트 SKU는 미완료 구매 복구를 위해 서버 목록에서 임의로 삭제하지 않습니다. Apple 환경은 테스트 서버에서 `sandbox`, 판매 서버에서 `production`을 사용합니다.

구매 전 인증된 서버 준비 상태 조회가 `UNAVAILABLE`이면 앱은 결제창을 열지 않습니다. `READY`는 설정 형식 확인 결과이며, 자격 증명의 유효성이나 스토어 상품·권한까지 검증했다는 뜻은 아닙니다.

```bash
python3 tool/supabase_readiness_check.py --project-ref rrbhxdtriummqpztpjrk
```

이 점검은 secret 이름과 함수 응답을 확인합니다. 실기기 라이선스/sandbox 결제를 대신하지 않습니다. [포인트 운영 및 환불 대사](POINT_PURCHASE_OPERATIONS.md), [실기기 점검표](REAL_DEVICE_CHECKLIST_BILLING_ORDER.md)를 함께 확인합니다.

과거 주문과 결제 기록은 보존합니다. 외부 결제 제거 이력은 [퇴역 기록](PRINT_ORDER_PAYMENT_SECURITY.md)에 남깁니다.
