import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';

Map<String, dynamic> _quote({String? status = 'FINAL'}) => {
  'amount': 57900,
  'pageCount': 20,
  'basePrice': 57900,
  'basePages': 20,
  'productCode': 'REDP_200_SOFT',
  if (status != null) 'retailPriceStatus': status,
  'supplierCostVerified': true,
  'shippingCostVerified': true,
  'packagingCostVerified': true,
  'priceIsEstimate': false,
  'pricePolicyVersion': 'local-confirmed-price-v1',
};

void main() {
  test(
    'FINAL server price is confirmed independently of sales availability',
    () {
      final quote = OrderQuoteResult.fromJson(_quote());
      expect(quote.retailPriceStatus, 'FINAL');
      expect(quote.amount, 57900);
      expect(quote.hasPlannedRetailPrice, isTrue);
      expect(quote.hasFinalRetailPrice, isTrue);
    },
  );

  test(
    'PLANNED never becomes final from positive price and confirmed flags',
    () {
      final quote = OrderQuoteResult.fromJson(_quote(status: 'PLANNED'));
      expect(quote.hasPlannedRetailPrice, isTrue);
      expect(quote.hasFinalRetailPrice, isFalse);
    },
  );

  test('missing legacy status can expose only a planned price', () {
    final quote = OrderQuoteResult.fromJson(_quote(status: null));
    expect(quote.retailPriceStatus, isEmpty);
    expect(quote.hasPlannedRetailPrice, isTrue);
    expect(quote.hasFinalRetailPrice, isFalse);
  });

  for (final status in ['PENDING_SUPPLIER_QUOTE', 'UNKNOWN', 'UNAPPROVED']) {
    test(
      'explicit $status hides the numeric estimate even with confirmed flags',
      () {
        final quote = OrderQuoteResult.fromJson(_quote(status: status));
        expect(quote.amount, 57900);
        expect(quote.hasPlannedRetailPrice, isFalse);
        expect(quote.hasFinalRetailPrice, isFalse);
      },
    );
  }

  for (final flag in [
    'supplierCostVerified',
    'shippingCostVerified',
    'packagingCostVerified',
  ]) {
    test('FINAL with unconfirmed $flag cannot claim finality', () {
      final quote = OrderQuoteResult.fromJson({..._quote(), flag: false});
      expect(quote.hasFinalRetailPrice, isFalse);
    });
  }

  test('zero or estimated FINAL values cannot claim a final selling price', () {
    expect(
      OrderQuoteResult.fromJson({
        ..._quote(),
        'amount': 0,
      }).hasPlannedRetailPrice,
      isFalse,
    );
    expect(
      OrderQuoteResult.fromJson({..._quote(), 'amount': 0}).hasFinalRetailPrice,
      isFalse,
    );
    expect(
      OrderQuoteResult.fromJson({
        ..._quote(),
        'priceIsEstimate': true,
      }).hasFinalRetailPrice,
      isFalse,
    );
  });
}
