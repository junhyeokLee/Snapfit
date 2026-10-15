import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/portone_payment.dart';
import 'portone_payment_launcher_native.dart'
    if (dart.library.js_interop) 'portone_payment_launcher_web.dart'
    as platform;

/// Does not prepare orders, confirm payment, or start print production.
Future<PortOneSdkResult> launchPortOnePayment(
  BuildContext context,
  PortOnePaymentRequest request,
) => platform.launchPortOnePayment(context, request);

typedef PortOnePaymentLauncher =
    Future<PortOneSdkResult> Function(
      BuildContext context,
      PortOnePaymentRequest request,
    );
final portOnePaymentLauncherProvider = Provider<PortOnePaymentLauncher>(
  (ref) => launchPortOnePayment,
);
