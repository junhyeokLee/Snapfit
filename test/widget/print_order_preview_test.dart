import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/album/presentation/views/print_order_preview_screen.dart';
import 'package:snap_fit/features/album/printing/album_print_exporter.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import '../printing/hardcover_print_export_test.dart' as hard;

class _OrderRepo extends Mock implements OrderRepository {}

class _Exporter extends AlbumPrintExporter {
  Object? failure;
  Object? generationFailure;
  int generationCalls = 0;
  PrintVendorSpec? verifiedSpec;
  PrintVendorSpec? generatedSpec;
  @override
  Future<Map<String, dynamic>> verify({
    required Map<String, dynamic> snapshot,
    required PrintVendorSpec spec,
    Map<String, String> sourceUrls = const {},
    void Function(int, int)? onProgress,
  }) async {
    verifiedSpec = spec;
    if (failure != null) throw failure!;
    return {'imageResolution': <dynamic>[], 'blankPagesAdded': 19};
  }

  @override
  Future<AlbumPrintExport> generate({
    required Map<String, dynamic> snapshot,
    required PrintVendorSpec spec,
    Map<String, String> sourceUrls = const {},
    void Function(int, int)? onProgress,
  }) async {
    generationCalls++;
    generatedSpec = spec;
    if (generationFailure != null) throw generationFailure!;
    return AlbumPrintExport(
      coverPdf: Uint8List(5),
      interiorPdf: Uint8List(5),
      report: {},
      interiorPageCount: 20,
    );
  }
}

