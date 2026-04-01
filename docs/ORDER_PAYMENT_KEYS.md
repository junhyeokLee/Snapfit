# 주문/결제 키 설정 (실서비스)

## 1) Backend `.env` 필수 키

```bash
SNAPFIT_BILLING_MOCK_MODE=false
SNAPFIT_BILLING_PUBLIC_BASE_URL=https://api.your-domain.com
SNAPFIT_BILLING_TOSS_SECRET_KEY=live_sk_xxx
SNAPFIT_BILLING_WEBHOOK_TOSS_SECRET=...
SNAPFIT_BILLING_WEBHOOK_INICIS_SECRET=...

SNAPFIT_ORDER_ADMIN_KEY=change_me

SNAPFIT_ORDER_PRICING_BASE_PAGES=12
SNAPFIT_ORDER_PRICING_MAX_PAGES=50
SNAPFIT_ORDER_PRICING_BASE_PRICE=19900
SNAPFIT_ORDER_PRICING_EXTRA_PAGE_PRICE=700

SNAPFIT_ADDRESS_JUSO_ENABLED=true
SNAPFIT_ADDRESS_JUSO_KEY=your_juso_key
```

## 2) Flutter 실행 키 (QA/개발)

```bash
flutter run \
  --dart-define=BASE_URL=http://54.253.3.176 \
  --dart-define=ORDER_ADMIN_KEY=change_me
```

## 3) 신규 API

- `GET /api/orders/quote?albumId={id}&pageCount={n}`
  - 페이지 수 기반 결제 금액 계산
- `GET /api/orders/address/search?keyword={text}&page=1`
  - 주소 검색(Juso API 프록시)

## 4) 가격 정책

`amount = basePrice + max(0, pageCount - basePages) * extraPagePrice`

- pageCount는 `album_page` 저장 수를 우선 사용
- 없는 경우 요청 pageCount 사용
- 최종 범위: `basePages ~ maxPages`
