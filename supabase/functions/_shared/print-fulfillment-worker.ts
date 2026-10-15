import { assertPrintWorker, PrintWorkerAuthError, type PrintWorkerUserLookup } from './print-worker-auth.ts'
import { OrderPaymentError, type OrderRow } from './order-types.ts'
import { getPrintSpec, PRINT_BUCKET, PRINT_MAX_PDF_BYTES, sourceFingerprint, calculateContribution, sha256 } from './print-contract.ts'
import { getPrintSnapshot, createPrintUploads, finalizePrintPackage, type PdfInspector } from './print-package.ts'
import { downloadPrepaymentPdf } from './print-prepayment-package.ts'
import { createPrintFileDeliveryUrl, readPrintFileDelivery, type PrintFileKind } from './print-file-delivery.ts'
import { assertFulfillmentAssetSources } from './print-fulfillment-assets.ts'
import { orderAcceptance, RedprintingError, type RedprintingSettings } from './redprinting.ts'
import { customerOrderPayload, nextSupplierPoll, supplierProgress, type FulfillmentVendor } from './print-fulfillment-vendor.ts'
import { queryPortOnePrintPayment, PortOnePrintPaymentError, type ExpectedPortOnePrintPayment, type PortOnePrintPaymentObservation } from './portone-print-payment.ts'

type Db = any
export type FulfillmentClaim = {
  job: { id: string; order_id: string; event_type: 'RENDER'|'SUBMIT'|'CONFIRM'|'POLL'; state: 'CLAIMED'; lease_owner: string; lease_until: string;
    payload: { vendorOrderNum: string; vendorOrderSeq: number; queryOnly?: boolean; depositAttempted?: boolean }; attempts: number }
  order: OrderRow; approvedSpec: Record<string, any>; orderCode: string; sourceFingerprint: string;
  allowedAssetOwners: string[]; paymentEnvironment: 'live'; paymentExpectation: ExpectedPortOnePrintPayment; costSnapshot: Record<string, any>; approvalCurrent: boolean
}
export type FulfillmentConfiguration = { enabled: boolean; environment: string; depositEnabled: boolean; vendorReady: boolean; supabaseUrl: string; paymentApiSecret: string; deliverySecret?: string }
type Dependencies = {
  getUser: PrintWorkerUserLookup; createAdminDatabase: () => Db; configuration: () => FulfillmentConfiguration;
  vendor: (db: Db) => FulfillmentVendor; sender: (db: Db) => Promise<RedprintingSettings>;
  inspectPdf?: PdfInspector; now?: () => number;
  paymentLookup?: (expectation: ExpectedPortOnePrintPayment) => Promise<PortOnePrintPaymentObservation>
}
const uuid = (value: unknown): value is string => typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
const check = <T>(result: { data: T; error?: unknown }): T => { if (result.error) throw new OrderPaymentError('print_worker_database_unavailable', 503); return result.data }
const safeCode = (error: unknown): string => {
  const code = error instanceof PortOnePrintPaymentError || error instanceof RedprintingError ? error.code : error instanceof OrderPaymentError ? error.message : 'print_worker_unavailable'
  return /^[a-z0-9_]{1,80}$/.test(code) ? code : 'print_worker_unavailable'
}
const terminalCode = (code: string) => /^(?:payment_(?:reversed|not_paid|cancellation_review_required|amount_mismatch|channel_mismatch|environment_mismatch)|frozen_print_spec_|print_spec_approval_revoked|print_asset_access_requires_review|print_margin_below_minimum|supplier_file_error|supplier_order_canceled|supplier_price_changed|direct_shipping_confirmation_required)/.test(code)

