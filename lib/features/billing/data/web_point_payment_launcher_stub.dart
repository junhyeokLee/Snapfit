import '../domain/web_point_topup.dart';

bool get hasUnresolvedWindow => false;
void confirmTerminal(WebPointTopup row) {}

void ensureSupported() =>
    throw const WebPointTopupException('web_point_checkout_closed');
Future<void> prepareSdk() async => ensureSupported();
Future<void> launch(WebPointSdkRequest request) async {
  throw const WebPointTopupException('web_point_checkout_closed');
}
