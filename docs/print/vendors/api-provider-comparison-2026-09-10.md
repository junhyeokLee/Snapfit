# 자동 포토북 제작 업체와 코드 전환 지도

조사일: 2026-09-10. 공식 문서와 현재 로컬 소스를 비교했다. 제작사 계정 가입·인증 API 호출·실주문·충전·배포는 수행하지 않았다. 아래는 도입 검증안이며 현재 앱의 공급사를 변경한 상태가 아니다.

## 추천

**국내 서비스인 스냅핏은 스위트북 Book Print API를 1순위로 검증한다.** 국내 포토북 사업자의 외부 PDF 업로드·주문·개별 배송 절차가 공개돼 있어 서비스 구조가 맞는다. 기존 편집기를 유지할 수 있는 PDF_UPLOAD 방식을 사용한다. 스위트북 본사이트도 [Book Print API를 공식 서비스로 연결](https://www.sweetbook.com/)한다.

앞선 [일괄 접수 검토](fulfillment-options-2026-09-10.md)에서는 국내 공개 API를 확인하지 못했지만, 이번 조사에서 아래 공식 자료를 확보했다. API 지원 확인과 스냅핏의 실제 단가·상품·인쇄 품질 검증은 구분한다.

| 후보 | 자동 발주 근거 | 스냅핏에 대한 판단 |
|---|---|---|
| **스위트북** | 외부 표지·내지 파일 업로드, 책 최종화, 배송지를 포함한 주문 생성. [PDF 업로드 절차](https://api.sweetbook.com/docs/guides/scenario-pdf/) | 국내 1순위. 실제 단가, 기존 5개 크기, 발송자명·포장 조건 협의 필요 |
| **Prodigi** | 포토북 API 주문, 견적, 제작·배송 추적. [공식 API](https://www.prodigi.com/print-api/) | 해외 대안. 한국 생산 상품 목록은 케이스류 중심이며 포토북 국내 생산을 확인한 것은 아님. [한국 생산 목록](https://www.prodigi.com/products/kr/) |
| **Gelato** | 포토북 PDF를 이용한 API 주문. [시작 문서](https://dashboard.gelato.com/docs/get-started/) | 해외 대안. 상품별 한국 배송 가능 여부·페이지 수를 인증된 상품 조회로 확인해야 함. [상품 API](https://dashboard.gelato.com/docs/products/product/get/) |
| Peecho | 앱의 포토북을 인쇄·배송하는 Polarsteps 사례와 Print API. [공식 사례](https://www.peecho.com/solutions/print-api) | 콘텐츠 앱에 맞는 대안. 한국행 실제 견적·배송 조건 미검증 |
| Lulu Print API | 표지·내지 PDF를 주문별로 전달하는 제작 API. [공식 안내서](https://assets.lulu.com/media/guides/en/lulu-api-getting-started-guide.pdf) | 일반 책 제작 대안. 한국은 배송 제외국에 포함되지 않지만 실제 상품별 운임·출발지 확인 필요. [배송 정책](https://help.lulu.com/en/support/solutions/articles/64000255307-shipping-the-basics) |

해외 업체의 전 세계 배송이나 한국 거점 표시는 선택한 포토북이 한국에서 만들어진다는 보장이 아니다. 현재 레드프린팅 도면을 다른 업체에 그대로 제출하지 않는다.

## 스위트북 상품과 비용 확인

공개 [BookSpecs 문서](https://api.sweetbook.com/docs/api/book-specs/) 기준 주요 상품은 아래와 같다. 모든 페이지 증분은 2페이지다. 업체가 스퀘어북이라고 부르는 제품의 실제 내지 치수는 **243×248mm**다.

| API 상품 ID | 내지 크기 | 표지/제본 | 책 내지 페이지 |
|---|---:|---|---:|
| PHOTOBOOK_A4_SC | 210×297mm | 소프트 / PUR | 24~130 |
| PHOTOBOOK_A5_SC | 148×210mm | 소프트 / PUR | 50~200 |
| SQUAREBOOK_HC | 243×248mm | 하드 / PUR | 24~130 |
| SQUAREBOOK_LAYFLAT_HC | 243×248mm | 하드 / 레이플랫 | 16~46 |

[제품 소개](https://api.sweetbook.com/products/)는 표준 3종과 맞춤 판형 협의를 안내하고, API 문서에는 레이플랫을 포함한 4종이 나온다. 실제 도입 시 해당 파트너 계정의 GET /book-specs 응답으로 판매 가능 상품을 확정한다. 현재의 200×150/200×200/250×200/250×250/300×300mm 각각 소프트·하드 조합을 모두 유지하려면 별도 맞춤 협의가 필요하다. 표준 상품으로 시작한다면 판매 선택지도 실제 조합으로 바꾼다. 모든 크기에 두 표지를 임의로 짝지어 만들면 안 된다.

20페이지는 위 레이플랫 범위에 들어가지만 이 제품은 최대 46페이지다. 80페이지까지 판매하려면 PUR 상품의 최소 페이지 조건도 반영해야 한다. 기존 주문을 조용히 새 규격으로 바꾸지 않고, 고객이 확인할 인쇄 미리보기와 추가 빈 페이지 안내를 갱신한다.

단가는 [파트너 로그인 후 확인](https://api.sweetbook.com/products/)하며, [가입 후 Sandbox 사용·사업 협의 후 Live 사용](https://api.sweetbook.com/docs/registration/) 절차다. 현재 판매가보다 저렴하거나 마진이 더 남는다는 결론은 아직 내릴 수 없다. 발송자명 ‘스냅핏’, 가격표/명세서 제외, 포장 표시, 반품 연락처, 입력 PDF의 sRGB·PDF 1.4 수용 여부를 함께 확인한다. 제품의 CMYK 인쇄 설명만으로 입력 PDF도 CMYK여야 한다고 판단하지 않는다.

## 연동 방식

1. 기존에 검수한 주문 스냅샷과 공급사별 규격으로 표지·내지 PDF를 만든다.
2. 스냅핏 서버가 스위트북에 책을 생성하고 파일을 업로드한다. API 키는 앱·관리자 브라우저에 배포하지 않는다.
3. 파일 검사 후 책을 최종화하고, 고객 배송지와 수량을 담아 주문한다.
4. 업체 주문번호를 보관하고 제작·출고·배송 이벤트를 받아 관리자와 고객 주문 내역에 반영한다.

제작사 [Orders API](https://api.sweetbook.com/docs/api/orders/)는 주문 생성 때 충전금을 차감한다. 주문 하나에 배송지 하나를 보내므로 고객 주소가 다르면 API 호출도 주문별로 하되, 그 반복을 서버가 처리한다. 고객이 스냅핏에 결제하는 PG와 스냅핏이 제작사에 지불하는 충전금은 별개다. 업체 취소에 따른 충전금 반환도 고객 PG 환불과 별개로 처리한다.

현재 자료에는 주문 전 전용 견적 엔드포인트를 확인하지 못했다. 인증된 상품/계정 단가와 배송·포장·부가세 규칙을 확보하고 가격 변경 정책을 합의해야 한다. 문서의 JSON 응답 예시 금액을 실제 공급 단가로 사용하지 않는다. 현재 최소 운영 기여금 10,000원 검사는 실제 원가 기준으로 유지하며, 외부 발주 후 청구액도 대조한다.

### PDF 변경의 핵심

[치수 계산 API](https://api.sweetbook.com/docs/concepts/pdf-size-api/)의 `GET /book-specs/{bookSpecUid}/calculated-size?pages=...`로 해당 상품·면수의 출력 크기를 받아 고정한다. 레드프린팅의 책등 추정식을 재사용하지 않는다.

[PDF 규격 문서](https://api.sweetbook.com/docs/concepts/pdf-size/)의 하드커버는 접힘 간격·감싸기 여유·3mm 도련이 반영되며, 일반 하드 24페이지 예시 표지는 544×288mm, 낱쪽 내지는 249×254mm다. PUR 내지는 책 한 페이지당 PDF 한 페이지, 레이플랫 내지는 두 페이지를 합친 펼침면이다. 책 20페이지 레이플랫은 PDF 내지 10페이지이므로 서버 검사에서도 책 페이지 수와 PDF 페이지 수를 나누어 다뤄야 한다. 단순히 현재 낱쪽 두 장을 축소해 한 장에 넣는 방식 대신 새 제본 규격에 맞춰 원본 레이어를 배치한다.

공식 문서의 치수 예시와 허용 오차 설명에 일부 표현 차이가 있으므로 최종 계정 응답과 샌드박스 업로드 검사로 확인한다. sRGB/색상·재단·제본 품질은 실제 샘플로 검증한다.

## 현재 코드에서 바꿀 곳

아래 경로는 조사 시점의 실제 파일이다. 새 공급사 연동은 신규 버전으로 추가하고 기존 레드프린팅 주문 계약을 보존한다.

| 구역 | 현재 파일 | 필요한 변경 |
|---|---|---|
| 앱의 크기·표지 선택 | [cover_size.dart](/Users/devsheep/SnapFit/SnapFit/lib/core/constants/cover_size.dart:37) | `_SOFT`→`_HARD` 문자열 교체로 표지를 만드는 구조를 실제 상품 조합 조회로 변경. 기존 앨범 복원은 유지 |
| 상품·규격 모델 | [print_vendor_spec.dart](/Users/devsheep/SnapFit/SnapFit/lib/features/album/printing/print_vendor_spec.dart:56) | 공급사, 명시적 표지/제본 종류, 책 페이지/PDF 페이지 구분, 업체별 영역 좌표와 치수 |
| PDF 생성 | [album_print_exporter.dart](/Users/devsheep/SnapFit/SnapFit/lib/features/album/printing/album_print_exporter.dart:113) | 사진·글꼴·레이어 합성 재사용. 새 도련·접힘 간격·판형·낱쪽/펼침면 처리. 색상/포맷 변경이 실제 요구되면 raster_print_pdf.dart도 조정 |
| 서버 상품·가격 계약 | [print-contract.ts](/Users/devsheep/SnapFit/SnapFit/supabase/functions/_shared/print-contract.ts:10) | 공급사별 카탈로그·가격·도면 버전, 금액/통화/세금/배송과 조회 시점 고정 |
| DB | [기존 계약 마이그레이션](/Users/devsheep/SnapFit/SnapFit/supabase/migrations/20260908120849_redprinting_cover_types_contract.sql:88) | **새 마이그레이션**으로 공급사 책/주문 ID, 작업·재시도·웹훅 이벤트 원장 추가. 기존 SQL 이력 수정 금지 |
| PDF 보관·검사 | [print-package.ts](/Users/devsheep/SnapFit/SnapFit/supabase/functions/_shared/print-package.ts:102) | 공급사 고정값과 규격 검사 분리. 자체 비공개 저장소의 파일을 서버에서 업체에 직접 업로드 |
| 외부 발주 | [order-fulfillment.ts](/Users/devsheep/SnapFit/SnapFit/supabase/functions/_shared/order-fulfillment.ts:87), [admin-ops](/Users/devsheep/SnapFit/SnapFit/supabase/functions/admin-ops/index.ts:179) | 현재 수동 발주번호 저장과 **새 실제 API 주문 생성** 액션 분리. 별도 공급사 어댑터·작업 처리기 추가 |
| 관리자 PDF 준비 | [admin_print_service.dart](/Users/devsheep/SnapFit/SnapFitAdmin/lib/printing/admin_print_service.dart:36) | 기존 생성·비공개 업로드 재사용. 여러 주문 준비 진행과 실패 항목 표시. 무인 PDF 생성은 별도 작업자로 이동 |
| 관리자 발주 UI | [order_dialogs.dart](/Users/devsheep/SnapFit/SnapFitAdmin/lib/features/orders/order_dialogs.dart:332), [order_detail_panel.dart](/Users/devsheep/SnapFit/SnapFitAdmin/lib/features/orders/order_detail_panel.dart:240) | 업체 사이트 열기·수동 비용/주문번호 입력을 원가 확인·승인·API 발주·결과 조회로 확장. 충전금 부족/오류 항목 표시 |
| 주문 상태 수신 | 신규 웹훅 수신 함수와 DB 이벤트 원장 | 서명 검증, 중복 수신 제거, 상태 역행 방지, 유실 이벤트 조회 보완. 제작 완료와 배송 완료 구별 |

AI 상품 허용표(`template-design.ts`), 일반/AI 앨범 생성의 상품 선택, 고객 미리보기·주문 내역, 발송자명과 제작기간 안내도 카탈로그 변경에 맞춰 함께 점검한다. 현재 `redprinting_fulfillment_policy.dart`의 공급사 회신을 새 업체에도 공통 적용하지 않는다.

## 유지할 부분과 작업 순서

원본 앨범·편집 기능, 고정 주문 스냅샷, 사진/글꼴 검사, 비공개 PDF 보관, 관리자 로그인과 권한, 주문 검색, 원가 비공개 및 기여금 계산은 재사용할 수 있다.

**1차는 관리자 승인 후 자동 발주**로 시작한다. 현재 PDF는 PC 브라우저에서 생성하므로 PDF 준비·검수는 관리자에서 하고, 승인한 주문의 업체 업로드·비용 차감·주문번호·상태 반영을 자동화한다. 고객 결제 직후 관리자 PC 없이 PDF까지 생성하려면 **2차로 렌더링 작업자**를 구현해야 한다. 기존 Flutter 레이어 렌더링을 재현하는 실행 환경이 필요하다.

중복 발주 방지는 외부 API 호출 전 작업/요청 키를 저장하고 같은 주문·같은 파일에 같은 키를 재사용하는 방식으로 설계한다. 현재 DB 저장의 원자성만으로 업체 중복 주문을 막을 수 없다. 응답을 못 받은 요청은 업체 상태를 조회·대조한 뒤 처리한다. [스위트북 멱등성 안내](https://api.sweetbook.com/docs/api/orders/)

[웹훅 이벤트](https://api.sweetbook.com/docs/api/webhook-events/)는 서명과 고유 ID를 검증해 저장한다. 현재 관리자 다운로드 URL은 15분 유효하므로 업체가 나중에 내려받을 링크로 그대로 전달하지 않는다. 스위트북에는 multipart 파일 업로드를 활용하고 원본 비공개 보관은 유지한다.

착수 순서는 파트너 Sandbox·단가/포장 조건 확인 → 판매할 상품 확정 → 해당 규격 PDF 검사와 실물 샘플 → 관리자 승인형 API 발주/오류·취소 테스트 → 고객 결제 연결/통합 검증 → 필요 시 무인 PDF 생성 순서다. 현재 PRINT_REDP V1/V2/V3의 이미 저장된 상품·가격·지문을 새 업체 것으로 덮어쓰지 않는다.
