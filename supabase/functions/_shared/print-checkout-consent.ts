export const printCheckoutConsent = {
  version: 'PRINT_ORDER_CONSENT_2026_10_19', policyVersion: 'v1.0-prelaunch-20261019',
  orderReviewed: true, policyAccepted: true, customProductionAccepted: true,
  customProductionNotice: '주문 확정 후 제 앨범 내용으로 개별 제작되며, 제작이 시작되어 회복하기 어려운 중대한 손해가 예상되는 경우 단순 변심에 따른 청약철회가 제한될 수 있음을 안내받고 동의합니다. 제작 전 취소 요청과 불량·오배송 등 법정 권리는 별도로 보장됩니다.',
} as const
export function validPrintCheckoutConsent(value: unknown): boolean {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false
  const candidate = value as Record<string, unknown>
  return Object.keys(candidate).length === Object.keys(printCheckoutConsent).length &&
    Object.entries(printCheckoutConsent).every(([key, expected]) => candidate[key] === expected)
}
