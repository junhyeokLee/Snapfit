# 실제 Flutter 렌더러로 만든 로컬 인쇄 연결 검증

고객 데이터가 없는 생성 테스트 카드입니다. 실제 인쇄업체 주문·결제·배송은 하지 않았습니다. 업체 파일 승인, 실물 사진 인쇄 품질이나 제본/포장 검수가 끝났다는 뜻은 아닙니다.

- `cover.pdf`: 1쪽, 417.22×160mm, 책등 7.22mm.
- `interior.pdf`: 20쪽, 210×160mm, 재단 200×150mm.
- 두 PDF는 앱의 `AlbumPrintExporter`/`LayerBuilder`에서 생성했으며 서버의 PDF 페이지·mm규격·TrimBox·300dpi·sRGB ICC 검사에 통과했습니다.
- `manifest.json`: 실제 렌더러 보고서. `vendor_color_sample_required` 경고는 그대로 보존합니다.
- `fixture.json`: 합성 테스트 입력과 로컬 전용 도면. `verified=true`는 로컬 stub용 설정이며 운영 승인 상태가 아닙니다.
- `pipeline-verification.json`: 서버 검수 파일 해시와 로컬 결제/업체/DB stub 연결 결과. 외부 요청/실결제/실발주/실배송은 0입니다.
- `cover-review.png`, `interior-01-review.png`, `interior-17-review.png`: 한글·페이지 번호·배치 확인용 렌더 이미지.

생성은 `node tool/print_fulfillment/run_worker.mjs --fixture`를 사용합니다. 반환 폴더를 `SNAPFIT_WORKER_FIXTURE_OUTPUT`로 지정하여 `node --experimental-transform-types --test test/server/print_worker_renderer_integration.test.mjs`를 실행합니다. `pdf-lib` 위치는 필요하면 `SNAPFIT_PDF_LIB_PATH`로 지정합니다. 이 시험에는 공급업체나 PG를 호출하는 네트워크 구현을 넣지 않았습니다.
