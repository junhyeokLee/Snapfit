# 관리자 소유 앨범의 TEST 결제와 DEV 자동 발주

2026-10-15 작성. **실제 앱의 80페이지 PDF 생성·업로드 → PortOne TEST 승인 → 앱 종료 → Cron의 결제 검증·레드프린팅 DEV 접수·파일 분석 완료까지 확인했다.** 같은 파일·결제·주문 참조를 유지했고 최종 상태는 `FILE_CHECKED`, 작업은 `DONE`이다. 실물 제작·배송이나 운영 판매를 완료했다는 뜻은 아니다. 이 문서는 준비·로컬 검증·실제 TEST/DEV 실행을 구분해 기록한다.

## 준비된 경로

1. 고객 앱에 관리자 계정으로 로그인하고 소유 앨범의 제작 미리보기에서 **관리자 개발 주문 테스트**를 연다.
2. 서버가 소유 앨범·사진 소유권·사용자가 확인한 앨범 버전을 확인하고 내용, 사양, 수령 정보를 고정한다.
3. 앱이 기존 Flutter 렌더러로 표지와 내지를 생성한다. 표지는 최대 150,000,000바이트, 내지는 최대 500,000,000바이트다. 50,000,000바이트를 넘으면 원본 바이트를 최대 16,000,000바이트씩 나누어 비공개 Storage에 올린다.
4. 서버가 각 조각과 전체 PDF의 SHA256, 80페이지, 실제 인쇄 치수, 300dpi·sRGB·ICC 조건을 검사한다. 완성된 동일 파일 묶음이 `READY`가 되어야 결제 화면을 발급한다. 재압축이나 화질·색상·PDF 형식 변경은 없다.
5. 승인된 PortOne TEST 채널로 159,900원 **테스트 결제**를 연다. 결제창을 열기 전에 `sdk_issued_at`과 `PAYMENT` 작업을 서버에 한 번만 기록한다.
6. 앱이 종료돼도 기존 2분 Cron이 PortOne에 실제 TEST 결과를 조회한다. 서버가 일치하는 TEST 영수증을 확인한 뒤에만 레드프린팅 DEV 주문을 보낸다. 공급사에는 조각 목록 대신 표지 PDF URL 한 개와 내지 PDF URL 한 개를 전달한다.
7. 후속 Cron이 동일한 업체 주문번호를 조회해 접수·파일 분석 결과를 기록한다. 앱의 상태 확인은 이 서버 기록을 읽기만 한다.

현재 시험 사양은 `REDP_300_HARD`의 80페이지 하드커버 한 조합이다. 승인된 DEV 주문관리코드는 `C8E9D98C73536387071`이며 확인된 제작비는 101,860원이다. 159,900원은 이 경로의 고정 TEST 금액으로, 모든 상품의 확정 판매가나 수익 보장을 뜻하지 않는다. 레드프린팅 개발 키 주문은 실물 제작·배송으로 이어지지 않으며 예치금 확인·제작 확정 API는 호출하지 않는다.

## 운영 주문과의 분리

요청자는 서버가 검증한 Auth `app_metadata.role=admin` 계정이어야 하고 앨범도 본인 소유여야 한다. 화면에서 보낸 관리자 표시나 결제 완료 값을 신뢰하지 않는다. 고정 앨범·사양·원본 파일 해시를 바꾸거나 다른 사용자의 앨범을 붙이면 중단한다.

개발 기록은 RLS가 켜진 다음 비공개 테이블 세 개와 기존 TEST 결제 세션에만 저장한다. 테이블과 내부 RPC는 서비스 역할만 사용할 수 있다.

- `private.print_dev_checkouts`: 관리자 소유의 고정 앨범·사양·TEST 참조·진행 상태
- `private.print_dev_packages`: 직접 업로드·16MB 조각·파일 검수·봉인 결과
- `private.print_dev_fulfillment_outbox`: `PAYMENT`, `SUBMIT`, `POLL` 작업과 임대·재시도 기록
- `private.print_payment_test_sessions`: `SFPGT_` 결제 ID와 실제 조회로 확인한 `VERIFIED_TEST` 영수증

`ordp_` 참조를 사용하는 개발 주문도 `public.orders`나 운영 결제 준비 테이블에는 넣지 않는다. 모든 응답의 `environment=test`, `isTest=true`, `productionApproved=false`를 유지한다. 실제 PG 조회의 `isTest=true`·상태·금액·통화·상점·채널·결제 ID가 모두 일치해야 진행하며 LIVE 영수증이나 임의의 완료 표시는 받아들이지 않는다. 운영 판매·PG·제작·예치금 게이트는 계속 닫혀 있다.

