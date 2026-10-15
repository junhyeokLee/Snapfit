// The real development handler and PDF inspector, with private in-memory
// storage/database adapters. No Auth, Supabase, vendor, or payment requests.
import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'
import { pathToFileURL } from 'node:url'
import { test } from 'node:test'
import { RedprintingAdmin } from '../../supabase/functions/_shared/redprinting-admin.ts'
import { createPdfInspector } from '../../supabase/functions/_shared/print-package.ts'
import { coverTrim } from '../../supabase/functions/_shared/redprinting.ts'
import { sha256 } from '../../supabase/functions/_shared/print-contract.ts'

const pdfLib = (await import(process.env.PDF_LIB_MODULE ? pathToFileURL(process.env.PDF_LIB_MODULE).href : 'pdf-lib')).default
const inspector = createPdfInspector(pdfLib)
const requestId = '11111111-1111-4111-8111-111111111111'
const recipient = { name: '개발 테스트', tel: '01000000000', zipcode: '00000', address: '테스트 주소', addressDetail: '실제 배송 없음', message: '' }
const config = { environment: 'development', enabled: true, userId: 'fixture-account', apiKey: 'local-fixture-key', expiresAt: '2099-11-07' }
const profileSource = readFileSync(new URL('../../lib/features/album/printing/srgb_profile.dart', import.meta.url), 'utf8')
const profile = Buffer.from([...profileSource.matchAll(/'([A-Za-z0-9+/=]{30,})'/g)].map(match => match[1]).join(''), 'base64')

class Query {
  filters = []; operation = 'select'; value; one = false
  constructor(rows) { this.rows = rows }
  select() { return this }
  eq(key, value) { this.filters.push(row => row[key] === value); return this }
  single() { this.one = true; return this }
  maybeSingle() { this.one = true; return this }
  update(value) { this.operation = 'update'; this.value = value; return this }
  insert(value) { this.operation = 'insert'; this.value = value; return this }
  then(resolve, reject) {
    let rows = this.rows.filter(row => this.filters.every(filter => filter(row)))
    if (this.operation === 'insert') {
      const row = { environment: 'development', status: 'DRAFT', created_at: '2026-10-08', vendor_status: {}, ...this.value }
      this.rows.push(row); rows = [row]
    } else if (this.operation === 'update') rows.forEach(row => Object.assign(row, this.value))
    return Promise.resolve({ data: this.one ? rows[0] ?? null : rows, error: null }).then(resolve, reject)
  }
}

class PrivateDatabase {
  tables = {
    redprinting_dev_tests: [], redprinting_dev_mappings: [],
    redprinting_dev_settings: [{ id: 1, sender_name: '스냅핏', sender_tel: '', sender_zipcode: '', sender_address: '', sender_address_detail: '',
      color_mode: 'UNCONFIRMED', color_approval_note: '', test_deposit_enabled: false, development_rgb_test_acknowledged: false, development_geometry_test_acknowledged: false }],
  }
  objects = new Map(); leases = new Set(); uploads = []; downloads = []; signedDownloads = []; vendorCalls = []
  from(table) { assert.ok(Object.hasOwn(this.tables, table), `Unexpected customer table access: ${table}`); return new Query(this.tables[table]) }
  async rpc(name, args) {
    if (name === 'redprinting_dev_acquire_test') { if (this.leases.has(args.p_id)) return { data: false }; this.leases.add(args.p_id); return { data: true } }
    assert.equal(name, 'redprinting_dev_release_test'); this.leases.delete(args.p_id); return { data: null }
  }
  storage = {
    getBucket: async bucket => { assert.equal(bucket, 'print-packages'); return { data: { public: false }, error: null } },
    from: bucket => {
      assert.equal(bucket, 'print-packages')
      return {
        createSignedUploadUrl: async (path, options) => {
          assert.deepEqual(options, { upsert: false }); this.uploads.push(path)
          return { data: { signedUrl: `https://storage-fixture.test/${path}`, token: 'local-upload-token' }, error: null }
        },
        download: async path => { this.downloads.push(path); return { data: this.objects.get(path) ?? null, error: null } },
        createSignedUrl: async (path, seconds) => { this.signedDownloads.push({ path, seconds }); return { data: { signedUrl: `https://storage-fixture.test/${path}?private=expiring` }, error: null } },
      }
    },
  }
  upload(path, bytes) { assert.ok(this.uploads.includes(path)); assert.equal(this.objects.has(path), false, 'An upload cannot replace an existing PDF'); this.objects.set(path, new Blob([bytes])) }
}