void main() {
  late _OrderRepo orders;
  late _Exporter exporter;
  setUp(() {
    orders = _OrderRepo();
    exporter = _Exporter();
    when(() => orders.fetchOrderQuote(albumId: 7)).thenAnswer(
      (_) async => OrderQuoteResult.fromJson({
        'pageCount': 20,
        'amount': 49900,
        'basePages': 20,
        'basePrice': 49900,
        'extraPageCount': 0,
        'extraPagePrice': 1200,
        'sourcePageCount': 1,
        'addedBlankPageCount': 19,
        'shippingIncluded': true,
        'spec': {
          'id': 'REDP_200_SOFT',
          'specVersion': 'review-v1',
          'pageCount': 20,
          'interior': {'trimWidthMm': 200, 'trimHeightMm': 200, 'bleedMm': 5},
          'cover': {
            'widthMm': 417.22,
            'heightMm': 210,
            'front': {'xMm': 212.22, 'yMm': 5, 'widthMm': 200, 'heightMm': 200},
            'back': {'xMm': 5, 'yMm': 5, 'widthMm': 200, 'heightMm': 200},
          },
        },
      }),
    );
    when(() => orders.fetchPrintPreviewSnapshot(albumId: 7)).thenAnswer(
      (_) async => {
        'album': {
          'id': 7,
          'title': 'Our album',
          'ratio': '1',
          'cover_theme': 'classic',
          'cover_layers_json': jsonEncode({
            'pages': [
              {'index': 0, 'isCover': true, 'layers': []},
              {'index': 1, 'isCover': false, 'layers': []},
            ],
          }),
        },
        'pages': <dynamic>[],
      },
    );
  });
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(orders),
          printPreviewExporterProvider.overrideWithValue(exporter),
        ],
        child: const MaterialApp(
          home: PrintOrderPreviewScreen(albumId: 7, albumTitle: 'Our album'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows server quote, square pages and appended blanks without payment',
    (tester) async {
      await pump(tester);
      expect(find.text('49,900원 예상'), findsOneWidget);
      expect(find.text('작성한 내지 1페이지 + 뒤에 추가되는 빈 페이지 19페이지'), findsOneWidget);
      await tester.scrollUntilVisible(find.byIcon(Icons.chevron_right), 300);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      expect(find.text('내지 2 / 20 · 추가 빈 페이지'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('빈 페이지'), -200);
      expect(find.text('빈 페이지'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, '인화 주문 결제 준비 중'),
        300,
      );
      final disabledPayment = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '인화 주문 결제 준비 중'),
      );
      expect(disabledPayment.onPressed, isNull);
      expect(find.textContaining('영업일 5~6일'), findsOneWidget);
      expect(find.textContaining('택배 배송 기간 별도'), findsOneWidget);
      expect(find.textContaining('주문번호 스티커'), findsOneWidget);
      final generate = find.widgetWithText(FilledButton, '표지·내지 검수용 PDF 만들기');
      expect(tester.widget<FilledButton>(generate).onPressed, isNull);
      await tester.scrollUntilVisible(find.byType(CheckboxListTile), -200);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.ensureVisible(generate);
      await tester.tap(generate);
      await tester.pumpAndSettle();
      expect(exporter.generationCalls, 1);
      expect(find.text('표지 PDF 보기·저장'), findsOneWidget);
    },
  );
  testWidgets(
    'low resolution originals block PDF generation with useful explanation',
    (tester) async {
      exporter.failure = const PrintPreflightException(
        'print_image_resolution_too_low',
        ['80ppi'],
      );
      await pump(tester);
      expect(find.textContaining('사진 해상도가 인쇄하기에 너무 낮습니다'), findsOneWidget);
      expect(find.text('표지·내지 검수용 PDF 만들기'), findsNothing);
      expect(exporter.generationCalls, 0);
    },
  );
  testWidgets('too many interior pages never enables export', (tester) async {
    when(() => orders.fetchOrderQuote(albumId: 7)).thenAnswer(
      (_) async => const OrderQuoteResult(
        pageCount: 82,
        amount: 124300,
        basePages: 20,
        basePrice: 49900,
        extraPageCount: 62,
        extraPagePrice: 1200,
        sourcePageCount: 81,
      ),
    );
    await pump(tester);
    expect(find.textContaining('80페이지 이하로 줄여주세요'), findsOneWidget);
    expect(exporter.generationCalls, 0);
    expect(find.text('표지·내지 검수용 PDF 만들기'), findsNothing);
  });
  testWidgets('missing originals during export never offers invalid PDFs', (
    tester,
  ) async {
    exporter.generationFailure = const PrintPreflightException(
      'print_original_load_failed',
      ['private-source'],
    );
    await pump(tester);
    await tester.scrollUntilVisible(find.byType(CheckboxListTile), 300);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    final generate = find.widgetWithText(FilledButton, '표지·내지 검수용 PDF 만들기');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('사진 원본을 불러오지 못했습니다'),
      -300,
    );
    expect(find.textContaining('사진 원본을 불러오지 못했습니다'), findsOneWidget);
    expect(find.text('표지 PDF 보기·저장'), findsNothing);
  });
  for (final id in [
    'REDP_200X150_SOFT',
    'REDP_200_SOFT',
    'REDP_250X200_SOFT',
    'REDP_250_SOFT',
    'REDP_300_SOFT',
  ]) {
    testWidgets('preview and export retain saved physical product $id', (
      tester,
    ) async {
      final product = PrintProduct.forId(id)!;
      final w = product.trimWidthMm, h = product.trimHeightMm;
      when(() => orders.fetchOrderQuote(albumId: 7)).thenAnswer(
        (_) async => OrderQuoteResult.fromJson({
          'pageCount': 20,
          'amount': 49900,
          'sourcePageCount': 1,
          'addedBlankPageCount': 19,
          'productCode': id,
          'printProduct': product.toJson(),
          'priceIsEstimate': true,
          'spec': {
            'id': id,
            'specVersion': '${id}_REVIEW_V2_7.22',
            'pageCount': 20,
            'interior': {'trimWidthMm': w, 'trimHeightMm': h, 'bleedMm': 5},
            'cover': {
              'widthMm': 2 * w + 17.22,
              'heightMm': h + 10,
              'front': {
                'xMm': w + 12.22,
                'yMm': 5,
                'widthMm': w,
                'heightMm': h,
              },
              'back': {'xMm': 5, 'yMm': 5, 'widthMm': w, 'heightMm': h},
            },
          },
        }),
      );
      when(() => orders.fetchPrintPreviewSnapshot(albumId: 7)).thenAnswer(
        (_) async => {
          'album': {
            'ratio': product.aspectRatio,
            'cover_layers_json': {
              'printProduct': product.toJson(),
              'pages': [
                {'index': 0, 'isCover': true, 'layers': []},
                {'index': 1, 'isCover': false, 'layers': []},
              ],
            },
          },
          'pages': [],
        },
      );
      await pump(tester);
      expect(find.text('${product.label} · 1권'), findsOneWidget);
      expect(find.textContaining('이 크기의 제작비는 추정치'), findsOneWidget);
      await tester.scrollUntilVisible(find.byType(PrintPageLayoutPreview), 250);
      final preview = tester.widget<PrintPageLayoutPreview>(
        find.byType(PrintPageLayoutPreview),
      );
      expect(preview.aspectRatio, closeTo(product.aspectRatio, .000001));
      final previewSize = tester.getSize(find.byType(PrintPageLayoutPreview));
      expect(previewSize.aspectRatio, closeTo(product.aspectRatio, .001));
      expect(exporter.verifiedSpec!.id, id);
      await tester.scrollUntilVisible(find.byType(CheckboxListTile), 250);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      final generate = find.widgetWithText(FilledButton, '표지·내지 검수용 PDF 만들기');
      await tester.ensureVisible(generate);
      await tester.tap(generate);
      await tester.pumpAndSettle();
      expect(exporter.generatedSpec!.id, id);
      expect(exporter.generatedSpec!.trimWidthMm, w);
      expect(exporter.generatedSpec!.trimHeightMm, h);
    });
  }

  testWidgets('legacy portrait never silently converts to a square book', (
    tester,
  ) async {
    when(() => orders.fetchPrintPreviewSnapshot(albumId: 7)).thenAnswer(
      (_) async => {
        'album': {
          'ratio': .75,
          'cover_layers_json': {
            'pages': [
              {'index': 0, 'isCover': true, 'layers': []},
              {'index': 1, 'isCover': false, 'layers': []},
            ],
          },
        },
        'pages': [],
      },
    );
    await pump(tester);
    expect(find.textContaining('현재 책 제작을 지원하지 않습니다'), findsOneWidget);
    expect(exporter.verifiedSpec, isNull);
    expect(find.text('표지·내지 검수용 PDF 만들기'), findsNothing);
  });

  testWidgets('stale square quote blocks a saved large square export', (
    tester,
  ) async {
    when(() => orders.fetchPrintPreviewSnapshot(albumId: 7)).thenAnswer(
      (_) async => {
        'album': {
          'ratio': 1,
          'cover_layers_json': {
            'printProduct': PrintProduct.forId('REDP_300_SOFT')!.toJson(),
            'pages': [
              {'index': 0, 'isCover': true, 'layers': []},
              {'index': 1, 'isCover': false, 'layers': []},
            ],
          },
        },
        'pages': [],
      },
    );
    await pump(tester);
    expect(find.textContaining('저장된 앨범 크기와 제작 규격이 일치하지 않습니다'), findsOneWidget);
    expect(exporter.verifiedSpec, isNull);
  });
  testWidgets(
    'hardcover without an official template shows choice and price but blocks PDF',
    (tester) async {
      final product = PrintProduct.forId('REDP_250X200_HARD')!;
      when(() => orders.fetchOrderQuote(albumId: 7)).thenAnswer(
        (_) async => OrderQuoteResult.fromJson({
          'pageCount': 20,
          'amount': 89900,
          'sourcePageCount': 1,
          'addedBlankPageCount': 19,
          'productCode': product.id,
          'printProduct': product.toJson(),
          'priceIsEstimate': true,
          'spec': null,
          'specMissing': true,
        }),
      );
      when(() => orders.fetchPrintPreviewSnapshot(albumId: 7)).thenAnswer(
        (_) async => {
          'album': {
            'ratio': product.aspectRatio,
            'cover_layers_json': {
              'printProduct': product.toJson(),
              'pages': [
                {'index': 0, 'isCover': true, 'layers': []},
                {'index': 1, 'isCover': false, 'layers': []},
              ],
            },
          },
          'pages': [],
        },
      );
      await pump(tester);
      expect(find.text('250×200mm 하드커버 · 1권'), findsOneWidget);
      expect(find.text('89,900원 예상'), findsOneWidget);
      expect(find.textContaining('표지 제작 도면을 확인하는 중입니다'), findsOneWidget);
      expect(exporter.verifiedSpec, isNull);
      expect(exporter.generationCalls, 0);
      expect(find.text('표지·내지 검수용 PDF 만들기'), findsNothing);
      await tester.scrollUntilVisible(find.byType(PrintPageLayoutPreview), 250);
      expect(
        tester.getSize(find.byType(PrintPageLayoutPreview)).aspectRatio,
        closeTo(1.25, .001),
      );
    },
  );
  testWidgets(
    'ready hardcover preview uses board ratio then interior ratio and retains hard export',
    (tester) async {
      final product = PrintProduct.forId('REDP_200X150_HARD')!;
      when(() => orders.fetchOrderQuote(albumId: 7)).thenAnswer(
        (_) async => OrderQuoteResult.fromJson({
          'pageCount': 20,
          'amount': 69900,
          'sourcePageCount': 1,
          'addedBlankPageCount': 19,
          'productCode': product.id,
          'printProduct': product.toJson(),
          'priceIsEstimate': true,
          'spec': hard.officialHardSpec(product.id),
        }),
      );
      when(() => orders.fetchPrintPreviewSnapshot(albumId: 7)).thenAnswer(
        (_) async => {
          'album': {
            'ratio': product.aspectRatio,
            'cover_layers_json': {
              'printProduct': product.toJson(),
              'pages': [
                {'index': 0, 'isCover': true, 'layers': []},
                {'index': 1, 'isCover': false, 'layers': []},
              ],
            },
          },
          'pages': [],
        },
      );
      await pump(tester);
      expect(find.text('200×150mm 하드커버 · 1권'), findsOneWidget);
      await tester.scrollUntilVisible(find.byType(PrintPageLayoutPreview), 250);
      expect(
        tester.getSize(find.byType(PrintPageLayoutPreview)).aspectRatio,
        closeTo(206 / 156, .001),
      );
      await tester.scrollUntilVisible(find.byIcon(Icons.chevron_right), 250);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      expect(
        tester.getSize(find.byType(PrintPageLayoutPreview)).aspectRatio,
        closeTo(200 / 150, .001),
      );
      await tester.scrollUntilVisible(find.byType(CheckboxListTile), 250);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      final generate = find.widgetWithText(FilledButton, '표지·내지 검수용 PDF 만들기');
      await tester.ensureVisible(generate);
      await tester.tap(generate);
      await tester.pumpAndSettle();
      expect(exporter.generatedSpec!.id, product.id);
      expect(exporter.generatedSpec!.coverBleedMm, 20);
      expect(exporter.generatedSpec!.front.width, closeTo(206, .001));
    },
  );
}
