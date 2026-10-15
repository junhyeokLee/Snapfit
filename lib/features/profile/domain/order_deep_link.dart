/// Order links only open saved order details. Legacy success callbacks are retired.
String? orderDetailIdFromUri(Uri uri) {
  if (uri.scheme.toLowerCase() != 'snapfit' ||
      uri.host.toLowerCase() != 'order' ||
      uri.path.toLowerCase() != '/detail') {
    return null;
  }
  final orderId = uri.queryParameters['orderId']?.trim();
  return orderId == null || orderId.isEmpty ? null : orderId;
}

/// A return route only triggers recovery of an already stored invoice.
/// No payment/order ID or success flag in the URL is trusted as payment evidence.
bool isPrintPaymentReturn(Uri uri) {
  if (uri.scheme.toLowerCase() == 'snapfit') {
    return uri.host.toLowerCase() == 'payment' ||
        uri.host.isEmpty && (uri.path.isEmpty || uri.path == '/payment-return');
  }
  return {'https', 'http'}.contains(uri.scheme.toLowerCase()) &&
      uri.path == '/payment-return';
}