/** No client can supply a paid snapshot, supplier specification or charge amount. */
export class PrintFulfillmentWorker {
  constructor(private db: Db, private config: FulfillmentConfiguration, private vendor: FulfillmentVendor,
    private sender: () => Promise<RedprintingSettings>, private options: { inspectPdf?: PdfInspector; now?: () => number;
      paymentLookup?: Dependencies['paymentLookup']; assetFetch?: typeof fetch } = {}) {}
  private now() { return this.options.now?.() ?? Date.now() }
  private async rpc<T>(name: string, args: Record<string, unknown>): Promise<T> { return check<T>(await this.db.rpc(name, args)) }
  private enabled() {
    if (!this.runtimeReady()) throw new OrderPaymentError('print_production_disabled', 503)
  }
  get runtimeEnabled() { return this.runtimeReady() }
  private runtimeReady() {
    return this.config.enabled === true && this.config.environment === 'live' && this.config.depositEnabled === true &&
      this.config.vendorReady === true && /^[\x21-\x7e]{8,2048}$/.test(this.config.paymentApiSecret)
  }
  async claim(owner: string): Promise<FulfillmentClaim|null> {
    // Claim also records the authenticated runner heartbeat when sales are closed.
    const claim = await this.rpc<FulfillmentClaim|null>('claim_print_fulfillment_job', { p_worker_id: owner, p_limit: 1, p_lease_seconds: 120,
      p_runtime_ready: this.runtimeReady() })
    if (claim) this.checkedClaim(claim, owner)
    return claim
  }
  async renew(id: string, owner: string) {
    const leaseUntil = await this.rpc<string|null>('renew_print_fulfillment_job', { p_id: id, p_owner: owner, p_lease_seconds: 120,
      p_runtime_ready: this.runtimeReady() })
    if (!leaseUntil) throw new OrderPaymentError('print_production_disabled', 503)
    return { leaseUntil }
  }
  async overview(orderId?: string) {
    return this.rpc<any[]>('list_print_fulfillment_jobs', { p_limit: 50, p_order_id: orderId ?? null })
  }
  private checkedClaim(claim: FulfillmentClaim, owner: string) {
    const leaseUntil = Date.parse(claim?.job?.lease_until ?? '')
    const packageLeaseUntil = Date.parse(String(claim?.order?.print_package_lock_until ?? ''))
    if (!claim || !uuid(claim.job?.id) || claim.job.state !== 'CLAIMED' || claim.job.lease_owner !== owner ||
        !Number.isFinite(leaseUntil) || leaseUntil <= this.now() || claim.order?.checkout_flow !== 'PORTONE_V2_V1' ||
        claim.order.order_id !== claim.job.order_id || claim.order.payment_reversed_at || claim.paymentEnvironment !== 'live' ||
        claim.order.print_package_lock_token !== owner || !Number.isFinite(packageLeaseUntil) || packageLeaseUntil <= this.now() ||
        claim.paymentExpectation?.environment !== 'live' || claim.paymentExpectation.paymentId !== claim.order.verified_payment_id ||
        claim.paymentExpectation.amount !== claim.order.amount || claim.paymentExpectation.currency !== 'KRW' ||
        !Array.isArray(claim.allowedAssetOwners) || claim.allowedAssetOwners.some(value => !uuid(value)) ||
        !/^SFO_[0-9a-f]{32}$/.test(claim.job.payload?.vendorOrderNum ?? '') || claim.job.payload.vendorOrderSeq !== 1 ||
        typeof claim.orderCode !== 'string' || !/^[A-Za-z0-9_-]{1,100}$/.test(claim.orderCode)) {
      throw new OrderPaymentError('invalid_print_worker_claim', 503)
    }
    if (JSON.stringify(getPrintSpec(claim.order)) !== JSON.stringify(claim.approvedSpec)) throw new OrderPaymentError('frozen_print_spec_mismatch', 409)
  }
  private async current(id: string, owner: string) {
    this.enabled()
    const claim = await this.rpc<FulfillmentClaim>('get_print_fulfillment_job', { p_id: id, p_owner: owner })
    this.checkedClaim(claim, owner)
    return claim
  }
  private async freshPayment(claim: FulfillmentClaim) {
    const observed = await (this.options.paymentLookup?.(claim.paymentExpectation) ??
      queryPortOnePrintPayment(claim.paymentExpectation, { apiSecret: this.config.paymentApiSecret }))
    if (observed.environment !== 'live' || observed.isTest !== false || observed.status !== 'PAID' ||
        observed.paymentId !== claim.order.verified_payment_id || observed.amount !== claim.order.amount ||
        observed.storeId !== claim.paymentExpectation.storeId || observed.channelKey !== claim.paymentExpectation.channelKey) {
      throw new OrderPaymentError('payment_environment_mismatch', 409)
    }
  }
  private async assertApproval(claim: FulfillmentClaim, owner: string) {
    if (claim.approvalCurrent !== true) {
      await this.fail(claim.job.id, owner, 'print_spec_approval_revoked', true)
      throw new OrderPaymentError('print_spec_approval_revoked', 409)
    }
  }
  async snapshot(id: string, owner: string) {
    const claim = await this.current(id, owner)
    if (claim.job.event_type !== 'RENDER') throw new OrderPaymentError('print_worker_stage_changed', 409)
    await this.assertApproval(claim, owner)
    assertFulfillmentAssetSources(claim.order.print_content_snapshot, this.config.supabaseUrl, claim.allowedAssetOwners)
    return getPrintSnapshot(this.db, claim.order, this.config.supabaseUrl, { allowedAssetOwners: claim.allowedAssetOwners })
  }
  async uploads(id: string, owner: string) {
    const claim = await this.current(id, owner)
    if (claim.job.event_type !== 'RENDER') throw new OrderPaymentError('print_worker_stage_changed', 409)
    await this.assertApproval(claim, owner)
    return createPrintUploads(this.db, claim.order, { owner })
  }
  private async patch(claim: FulfillmentClaim, owner: string, patch: Record<string, unknown>) {
    const result = await this.db.from('orders').update(patch).eq('order_id', claim.order.order_id)
      .eq('checkout_flow', 'PORTONE_V2_V1').eq('print_package_lock_token', owner)
      .gt('print_package_lock_until', new Date(this.now()).toISOString()).is('payment_reversed_at', null)
      .eq('status', claim.order.status).eq('print_fulfillment_status', claim.order.print_fulfillment_status).select().maybeSingle()
    const row = check<OrderRow|null>(result)
    if (!row) throw new OrderPaymentError('print_worker_lease_lost', 409)
    claim.order = row
    return row
  }
  private async finish(claim: FulfillmentClaim, owner: string, result: Record<string, unknown>) {
    const job = await this.rpc<any>('finish_print_fulfillment_job', {
      p_id: claim.job.id, p_owner: owner, p_expected_stage: claim.job.event_type, p_result: result,
    })
    return { jobId: job.id, stage: job.event_type, state: job.state, customerStage: result.customerStage, availableAt: job.available_at }
  }
  async fail(id: string, owner: string, code: string, terminal = false, supplier = false) {
    return this.rpc<any>('fail_print_fulfillment_job', { p_id: id, p_owner: owner, p_error_code: code,
      p_available_at: supplier ? nextSupplierPoll(this.now()) : new Date(this.now() + 60_000).toISOString(), p_terminal: terminal })
  }
  async finalized(id: string, owner: string, uploadId: string, manifest: Record<string, unknown>) {
    const claim = await this.current(id, owner)
    if (claim.job.event_type !== 'RENDER') throw new OrderPaymentError('print_worker_stage_changed', 409)
    await this.assertApproval(claim, owner)
    const order = await finalizePrintPackage(this.db, claim.order, { uploadId, manifest }, this.options.inspectPdf, { owner })
    claim.order = order
    // The frozen FINAL product was released only after supplier file/sample and
    // exact template approval. The server preflight still checks each new PDF.
    if (!['REVIEW_REQUIRED', 'READY'].includes(String(order.print_fulfillment_status))) throw new OrderPaymentError('print_files_not_ready', 409)
    if (order.print_fulfillment_status !== 'READY') await this.patch(claim, owner, {
      print_fulfillment_status: 'READY', print_spec_confirmed_at: new Date(this.now()).toISOString(),
    })
    return this.finish(claim, owner, { nextStage: 'SUBMIT', queryOnly: false, customerStage: 'FILE_CHECKING' })
  }
  private costs(claim: FulfillmentClaim, printCost: number) {
    const cost = claim.costSnapshot, confirmation = cost?.fulfillmentConfirmation
    if (!cost || printCost !== cost.estimatedPrintCost) throw new OrderPaymentError('supplier_price_changed', 409)
    if (confirmation?.senderName !== '스냅핏' || confirmation?.senderLabelConfirmed !== true || confirmation?.priceSlipOmittedConfirmed !== true ||
        confirmation?.promotionalMaterialsOmittedConfirmed !== true || typeof confirmation.evidence !== 'string' || confirmation.evidence.trim().length < 10) {
      throw new OrderPaymentError('direct_shipping_confirmation_required', 409)
    }
    return { ...calculateContribution({ ...claim.order, print_cost_snapshot: cost }, {
      actualPrintCost: printCost, actualShippingCost: cost.estimatedShippingCost, actualPackagingCost: cost.estimatedPackagingCost,
    }), fulfillment_confirmation: { ...confirmation } }
  }
  private async fileLinks(claim: FulfillmentClaim) {
    const manifest = claim.order.print_manifest as any, spec = getPrintSpec(claim.order), fingerprint = await sourceFingerprint(claim.order)
    if (manifest?.sourceFingerprint !== fingerprint || manifest?.spec?.specVersion !== spec.specVersion ||
        !claim.order.print_upload_id || !manifest.cover?.sha256 || !manifest.interior?.sha256) throw new OrderPaymentError('print_preflight_failed', 409)
    const urls: Record<string, string> = {}
    const transport = manifest.fileTransport
    if (transport !== undefined && (!transport || Array.isArray(transport) || typeof transport !== 'object' ||
        !['DIRECT_V1', 'CHUNKED_V1'].includes(transport.version) || !transport.files || Array.isArray(transport.files) ||
        typeof transport.files !== 'object' || Object.keys(transport.files).some(kind => !['cover', 'interior'].includes(kind)))) {
      throw new OrderPaymentError('print_preflight_failed', 409)
    }
    for (const kind of ['cover', 'interior'] as PrintFileKind[]) {
      const path = `${claim.order.order_id}/${claim.order.print_upload_id}/${kind}.pdf`
      if (claim.order[kind === 'cover' ? 'print_cover_pdf_path' : 'print_interior_pdf_path'] !== path) throw new OrderPaymentError('print_preflight_failed', 409)
      const parts = transport?.files?.[kind]
      if (parts !== undefined && (!Array.isArray(parts) || transport.version !== 'CHUNKED_V1')) throw new OrderPaymentError('print_preflight_failed', 409)
      if (parts?.length) {
        if (typeof claim.order.order_id !== 'string' || typeof claim.order.print_upload_id !== 'string') throw new OrderPaymentError('print_preflight_failed', 409)
        const reference = { orderId: claim.order.order_id, packageId: claim.order.print_upload_id, kind, sha256: manifest[kind].sha256 }
        const file = await readPrintFileDelivery(this.db, reference)
        if (Object.keys(file.result).some(key => file.result[key as keyof typeof file.result] !== manifest[kind][key]) ||
            parts.length !== file.parts.length || file.parts.some((part, index) => Object.keys(part).some(key =>
              part[key as keyof typeof part] !== parts[index]?.[key]) || Object.keys(parts[index] ?? {}).length !== 4)) {
          throw new OrderPaymentError('print_preflight_failed', 409)
        }
        urls[kind] = await createPrintFileDeliveryUrl(reference, { supabaseUrl: this.config.supabaseUrl,
          secret: this.config.deliverySecret ?? '', now: this.now() })
        continue
      }
      if (this.options.assetFetch) {
        const bytes=await downloadPrepaymentPdf(this.db,path,manifest[kind].byteLength,this.config.supabaseUrl,this.options.assetFetch)
        if(await sha256(bytes)!==manifest[kind].sha256)throw new OrderPaymentError('print_preflight_failed',409)
      } else {
        const file = check<any>(await this.db.storage.from(PRINT_BUCKET).download(path))
        if (!file || file.size > PRINT_MAX_PDF_BYTES || file.size !== manifest[kind].byteLength ||
            await sha256(new Uint8Array(await file.arrayBuffer())) !== manifest[kind].sha256) throw new OrderPaymentError('print_preflight_failed', 409)
      }
      const signed = check<any>(await this.db.storage.from(PRINT_BUCKET).createSignedUrl(path, 3600))
      if (!signed?.signedUrl) throw new OrderPaymentError('print_asset_signing_failed', 503)
      urls[kind] = signed.signedUrl
    }
    return urls as { cover: string; interior: string }
  }
  private async accepted(claim: FulfillmentClaim, owner: string) {
    if (claim.order.print_fulfillment_status === 'READY') {
      const price = await this.vendor.price(claim.orderCode)
      const costs = this.costs(claim, price.totalPrice)
      // This RPC locks the same active outbox lease before atomically storing
      // procurement costs and the supplier's confirmed stable order identity.
      claim.order = await this.rpc<OrderRow>('commit_print_fulfillment_submission', { p_id: claim.job.id, p_owner: owner,
        p_vendor_order_id: claim.job.payload.vendorOrderNum, p_operations_patch: costs })
    } else if (!['SUBMITTED', 'ACCEPTED'].includes(String(claim.order.print_fulfillment_status))) {
      throw new OrderPaymentError('print_files_not_ready', 409)
    }
  }
  private async observe(claim: FulfillmentClaim, owner: string, allowConfirm: boolean) {
    const status = await this.vendor.status(claim.job.payload.vendorOrderNum, 1), progress = supplierProgress(status)
    await this.accepted(claim, owner)
    if (progress.canceled) throw new OrderPaymentError('supplier_order_canceled', 409)
    if (progress.needsAttention) throw new OrderPaymentError('supplier_file_error', 409)
    // A cancellation review cannot undo physical manufacture. Once production
    // was independently recorded, polling must keep actual tracking visible
    // even when the payment later needs review. New financial calls still
    // require a fresh LIVE receipt in SUBMIT/CONFIRM.
    const trackingOnly = claim.job.event_type === 'POLL' && Boolean(claim.order.print_accepted_at) &&
      ['IN_PRODUCTION', 'PRINTING', 'SHIPPING'].includes(String(claim.order.status))
    if (progress.productionStarted && !trackingOnly) await this.freshPayment(claim)
    if (progress.fileChecked && !claim.order.print_file_checked_at) await this.patch(claim, owner, { print_file_checked_at: new Date(this.now()).toISOString() })
    if (progress.productionStarted && claim.order.print_fulfillment_status === 'SUBMITTED') await this.patch(claim, owner, {
      status: 'IN_PRODUCTION', print_fulfillment_status: 'ACCEPTED', print_accepted_at: new Date(this.now()).toISOString(),
    })
    if (progress.shipped && claim.order.status !== 'SHIPPING') await this.patch(claim, owner, {
      status: 'SHIPPING', courier: status.courier, tracking_number: status.trackingNumber, shipped_at: new Date(this.now()).toISOString(),
    })
    const depositProcessingOrPaid = ['PGS_11', 'PGS_12'].includes(status.statusCodeOrg)
    const nextStage = allowConfirm && claim.approvalCurrent === true && progress.fileChecked && !progress.productionStarted && !depositProcessingOrPaid &&
      !claim.job.payload.depositAttempted && this.config.depositEnabled ? 'CONFIRM' : 'POLL'
    return this.finish(claim, owner, { nextStage, queryOnly: false, supplierStatus: status.statusCode,
      customerStage: progress.shipped ? 'SHIPPING' : progress.productionStarted ? 'PRODUCTION' : 'FILE_CHECKING',
      availableAt: nextStage === 'CONFIRM' ? new Date(this.now()).toISOString() : nextSupplierPoll(this.now()),
      ...(progress.fileChecked ? { fileCheckedAt: claim.order.print_file_checked_at } : {}),
    })
  }
  async advance(id: string, owner: string) {
    const claim = await this.current(id, owner)
    try {
      if (claim.job.event_type === 'SUBMIT') {
        if (claim.job.payload.queryOnly) return await this.observe(claim, owner, true)
        if (claim.approvalCurrent !== true) throw new OrderPaymentError('print_spec_approval_revoked', 409)
        await this.freshPayment(claim)
        const price = await this.vendor.price(claim.orderCode)
        this.costs(claim, price.totalPrice)
        const files = await this.fileLinks(claim)
        const payload = customerOrderPayload(claim.order, await this.sender(), claim.job.payload.vendorOrderNum, claim.orderCode, files)
        if ((await this.current(id, owner)).approvalCurrent !== true) throw new OrderPaymentError('print_spec_approval_revoked', 409)
        await this.rpc('record_print_fulfillment_attempt', { p_id: id, p_owner: owner, p_vendor_order_num: claim.job.payload.vendorOrderNum, p_vendor_order_seq: 1 })
        const acceptance = orderAcceptance(await this.vendor.submit(payload), claim.job.payload.vendorOrderNum, 1)
        if (!acceptance.accepted && !acceptance.acknowledged) throw new OrderPaymentError('supplier_submission_unknown', 503)
        // A summary acknowledges only the request. The immediate matching
        // status lookup confirms receipt and recovers file/production facts;
        // HTTP 200 alone never marks acceptance, analysis or manufacture.
        return await this.observe(claim, owner, true)
      }
      if (claim.job.event_type === 'CONFIRM') {
        const status = await this.vendor.status(claim.job.payload.vendorOrderNum, 1), progress = supplierProgress(status)
        if (progress.canceled) throw new OrderPaymentError('supplier_order_canceled', 409)
        if (progress.needsAttention) throw new OrderPaymentError('supplier_file_error', 409)
        if (claim.job.payload.queryOnly || claim.job.payload.depositAttempted || progress.productionStarted ||
            ['PGS_11', 'PGS_12'].includes(status.statusCodeOrg)) return await this.observe(claim, owner, false)
        if (!this.config.depositEnabled || !progress.fileChecked || !claim.order.print_file_checked_at) throw new OrderPaymentError('production_deposit_disabled', 503)
        if (claim.approvalCurrent !== true) throw new OrderPaymentError('print_spec_approval_revoked', 409)
        await this.freshPayment(claim)
        this.costs(claim, (await this.vendor.price(claim.orderCode)).totalPrice)
        // The customer's payment settles separately. Before the first supplier
        // financial POST, check the prepaid account against all frozen costs.
        // This is a current balance check, not a reservation or a PG transfer.
        const costs = claim.costSnapshot
        const required = costs.estimatedPrintCost + costs.estimatedShippingCost + costs.estimatedPackagingCost
        if (!Number.isSafeInteger(required) || required <= 0) throw new OrderPaymentError('supplier_price_changed', 409)
        let balance: number
        try { balance = await this.vendor.depositBalance() }
        catch { throw new OrderPaymentError('supplier_deposit_unavailable', 503) }
        if (!Number.isSafeInteger(balance) || balance < 0) throw new OrderPaymentError('supplier_deposit_unavailable', 503)
        if (balance < required) throw new OrderPaymentError('supplier_deposit_insufficient', 503)
        if ((await this.current(id, owner)).approvalCurrent !== true) throw new OrderPaymentError('print_spec_approval_revoked', 409)
        await this.rpc('record_print_fulfillment_attempt', { p_id: id, p_owner: owner, p_vendor_order_num: claim.job.payload.vendorOrderNum, p_vendor_order_seq: 1 })
        claim.job.payload.depositAttempted = true
        const confirmed = await this.vendor.confirm(claim.job.payload.vendorOrderNum)
        if (!confirmed || typeof confirmed !== 'object' || Array.isArray(confirmed) || (confirmed as Record<string, unknown>).success !== true) {
          throw new OrderPaymentError('supplier_confirmation_unknown', 503)
        }
        return await this.observe(claim, owner, false)
      }
      if (claim.job.event_type === 'POLL') return await this.observe(claim, owner, true)
      throw new OrderPaymentError('print_render_required', 409)
    } catch (error) {
      const code = safeCode(error)
      await this.fail(id, owner, code, terminalCode(code), true)
      throw error
    }
  }
}

