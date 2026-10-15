import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/printing/album_print_exporter.dart';
import 'package:snap_fit/features/album/printing/print_album_document.dart';

import '../../tool/print_samples/redprinting_soft_sample.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'generate operator-owned app sample through actual print renderer',
    (tester) async {
      await tester.runAsync(() async {
        final snapshot = softSampleAlbumSnapshot();
        final spec = softSampleSpec();
        final document = PrintAlbumDocument.fromSnapshot(snapshot);
        document.validateSpec(spec, newPreview: true);
        expect(document.interiors, hasLength(20));
        expect(
          document.interiors.map((page) => page.index),
          List.generate(20, (i) => i + 1),
        );
        final card = await generatedSampleTestCard();
        final output = await AlbumPrintExporter(
          loadOnlyUsedFonts: true,
          assetLoader: (source) async {
            if (source != sampleTestCardSource) {
              throw StateError(
                'Unexpected asset in operator-owned sample: $source',
              );
            }
            return card;
          },
        ).generate(snapshot: snapshot, spec: spec);
        expect(output.interiorPageCount, 20);
        expect(output.report['blankPagesAdded'], 0);
        expect(output.report['missingAssets'], isEmpty);
        expect(output.report['iccProfileEmbedded'], true);
        expect(output.report['dpi'], 300);
        expect(output.report['specVerified'], false);
        final crops = (output.report['imageResolution'] as List).cast<Map>();
        expect(
          crops.every((row) => (row['effectivePpi'] as num) >= 150),
          isTrue,
        );
        expect(crops.any((row) => row['cropZoom'] == 4), isTrue);
        expect(output.coverPdf.length, lessThan(100 * 1024 * 1024));
        expect(output.interiorPdf.length, lessThan(100 * 1024 * 1024));
        final directory = Directory(
          Platform.environment['SNAPFIT_PRINT_SAMPLE_OUTPUT'] ??
              '/Users/devsheep/SnapFit/SnapFitAdmin/output/print-samples/2026-10-12/soft-200x150-20',
        )..createSync(recursive: true);
        File('${directory.path}/cover.pdf').writeAsBytesSync(output.coverPdf);
        File(
          '${directory.path}/interior.pdf',
        ).writeAsBytesSync(output.interiorPdf);
        File('${directory.path}/source-album.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(snapshot),
        );
        File(
          '${directory.path}/generated-test-card.png',
        ).writeAsBytesSync(card);
        File('${directory.path}/report.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert({
            ...output.report,
            'samplePurpose': 'operator-owned physical print validation',
            'containsCustomerData': false,
            'testCardSource':
                'code-generated color/gradient/grayscale/line card',
            'sourceTestCardPixels': [4800, 3600],
            'naturalPhotoQualityValidated': false,
            'physicalSampleValidated': false,
            'productionApproved': false,
            'pageTemplateIds': document.interiors
                .take(12)
                .map(
                  (page) => page.layers
                      .firstWhere((layer) => layer.type.name == 'image')
                      .id,
                )
                .toList(),
            'coverPdfBytes': output.coverPdf.length,
            'interiorPdfBytes': output.interiorPdf.length,
          }),
        );
        File('${directory.path}/README.md').writeAsStringSync('''# 스냅핏 실물 검수 샘플

200×150mm 소프트커버, 내지 20쪽, 1권용입니다. PDF 생성만 진행했고 주문·결제·발송은 하지 않았습니다.

- 표지: `cover.pdf`, 1쪽, 417.22×160mm, 책등 7.22mm.
- 내지: `interior.pdf`, 20쪽을 순서대로 개별 페이지로 저장, 페이지 210×160mm, 재단 200×150mm.
- 인쇄 파일: 실제 앱의 `AlbumEditorService`, `LayerExportMapper`, `PrintAlbumDocument`, `AlbumPrintExporter` 경로를 사용합니다. 300dpi 래스터와 sRGB ICC를 포함합니다.
- 입력: 코드를 통해 생성한 4800×3600px 테스트 카드입니다. 고객 사진·주소·계정 정보, 외부 이미지를 사용하지 않았습니다.
- 1-12쪽: 앱의 현재 페이지 템플릿 12종. 검수용 제목과 번호를 위해 상하 여백을 두었습니다.
- 13-14쪽: 사진 확대 1배/4배, 이동, 회전, 즉석사진·타원·필름 프레임.
- 15쪽: 색상·그라데이션·회색·가는 선. 원본 선 폭은 2/4/8px입니다. PDF의 JPEG 압축과 축소를 거치므로 교정기나 측정용 색상 기준표를 대체하지 않습니다.
- 16-18쪽: 긴 한글 문단, 자동 줄바꿈, NotoSans/을유명조/손글씨, 작은 글씨, 어두운 배경.
- 19-20쪽: 페이지 순서·제본·실물 확인 항목.

앞표지는 앱에서 장식 책등을 제외하고 전체 배치를 맞춘 결과입니다. 뒤표지와 실제 책등은 앞표지 배경색으로 만들어집니다. 샘플을 받은 후 재단, 책등, 색상, 한글, 사진 확대 후 선명함, 내지 순서, 종이·제본·포장을 확인해야 합니다. 이 카드는 자연사진의 피부색이나 실제 고객 사진 품질을 확인하지 않습니다.

`report.json`은 파일 생성 검사 결과이고, 실물 승인이나 운영 발주 승인이 아닙니다. `source-album.json`과 `generated-test-card.png`는 재현 자료이며 제작사에는 표지와 내지 PDF만 전달합니다.
''');
      });
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
