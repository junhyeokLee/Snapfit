# 300×300mm 하드커버 80쪽 합성 소프트웨어 검수

실제 앱의 Flutter `AlbumPrintExporter`가 합성 카드/글로 표지 1쪽과 내지 80쪽을 만들었습니다. 300dpi, JPEG 품질 95, sRGB/ICC와 현재 90MiB 작성기·100MiB 업로드 제한을 유지합니다. 표지 MediaBox는 681.2×346mm, 내지는 310×310mm입니다.

실제 서버 PDF 검사기로 이 파일의 페이지·형상·dpi·ICC·지문을 검사했습니다. `pipeline-verification.json`은 **로컬 가짜 PG·DB·공급업체**를 이용한 연결 증거입니다. 공급업체 제출 1회, 예치금 처리 1회 뒤 파일 확인/제작/송장 단계를 구분하고 최종 상태를 배송중으로 유지했습니다. 요청 복구 tick은 비운영 stub입니다.

`cover-review.png`, `interior-01-review.png`, `interior-80-review.png`를 시각 검사해 한글, 카드 배치, 페이지 번호와 잘림 여부를 확인했습니다. `fixture-render-metrics.json`과 `host-render-runtime.json`은 macOS 합성 시험의 시간·파일 용량·메모리 관찰입니다. Linux 호스트 성능/상시 운영은 확인하지 않았습니다.

`dense-artwork-limit-failure.json`과 `dense-artwork-limit-runtime.json`은 원본의 복잡한 카드를 반복한 첫 80쪽 시험이 `print_pdf_exceeds_90mb_limit`로 중단된 증거입니다. 그 시험에서는 완성 PDF를 만들지 않았습니다. `--fixture-scenario HARD_80 --fixture-artwork standard`로 해당 용량 제한을 다시 시험할 수 있습니다. 기본 HARD_80은 압축 가능한 `compact` 카드이며, 성공을 위해 해상도나 JPEG 품질을 낮추지 않았습니다.

실제 고객 사진·실결제·실발주·실발송을 사용하지 않았습니다. 이 자료는 모든 80쪽 사진 분량의 용량 적합성, 업체 파일 검사, 실물 샘플 또는 운영 승인을 보증하지 않습니다. `productionApproved`와 `physicalSampleValidated`는 계속 false입니다.