function setup() {
  const db = new PrivateDatabase()
  const vendor = { call: async path => { db.vendorCalls.push(path); throw new Error('Unexpected external order request') } }
  return { db, admin: new RedprintingAdmin(db, config, null, { inspectPdf: inspector, vendor }) }
}
async function draft(admin, productId = 'REDP_200X150_SOFT', pageCount = 20) {
  const created = await admin.action('createTest', { requestId, productId, pageCount, recipient })
  assert.equal(created.status, 'DRAFT'); assert.match(created.orderNum, /^SFD[a-f0-9]{32}$/); assert.equal(created.orderSeq, 1)
  const snapshot = await admin.action('getTestSnapshot', { id: created.id })
  const upload = await admin.action('createTestUploads', { id: created.id })
  return { created, snapshot, upload }
}
const report = snapshot => ({ dpi: 300, colorSpace: 'sRGB', iccProfileEmbedded: true, missingAssets: [], warnings: [], sourceFingerprint: snapshot.sourceFingerprint, specVersion: snapshot.spec.specVersion })
const finalizeBody = ({ created, snapshot, upload }) => ({ id: created.id, uploadId: upload.uploadId, report: report(snapshot) })

async function pdf(pages, widthMm, heightMm, trim = { xMm: 5, yMm: 5, widthMm: widthMm - 10, heightMm: heightMm - 10 }) {
  const { PDFDocument, PDFName } = pdfLib, doc = await PDFDocument.create(), context = doc.context
  const profileRef = context.register(context.stream(profile, { N: 3, Alternate: 'DeviceRGB' }))
  const image = context.register(context.flateStream(new Uint8Array([255, 250, 245]), {
    Type: 'XObject', Subtype: 'Image', Width: Math.ceil(widthMm * 300 / 25.4), Height: Math.ceil(heightMm * 300 / 25.4),
    BitsPerComponent: 8, ColorSpace: ['ICCBased', profileRef],
  }))
  for (let i = 0; i < pages; i++) {
    const page = doc.addPage([widthMm * 72 / 25.4, heightMm * 72 / 25.4])
    page.setTrimBox(trim.xMm * 72 / 25.4, (heightMm - trim.yMm - trim.heightMm) * 72 / 25.4, trim.widthMm * 72 / 25.4, trim.heightMm * 72 / 25.4)
    page.node.set(PDFName.of('Resources'), context.obj({ XObject: { Im: image } }))
    page.node.set(PDFName.of('Contents'), context.register(context.flateStream(new TextEncoder().encode('q 1 0 0 1 0 0 cm /Im Do Q'))))
  }
  return doc.save({ useObjectStreams: false })
}
async function pdfPair(snapshot) {
  const { spec } = snapshot
  return { cover: await pdf(1, spec.cover.widthMm, spec.cover.heightMm, coverTrim(spec)),
    interior: await pdf(spec.pageCount, spec.interior.trimWidthMm + 2 * spec.interior.bleedMm, spec.interior.trimHeightMm + 2 * spec.interior.bleedMm) }
}
function uploadPair(db, upload, pair) { db.upload(upload.cover.path, pair.cover); db.upload(upload.interior.path, pair.interior) }
function assertUnpublished(db) {
  const row = db.tables.redprinting_dev_tests[0]
  assert.equal(row.status, 'DRAFT'); assert.equal(row.cover_path ?? null, null); assert.equal(row.interior_path ?? null, null)
  assert.equal(row.pdf_manifest.validatedAt, undefined)
  assert.ok(Object.keys(row.pdf_manifest).every(key => key === 'previousVersions'))
}

