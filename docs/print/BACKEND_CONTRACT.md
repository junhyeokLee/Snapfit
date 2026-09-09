# 인쇄 준비 서버 계약

업체 조건 해석은 [2026-09-10 사용자 공유 회신](vendors/redprinting/reply-shared-2026-09-10.md)을 반영한다. 이 회신 기록의 공유일은 메일 수신일을 뜻하지 않는다. API의 검수·접수 필드는 아래와 같이 SnapFit 자체 검수와 실제 업체 주문 상태를 구분한다.

현재 물리 상품 신규 주문 생성·외부 결제는 비활성 상태다. 이 변경은 결제사 연결을 만들거나 과거 결제 검증 함수를 복구하지 않는다. 앨범 소유자의 `get_print_order_quote`는 읽기 전용 규격/가격 미리보기이고, 관리자 제작 API는 이미 확인된 결제 이력이 있는 주문만 처리한다.

- 상품은 다섯 크기 × 소프트/하드커버의 아래 열 가지이며, 모두 내지 20~80페이지의 짝수 규격이다. 원본 내용은 `cover_layers_json.pages`의 내지 수를 우선 계산한다. 부족한 장수는 뒤쪽 빈 페이지로 채운다.
- 가격은 **제작업체 주문·결제 화면의 실제 청구 금액 확인 전 예상 판매가**이며 모든 견적에 `priceIsEstimate:true`, `supplierCostVerified:false`가 표시된다. 일반 배송을 포함한다. 인쇄 규격/패딩 상세는 견적의 `spec`에 포함된다.

| 상품 ID | 재단 크기 | 20페이지 예상 판매가 | 추가 2페이지 | 예상 제작비 20페이지 / 추가 2페이지 |
|---|---|---:|---:|---:|
| `REDP_200X150_SOFT` | 200×150mm | 49,900원 | 2,400원 | 22,000원 / 1,800원 |
| `REDP_200_SOFT` | 200×200mm | 49,900원 | 2,400원 | 22,600원 / 1,800원 |
| `REDP_250X200_SOFT` | 250×200mm | 64,900원 | 3,600원 | 34,000원 / 2,600원 |
| `REDP_250_SOFT` | 250×250mm | 79,900원 | 4,400원 | 44,000원 / 3,200원 |
| `REDP_300_SOFT` | 300×300mm | 99,900원 | 6,000원 | 60,000원 / 4,400원 |
| `REDP_200X150_HARD` | 200×150mm | 69,900원 | 2,400원 | 34,000원 / 1,800원 |
| `REDP_200_HARD` | 200×200mm | 69,900원 | 2,400원 | 34,600원 / 1,800원 |
| `REDP_250X200_HARD` | 250×200mm | 84,900원 | 3,600원 | 46,000원 / 2,600원 |
| `REDP_250_HARD` | 250×250mm | 99,900원 | 4,400원 | 56,000원 / 3,200원 |
| `REDP_300_HARD` | 300×300mm | 129,900원 | 6,000원 | 80,000원 / 4,400원 |

업체 제작비는 실제 청구 금액이 확인되기 전의 보수적인 운영 예상치다. 업체는 별도 견적을 제공하지 않으며 실제 주문·결제 화면 금액을 기준으로 안내했다. 회신만으로 `priceIsEstimate`나 `supplierCostVerified`를 확정값으로 바꾸거나 도매·반복 발주 할인을 적용하지 않는다. 고객에게는 내부 원가가 전달되지 않는다.
- 제조/배송/포장 원가, 수수료·재제작·운영 충당, 업체 확인 근거는 `print_order_operations`에 분리한다. RLS가 켜져 있고 고객 역할에는 권한이 없다. `admin-ops`에서만 합친다.
- 재포장 경로의 배송 합계 7,000원, 포장 1,500원을 추가 예상한다. 실제 발주 전 관리자 입력 비용으로 다시 검사한다.
- 예상 기여이익: 판매금액 - 실제 제작/전체 배송/포장비 - 결제 수수료 충당 4% - 재제작 충당 5% - 운영 충당 3,000원. 최소 10,000원 이상이어야 발주번호를 저장할 수 있다. 세금·잔여 인건비·고정비 차감 전 금액이며 순이익을 보장하지 않는다.

## 저장된 상품과 견적

