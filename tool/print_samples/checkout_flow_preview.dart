import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/presentation/views/print_order_checkout_screen.dart';
import 'package:snap_fit/features/album/printing/print_vendor_spec.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/profile/domain/print_checkout.dart';

/// Local UI review only. This entry point never initializes accounts or Supabase.
const _albumId = 700001;
const _albumTitle = '우리의 순간을 담은 앨범';

Map<String, dynamic> _previewSnapshot() => {
  'album': {
    'id': _albumId,
    'title': _albumTitle,
    'ratio': 200 / 150,
    'cover_theme': 'classic',
    'cover_layers_json': {
      'printProduct': PrintProduct.forId('REDP_200X150_SOFT')!.toJson(),
      'pages': [
        {'index': 0, 'isCover': true, 'layers': []},
        for (var index = 1; index <= 20; index++)
          {'index': index, 'isCover': false, 'layers': []},
      ],
    },
  },
  'pages': <Map<String, dynamic>>[],
};

OrderQuoteResult _previewQuote() => OrderQuoteResult.fromJson({
  'pageCount': 20,
  'amount': 49900,
  'basePages': 20,
  'basePrice': 49900,
  'extraPageCount': 0,
  'extraPagePrice': 0,
  'sourcePageCount': 20,
  'addedBlankPageCount': 0,
  'productCode': 'REDP_200X150_SOFT',
  'productName': '200×150mm 소프트커버',
  'printProduct': PrintProduct.forId('REDP_200X150_SOFT')!.toJson(),
  'shippingIncluded': true,
  'priceIsEstimate': true,
  'supplierCostVerified': true,
  'shippingCostVerified': true,
  'packagingCostVerified': true,
  'retailPriceStatus': 'PLANNED',
  'pricePolicyVersion': 'PRINT_REDP_VERIFIED_COMBO_20261013_V1',
  'priceNotice': '업체 제작 견적을 반영한 기본 배송 포함 예정 판매가입니다.',
});

class _PreviewOrders extends OrderRepository {
  _PreviewOrders() : super(tokenStorage: TokenStorage());

  void _checkAlbum(int albumId) {
    if (albumId != _albumId) throw StateError('preview_album_only');
  }

  @override
  Future<OrderQuoteResult> fetchOrderQuote({
    required int albumId,
    int? pageCount,
  }) async {
    _checkAlbum(albumId);
    return _previewQuote();
  }

  @override
  Future<Map<String, dynamic>> fetchPrintPreviewSnapshot({
    required int albumId,
  }) async {
    _checkAlbum(albumId);
    return _previewSnapshot();
  }

  @override
  Future<PrintCheckoutReadiness> fetchPrintCheckoutReadiness({
    required int albumId,
    int? pageCount,
  }) async {
    _checkAlbum(albumId);
    return PrintCheckoutReadiness(
      canPay: false,
      status: 'PREPARING',
      reasonCode: 'preview_only',
      message: '정식 주문 서비스를 준비하고 있어요.',
      quote: _previewQuote(),
      environment: 'preview',
    );
  }

  @override
  Future<AddressSearchResult> searchAddress({
    required String keyword,
    int page = 1,
  }) async {
    if (keyword.trim().length < 2) {
      throw ArgumentError('검색어를 2글자 이상 입력해주세요.');
    }
    return const AddressSearchResult(
      page: 1,
      totalCount: 1,
      items: [
        AddressSearchItem(
          zipCode: '12345',
          roadAddress: '미리보기시 미리보기도로 1 (실제 주소 아님)',
          roadAddressPart1: '미리보기시 미리보기도로 1',
          roadAddressPart2: '(실제 주소 아님)',
          jibunAddress: '미리보기동 1 (실제 주소 아님)',
        ),
      ],
    );
  }

  @override
  Future<PrintPaidReceipt> fetchPrintPaidReceipt({
    required String orderId,
    required int albumId,
    required int expectedAmount,
    String? expectedPaymentId,
  }) async => throw StateError('preview_has_no_payments');
}

void main() {
  runApp(
    ProviderScope(
      overrides: [orderRepositoryProvider.overrideWithValue(_PreviewOrders())],
      child: MaterialApp(
        title: '스냅핏 주문 화면 미리보기',
        debugShowCheckedModeBanner: false,
        theme: SnapFitTheme.light(),
        builder: (context, child) => Column(
          children: [
            Material(
              color: const Color(0xFFE0F5F7),
              child: SafeArea(
                bottom: false,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: const Text(
                    '주문 화면 미리보기 · 실제 주문 아님',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF063740),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'NotoSans',
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: child!),
          ],
        ),
        home: PrintOrderCheckoutScreen(
          albumId: _albumId,
          albumTitle: _albumTitle,
          initialQuote: _previewQuote(),
          reviewedRevision: printCheckoutRevision(_previewSnapshot()),
        ),
      ),
    ),
  );
}
