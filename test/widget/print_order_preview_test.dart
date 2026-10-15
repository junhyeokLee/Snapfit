import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/album/presentation/views/print_order_checkout_screen.dart';
import 'package:snap_fit/features/album/presentation/views/print_order_preview_screen.dart';
import 'package:snap_fit/features/album/printing/album_print_exporter.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/profile/domain/print_checkout.dart';
import '../printing/hardcover_print_export_test.dart' as hard;

class _OrderRepo extends Mock implements OrderRepository {}

class _Exporter extends AlbumPrintExporter {
  Object? failure;
  Object? generationFailure;
  int generationCalls = 0;
  int coverBytes = 5;
  int interiorBytes = 5;
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
      coverPdf: Uint8List(coverBytes),
      interiorPdf: Uint8List(interiorBytes),
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
    when(() => orders.fetchPrintCheckoutReadiness(albumId: 7)).thenAnswer(
      (_) async => PrintCheckoutReadiness(
        canPay: false,
        status: 'PREPARING',
        reasonCode: 'print_sales_not_ready',
        message: '정식 주문을 준비하고 있어요.',
        quote: await orders.fetchOrderQuote(albumId: 7),
      ),
    );
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

  Future<void> openPdfTools(WidgetTester tester) async {
    final tools = find.byKey(const ValueKey('print-review-pdf-tools'));
    await tester.ensureVisible(tools);
    await tester.tap(find.text('검수용 PDF 보기·저장'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'reviewed album moves directly to delivery without exporting PDFs or creating an order',
    (tester) async {
      when(() => orders.fetchPrintCheckoutReadiness(albumId: 7)).thenAnswer(
        (_) async => PrintCheckoutReadiness(
          canPay: false,
          status: 'PREPARING',
          reasonCode: 'print_sales_not_ready',
          message: '정식 주문 서비스를 준비하고 있어요.',
          quote: await orders.fetchOrderQuote(albumId: 7),
        ),
      );
      await pump(tester);
      final next = find.byKey(const ValueKey('print-continue-to-delivery'));
      await tester.ensureVisible(next);
      expect(tester.widget<FilledButton>(next).onPressed, isNull);
      expect(find.text('표지·내지 검수용 PDF 만들기'), findsNothing);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.byType(PrintOrderCheckoutScreen), findsOneWidget);
      expect(find.text('배송지 입력'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('print-recipient-name')),
        findsOneWidget,
      );
      expect(exporter.generationCalls, 0);
      verifyNever(() => orders.fetchMyOrders());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unverified server estimate stays hidden while square preview remains available',
    (tester) async {
      await pump(tester);
      expect(find.text('견적 확인 중'), findsOneWidget);
      expect(find.textContaining('49,900원'), findsNothing);
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
        find.widgetWithText(FilledButton, '배송지 입력하기'),
        300,
      );
      final disabledPayment = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '배송지 입력하기'),
      );
      expect(disabledPayment.onPressed, isNull);
      expect(find.textContaining('영업일 5~6일'), findsOneWidget);
      expect(find.textContaining('택배 배송 기간 별도'), findsOneWidget);
      expect(find.textContaining('주문번호 스티커'), findsOneWidget);
      await openPdfTools(tester);
      final generate = find.widgetWithText(OutlinedButton, '표지·내지 검수용 PDF 만들기');
      expect(tester.widget<OutlinedButton>(generate).onPressed, isNull);
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
    'preview uses the FINAL checkout price and approved geometry rather than legacy planned quote',
    (tester) async {
      final legacy = await orders.fetchOrderQuote(albumId: 7);
      final finalSpec = {
        ...legacy.printSpec,
        'specVersion': 'APPROVED_FINAL_V9',
        'verified': true,
      };
      final finalQuote = OrderQuoteResult.fromJson({
        'pageCount': 20,
        'amount': 52900,
        'basePages': 20,
        'basePrice': 52900,
        'sourcePageCount': 1,
        'addedBlankPageCount': 19,
        'priceIsEstimate': false,
        'supplierCostVerified': true,
        'shippingCostVerified': true,
        'packagingCostVerified': true,
        'shippingIncluded': true,
        'productCode': 'REDP_200_SOFT',
        'spec': finalSpec,
      });
      final snapshot = await orders.fetchPrintPreviewSnapshot(albumId: 7);
      when(() => orders.fetchPrintCheckoutReadiness(albumId: 7)).thenAnswer(
        (_) async => PrintCheckoutReadiness(
          canPay: true,
          status: 'READY',
          reasonCode: '',
          message: '',
          quote: finalQuote,
          reviewedRevision: printCheckoutRevision(snapshot),
          reviewedSpecRevision: printSpecRevision(finalSpec),
        ),
      );
      clearInteractions(orders);
      await pump(tester);
      expect(exporter.verifiedSpec?.specVersion, 'APPROVED_FINAL_V9');
      expect(exporter.generationCalls, 0);
      expect(find.text('52,900원'), findsOneWidget);
      expect(find.text('52,900원 예정'), findsNothing);
      expect(find.textContaining('현재 주문·결제는 준비 중'), findsNothing);
      verifyNever(() => orders.fetchOrderQuote(albumId: 7));
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      final next = find.byKey(const ValueKey('print-continue-to-delivery'));
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.byType(PrintOrderCheckoutScreen), findsOneWidget);
    },
  );
  testWidgets(
    'a changed server review revision blocks a mixed snapshot before exporter verification',
    (tester) async {
      final quote = await orders.fetchOrderQuote(albumId: 7);
      when(() => orders.fetchPrintCheckoutReadiness(albumId: 7)).thenAnswer(
        (_) async => PrintCheckoutReadiness(
          canPay: false,
          status: 'PREPARING',
          reasonCode: '',
          message: '',
          quote: quote,
          reviewedRevision: 'changed',
        ),
      );
      await pump(tester);
      expect(exporter.verifiedSpec, isNull);
      expect(find.textContaining('앨범 내용이나 인쇄 규격이 바뀌었어요'), findsOneWidget);
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
  testWidgets(
    'production preview does not render and discard a PDF before frozen checkout',
    (tester) async {
      final quote = await orders.fetchOrderQuote(albumId: 7);
      when(() => orders.fetchPrintCheckoutReadiness(albumId: 7)).thenAnswer(
        (_) async => PrintCheckoutReadiness(
          canPay: true,
          status: 'READY',
          reasonCode: '',
          message: '',
          quote: quote,
        ),
      );
      exporter.generationFailure = StateError(
        'must_generate_from_frozen_checkout',
      );
      await pump(tester);
      expect(exporter.generationCalls, 0);
      expect(
        find.byKey(const ValueKey('print-continue-to-delivery')),
        findsOneWidget,
      );
      expect(
        find.textContaining('must_generate_from_frozen_checkout'),
        findsNothing,
      );
    },
  );
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
    await openPdfTools(tester);
    final generate = find.widgetWithText(OutlinedButton, '표지·내지 검수용 PDF 만들기');
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
      expect(find.text('견적 확인 중'), findsOneWidget);
      expect(find.textContaining('제작 견적을 확인한 뒤 판매가를 안내'), findsOneWidget);
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
      await openPdfTools(tester);
      final generate = find.widgetWithText(OutlinedButton, '표지·내지 검수용 PDF 만들기');
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

  for (final item in [
    ('REDP_200X150_SOFT', 20, 49900),
    ('REDP_300_HARD', 80, 159900),
  ]) {
    testWidgets(
      'exact planned retail ${item.$1} ${item.$2} pages uses the server notice without guessed extra-page prices',
      (tester) async {
        final product = PrintProduct.forId(item.$1)!;
        final isHard = item.$1.endsWith('_HARD');
        final notice = isHard
            ? '배송·포장 비용은 최종 확인 후 확정됩니다.'
            : '업체 제작 견적을 확인한 기본 배송 포함 예정 판매가입니다.';
        final spec = isHard
            ? <String, dynamic>{
                ...hard.officialHardSpec(item.$1),
                'pageCount': 80,
                'spineMm': 29.2,
                'cover': {
                  'construction': 'casewrap',
                  'bleedMm': 20,
                  'widthMm': 681.2,
                  'heightMm': 346,
                  'front': {
                    'xMm': 355.2,
                    'yMm': 20,
                    'widthMm': 306,
                    'heightMm': 306,
                  },
                  'back': {
                    'xMm': 20,
                    'yMm': 20,
                    'widthMm': 306,
                    'heightMm': 306,
                  },
                  'trim': {
                    'xMm': 20,
                    'yMm': 20,
                    'widthMm': 641.2,
                    'heightMm': 306,
                  },
                },
              }
            : <String, dynamic>{
                'id': item.$1,
                'specVersion': 'review-soft-20',
                'pageCount': 20,
                'interior': {
                  'trimWidthMm': 200,
                  'trimHeightMm': 150,
                  'bleedMm': 5,
                },
                'cover': {
                  'widthMm': 417.22,
                  'heightMm': 160,
                  'front': {
                    'xMm': 212.22,
                    'yMm': 5,
                    'widthMm': 200,
                    'heightMm': 150,
                  },
                  'back': {'xMm': 5, 'yMm': 5, 'widthMm': 200, 'heightMm': 150},
                },
              };
        when(() => orders.fetchOrderQuote(albumId: 7)).thenAnswer(
          (_) async => OrderQuoteResult.fromJson({
            'pageCount': item.$2,
            'amount': item.$3,
            'basePages': item.$2,
            'basePrice': item.$3,
            'extraPageCount': 0,
            'sourcePageCount': 1,
            'addedBlankPageCount': item.$2 - 1,
            'productCode': product.id,
            'printProduct': product.toJson(),
            'supplierCostVerified': true,
            'shippingCostVerified': !isHard,
            'packagingCostVerified': !isHard,
            'shippingIncluded': true,
            'priceIsEstimate': true,
            'priceNotice': notice,
            'spec': spec,
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
        expect(
          find.text('${isHard ? '159,900' : '49,900'}원 예정'),
          findsOneWidget,
        );
        expect(find.text(notice), findsOneWidget);
        expect(find.text('견적 확인 중'), findsNothing);
        expect(find.textContaining('기본 20페이지'), findsNothing);
        expect(find.textContaining('309,900원'), findsNothing);
        await tester.scrollUntilVisible(
          find.widgetWithText(FilledButton, '배송지 입력하기'),
          300,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, '배송지 입력하기'),
              )
              .onPressed,
          isNull,
        );
      },
    );
  }

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
    'hardcover without an official template shows choice and pending quote but blocks PDF',
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
      expect(find.text('견적 확인 중'), findsOneWidget);
      expect(find.textContaining('89,900원'), findsNothing);
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
      await openPdfTools(tester);
      final generate = find.widgetWithText(OutlinedButton, '표지·내지 검수용 PDF 만들기');
      await tester.ensureVisible(generate);
      await tester.tap(generate);
      await tester.pumpAndSettle();
      expect(exporter.generatedSpec!.id, product.id);
      expect(exporter.generatedSpec!.coverBleedMm, 20);
      expect(exporter.generatedSpec!.front.width, closeTo(206, .001));
    },
  );
}