DEV 주문 POST 전에 동일한 공급사 주문번호와 `submitted_at`, `queryOnly=true`를 저장한다. 응답을 받지 못하거나 접수 여부가 불명확하면 다음 Cron은 같은 번호를 조회한다. 자동으로 새 번호를 만들어 재접수하지 않는다. 작업은 120초 임대로 보호하고 임대 소유자가 다르면 완료 처리를 거절한다.

`PRINT_DEV_CHECKOUT_ENABLED=true`와 승인된 TEST·DEV 설정을 함께 만족해야 이 경로가 실행된다. PortOne 환경을 LIVE로 바꾸면 개발 경로는 중단되어 운영 큐 처리를 막지 않는다. DEV PDF 전달은 별도 서명 범위와 실제 TEST 검증·동일한 `READY` 파일 조건을 사용하며 기존 운영 PDF 전달 조건은 유지한다.

## API와 구현 위치

`print-dev-checkout`은 JWT와 관리자 권한을 확인하는 API다. `prepare` 이후 요청은 `runId`, `requestId`, `orderId`, `paymentId`, `albumId`를 함께 확인한다. 비밀키는 앱·요청 본문·이 문서에 넣지 않는다.

| action | 역할 |
| --- | --- |
| `prepare` | 본인 소유 80페이지 앨범과 검토 버전을 확인하고 TEST 주문·세션을 고정 |
| `snapshot` | 고정 앨범·사양·사진 접근 URL·원본 식별값 조회. 모든 업로드 증거가 있는 미완료 묶음에만 동일 manifest 복구 정보 제공 |
| `uploads` | 원본 길이·해시·조각 선언을 고정하고 비공개 업로드 URL 발급 |
| `finalize` | 조각별 바이트 검증, 전체 PDF 검수, 동일 manifest 게시와 `READY` 봉인 |
| `authorize` | `READY` 확인 후 SDK 발급 시각·`PAYMENT` 작업을 기록하고 TEST 결제 요청 반환 |
| `status` | 저장된 상태만 조회. PG 조회·결제 검증·작업 생성·발주는 수행하지 않음 |

주요 구현은 [새 비공개 SQL과 권한](../../../supabase/migrations/20261015030803_admin_owned_test_checkout_pipeline.sql), [API 처리](../../../supabase/functions/_shared/print-dev-checkout.ts), [실제 TEST 조회와 DEV 작업 처리](../../../supabase/functions/_shared/print-dev-fulfillment.ts), [Cron 연결](../../../supabase/functions/print-order-scheduler/index.ts), [서명 PDF 전달](../../../supabase/functions/_shared/print-file-delivery.ts), [앱 서비스](../../../lib/features/profile/data/print_dev_checkout.dart), [개발 주문 화면](../../../lib/features/album/presentation/views/print_dev_checkout_screen.dart)을 따른다. [대용량 원본 PDF 전송](large-original-pdf-transport-2026-10-15.md)의 검사·전달 방식을 재사용한다.

## 실제 앱 시험 중 보완한 부분

같은 원본 이미지를 여러 페이지에서 쓸 때 매번 다시 내려받던 동작을 렌더링 한 번 안에서만 공유하도록 바꿨다. 인코딩된 원본 바이트의 캐시는 항목 16MB·합계 32MB로 제한하고 종료 시 비운다. 각 페이지의 해상도·잘림 검사는 계속 수행하며 300dpi·JPEG 95·sRGB와 배치는 유지한다.

제작 미리보기는 해당 앨범이 사용하는 글꼴만 준비하도록 바꿨다. `NotoSans`, 저장된 `FigmaHand`/`Figma Hand` 이름과 굵기를 확인했고, 전체 글꼴 로딩과 비교한 검증 글자의 픽셀이 같았다. 사용하지 않는 글꼴 파일은 읽지 않으며 실제 사용하는 글꼴의 검증과 누락 차단은 유지한다. 이미 업로드한 PDF는 변경하지 않았다.