앨범 생성/저장 시 `cover_layers_json.printProduct`에 `{id,trimWidthMm,trimHeightMm}`를 저장한다. `get_print_order_quote(p_album_id,p_page_count)`의 호출 인자는 그대로이며, 클라이언트가 임의 상품을 덮어쓰는 인자는 없다. 서버가 저장된 상품 ID, 정확한 치수, 앨범 비율을 검증한 다음 견적을 계산한다. 상품 메타데이터가 없는 기존 정사각형은 200×200mm, 기존 4:3 가로형은 200×150mm로 해석한다. 기존 세로형이나 알려지지 않은 비율은 `unsupported_print_product`로 거절하며 자동 변형하지 않는다.

신규 준비 데이터의 버전은 `PRINT_REDP_COVERTYPE_V3`이다. 커버 종류는 상품 ID의 `_SOFT`/`_HARD`에서 결정하며 저장 메타데이터는 기존 세 필드를 유지한다. 공개 견적/spec에는 `coverType`과 `coverLabel`을 추가한다. `orders.print_product_snapshot`과 `print_content_snapshot.printProduct`에 동일한 상품을 고정하고 변경을 막는다. V3 소프트커버 specVersion은 `{상품ID}_REVIEW_V3_{책등mm}`이며 원본 지문에 SKU와 치수가 포함된다. 기존 `PRINT_REDP_MULTISIZE_V2` 주문은 소프트커버 다섯 종류만 허용하고 기존 가격·specVersion·지문을 그대로 유지한다. 이미 결제된 `PRINT_REDP_200_SOFT_V1`은 원래 200×200mm 규격, specVersion, 원본 지문 계산식을 유지한다.

모든 내지 및 소프트커버 규격의 도련은 5mm다. 내지 작업 크기는 재단 크기의 가로/세로 각각 +10mm이고, 소프트커버 표지 펼침 작업 크기는 `(재단가로×2 + 책등 +10) × (재단세로+10)`이다. 현재 책등 계산은 기존 측정치에서 추정하므로 해당 크기·페이지 수의 업체 제공 도면과 반드시 대조한다. 업체는 제공 표지 도면만 사용하고 별도 맞춤 도면을 제공하지 않는다고 안내했다. 내부 `admin_override`는 제공 도면의 값을 정확히 반영하기 위한 기능이며 임의 도면 승인 기록이 아니다. `verified:false`와 최종 검수 단계는 유지된다.

하드커버 표지는 소프트커버 공식을 재사용하지 않는다. 다섯 크기의 공식 20페이지 도면과 200×150mm/22페이지·300×300mm/80페이지 도면(총 7개)을 확인하여 보드(내지+6mm), 감싸기20mm, 책등 `2.40 + 0.67×(페이지수÷2)`의 별도 REVIEW 프로파일을 제공한다. 직접 측정한 조합은 `geometryMeasured:true`, 나머지 조합은 `false`와 추정 출처가 명시된다. 전부 `verified:false`로 유지하여 실제 해당 페이지수 도면과 대조한다. 하드 기본 spec에는 `coverGeometrySource:official_default`, `templateFamily:REDP_PHBKMYB_CASEWRAP`이 포함되며 관리자 도면 변경 후에는 `admin_override`로 바뀐다. 사용할 도면 프로파일이 없으면 견적에는 `spec:null`, `specMissing:true`, `printPdfAvailable:false`, `printTemplateStatus:'REQUIRES_VENDOR_TEMPLATE'`가 반환되며 해당 표지 PDF를 생성/업로드할 수 없다. 관리자 도면 설정은 `coverGeometry:{construction:'casewrap',bleedMm,widthMm,heightMm,front,back,trim}`이고, 세 사각형은 `{xMm,yMm,widthMm,heightMm}`(좌상단 기준 mm)다. 전체 용지·보드·재단 영역·책등 간격이 검증되어야 한다. 공식 200×150mm/20페이지 예시는 작업 461.10×196mm, 보드 206×156mm, 감싸기 20mm, back(20,20), front(235.10,20), trim(20,20,421.10,156)이며 해당 페이지수 도면 근거를 함께 기록한다. 감싸기 부분은 가장자리 사진/배경을 연장한다. 임의 크기 도면이 다른 페이지수에도 맞는다고 간주하지 않는다.

## 관리자 작업

`admin-ops`는 기존 관리자 JWT `app_metadata.role=admin` 또는 서버에 설정된 관리자 키를 확인한다. 모든 작업은 `POST {action, orderId, ...}`로 호출한다.