test('admin sample download signs only revalidated current soft/hard PDFs for 15 minutes without changing tests or manufacturing', async () => {
  for (const [productId, pages] of [['REDP_200X150_SOFT', 20], ['REDP_300_HARD', 80]]) {
    const { db, admin } = setup(), source = await draft(admin, productId, pages), pair = await pdfPair(source.snapshot)
    uploadPair(db, source.upload, pair)
    await admin.action('finalizeTestFiles', finalizeBody(source))
    const before = structuredClone(db.tables.redprinting_dev_tests)
    const links = await admin.action('getTestDownloadLinks', { action: 'getTestDownloadLinks', id: source.created.id })
    assert.equal(links.productId, productId); assert.equal(links.pageCount, pages); assert.equal(links.productionApproved, false)
    assert.equal(links.cover.bytes, pair.cover.length); assert.equal(links.interior.bytes, pair.interior.length)
    assert.equal(links.cover.sha256, await sha256(pair.cover)); assert.equal(links.interior.sha256, await sha256(pair.interior))
    assert.ok(Date.parse(links.expiresAt) > Date.now()); assert.ok(Date.parse(links.expiresAt) <= Date.now() + 900000)
    assert.deepEqual(db.signedDownloads, [{ path: source.upload.cover.path, seconds: 900 }, { path: source.upload.interior.path, seconds: 900 }])
    assert.deepEqual(db.tables.redprinting_dev_tests, before); assert.equal(db.leases.size, 0); assert.deepEqual(db.vendorCalls, [])
    assert.doesNotMatch(JSON.stringify(links), /fixture-account|local-fixture-key|테스트 주소|vendor_status/)
  }
})

test('sample downloads reject missing validation, tampered bytes, path swaps and caller-supplied storage paths', async () => {
  for (const mutate of [row => row.pdf_manifest.validatedAt = null, row => row.pdf_manifest.specVersion = 'stale',
    row => row.cover_path = `another-test/${row.upload_id}/cover.pdf`, row => row.pdf_manifest.cover.sha256 = '0'.repeat(64)]) {
    const { db, admin } = setup(), source = await draft(admin), pair = await pdfPair(source.snapshot)
    uploadPair(db, source.upload, pair); await admin.action('finalizeTestFiles', finalizeBody(source))
    mutate(db.tables.redprinting_dev_tests[0])
    await assert.rejects(admin.action('getTestDownloadLinks', { id: source.created.id }), /test_pdf_validation_required|test_pdf_preflight_failed/)
    assert.deepEqual(db.signedDownloads, []); assert.deepEqual(db.vendorCalls, [])
  }
  const { db, admin } = setup(), source = await draft(admin)
  await assert.rejects(admin.action('getTestDownloadLinks', { id: source.created.id, path: 'arbitrary.pdf' }), /invalid_body/)
  assert.deepEqual(db.signedDownloads, [])
})

