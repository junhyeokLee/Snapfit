import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/print_order_request.dart';
import 'order_repository.dart';

class PrintOrderRequestRepository {
  const PrintOrderRequestRepository(this.orders);
  final OrderRepository orders;
  Future<PrintOrderRequestResult> create({
    required PrintOrderRequestTarget target,
    required String requestId,
    required String type,
    required String reason,
  }) => _call(
    {
      'action': 'create',
      'requestId': requestId,
      'type': type,
      ...target.toJson(),
      'reason': reason.trim(),
    },
    target: target,
    requestId: requestId,
  );
  Future<PrintOrderRequestResult> status({
    PrintOrderRequestTarget? target,
    String? requestId,
  }) {
    if ((target == null) == (requestId == null))
      throw const FormatException('invalid_order_request_selector');
    return _call(
      {
        'action': 'status',
        if (target != null) ...target.toJson(),
        if (requestId != null) 'requestId': requestId,
      },
      target: target,
      requestId: requestId,
    );
  }

  Future<PrintOrderRequestResult> _call(
    Map<String, dynamic> body, {
    PrintOrderRequestTarget? target,
    String? requestId,
  }) async {
    final owner = await orders.printPaymentOwnerId();
    final client = orders.supabase;
    if (client == null)
      throw const PrintOrderRequestException('request_unavailable', 503);
    try {
      final response = await client.functions.invoke(
        'print-order-request',
        body: body,
      );
      if (await orders.printPaymentOwnerId() != owner)
        throw const PrintOrderRequestException('request_owner_changed', 401);
      if (response.data is! Map)
        throw const FormatException('invalid_order_request_response');
      final result = PrintOrderRequestResult.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      if (target != null && !target.matches(result) ||
          requestId != null && result.requestId != requestId)
        throw const FormatException('order_request_identity_changed');
      return result;
    } on FunctionException catch (error) {
      final details = error.details;
      throw PrintOrderRequestException(
        details is Map
            ? '${details['error'] ?? 'request_unavailable'}'
            : 'request_unavailable',
        error.status,
      );
    }
  }
}

final printOrderRequestRepositoryProvider =
    Provider<PrintOrderRequestRepository>(
      (ref) => PrintOrderRequestRepository(ref.read(orderRepositoryProvider)),
    );
