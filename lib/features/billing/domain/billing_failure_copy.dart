enum BillingPurchaseKind { points }

String billingStoreUnavailableMessage() {
  return '현재 기기에서 스토어 결제를 사용할 수 없습니다. Android는 Google Play, iOS는 App Store 계정 상태를 확인해 주세요.';
}

String billingProductQueryFailureMessage(Object error) {
  final normalized = error.toString().toLowerCase();
  if (normalized.contains('network') ||
      normalized.contains('timeout') ||
      normalized.contains('connection')) {
    return '스토어 상품을 불러오지 못했어요. 네트워크 상태를 확인한 뒤 다시 시도해 주세요.';
  }
  if (normalized.contains('not found') ||
      normalized.contains('not_found') ||
      normalized.contains('unavailable') ||
      normalized.contains('product')) {
    return '스토어 상품 설정을 확인하는 중이에요. 상품이 아직 sandbox/스토어에 반영되지 않았을 수 있습니다.';
  }
  return '스토어 상품을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.';
}

String billingMissingProductsMessage(Iterable<String> missingProductIds) {
  final ids = missingProductIds.where((id) => id.trim().isNotEmpty).join(', ');
  if (ids.isEmpty) {
    return '스토어 상품 준비 중입니다. sandbox 상품 등록과 앱 설정을 확인해 주세요.';
  }
  return '스토어에서 일부 상품을 아직 찾지 못했어요. sandbox 상품 등록을 확인해 주세요: $ids';
}

String billingPurchaseStartFailureMessage({
  required BillingPurchaseKind kind,
  required Object error,
}) {
  const prefix = '포인트 결제';
  final normalized = error.toString().toLowerCase();
  if (normalized.contains('point_purchase_not_configured')) {
    return '포인트 충전을 준비하고 있어요. 잠시 후 다시 확인해 주세요. 결제는 시작되지 않았습니다.';
  }
  if (normalized.contains('network') ||
      normalized.contains('timeout') ||
      normalized.contains('connection')) {
    return '$prefix를 시작하지 못했어요. 네트워크 상태를 확인한 뒤 다시 시도해 주세요.';
  }
  if (normalized.contains('billing_unavailable') ||
      normalized.contains('storekit') ||
      normalized.contains('store unavailable')) {
    return '$prefix를 시작할 수 없는 스토어 상태예요. sandbox 계정 또는 스토어 로그인을 확인해 주세요.';
  }
  return '$prefix를 시작하지 못했어요. 잠시 후 다시 시도해 주세요.';
}

String billingPurchaseUpdateFailureMessage({String? code, String? message}) {
  final raw = '${code ?? ''} ${message ?? ''}'.toLowerCase();
  if (raw.contains('user') && raw.contains('cancel')) {
    return '결제가 취소되었습니다. 포인트는 차감되지 않았어요.';
  }
  if (raw.contains('network') ||
      raw.contains('timeout') ||
      raw.contains('connection')) {
    return '스토어 결제 상태를 확인하지 못했어요. 네트워크 상태를 확인한 뒤 구매 복원을 눌러 주세요.';
  }
  if (raw.contains('billing_unavailable') ||
      raw.contains('storekit') ||
      raw.contains('service_unavailable')) {
    return '스토어 결제 환경을 확인해 주세요. sandbox 계정, 결제 권한, 상품 등록 상태가 필요합니다.';
  }
  return '결제가 완료되지 않았어요. 포인트는 차감되지 않았습니다.';
}

String billingVerificationFailureMessage(Object error, {String? supportCode}) {
  final normalized = error.toString().toLowerCase();
  if (normalized.contains('purchase_account_') ||
      normalized.contains('purchase_owner_')) {
    return _withSupportCode(
      '구매한 계정으로 로그인한 뒤 다시 확인해 주세요. 계속 실패하면 문의 코드와 함께 고객 지원에 알려 주세요.',
      supportCode,
    );
  }
  if (normalized.contains('purchase_revoked')) {
    return _withSupportCode('취소되거나 환불된 구매여서 포인트를 충전할 수 없어요.', supportCode);
  }
  if (normalized.contains('already') ||
      normalized.contains('duplicate') ||
      normalized.contains('idempot')) {
    return _withSupportCode(
      '이미 처리된 구매예요. 포인트가 중복 충전되지 않도록 확인했습니다.',
      supportCode,
    );
  }
  if (normalized.contains('credential') ||
      normalized.contains('secret') ||
      normalized.contains('service account') ||
      normalized.contains('private key')) {
    return _withSupportCode(
      '구매 확인 서버 설정이 아직 준비되지 않았어요. 운영 설정을 확인한 뒤 다시 시도해 주세요.',
      supportCode,
    );
  }
  if (normalized.contains('receipt') ||
      normalized.contains('token') ||
      normalized.contains('transaction') ||
      normalized.contains('verify') ||
      normalized.contains('verification')) {
    return _withSupportCode(
      '구매는 접수됐지만 확인을 완료하지 못했어요. 포인트가 바로 보이지 않으면 구매 복원을 눌러 주세요.',
      supportCode,
    );
  }
  if (normalized.contains('network') ||
      normalized.contains('timeout') ||
      normalized.contains('connection')) {
    return _withSupportCode(
      '구매 확인 중 네트워크가 불안정했어요. 잠시 후 구매 복원을 눌러 주세요.',
      supportCode,
    );
  }
  return _withSupportCode(
    '구매 확인을 완료하지 못했어요. 포인트가 반영되지 않으면 구매 복원을 눌러 주세요.',
    supportCode,
  );
}

String snapfitSupportCode({required String scope, required String seed}) {
  final cleanScope = scope
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]'), '')
      .padRight(3, 'X')
      .substring(0, 3);
  var hash = 0x811C9DC5;
  for (final unit in seed.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  const alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  var value = hash;
  final buffer = StringBuffer();
  for (var i = 0; i < 4; i += 1) {
    buffer.write(alphabet[value & 31]);
    value = value >> 5;
  }
  return 'SF-$cleanScope-${buffer.toString()}';
}

String _withSupportCode(String message, String? supportCode) {
  final code = supportCode?.trim();
  if (code == null || code.isEmpty) return message;
  return '$message\n문의 코드: $code';
}