1. `configurePrintSpec`: 소프트커버는 `spineMm`, 하드커버는 공식 도면의 전체 `coverGeometry`를 저장한다. 두 경우 모두 `evidence`(10자 이상)가 필요하다. 도면에 맞춘 변경은 이전 제작 파일 준비 상태를 초기화한다.
2. `getPrintSnapshot`: 고정된 `{album,pages}`, `spec`, `sourceFingerprint`를 읽는다.
3. `createPrintUploads`: `{uploadId,bucket,cover:{path,token,signedUrl},interior:{...},sourceFingerprint,spec}`. Supabase Flutter `uploadBinaryToSignedUrl`로 `application/pdf` 파일을 업로드한다. 경로는 서버가 생성하고 덮어쓰기 토큰은 발행하지 않는다.
4. `finalizePrintPackage`: `uploadId`, `manifest`를 전달한다. manifest에는 정확한 `sourceFingerprint`, `specVersion`, `pageCount`, `missingAssets:[]`, `warnings:[]`, `dpi:300`, `colorSpace:'sRGB'`, `iccProfileEmbedded:true`가 필요하다. 상태는 `REVIEW_REQUIRED`로 바뀌며 결제완료 상태를 유지한다.
5. `getPrintDownloadLinks`: 표지/내지/manifest의 15분 다운로드 링크를 발행한다.
6. `markPrintReviewed`: `vendorSpecConfirmed:true`, `reviewNote`(10자 이상). SnapFit 운영자가 업체 제공 도면·표지/내지 낱쪽 순서와 배치·빈 페이지·색상 견본을 검수한 뒤 `READY`가 된다. `vendorSpecConfirmed`는 운영자의 대조 확인이며 업체 사전 검수 확인서나 특정 PDF 승인 여부를 뜻하지 않는다. 업체는 주문 전 사전 검수를 제공하지 않는다.
7. `evaluatePrintCosts`: 발주 직전 주문·결제 화면에 표시된 청구 금액을 기준으로 `actualPrintCost`, `actualShippingCost`, `actualPackagingCost` 정수를 입력한다. 읽기 전용으로 `contributionMargin`, `minContributionMargin`, `eligible`와 각 충당금을 돌려준다. 업체에서 결제하기 전에 확인한다. 재포장 경로 배송비는 두 번의 배송 합계다.
8. `submitPrintVendor`: 실제 `vendorOrderId`, 위 세 가지 비용, `fulfillmentMethod`(`REPACK`/`DIRECT`)를 저장한다. `DIRECT`는 `senderLabelConfirmed`, `priceSlipOmittedConfirmed`, `promotionalMaterialsOmittedConfirmed`가 모두 true이고 `evidence` 10자 이상이어야 한다. 업체 주문번호와 비용은 원자적으로 저장되고 `SUBMITTED`가 된다.
9. `acceptPrintVendor`: 업체 주문 화면에서 실제 접수·제작 상태를 확인한 후 `ACCEPTED`/`IN_PRODUCTION`으로 전환한다. 업체 사전 검수 확인서를 요구하는 단계가 아니며 파일 생성·자체 검수·주문번호 저장을 업체 접수로 간주하지 않는다. 주문 후 파일 문제 문자에 대한 처리가 필요하면 이를 해결하고 실제 주문 상태를 다시 확인한다.
10. `markShipping`(`courier`, `trackingNumber`), `markDelivered`: 실제 고객 배송을 기록한다.

서버는 PDF 파싱으로 페이지 수, mm 크기, 규격에 명시된 TrimBox(내지/소프트는 5mm, 하드는 도면의 별도 사각형), 회전 0, 페이지별 300dpi 래스터 크기와 정확한 sRGB ICC 프로필을 확인한다. 암호화·스크립트·첨부 동작을 거부한다. PDF와 고정 스냅샷의 연결은 지문/파일 SHA-256으로 기록한다. 서버의 파일 검증과 업체의 실제 주문 접수는 서로 다른 사실이다. 재단·색상·가운데 접힘·실물 품질은 SnapFit 운영자가 PDF와 실물 샘플로 확인한다. 업체가 안내한 RGB와 권장 프로파일 없음은 현재 sRGB ICC나 PDF 1.4, 개별 출력 파일의 승인을 뜻하지 않는다. 회신만으로 기본 `verified:false`를 자동 해제하지 않는다.

## 회신을 반영한 주문 운영 의미

