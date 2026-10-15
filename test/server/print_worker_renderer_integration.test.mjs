import assert from 'node:assert/strict'
import { test } from 'node:test'
import { readFile, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import { createRequire } from 'node:module'
import { PrintFulfillmentWorker } from '../../supabase/functions/_shared/print-fulfillment-worker.ts'
import { createPdfInspector, validatePrintPdf } from '../../supabase/functions/_shared/print-package.ts'
import { sourceFingerprint } from '../../supabase/functions/_shared/print-contract.ts'
import { workerTick } from '../../tool/print_fulfillment/run_worker.mjs'
import { makeFixture, owner, jobId } from './fixtures/print_worker_fixture.mjs'

// Run only with the actual AlbumPrintExporter fixture produced by run_worker
// --fixture. Supplier/payment/database ports are local stubs, never live APIs.
const directory = process.env.SNAPFIT_WORKER_FIXTURE_OUTPUT
if (!directory) throw new Error('SNAPFIT_WORKER_FIXTURE_OUTPUT is required; generate actual Flutter PDFs first')
const require = createRequire(import.meta.url)
const pdfLib = require(process.env.SNAPFIT_PDF_LIB_PATH ?? '/Users/devsheep/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/pdf-lib/cjs/index.js')
const inspectPdf = createPdfInspector(pdfLib)

test('actual Flutter album PDFs pass server preflight and worker → stub receipt → file Y → production → tracking is connected', async () => {
  const artwork = JSON.parse(await readFile(join(directory, 'fixture.json'), 'utf8'))
  assert.equal(artwork.fixtureOnly, true); assert.equal(artwork.productionApproved, false)
  const cover = await readFile(join(directory, 'cover.pdf')), interior = await readFile(join(directory, 'interior.pdf'))
  const report = JSON.parse(await readFile(join(directory, 'manifest.json'), 'utf8'))
  const expectedPages = artwork.spec.pageCount
  assert.equal(report.sourceInteriorPages, expectedPages)
  assert.equal(report.blankPagesAdded, 0)
  const f = makeFixture({ snapshot: artwork.snapshot, spec: artwork.spec, cover, interior, inspectPdf })
  // No outbound fetch implementation exists in this integration harness.
  const w = new PrintFulfillmentWorker(f.db, f.config, f.vendor, f.sender, { now: f.now, inspectPdf, paymentLookup: f.paymentLookup })
  const fingerprint = await sourceFingerprint(f.order)
  const transport = { url: 'https://fixture.supabase.co', async call(endpoint, body) {
    if (endpoint === 'print-payment-reconcile') { f.calls.push('reconcile-first'); return { enabled: true, verifiedPaid: 1 } }
    if (endpoint === 'print-order-request-resolve') {
      assert.deepEqual(body, { action: 'tick', limit: 1 })
      f.calls.push('request-resolution-stub-disabled')
      return { enabled: false, processed: 0, waiting: 0, completed: 0, reviewRequired: 0 }
    }
    switch (body.action) {
      case 'claim': return { enabled: true, claim: await w.claim(body.workerId) }
      case 'renew': return w.renew(body.jobId, body.workerId)
      case 'snapshot': return w.snapshot(body.jobId, body.workerId)
      case 'uploads': return w.uploads(body.jobId, body.workerId)
      case 'finalized': return w.finalized(body.jobId, body.workerId, body.uploadId, body.manifest)
      case 'advance': return w.advance(body.jobId, body.workerId)
      case 'fail': return w.fail(body.jobId, body.workerId, body.errorCode, true)
      default: assert.fail('Unexpected integration action')
    }
  }, async upload(target, bytes) { f.files.set(target.path, bytes) } }
  const rendered = await workerTick({ transport, workerId: owner, renderer: async input => {
    assert.equal(input.sourceFingerprint, fingerprint)
    assert.notEqual(input.sourceFingerprint, 'immutable-review-revision-distinct-from-pdf-fingerprint')
    // Paid intents add canonical product metadata to the editor document; the
    // exact pages, layers and original artwork rendered above remain frozen.
    assert.deepEqual(input.snapshot, f.order.print_content_snapshot)
    assert.deepEqual(input.spec, artwork.spec)
    return { cover, interior, manifest: report }
  } })
  assert.equal(rendered.stage, 'SUBMIT'); assert.equal(f.order.print_fulfillment_status, 'READY')
  assert.equal(f.calls[0], 'reconcile-first')
  assert.equal(f.calls[1], 'request-resolution-stub-disabled')
  assert.equal(f.order.print_manifest.cover.pageCount, 1); assert.equal(f.order.print_manifest.interior.pageCount, expectedPages)
  assert.equal(f.order.print_manifest.sourceFingerprint, fingerprint)
  assert.equal(f.order.print_manifest.spec.specVersion, artwork.spec.specVersion)
  assert.equal(f.order.status, 'PAYMENT_COMPLETED')
  assert.equal(f.order.print_file_checked_at, undefined)
  await workerTick({ transport, workerId: owner })
  assert.equal(f.order.print_fulfillment_status, 'SUBMITTED')
  assert.equal(f.order.status, 'PAYMENT_COMPLETED')
  assert.equal(f.order.print_file_checked_at, undefined)
  const supplierPosts = f.calls.filter(call => call?.supplierSubmit)
  assert.equal(supplierPosts.length, 1)
  const payload = supplierPosts[0].supplierSubmit.order_data[0]
  assert.equal(payload.send_name, '스냅핏'); assert.equal(payload.qty, 1)
  assert.equal(payload.order_num, f.job.payload.vendorOrderNum)
  assert.match(payload.file_url1, /\/print-packages\/ordp_fixture\//)
  assert.equal(f.calls.filter(call => call === 'supplier-deposit').length, 0)
  f.status.fileProcessYn = 'Y'
  await workerTick({ transport, workerId: owner })
  assert.equal(f.job.event_type, 'CONFIRM'); assert.ok(f.order.print_file_checked_at)
  assert.equal(f.order.status, 'PAYMENT_COMPLETED')
  await workerTick({ transport, workerId: owner })
  assert.equal(f.order.status, 'IN_PRODUCTION'); assert.equal(f.order.print_fulfillment_status, 'ACCEPTED')
  assert.equal(f.calls.filter(call => call === 'supplier-deposit').length, 1)
  assert.equal(f.job.payload.depositAttempted, true)
  Object.assign(f.status, { statusCode: 'PGS_55', statusCodeOrg: 'PGS_55', courier: '로컬 검수 택배', trackingNumber: '123456789' })
  await workerTick({ transport, workerId: owner })
  assert.equal(f.order.status, 'SHIPPING'); assert.equal(f.order.tracking_number, '123456789')
  assert.notEqual(f.order.status, 'DELIVERED')
  assert.equal(f.calls.filter(call => call?.supplierSubmit).length, 1)
  assert.equal(f.calls.filter(call => call === 'supplier-deposit').length, 1)
  await writeFile(join(directory, 'pipeline-verification.json'), JSON.stringify({
    verifiedAt: new Date().toISOString(), fixtureOnly: true, renderer: 'actual Flutter AlbumPrintExporter',
    fixtureScenario: artwork.scenario ?? 'SOFT_20', artworkProfile: artwork.artworkProfile ?? 'standard', pageCount: expectedPages, productId: artwork.spec.id,
    paymentProvider: 'LOCAL STUB', supplier: 'LOCAL STUB', database: 'LOCAL IN-MEMORY STUB',
    externalRequestCount: 0, actualPaymentMade: false, actualSupplierOrderMade: false, actualShipmentMade: false,
    physicalSampleValidated: false, productionApproved: false, sourceFingerprint: fingerprint,
    cover: f.order.print_manifest.cover, interior: f.order.print_manifest.interior,
    supplierStubSubmissionCount: 1, supplierStubDepositCount: 1,
    finalLocalCustomerStage: 'SHIPPING', deliveredConfirmed: false,
  }, null, 2))
})

test('real rendered PDFs with incorrect purchased geometry/page count are rejected before supplier network work', async () => {
  const artwork = JSON.parse(await readFile(join(directory, 'fixture.json'), 'utf8'))
  const interior = await readFile(join(directory, 'interior.pdf'))
  const pages = artwork.spec.pageCount, width = artwork.spec.interior.trimWidthMm + 10, height = artwork.spec.interior.trimHeightMm + 10
  await assert.rejects(validatePrintPdf(interior, pages + 2, width, height, inspectPdf), /print_pdf_page_count_mismatch/)
  await assert.rejects(validatePrintPdf(interior, pages, width + 10, height, inspectPdf), /print_pdf_dimensions_mismatch/)
  const result = await validatePrintPdf(interior, pages, width, height, inspectPdf)
  assert.equal(result.pageCount, pages); assert.equal(result.widthMm, width)
  assert.equal(artwork.physicalSampleValidated, false)
})