const headers = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }
const response = (value: unknown, status = 200) => new Response(JSON.stringify(value), { status, headers })
export function createPrintFulfillmentWorkerHandler(dependencies: Dependencies) {
  return async (req: Request) => {
    if (req.method === 'OPTIONS') return response({ ok: true })
    if (req.method !== 'POST') return response({ error: 'method_not_allowed' }, 405)
    try {
      const actor = await assertPrintWorker(req, dependencies.getUser)
      const raw = await req.text()
      if (raw.length > 150_000) throw new OrderPaymentError('invalid_print_worker_request')
      let body: any
      try { body = JSON.parse(raw) } catch { throw new OrderPaymentError('invalid_print_worker_request') }
      const actions: Record<string, string[]> = { claim: ['action','workerId'], renew: ['action','jobId','workerId'],
        overview: ['action','orderId'], snapshot: ['action','jobId','workerId'], uploads: ['action','jobId','workerId'],
        finalized: ['action','jobId','workerId','uploadId','manifest'], advance: ['action','jobId','workerId'], fail: ['action','jobId','workerId','errorCode'] }
      if (!body || typeof body !== 'object' || Array.isArray(body) || !actions[body.action] ||
          Object.keys(body).some(key => !actions[body.action].includes(key)) ||
          body.action !== 'overview' && (!uuid(body.workerId) || body.action !== 'claim' && !uuid(body.jobId)) ||
          body.action === 'finalized' && (!uuid(body.uploadId) || !body.manifest || Array.isArray(body.manifest) || typeof body.manifest !== 'object') ||
          body.action === 'fail' && !['print_renderer_failed','print_upload_failed','print_worker_interrupted'].includes(body.errorCode)) {
        throw new OrderPaymentError('invalid_print_worker_request')
      }
      if (body.action === 'overview' && Object.hasOwn(body, 'orderId') &&
          (typeof body.orderId !== 'string' || body.orderId.length > 100 || !body.orderId.startsWith('ordp_') || !uuid(body.orderId.slice(5)))) {
        throw new OrderPaymentError('invalid_print_worker_request')
      }
      if (body.action === 'overview' && actor.role !== 'admin') throw new OrderPaymentError('forbidden', 403)
      const db = dependencies.createAdminDatabase(), config = dependencies.configuration()
      const worker = new PrintFulfillmentWorker(db, config, dependencies.vendor(db), () => dependencies.sender(db), {
        inspectPdf: dependencies.inspectPdf, now: dependencies.now, paymentLookup: dependencies.paymentLookup,
      })
      let value: unknown
      if (body.action === 'claim') value = { enabled: worker.runtimeEnabled, claim: await worker.claim(body.workerId) }
      else if (body.action === 'overview') value = { jobs: await worker.overview(body.orderId), environment: config.environment, enabled: worker.runtimeEnabled }
      else if (body.action === 'renew') value = await worker.renew(body.jobId, body.workerId)
      else if (body.action === 'snapshot') value = await worker.snapshot(body.jobId, body.workerId)
      else if (body.action === 'uploads') value = await worker.uploads(body.jobId, body.workerId)
      else if (body.action === 'finalized') value = await worker.finalized(body.jobId, body.workerId, body.uploadId, body.manifest)
      else if (body.action === 'advance') value = await worker.advance(body.jobId, body.workerId)
      else value = await worker.fail(body.jobId, body.workerId, body.errorCode, body.errorCode === 'print_renderer_failed')
      return response(value)
    } catch (error) {
      if (error instanceof PrintWorkerAuthError) return response({ error: error.code }, error.status)
      return response({ error: safeCode(error), retryable: !terminalCode(safeCode(error)) },
        error instanceof PortOnePrintPaymentError || error instanceof RedprintingError ? error.status : error instanceof OrderPaymentError ? error.status : 503)
    }
  }
}