파일 전체 검수 실패 후 앱 복원 시에는 같은 앨범을 다시 렌더링해 다른 PDF를 만들지 않는다. 소유권과 모든 조각 증거가 확인된 기존 `UPLOADING` 묶음만 서버가 `fileRecovery:{packageId,manifest}`를 반환한다. manifest는 저장된 원본 report이며 파일 목록·경로·토큰을 추가하지 않는다. 앱은 같은 package·결제·주문 참조로 기존 전체 파일 검사를 다시 요청한다. 안전한 복구 증거가 없으면 기존 파일과 참조를 보존하고 SDK 발급을 막는다.

전체 검수의 실제 CPU 제한은 재다운로드를 줄여 해결했다. 검수마다 최대 112,000,000바이트의 검증된 조각을 보관하고 새 조각 fetch 전에 LRU를 비운다. 100MB 안팎의 7조각은 원본 전체 SHA 이후 문법 검사에서 다시 내려받지 않는다. 조각 SHA·전체 SHA·PDF 문법·페이지·ICC·300dpi·TrimBox 검사는 모두 유지한다. 500MB 전체를 합친 버퍼를 만들지 않으며 업체 전달은 한 조각씩 보내는 기존 방식을 유지한다.

## 로컬 검증 결과

관련 서버 7개 파일의 **77개가 통과**했고 실패·제외는 없다. 실제 Flutter가 생성한 내지 102,193,868바이트의 80페이지 PDF를 7개 조각으로 나누어 API→SQL 파일 검사→봉인→SDK 발급→Cron 작업과 단일 PDF 전달 조건을 확인했다. 관련 앱 **66개 검증과 범위 분석**도 통과했다.

후속 복구·캐시 변경은 서버 5개 파일의 고유 35개가 통과했다. 앱의 초기 66개와 이미지 공유·불변 파일 복구 검증은 중복을 제외한 86개가 통과했고, 미리보기 글꼴·복구 관련 후속 검증과 분석도 통과했다. 서로 겹치는 실행 묶음을 단순 합산하지 않는다. [앱 검증 기록](../../../output/print-dev-order-e2e-2026-10-15/client-verification.json), [복구 검증](../../../output/print-dev-order-e2e-2026-10-15/backend-recovery-tests.json), [캐시 검증](../../../output/print-dev-order-e2e-2026-10-15/backend-cache-tests.json)을 따른다.

검증에는 미완료·변경된 조각 차단, 소유권·관리자 검증, LIVE 설정·영수증 거절, 중복 SDK의 단일 작업, 잘못된 임대, POST 후 조회만 하는 재시도, 읽기 전용 상태 확인이 포함된다. PG·공급사·Storage 어댑터와 SQL 엔진을 사용하는 로컬 검증이며 실제 결제나 업체 주문을 대신하는 완료 증거가 아니다. 합성 영수증을 원격 Supabase에 넣지 않았다.

- [서버 검증 요약](../../../output/print-dev-order-e2e-2026-10-15/backend-tests.json) / [상세 결과](../../../output/print-dev-order-e2e-2026-10-15/backend-tests.txt)
- [앱 검증·빌드 기록](../../../output/print-dev-order-e2e-2026-10-15/client-verification.json)
- [새 관리자 소유 검증 앨범](../../../output/print-dev-order-e2e-2026-10-15/owned-album.json)

## 실제 배포와 연결 검증 결과

기존 Supabase 프로젝트에 위 SQL을 적용하고 `print-dev-checkout`, `print-dev-file-delivery`, `print-order-scheduler`, `print-file-delivery`, `print-fulfillment-worker`를 배포했다. 새로 켠 값은 관리자 전용 `PRINT_DEV_CHECKOUT_ENABLED`뿐이다. 2026-10-15 **03:26 UTC(12:26 KST)**의 실제 Cron은 HTTP 200, 개발 경로 활성, 오류 0건, 처리할 작업 0건이었다. 비공개 테이블 세 개의 RLS와 서비스 전용 RPC 권한을 확인했고 고객 주문·운영 결제 준비는 모두 0건이었다. 별도 유료 서버·구독은 추가하지 않았다.

새 관리자 소유 앨범 ID는 **69**, 제목은 **개발 검증 · 80페이지 앨범 (2026-10-15)**이다. 표지와 내지 80페이지, 직접 생성한 검증 이미지로 구성했고 기존 고객 앨범은 변경하지 않았다. 고객 앱 `http://127.0.0.1:7357/`의 실제 화면에서 생성한 표지는 1,800,318바이트, 내지는 100,423,393바이트·7조각이다. 같은 원본의 내지 SHA256은 `602676bbb7c4b1cac32e902defd4552d9372a217fda50946d60ff62469b29989`다.

