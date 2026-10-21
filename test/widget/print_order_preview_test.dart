import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/album/presentation/views/print_order_checkout_screen.dart';
import 'package:snap_fit/features/album/presentation/views/print_order_preview_screen.dart';
import 'package:snap_fit/features/album/presentation/utils/print_photo_issue.dart';
import 'package:snap_fit/features/album/printing/album_print_exporter.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';
import 'package:snap_fit/features/profile/data/print_dev_checkout.dart';
import 'package:snap_fit/features/profile/data/print_payment_service.dart';
import 'package:snap_fit/features/profile/domain/print_checkout.dart';
import '../printing/hardcover_print_export_test.dart' as hard;

class _OrderRepo extends Mock implements OrderRepository {}

class _PreviewAuth extends AuthViewModel {
  @override
  Future<UserInfo?> build() async => const UserInfo(
    id: 'preview-fixture-owner',
    name: '테스트 고객',
    email: 'preview.owner@example.com',
    provider: 'EMAIL',
  );
}

class _EmptyPreviewRecovery extends PrintPaymentRecoveryStore {
  @override
  Future<PendingPrintPayment?> read(String owner) async => null;
}

class _Exporter extends AlbumPrintExporter {
  Object? failure;
  Object? generationFailure;
  int generationCalls = 0;
  int verificationCalls = 0;
  Map<String, dynamic> report = {
    'imageResolution': <dynamic>[],
    'blankPagesAdded': 19,
  };
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
    verificationCalls++;
    if (failure != null) throw failure!;
    return report;
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
    when(
      () => orders.printPaymentOwnerId(),
    ).thenAnswer((_) async => 'preview-fixture-owner');
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
  Future<void> pump(
    WidgetTester tester, {
    Future<bool> Function(PrintPhotoEditTarget)? onEditPhotoIssue,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(orders),
          authViewModelProvider.overrideWith(_PreviewAuth.new),
          visibleOrderOwnerProvider.overrideWithValue('preview-fixture-owner'),
          printDevAdminAccessProvider.overrideWithValue(false),
          printPaymentServiceProvider.overrideWith(
            (_) => PrintPaymentService(
              repository: orders,
              store: _EmptyPreviewRecovery(),
            ),
          ),
          printPreviewExporterProvider.overrideWithValue(exporter),
        ],
        child: MaterialApp(
          home: PrintOrderPreviewScreen(
            albumId: 7,
            albumTitle: 'Our album',
            onEditPhotoIssue: onEditPhotoIssue,
          ),
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

  Future<void> scrollPreviewTo(
    WidgetTester tester,
    Finder target,
    double delta,
  ) async {
    final native = find.byKey(const ValueKey('print-preview-details-scroll'));
    final pane = native.evaluate().isNotEmpty
        ? native
        : find.byKey(const ValueKey('web-print-preview-scroll'));
    final scrollable = find.descendant(
      of: pane,
      matching: find.byType(Scrollable),
    );
    expect(scrollable, findsOneWidget);
    await tester.scrollUntilVisible(target, delta, scrollable: scrollable);
  }

  Future<Map<String, dynamic>> photoSnapshot() async {
    final snapshot = await orders.fetchPrintPreviewSnapshot(albumId: 7);
    final album = Map<String, dynamic>.from(snapshot['album'] as Map);
    album['cover_layers_json'] = jsonEncode({
      'pages': [
        {'index': 0, 'isCover': true, 'layers': []},
        {
          'index': 1,
          'isCover': false,
          'layers': [
            {
              'id': 'photo-one',
              'type': 'image',
              'x': .1,
              'y': .1,
              'width': .5,
              'height': .5,
              'scale': 1,
              'zIndex': 0,
            },
          ],
        },
      ],
    });
    final result = {...snapshot, 'album': album};
    when(
      () => orders.fetchPrintPreviewSnapshot(albumId: 7),
    ).thenAnswer((_) async => result);
    return result;
  }

  testWidgets(
    'photo warnings reveal the reviewed page and reload after editing without export',
    (tester) async {
      final snapshot = await photoSnapshot();
      exporter.report = {
        'imageResolution': [
          {'page': 1, 'layerId': 'photo-one', 'effectivePpi': 180},
          {'page': 1, 'layerId': 'missing-photo', 'effectivePpi': 180},
          {'page': 999, 'layerId': 'photo-one', 'effectivePpi': 180},
        ],
      };
      PrintPhotoEditTarget? requested;
      await pump(
        tester,
        onEditPhotoIssue: (target) async {
          requested = target;
          exporter.report = {'imageResolution': <dynamic>[]};
          return true;
        },
      );
      expect(find.text('내지 1쪽 · 사진 1'), findsOneWidget);
      expect(find.text('현재 180ppi · 권장 300ppi'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('print-edit-photo-999-photo-one')),
        findsNothing,
      );
      final showPage = find.widgetWithText(TextButton, '페이지 보기');
      await scrollPreviewTo(tester, showPage, 250);
      await tester.pumpAndSettle();
      expect(showPage.hitTestable(), findsOneWidget);
      await tester.tap(showPage);
      await tester.pumpAndSettle();
      expect(find.text('내지 1 / 20'), findsOneWidget);
      final checkbox = find.byType(CheckboxListTile);
      await scrollPreviewTo(tester, checkbox, 250);
      await tester.pumpAndSettle();
      expect(checkbox.hitTestable(), findsOneWidget);
      await tester.tap(checkbox);
      await tester.pump();
      final edit = find.byKey(const ValueKey('print-edit-photo-1-photo-one'));
      await scrollPreviewTo(tester, edit, -250);
      await tester.pumpAndSettle();
      expect(edit.hitTestable(), findsOneWidget);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(requested?.pageIndex, 1);
      expect(requested?.layerId, 'photo-one');
      expect(requested?.reviewedRevision, printCheckoutRevision(snapshot));
      expect(exporter.verificationCalls, 2);
      expect(exporter.generationCalls, 0);
      expect(find.text('선명도를 확인할 사진'), findsNothing);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('print-continue-to-delivery')),
            )
            .onPressed,
        isNull,
      );
      verifyNever(() => orders.fetchMyOrders());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'blocking resolution failures link the exact photo while checkout stays blocked',
    (tester) async {
      await photoSnapshot();
      exporter.failure = const PrintPreflightException(
        'print_image_resolution_too_low',
        ['page:1', 'layer:photo-one', '80ppi'],
      );
      PrintPhotoEditTarget? requested;
      await pump(
        tester,
        onEditPhotoIssue: (target) async {
          requested = target;
          return false;
        },
      );
      expect(find.text('인쇄하려면 이 사진을 수정해 주세요.'), findsOneWidget);
      expect(find.text('현재 80ppi · 권장 300ppi'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('print-continue-to-delivery')),
        findsNothing,
      );
      final edit = find.byKey(const ValueKey('print-edit-photo-1-photo-one'));
      await scrollPreviewTo(tester, edit, 250);
      await tester.pumpAndSettle();
      expect(edit.hitTestable(), findsOneWidget);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(requested?.layerId, 'photo-one');
      expect(exporter.verificationCalls, 2);
      expect(exporter.generationCalls, 0);
      expect(find.text('인쇄하려면 이 사진을 수정해 주세요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'photo warning actions fit narrow large text and failed editing keeps the warning',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await photoSnapshot();
      exporter.report = {
        'imageResolution': [
          {'page': 1, 'layerId': 'photo-one', 'effectivePpi': 180},
        ],
      };
      await pump(
        tester,
        onEditPhotoIssue: (_) async => throw StateError('fixture failure'),
      );
      final edit = find.byKey(const ValueKey('print-edit-photo-1-photo-one'));
      await scrollPreviewTo(tester, edit, 250);
      await tester.pumpAndSettle();
      expect(edit.hitTestable(), findsOneWidget);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.text('사진 편집을 열지 못했어요. 앨범에서 다시 시도해 주세요.'), findsOneWidget);
      expect(find.text('내지 1쪽 · 사진 1'), findsOneWidget);
      expect(exporter.verificationCalls, 2);
      expect(exporter.generationCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

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
      await scrollPreviewTo(tester, find.byIcon(Icons.chevron_right), 300);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      expect(find.text('내지 2 / 20 · 추가 빈 페이지'), findsOneWidget);
      await scrollPreviewTo(tester, find.text('빈 페이지'), -200);
      expect(find.text('빈 페이지'), findsOneWidget);
      await scrollPreviewTo(
        tester,
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
      await scrollPreviewTo(tester, find.byType(CheckboxListTile), -200);
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
        'retailPriceStatus': 'FINAL',
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
    await scrollPreviewTo(tester, find.byType(CheckboxListTile), 300);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await openPdfTools(tester);
    final generate = find.widgetWithText(OutlinedButton, '표지·내지 검수용 PDF 만들기');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpAndSettle();
    await scrollPreviewTo(
      tester,
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
      await scrollPreviewTo(tester, find.byType(PrintPageLayoutPreview), 250);
      final preview = tester.widget<PrintPageLayoutPreview>(
        find.byType(PrintPageLayoutPreview),
      );
      expect(preview.aspectRatio, closeTo(product.aspectRatio, .000001));
      final previewSize = tester.getSize(find.byType(PrintPageLayoutPreview));
      expect(previewSize.aspectRatio, closeTo(product.aspectRatio, .001));
      expect(exporter.verifiedSpec!.id, id);
      await scrollPreviewTo(tester, find.byType(CheckboxListTile), 250);
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
        await scrollPreviewTo(
          tester,
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
      await scrollPreviewTo(tester, find.byType(PrintPageLayoutPreview), 250);
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
      await scrollPreviewTo(tester, find.byType(PrintPageLayoutPreview), 250);
      expect(
        tester.getSize(find.byType(PrintPageLayoutPreview)).aspectRatio,
        closeTo(206 / 156, .001),
      );
      await scrollPreviewTo(tester, find.byIcon(Icons.chevron_right), 250);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      expect(
        tester.getSize(find.byType(PrintPageLayoutPreview)).aspectRatio,
        closeTo(200 / 150, .001),
      );
      await scrollPreviewTo(tester, find.byType(CheckboxListTile), 250);
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