test('new development test publishes only after inspecting both private PDFs; no approved code or shipping settings are needed to prepare files', async () => {
  const { admin, db } = setup(), source = await draft(admin), pair = await pdfPair(source.snapshot)
  assert.equal(source.snapshot.productionApproved, false); assert.equal(source.upload.bucket, 'print-packages')
  assert.match(source.snapshot.sourceFingerprint, /^[a-f0-9]{64}$/)
  assertUnpublished(db); uploadPair(db, source.upload, pair)
  const result = await admin.action('finalizeTestFiles', finalizeBody(source))
  assert.equal(result.status, 'FILES_READY'); assert.equal(result.orderNum, source.created.orderNum)
  assert.equal(result.pdfManifest.cover.pageCount, 1); assert.equal(result.pdfManifest.interior.pageCount, 20)
  assert.equal(result.pdfManifest.cover.sha256, await sha256(pair.cover)); assert.equal(result.pdfManifest.interior.sha256, await sha256(pair.interior))
  assert.equal(result.pdfManifest.productionApproved, false); assert.equal(result.sourceFingerprint, source.snapshot.sourceFingerprint)
  assert.deepEqual(db.downloads, [source.upload.cover.path, source.upload.interior.path]); assert.equal(db.leases.size, 0); assert.deepEqual(db.vendorCalls, [])
  await assert.rejects(admin.action('submitTest', { id: result.id }), /sender_details_required/)
  Object.assign(db.tables.redprinting_dev_settings[0], { sender_tel: '01000000000', sender_zipcode: '00000', sender_address: '테스트 주소', sender_address_detail: '반송 테스트',
    development_rgb_test_acknowledged: true, development_geometry_test_acknowledged: true })
  await assert.rejects(admin.action('submitTest', { id: result.id }), /test_vendor_recipient_required/)
  await admin.action('updateTestRecipient', { id: result.id, recipient: { ...recipient, zipcode: '01234' } })
  await assert.rejects(admin.action('submitTest', { id: result.id }), /exact_order_code_approval_required/)
  assert.deepEqual(db.vendorCalls, []); assert.equal(db.tables.redprinting_dev_tests[0].status, 'FILES_READY')
})

test('missing interior never publishes a partial cover; the same upload can complete after the missing object arrives', async () => {
  const { admin, db } = setup(), source = await draft(admin), pair = await pdfPair(source.snapshot)
  db.upload(source.upload.cover.path, pair.cover)
  await assert.rejects(admin.action('finalizeTestFiles', finalizeBody(source)), /test_pdf_upload_missing/)
  assertUnpublished(db); assert.equal(db.leases.size, 0)
  db.upload(source.upload.interior.path, pair.interior)
  assert.equal((await admin.action('finalizeTestFiles', finalizeBody(source))).status, 'FILES_READY')
  assert.deepEqual(db.vendorCalls, [])
})

test('client claims cannot publish PDFs for a different snapshot or waive color and missing-asset checks', async () => {
  const { admin, db } = setup(), source = await draft(admin)
  for (const patch of [{ sourceFingerprint: 'different-snapshot' }, { specVersion: 'different-version' }, { colorSpace: 'CMYK' }, { dpi: 72 }, { iccProfileEmbedded: false }, { missingAssets: ['missing.jpg'] }]) {
    await assert.rejects(admin.action('finalizeTestFiles', { ...finalizeBody(source), report: { ...report(source.snapshot), ...patch } }), /test_pdf_preflight_failed/)
    assertUnpublished(db)
  }
  assert.deepEqual(db.downloads, []); assert.equal(db.leases.size, 0)
})

test('a correct client report cannot hide the actual PDF page count or physical size', async () => {
  for (const [badInterior, expected] of [[await pdf(22, 210, 160), /print_pdf_page_count_mismatch/], [await pdf(20, 210, 210), /print_pdf_dimensions_mismatch/]]) {
    const { admin, db } = setup(), source = await draft(admin), pair = await pdfPair(source.snapshot)
    uploadPair(db, source.upload, { cover: pair.cover, interior: badInterior })
    await assert.rejects(admin.action('finalizeTestFiles', finalizeBody(source)), expected)
    assertUnpublished(db); assert.equal(db.leases.size, 0); assert.deepEqual(db.vendorCalls, [])
  }
})