전체 검수는 처음 두 번 CPU 제한으로 HTTP 546을 반환했다. 새 worker에서도 CPU 2,018ms로 재현돼 이전 요청 누적만으로 단정하지 않았다. 캐시 보완 뒤 같은 파일·패키지로 재검수해 **04:21:57.767610 UTC에 READY**, **04:21:58.393314 UTC에 SDK 발급**을 기록했다. 전체 검수 응답은 04:21:57.870 UTC HTTP 200·12,271ms wall time이었고, 해당 실행 로그의 CPU는 1,286ms, 메모리 합계는 118,582,388바이트였다. 이 메모리 값은 별도로 측정한 최대 RSS가 아니다. [실제 CPU 진단과 성공 로그](../../../output/print-dev-order-e2e-2026-10-15/finalize-cpu-diagnostic.json)를 따른다.

이후 PortOne iframe의 공개 `/driver-host?definitionPath=…` GET이 HTTP 500을 반환해 회색 화면을 확인했다. Chrome User-Agent·Referer를 사용한 조회에서도 같은 결과였다. 그러나 **SDK·키·채널·결제 ID·상점 설정을 바꾸지 않은 동일 결제창이 이후 정상으로 돌아왔고 실제 TEST 승인이 성공했다.** 이 관측으로 상점 설정 오류나 포트원 전체 장애를 단정하지 않는다. 당시 `PREPARED`·`payment_not_paid` 기록은 미승인 시점의 이력이며 실패 기록을 삭제하지 않는다. 외부 문의는 발송하지 않았다.

실제 PortOne TEST 영수증은 금액 159,900원·KRW·`PAID`·`isTest=true`이며 PG 승인 시각은 **04:46:58 UTC**다. SDK 반환을 본 뒤 **04:47:08.367 UTC에 앱 탭을 닫았고**, 앱 탭이 남아 있지 않음을 확인했다. 앱을 다시 열지 않은 상태에서 **04:50:01.903874 UTC에 Cron이 같은 결제를 `VERIFIED_TEST`로 검증**하고 기존 작업 한 건을 `PAYMENT`에서 `SUBMIT`으로 바꿨다. [앱 종료 기록](../../../output/print-dev-order-e2e-2026-10-15/app-close-proof.json)과 [현재 실제 서버 상태](../../../output/print-dev-order-e2e-2026-10-15/actual-latest.json)를 따른다. 임의의 영수증을 넣거나 새 결제 ID를 만들지 않았다.

첫 DEV 전송은 결과를 확정하지 못해 `vendor_request_uncertain`으로 남았다. 전송 전에 **04:52:07.242451 UTC의 `submitted_at`과 동일 주문번호를 저장**했으므로 새 주문을 보내지 않고 `queryOnly=true`로 전환했다. 이후 정기 Cron의 조회만으로 **04:56:02.315342 UTC에 `FILE_CHECKED`·작업 `DONE`**으로 복구됐고, 04:56:43.893691 UTC의 읽기 전용 상태에서 이를 확인했다. 추가 주문 POST는 없었다. 작업 `attempts=12`는 결제 조회와 후속 처리 횟수이며 주문 12건을 뜻하지 않는다.

확인된 레드프린팅 DEV 주문번호는 **`SFD0c3edc06ce464decb430979c82516fe0`**다. 업체 상태는 `file_process_yn=Y`, API 코드 `PGS_06`, 원본 코드 `PGS_05`다. 담당자 회신에 따라 원본 `PGS_05`는 파일 분석에서 나올 수 있는 주의 상태로 구분하며, 실제 생산 불가 오류인 원본 `PGS_06`과 혼동하지 않는다. 별도 `resultId`는 null인 원본 응답을 그대로 보존했다. 따라서 ‘주의 표시 없는 인쇄 승인’으로 바꾸지는 않되, 해당 개발 주문의 접수와 파일 분석 완료는 확인했다.

