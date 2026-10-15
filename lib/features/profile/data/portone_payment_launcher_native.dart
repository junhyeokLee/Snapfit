import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:portone_flutter/v2/model/entity/currency.dart';
import 'package:portone_flutter/v2/model/entity/payment_pay_method.dart';
import 'package:portone_flutter/v2/model/request/payment_request.dart';
import 'package:portone_flutter/v2/portone_payment.dart';

import '../domain/portone_payment.dart';

bool _requestOpen = false;

PaymentRequest buildPortOneMobilePaymentRequest(
  PortOnePaymentRequest request,
) => PaymentRequest(
  storeId: request.storeId,
  channelKey: request.channelKey,
  paymentId: request.paymentId,
  orderName: request.orderName,
  totalAmount: request.totalAmount,
  currency: Currency.KRW,
  payMethod: PaymentPayMethod.CARD,
  appScheme: request.appScheme,
);

Future<PortOneSdkResult> launchPortOnePayment(
  BuildContext context,
  PortOnePaymentRequest request,
) async {
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return const PortOneSdkResult.failed('sdk_platform_unsupported');
  }
  if (_requestOpen) {
    return const PortOneSdkResult.failed('sdk_request_in_progress');
  }
  if (!context.mounted) return const PortOneSdkResult.canceled();
  _requestOpen = true;
  try {
    final result = await Navigator.push<PortOneSdkResult>(
      context,
      MaterialPageRoute(
        builder: (_) => _PortOneTestPaymentPage(request: request),
      ),
    );
    return result ?? const PortOneSdkResult.canceled();
  } catch (_) {
    return const PortOneSdkResult.failed('sdk_unavailable');
  } finally {
    _requestOpen = false;
  }
}

class _PortOneTestPaymentPage extends StatefulWidget {
  const _PortOneTestPaymentPage({required this.request});
  final PortOnePaymentRequest request;

  @override
  State<_PortOneTestPaymentPage> createState() =>
      _PortOneTestPaymentPageState();
}

class _PortOneTestPaymentPageState extends State<_PortOneTestPaymentPage> {
  bool _finished = false;

  void _finish(PortOneSdkResult result) {
    if (!mounted || _finished) return;
    _finished = true;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return PortonePayment(
      appBar: AppBar(
        title: Text(request.environment == 'test' ? '개발 결제 테스트' : '앨범 결제'),
        leading: IconButton(
          tooltip: '결제 창 닫기',
          icon: const Icon(Icons.close),
          onPressed: () => _finish(const PortOneSdkResult.canceled()),
        ),
      ),
      initialChild: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('결제 창을 열고 있어요.'),
          ],
        ),
      ),
      data: buildPortOneMobilePaymentRequest(request),
      callback: (response) => _finish(
        PortOneSdkResult.fromCallback({
          'paymentId': response.paymentId,
          'code': response.code,
        }, request),
      ),
    );
  }
}
