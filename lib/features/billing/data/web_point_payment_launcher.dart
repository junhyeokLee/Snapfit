import '../domain/web_point_topup.dart';
import 'web_point_payment_launcher_stub.dart'
  if (dart.library.js_interop) 'web_point_payment_launcher_web.dart' as platform;

/// A returned window outcome is never a receipt. Call server confirm afterwards.
Future<void> launchWebPointPayment(WebPointSdkRequest request) => platform.launch(request);
void ensureWebPointPaymentSupported() => platform.ensureSupported();
Future<void> prepareWebPointPaymentSdk() => platform.prepareSdk();
