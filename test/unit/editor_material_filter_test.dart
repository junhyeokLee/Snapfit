import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/shared/widgets/editor_material_filter_bar.dart';

void main() {
  final products = {
    for (final (id, price, active) in [
      ('free', 0, true),
      ('paid', 120, true),
      ('inactive', 0, false),
      ('unknown', null, true),
    ])
      id: PointShopProduct(
        productKey: id,
        kind: 'frame',
        assetId: id,
        title: id,
        pointPrice: price,
        isActive: active,
      ),
  };
  bool matches(
    String? key,
    String price, {
    String query = '',
    String label = '자수 코너 매트',
  }) => matchesEditorMaterial(
    query: query,
    price: price,
    label: label,
    productKey: key,
    products: products,
    owned: {'paid'},
  );
  test(
    'free only includes confirmed zero-price products or unpriced legacy actions',
    () {
      expect(matches('free', '무료'), isTrue);
      expect(matches(null, '무료'), isTrue);
      for (final key in ['paid', 'inactive', 'unknown', 'unregistered']) {
        expect(matches(key, '무료'), isFalse, reason: key);
      }
    },
  );
  test(
    'paid and owned are independent, so purchased paid materials still appear in both',
    () {
      expect(matches('paid', '유료'), isTrue);
      expect(matches('paid', '보유'), isTrue);
      expect(matches('free', '보유'), isFalse);
      expect(matches(null, '보유'), isFalse);
      expect(matches('unknown', '유료'), isFalse);
    },
  );
  test('search trims whitespace and preserves price restrictions', () {
    expect(matches('paid', '유료', query: ' 자수 '), isTrue);
    expect(matches('paid', '무료', query: '자수'), isFalse);
    expect(matches('free', '전체', query: '필름'), isFalse);
    expect(matches('free', '전체', query: 'linen', label: 'LINEN 사진'), isTrue);
  });
}
