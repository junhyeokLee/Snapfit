import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/profile/domain/order_deep_link.dart';

void main() {
  test('order details remain accessible from notification links', () {
    expect(
      orderDetailIdFromUri(Uri.parse('snapfit://order/detail?orderId=order-a')),
      'order-a',
    );
  });

  test('retired payment callbacks and invalid routes have no order action', () {
    for (final link in [
      'snapfit://order/success?orderId=order-a',
      'snapfit://order/fail?orderId=order-a',
      'snapfit://order/success/detail?orderId=order-a',
      'snapfit://order/detail',
      'snapfit://order/detail?orderId=%20',
      'https://order/detail?orderId=order-a',
      'snapfit://auth/detail?orderId=order-a',
    ]) {
      expect(orderDetailIdFromUri(Uri.parse(link)), isNull, reason: link);
    }
  });
}