- 내지는 낱쪽을 올바른 순서대로 담은 PDF 한 파일로 제출한다. 별도 면지 규칙이나 모든 면수의 책등 두께가 이번 회신으로 승인된 것은 아니다.
- 배송 주소마다 업체 주문을 따로 만든다. `vendorOrderId`와 고정 PDF를 해당 주소의 발주에 연결하고 다른 고객 배송지와 합치지 않는다.
- 발송인 변경은 보내는 고객 정보의 `주문자(발송자명)변경`을 실제 선택하고, 사용자가 지정한 한글 발송자명 `스냅핏`을 입력·확인한다. `DIRECT`의 기존 확인 필드는 회신 내용과 해당 주문의 입력 확인 근거를 함께 기록한다. 별도 동봉물 없음은 확인됐으며 OPP 주문번호 스티커는 남는다. 이 필드들은 포장/책의 로고 없음이나 반품지 변경을 보증하지 않는다.
- 약 5–6영업일에 택배 운송기간이 추가된다는 안내와 주문 버튼 아래 예상 출고일은 예상 일정이다. 날짜 경과로 접수·출고·배송 완료 상태를 자동 확정하지 않는다.
- 주문 후 파일 문제는 주문 창의 고객 연락처로 문자 안내되므로 운영자가 확인 가능한 연락처인지 발주 전에 점검한다. 업체 사전 검수 API나 사전 검수 인증서를 전제로 새 상태를 만들지 않는다.
- 업체는 파일을 보관하지 않는다고 안내했다. SnapFit은 보존 정책에 따라 원본·고정 스냅샷·최종 PDF·manifest/SHA-256의 비공개 보관본을 유지한다. 15분 서명 링크 만료는 저장 파일 삭제가 아니다. 업체의 구체적 삭제 시점·보존 기간은 확인되지 않았다.

상세 근거는 [회신 기록](vendors/redprinting/reply-shared-2026-09-10.md), 주문별 실행 순서는 [제작 운영 문서](operations.md)를 참고한다. 과거 [웹 조사](vendors/redprinting/research-2026-09-08.md)의 표시 가격은 해당 조회 시점의 이력이다.

## 변경 및 확인

- 최초 준비 마이그레이션: `supabase/migrations/20260908104605_redprinting_fulfillment_contract.sql`.
- 다섯 규격 확장: `supabase/migrations/20260908114757_redprinting_five_size_contract.sql` (새로 CLI 생성). 이미 배포된 이전 파일은 수정하지 않는다.
- 커버 종류 확장: `supabase/migrations/20260908120849_redprinting_cover_types_contract.sql` (새 CLI 마이그레이션, 기존 파일 수정 없음).
- 서버: `supabase/functions/admin-ops/index.ts`, `_shared/{order-types,order-fulfillment,print-contract,print-package}.ts`.
- `create_print_order`는 이 마이그레이션 자체에서 public/anon/authenticated/service_role 권한을 철회한다. 이미 적용된 `20260908105146_remove_external_print_payment_integration.sql` 뒤에 적용해도 신규 주문 생성이나 결제 증빙 변경이 다시 열리지 않는다.
- 신규 Supabase 테이블/함수와 Storage 버킷을 먼저 적용한 다음 `admin-ops`를 배포한다. 기존 물리 결제 비활성 마이그레이션은 유지한다.

로컬 격리 검사(실제 DB/결제/발주 없음):

```sh
npm install --prefix /tmp/snapfit-print-validation pdf-lib@1.17.1 --no-audit --no-fund
npm install --prefix /tmp/snapfit-payment-sql-test @electric-sql/pglite@0.3.14 --no-audit --no-fund
PGLITE_MODULE=/tmp/snapfit-payment-sql-test/node_modules/@electric-sql/pglite/dist/index.js PDF_LIB_MODULE=/tmp/snapfit-print-validation/node_modules/pdf-lib/cjs/index.js node --test test/server/print_fulfillment.test.mjs test/server/print_fulfillment_sql.test.mjs test/server/print_five_sizes_sql.test.mjs test/server/print_cover_types_sql.test.mjs
```

PDF당 파일 상한은 100MB다. 큰 규격의 많은 사진으로 이를 넘기면 실패를 명시하고 재생성/운영 검토가 필요하다. 원본을 임의로 축소해 통과시키지 않는다.

Flutter proof PDF가 `output/pdf/print-export-proof/`에 있으면 실제 생성 결과도 같은 서버 검사기로 검증한다. Docker/로컬 Postgres가 실행되지 않은 환경에서는 `supabase db advisors --local`/`migration list --local`를 실행할 수 없으며, PGlite는 Supabase Storage 서버 자체의 통합 검증을 대신하지 않는다.
