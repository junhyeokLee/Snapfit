# Billing/Order QA (테스트 모드)

사업자 등록 전 실서비스 개발 단계에서 토스/네이버/KG를 **mock 모드**로 검증하는 표준 시나리오입니다.

## 0) 전제

- 서버 `.env`
  - `SNAPFIT_BILLING_MOCK_MODE=true`
  - `SNAPFIT_ORDER_ADMIN_KEY` 설정됨
  - `SNAPFIT_ADDRESS_JUSO_ENABLED=true`
  - `SNAPFIT_ADDRESS_JUSO_KEY` 설정됨

## 1) 자동 QA 스위트 실행

```bash
cd /Users/devsheep/SnapFit/SnapFit-BackEnd
./scripts/run-qa-mock-suite.sh http://54.253.3.176 1958142146 <ORDER_ADMIN_KEY> 178
```

검증 항목:
- 구독 준비/승인 (TOSS_NAVERPAY)
- 네이버 진입 경로 준비/승인 (`/api/billing/naverpay/prepare`)
- 구독 준비/승인 (INICIS_NAVERPAY)
- 주소검색 (`/api/orders/address/search`)
- 주문 흐름 (`PAYMENT_PENDING -> IN_PRODUCTION -> SHIPPING -> DELIVERED`)
- 페이지수 기반 금액 강제 저장 검증(클라이언트 위변조 금액 무시)

## 2) 실기기 수동 QA

1. 마이페이지 -> 주문현황 숫자 서버와 일치 확인
2. 주문 상세 타임라인 시간 표시가 KST로 보이는지 확인
3. 제작확정 -> 주문 생성 -> 결제창 열기 -> 앱 복귀 동작 확인
4. 주소 검색 후 우편번호/기본주소 자동 채움 확인

## 3) 운영 전환 시 체크

mock 검증 완료 후 아래 값 준비되면 운영 전환:
- `SNAPFIT_BILLING_MOCK_MODE=false`
- `SNAPFIT_BILLING_TOSS_SECRET_KEY=live_sk_...`
- `SNAPFIT_BILLING_WEBHOOK_TOSS_SECRET=...`
- `SNAPFIT_BILLING_WEBHOOK_INICIS_SECRET=...`

