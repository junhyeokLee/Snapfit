import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/commerce/data/public_print_catalog.dart';

Map<String, dynamic> _price() => {
  'productId': 'REDP_200_SOFT',
  'pageCount': 20,
  'retailPrice': 49900,
  'shippingFee': 0,
  'shippingIncluded': true,
  'priceIsEstimate': true,
  'orderCodeApproved': false,
};
Map<String, dynamic> _catalog(List<Map<String, dynamic>> prices) => {
  'generatedAt': '2026-10-19T00:00:00Z',
  'currency': 'KRW',
  'salesOpen': false,
  'items': prices,
};

void main() {
  test(
    'public prices retain retail and exact combination without inventing missing prices',
    () {
      final catalog = PublicPrintCatalog.fromJson(_catalog([_price()]));
      expect(catalog.price('REDP_200_SOFT', 20)!.retailPrice, 49900);
      expect(catalog.price('REDP_200_SOFT', 22), isNull);
      expect(catalog.price('REDP_200_HARD', 20), isNull);
    },
  );

  test(
    'invalid or live-enabled public data never becomes an offered price',
    () {
      for (final change in <Map<String, dynamic>>[
        {'retailPrice': 0},
        {'retailPrice': -1},
        {'retailPrice': 49.9},
        {'pageCount': 19},
        {'pageCount': 21},
        {'pageCount': 82},
        {'productId': 'UNREVIEWED_PRODUCT'},
        {'shippingFee': -1},
        {'shippingIncluded': false},
        {'priceIsEstimate': false},
        {'orderCodeApproved': 'true'},
      ]) {
        expect(
          () => PublicPrintCatalog.fromJson(
            _catalog([
              {..._price(), ...change},
            ]),
          ),
          throwsFormatException,
          reason: change.toString(),
        );
      }
      expect(
        () => PublicPrintCatalog.fromJson({
          ..._catalog([_price()]),
          'salesOpen': true,
        }),
        throwsFormatException,
      );
      expect(
        () => PublicPrintCatalog.fromJson({
          ..._catalog([_price()]),
          'currency': 'USD',
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'duplicates and missing catalog are rejected rather than guessing a price',
    () {
      expect(
        () => PublicPrintCatalog.fromJson(_catalog([_price(), _price()])),
        throwsFormatException,
      );
      expect(
        () => PublicPrintCatalog.fromJson(_catalog([])),
        throwsFormatException,
      );
    },
  );
}
