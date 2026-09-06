enum BillingPurchaseKind { points, subscription }

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
  final prefix = kind == BillingPurchaseKind.points ? '포인트 결제' : '구독 결제';
  final normalized = error.toString().toLowerCase();
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

String billingVerificationFailureMessage(Object error) {
  final normalized = error.toString().toLowerCase();
  if (normalized.contains('already') ||
      normalized.contains('duplicate') ||
      normalized.contains('idempot')) {
    return '이미 처리된 구매예요. 포인트가 중복 충전되지 않도록 확인했습니다.';
  }
  if (normalized.contains('credential') ||
      normalized.contains('secret') ||
      normalized.contains('service account') ||
      normalized.contains('private key')) {
    return '구매 확인 서버 설정이 아직 준비되지 않았어요. 운영 설정을 확인한 뒤 다시 시도해 주세요.';
  }
  if (normalized.contains('receipt') ||
      normalized.contains('token') ||
      normalized.contains('transaction') ||
      normalized.contains('verify') ||
      normalized.contains('verification')) {
    return '구매는 접수됐지만 확인을 완료하지 못했어요. 포인트가 바로 보이지 않으면 구매 복원을 눌러 주세요.';
  }
  if (normalized.contains('network') ||
      normalized.contains('timeout') ||
      normalized.contains('connection')) {
    return '구매 확인 중 네트워크가 불안정했어요. 잠시 후 구매 복원을 눌러 주세요.';
  }
  return '구매 확인을 완료하지 못했어요. 포인트가 반영되지 않으면 구매 복원을 눌러 주세요.';
}
