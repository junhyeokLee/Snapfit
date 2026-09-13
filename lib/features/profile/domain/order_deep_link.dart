/// Order links only open saved order details. Payment callbacks are retired.
String? orderDetailIdFromUri(Uri uri) {
  if (uri.scheme.toLowerCase() != 'snapfit' ||
      uri.host.toLowerCase() != 'order' ||
      uri.path.toLowerCase() != '/detail') {
    return null;
  }
  final orderId = uri.queryParameters['orderId']?.trim();
  return orderId == null || orderId.isEmpty ? null : orderId;
}
