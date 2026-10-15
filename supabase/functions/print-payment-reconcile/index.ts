import { adminClient, getUser } from '../_shared/supabase.ts'
import { createPrintPaymentReconcileHandler } from '../_shared/print-payment-reconcile.ts'
import { reconcileProductionPrintPayment } from '../_shared/production-print-checkout.ts'

// Signed-JWT gateway and a current Auth admin/worker role are both required.
// A scheduler uses this endpoint; it never accepts client payment assertions.
Deno.serve(createPrintPaymentReconcileHandler({
  getUser,
  createAdminDatabase: adminClient,
  configuration: () => ({
    enabled: Deno.env.get('PRINT_PORTONE_PRODUCTION_ENABLED') === 'true',
    environment: Deno.env.get('PRINT_PORTONE_ENVIRONMENT') ?? 'disabled',
    storeId: Deno.env.get('PRINT_PORTONE_STORE_ID') ?? '',
    channelKey: Deno.env.get('PRINT_PORTONE_CHANNEL_KEY') ?? '',
    apiSecret: Deno.env.get('PRINT_PORTONE_V2_API_SECRET') ?? '',
  }),
  reconcile: async (db, configuration, payment) => {
    const intent = await reconcileProductionPrintPayment(db, configuration, payment)
    return {
      verifiedPaid: intent.status === 'PAID',
      verifiedUnpaid: intent.status === 'FAILED' || intent.status === 'CANCELED',
    }
  },
}))