test('a newer upload preserves previous PDF evidence while invalidating current paths and keeping the order identity', async () => {
  const { admin, db } = setup(), source = await draft(admin), pair = await pdfPair(source.snapshot)
  uploadPair(db, source.upload, pair)
  const ready = await admin.action('finalizeTestFiles', finalizeBody(source))
  const newUpload = await admin.action('createTestUploads', { id: source.created.id })
  assert.notEqual(newUpload.uploadId, source.upload.uploadId); assertUnpublished(db)
  const prior = db.tables.redprinting_dev_tests[0].pdf_manifest.previousVersions[0]
  assert.equal(prior.coverPath, ready.coverPath); assert.equal(prior.interiorPath, ready.interiorPath)
  assert.deepEqual(prior.cover, ready.pdfManifest.cover); assert.deepEqual(prior.interior, ready.pdfManifest.interior)
  assert.equal(prior.validatedAt, ready.pdfManifest.validatedAt); assert.ok(prior.replacedAt)
  const downloadsBefore = db.downloads.length
  await assert.rejects(admin.action('finalizeTestFiles', finalizeBody(source)), /test_upload_expired/)
  assert.equal(db.downloads.length, downloadsBefore)
  uploadPair(db, newUpload, pair)
  const next = await admin.action('finalizeTestFiles', finalizeBody({ ...source, upload: newUpload }))
  assert.equal(next.status, 'FILES_READY'); assert.equal(next.orderNum, ready.orderNum); assert.equal(next.orderSeq, ready.orderSeq)
  assert.ok(next.coverPath.startsWith(`${source.created.id}/${newUpload.uploadId}/`))
  assert.ok(next.interiorPath.startsWith(`${source.created.id}/${newUpload.uploadId}/`)); assert.equal(db.objects.size, 4)
  assert.deepEqual(next.pdfManifest.previousVersions, [prior])
  assert.deepEqual(db.vendorCalls, [])
})

// Supply the output directory produced by redprinting fixture QA to exercise
// full Flutter raster files too. Do not copy large generated PDFs into Git.
for (const item of [{ productId: 'REDP_200X150_SOFT', pageCount: 20 }, { productId: 'REDP_300_HARD', pageCount: 80 }]) {
  test(`actual Flutter ${item.productId} ${item.pageCount}-page PDFs complete DRAFT to FILES_READY`, async context => {
    const root = process.env.REDPRINTING_PDF_FIXTURE_ROOT
    if (!root) { context.skip('Set REDPRINTING_PDF_FIXTURE_ROOT to the local Flutter fixture QA output'); return }
    const base = pathToFileURL(`${root.replace(/\/$/, '')}/`)
    const generated = new URL(`${item.productId}-${item.pageCount}/`, base)
    // Earlier 20-page fixture runs wrote directly into the output root.
    const directory = item.pageCount === 20 && !existsSync(new URL('cover.pdf', generated)) ? base : generated
    const { admin, db } = setup(), source = await draft(admin, item.productId, item.pageCount)
    const pair = { cover: readFileSync(new URL('cover.pdf', directory)), interior: readFileSync(new URL('interior.pdf', directory)) }
    const originalReport = JSON.parse(readFileSync(new URL('report.json', directory), 'utf8'))
    assert.equal(originalReport.productId, item.productId); assert.equal(originalReport.pageCount, item.pageCount)
    uploadPair(db, source.upload, pair)
    const result = await admin.action('finalizeTestFiles', { ...finalizeBody(source), report: { ...originalReport, sourceFingerprint: source.snapshot.sourceFingerprint, specVersion: source.snapshot.spec.specVersion } })
    assert.equal(result.status, 'FILES_READY'); assert.equal(result.pdfManifest.cover.pageCount, 1); assert.equal(result.pdfManifest.interior.pageCount, item.pageCount)
    assert.equal(result.pdfManifest.cover.byteLength, pair.cover.length); assert.equal(result.pdfManifest.interior.byteLength, pair.interior.length)
    assert.equal(result.pdfManifest.cover.sha256, await sha256(pair.cover)); assert.equal(result.pdfManifest.interior.sha256, await sha256(pair.interior))
    assert.equal(result.pdfManifest.productionApproved, false); assert.deepEqual(db.vendorCalls, []); assert.equal(db.leases.size, 0)
  })
}