| 시각(2026-10-15 UTC) | 실제 관측 |
| --- | --- |
| 04:21:57.767610 | 원본 PDF 전체 검수·봉인 `READY` |
| 04:21:58.393314 | 같은 TEST SDK 발급, 서버 작업 기록 |
| 04:46:58 | PortOne TEST 승인 `PAID`, 159,900원·`isTest=true` |
| 04:47:08.367 | 앱 탭 종료 |
| 04:50:01.903874 | 정기 Cron이 실제 영수증을 `VERIFIED_TEST`로 검증 |
| 04:52:07.242451 | 같은 DEV 주문번호의 전송 시도 기록, 이후 응답 불명확 상태 보존 |
| 04:56:02.315342 | 정기 Cron의 GET 조회로 `file_process_yn=Y`, `FILE_CHECKED`·`DONE` 기록 |
| 04:56:43.893691 | 최종 서버 상태 읽기 확인 |
| 04:57:05.740 | 결과 확인 화면을 다시 열기 전 앱 탭 0개 확인 |

결제 검증·DEV 전송·복구 조회 동안 앱은 닫혀 있었고 수동 스케줄러 호출·수동 결제 확인·별도 수동 발주는 하지 않았다. [현재 실제 상태](../../../output/print-dev-order-e2e-2026-10-15/actual-latest.json), [앱 종료 기록](../../../output/print-dev-order-e2e-2026-10-15/app-close-proof.json), [업체 파일 다운로드 로그](../../../output/print-dev-order-e2e-2026-10-15/vendor-file-delivery-proof.json)를 함께 대조한다. 다운로드 로그의 Content-Length만으로 수신 파일의 독립 SHA까지 측정했다고 주장하지 않으며, 실제 접수·분석 완료는 별도 상태 조회로 확인했다. 고객 운영 주문과 운영 결제 준비는 계속 0건이고 실제 제작·예치금 확정은 하지 않았다.

앱 종료 후 실제 진행 여부는 다음 순서로 대조한다. 이번 TEST run에서는 1–5단계를 모두 확인했다.

1. 앱에서 앨범과 사양·배송 정보를 확인하고 PDF 생성·업로드·서버 `READY`를 완료한다. 고정 파일의 길이·전체 SHA와 패키지 ID를 기록한다.
2. 같은 `SFPGT_` ID로 TEST 결제창을 한 번만 열어 테스트 표시를 확인하고 사용자가 약관·테스트 승인을 직접 완료한다. 클라이언트 콜백으로 결제 완료를 기록하지 않는다.
3. 실제 앱 또는 브라우저 탭을 닫고 닫은 시각을 기록한다. 이후 앱에서 확인·발주 API를 호출하지 않고 Cron 결과와 서버의 읽기 전용 기록만 확인한다.
4. 원래 `sdk_issued_at` 이후이며 **앱을 닫은 시각 이후**에 Cron이 `VERIFIED_TEST`의 `verified_at`을 기록했는지 확인한다. 실제 PortOne TEST 영수증의 ID·금액·채널·`isTest`와 같은 세션인지 대조한다.
5. 같은 개발 주문의 `submitted_at`, 작업 큐 갱신 시각, 레드프린팅 주문번호·접수 응답과 조회 결과를 확인한다. HTTP 200만으로 완료라고 하지 않고 `file_process_yn=Y`와 파일 오류 의미까지 확인한다. 실제 제조·예치금 확정은 진행하지 않는다.

결제 승인이 끝나기 전에 Cron이 조회한 미결제·404는 결제 완료로 만들지 않고 후속 조회를 기다린다. 접수가 불명확하면 같은 주문을 조회하고 재결제를 만들지 않는다. 후속 시험도 위 증거를 모두 확인한 뒤 TEST/DEV 자동 발주 검증 완료로 기록한다.

16MB 조각도 Storage·전송량·함수 호출을 사용한다. 기존 무료 제공량 안에서 소량 개발을 준비한 것이며 무제한 저장·전송이나 무중단 운영을 보장하지 않는다. 실제 판매는 사업자·PG·레드프린팅 운영 계약/키·예치금과 최종 사양·가격·실물 확인을 별도로 마친 뒤 연다.

### 앱 재실행 결과

업체의 `FILE_CHECKED` 확정 뒤에만 앱을 다시 열었다. 동일 TEST 결제·개발 주문 참조가 복원됐고, 화면에 TEST 영수증 확인 완료·표지/내지 검수 완료·업체 개발 파일 확인 완료가 표시됐다. 새 결제 버튼은 나타나지 않았다. [재실행 증거](../../../output/print-dev-order-e2e-2026-10-15/app-reopened-result-proof.json)와 [최종 화면](../../../output/print-dev-order-e2e-2026-10-15/app-test-order-complete.png)을 기록했다.
