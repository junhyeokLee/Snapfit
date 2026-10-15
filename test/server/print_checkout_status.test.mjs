import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { stripTypeScriptTypes } from 'node:module'
import { test } from 'node:test'
import vm from 'node:vm'
import { createPrintCheckoutStatusHandler } from '../../supabase/functions/_shared/print-checkout.ts'

const quote = (overrides = {}) => ({
  pageCount: 20, amount: 49900, sourcePageCount: 18, addedBlankPageCount: 2,
  productCode: 'REDP_200X150_SOFT', productName: '20×15cm 소프트커버 포토북',
  printProduct: { id: 'REDP_200X150_SOFT', trimWidthMm: 200, trimHeightMm: 150 },
  shippingIncluded: true, supplierCostVerified: true, shippingCostVerified: true,
  packagingCostVerified: true, pricingVersion: 'PRINT_REDP_COVERTYPE_V3',
  pricePolicyVersion: 'PRINT_REDP_VERIFIED_COMBO_20261013_V1', retailPriceStatus: 'PLANNED',
  priceIsEstimate: true, printTemplateStatus: 'REVIEW_REQUIRED',
  spec: { id: 'REDP_200X150_SOFT', pageCount: 20, verified: false },
  ...overrides,
})

function fixture({ user = { id: 'owner' }, authError = null, authThrows = false, rpcError = null,
  result = quote(), member = false, factoryThrows = false, rpcThrows = false } = {}) {
  const calls = []
  const client = {
    auth: { async getUser() { calls.push('getUser'); if (authThrows) throw new Error('private auth error'); return { data: { user }, error: authError } } },
    async rpc(name, params) {
      calls.push({ name, params })
      if (rpcThrows) throw new Error('private database address')
      if (rpcError) return { data: null, error: rpcError }
      // Model the existing quote access contract: owner or album collaborator.
      if (params.p_album_id !== 77 || (user.id !== 'owner' && !member)) {
        return { data: null, error: { code: '42501', message: 'private album details' } }
      }
      return { data: structuredClone(result), error: null }
    },
  }
  const handler = createPrintCheckoutStatusHandler(req => {
    calls.push({ authorization: req.headers.get('Authorization') })
    if (factoryThrows) throw new Error('private environment key')
    return client
  })
  return { handler, calls }
}
function request(body = { albumId: 77 }, { method = 'POST', authorization = 'Bearer session-fixture', raw = false } = {}) {
  return new Request('https://example.invalid/print-checkout-status', {
    method,
    headers: authorization ? { Authorization: authorization } : {},
    ...(method === 'POST' ? { body: raw ? body : JSON.stringify(body) } : {}),
  })
}

test('authenticated owner receives the actual public quotation and a closed preparation state', async () => {
  const f = fixture()
  const response = await f.handler(request({ albumId: 77, pageCount: 20 }))
  assert.equal(response.status, 200)
  assert.equal(response.headers.get('cache-control'), 'no-store')
  const result = await response.json()
  assert.deepEqual(result.quote, quote())
  assert.equal(result.canPay, false)
  assert.equal(result.status, 'PREPARING')
  assert.equal(result.reasonCode, 'print_sales_not_ready')
  assert.equal(result.environment, 'unavailable')
  assert.equal(result.paymentProvider, 'PORTONE')
  assert.match(result.message, /정식 주문이 열리면/)
  assert.deepEqual(f.calls, [{ authorization: 'Bearer session-fixture' }, 'getUser',
    { name: 'get_print_order_quote', params: { p_album_id: 77, p_page_count: 20 } }])
})

test('collaborator access follows the existing quotation permission, unrelated user is denied', async () => {
  const permitted = fixture({ user: { id: 'editor' }, member: true })
  assert.equal((await permitted.handler(request())).status, 200)
  const unrelated = fixture({ user: { id: 'stranger' } })
  const response = await unrelated.handler(request())
  assert.equal(response.status, 403)
  assert.deepEqual(await response.json(), { error: 'album_access_denied' })
})

test('nonexistent and inaccessible albums share a safe denial response', async () => {
  for (const error of [{ code: '42501', message: 'owner ID' }, { code: 'P0002', message: 'private album' }]) {
    const response = await fixture({ rpcError: error }).handler(request())
    assert.equal(response.status, 403)
    assert.deepEqual(await response.json(), { error: 'album_access_denied' })
  }
})

test('anonymous and malformed bearer callers cannot reach Auth or quotation data', async () => {
  for (const authorization of [null, '', 'Basic secret', 'Bearer two tokens', 'Bearer ']) {
    const f = fixture()
    const response = await f.handler(request({}, { authorization }))
    assert.equal(response.status, 401)
    assert.deepEqual(await response.json(), { error: 'authentication_required' })
    assert.equal(f.calls.length, 0)
  }
})

test('Auth rejects stale, missing, malformed, or forged sessions before any RPC', async () => {
  for (const options of [{ user: null }, { user: { id: '' } }, { user: { id: 42 } },
    { authError: { message: 'session expired' } }, { authThrows: true }]) {
    const f = fixture(options)
    const response = await f.handler(request())
    assert.equal(response.status, 401)
    assert.deepEqual(await response.json(), { error: 'invalid_session' })
    assert.equal(f.calls.length, 2)
  }
})

test('authentication precedes parsing so malformed anonymous bodies cannot inspect the contract', async () => {
  const f = fixture()
  const response = await f.handler(request('{invalid', { authorization: null, raw: true }))
  assert.equal(response.status, 401)
  assert.equal(f.calls.length, 0)
})

test('preflight and wrong methods perform no authentication or database actions', async () => {
  for (const [method, status] of [['OPTIONS', 200], ['GET', 405], ['PUT', 405], ['DELETE', 405]]) {
    const f = fixture()
    const response = await f.handler(request(null, { method }))
    assert.equal(response.status, status)
    assert.equal(f.calls.length, 0)
  }
})

test('invalid album identifiers, odd page counts, and client identity or payment flags never reach the RPC', async () => {
  for (const body of [null, [], {}, { albumId: '77' }, { albumId: 0 }, { albumId: -1 },
    { albumId: 1.5 }, { albumId: Number.MAX_SAFE_INTEGER + 1 },
    { albumId: 77, pageCount: 19 }, { albumId: 77, pageCount: 21 }, { albumId: 77, pageCount: 82 },
    { albumId: 77, pageCount: '20' }, { albumId: 77, userId: 'owner' },
    { albumId: 77, canPay: true }, { albumId: 77, paymentStatus: 'PAID' },
    { albumId: 77, recipientName: 'private recipient' }]) {
    const f = fixture()
    const response = await f.handler(request(body))
    assert.equal(response.status, 400, JSON.stringify(body))
    assert.deepEqual(await response.json(), { error: 'invalid_checkout_request' })
    assert.equal(f.calls.length, 2)
  }
})

test('malformed and excessive bodies are rejected without querying', async () => {
  for (const body of ['{invalid', 'x'.repeat(4097)]) {
    const f = fixture()
    assert.equal((await f.handler(request(body, { raw: true }))).status, 400)
    assert.equal(f.calls.length, 2)
  }
})

test('omitted or null page selection asks the server to choose the album-supported count', async () => {
  for (const body of [{ albumId: 77 }, { albumId: 77, pageCount: null }]) {
    const f = fixture()
    assert.equal((await f.handler(request(body))).status, 200)
    assert.deepEqual(f.calls[2].params, { p_album_id: 77, p_page_count: null })
  }
})

test('unverified price combinations can be reviewed but cannot enable payment', async () => {
  const f = fixture({ result: quote({ supplierCostVerified: false, retailPriceStatus: 'PENDING_SUPPLIER_QUOTE',
    pricePolicyVersion: 'PRINT_REDP_COVERTYPE_ESTIMATE_V3' }) })
  const response = await f.handler(request())
  assert.equal(response.status, 200)
  const result = await response.json()
  assert.equal(result.canPay, false)
  assert.equal(result.quote.supplierCostVerified, false)
  assert.equal(result.quote.retailPriceStatus, 'PENDING_SUPPLIER_QUOTE')
})

test('a final retail quotation remains reviewable while the separate sales and payment gates stay closed', async () => {
  const finalQuote = quote({ retailPriceStatus: 'FINAL', priceIsEstimate: false })
  const response = await fixture({ result: finalQuote }).handler(request())
  assert.equal(response.status, 200)
  const value = await response.json()
  assert.equal(value.quote.retailPriceStatus, 'FINAL')
  assert.equal(value.quote.amount, 49900)
  assert.equal(value.canPay, false)
  assert.equal(value.environment, 'unavailable')
})

test('public quotation preserves exact print rectangles and removes nested private supplier material', async () => {
  const response = await fixture({ result: quote({
    printProduct: { ...quote().printProduct, supplierOrderCode: 'private-code', approval: { token: 'private-token' } },
    spec: { id: 'REDP_200X150_SOFT', pageCount: 20, verified: false, supplierCost: 21230,
      approvalEvidence: 'private-evidence', reviewRequired: ['physical_sample', 'private-evidence', { secret: 'private-token' }],
      interior: { trimWidthMm: 200, trimHeightMm: 150, bleedMm: 5, downloadURL: 'https://private.invalid' },
      cover: { widthMm: 417.22, heightMm: 160, privateToken: 'private-token',
        front: { xMm: 212.22, yMm: 5, widthMm: 200, heightMm: 150, evidence: 'private-evidence' } } },
  }) }).handler(request())
  assert.equal(response.status, 200)
  const value = await response.json()
  assert.equal(value.quote.spec.cover.front.xMm, 212.22)
  assert.deepEqual(value.quote.spec.reviewRequired, ['physical_sample'])
  assert.deepEqual(value.quote.printProduct, quote().printProduct)
  assert.doesNotMatch(JSON.stringify(value), /private|"supplierCost":|supplierOrderCode|approvalEvidence|downloadURL/)
  assert.equal(value.canPay, false)
})

test('a planned price or supplier completion flags never certify commercial readiness', async () => {
  const f = fixture({ result: quote({ canPay: true, productionEnabled: true, verifiedPaymentId: 'forged',
    supplierCost: 21230, apiKey: 'private', recipient: { name: 'private' },
    printFilePdfUrl: 'https://private.invalid/file', spec: { verified: true } }) })
  const response = await f.handler(request())
  const result = await response.json()
  assert.equal(response.status, 200)
  assert.equal(result.canPay, false)
  assert.equal(result.environment, 'unavailable')
  for (const key of ['canPay', 'productionEnabled', 'verifiedPaymentId', 'supplierCost', 'apiKey', 'recipient', 'printFilePdfUrl']) {
    assert.equal(Object.hasOwn(result.quote, key), false)
  }
})

test('invalid or stale quotation contracts fail closed without returning malformed prices', async () => {
  for (const result of [null, [], quote({ amount: 0 }), quote({ amount: '49900' }),
    quote({ pageCount: 21 }), quote({ pageCount: 82 }), quote({ sourcePageCount: 21 }),
    quote({ productCode: 'UNKNOWN' }), quote({ pricingVersion: 'PRINT_2026_09' }),
    quote({ pricePolicyVersion: '' }), quote({ retailPriceStatus: 'SELLABLE' })]) {
    const response = await fixture({ result }).handler(request())
    assert.equal(response.status, 503)
    assert.deepEqual(await response.json(), { error: 'print_quote_unavailable' })
  }
  assert.equal((await fixture().handler(request({ albumId: 77, pageCount: 22 }))).status, 503)
})

test('RPC and configuration failures expose safe errors without leaking database details', async () => {
  for (const options of [{ factoryThrows: true }, { rpcThrows: true },
    { rpcError: { code: 'XX000', message: 'private server detail' } }]) {
    const response = await fixture(options).handler(request())
    assert.equal(response.status, 503)
    assert.deepEqual(await response.json(), { error: 'print_checkout_unavailable' })
  }
  const response = await fixture({ rpcError: { code: '22023', message: 'unsupported_print_product' } }).handler(request())
  assert.equal(response.status, 400)
  assert.deepEqual(await response.json(), { error: 'print_album_not_supported' })
})

test('deployed wrapper creates only a user-scoped client and uses Auth server verification', async () => {
  const file = new URL('../../supabase/functions/print-checkout-status/index.ts', import.meta.url)
  const calls = []; let handler
  const client = {
    auth: { async getUser() { calls.push('getUser'); return { data: { user: { id: 'owner' } }, error: null } } },
    async rpc(name, parameters) { calls.push({ name, parameters }); return { data: quote(), error: null } },
  }
  const source = stripTypeScriptTypes(readFileSync(file, 'utf8').replace(/^import .*$/gm, ''))
  vm.runInNewContext(source, {
    Deno: {
      serve: fn => { handler = fn },
      env: { get: name => { calls.push({ environment: name }); return name === 'SUPABASE_URL'
        ? 'https://example.invalid' : name === 'SUPABASE_ANON_KEY' ? 'public-fixture-key' : assert.fail('privileged key requested') } },
    },
    createClient: (url, key, options) => { calls.push({ url, key, options }); return client },
    createPrintCheckoutStatusHandler,
    Error,
  })
  const response = await handler(request())
  assert.equal(response.status, 200)
  assert.equal(calls[2].url, 'https://example.invalid')
  assert.equal(calls[2].key, 'public-fixture-key')
  assert.equal(calls[2].options.global.headers.Authorization, 'Bearer session-fixture')
  assert.equal(calls[2].options.auth.persistSession, false)
  assert.equal(calls[2].options.auth.autoRefreshToken, false)
  assert.equal(calls[3], 'getUser')
  assert.equal(calls[4].name, 'get_print_order_quote')
})

test('gateway validation stays enabled and legacy paid checkout entrypoints stay disabled', () => {
  const config = readFileSync(new URL('../../supabase/config.toml', import.meta.url), 'utf8')
  assert.match(config, /\[functions\.print-checkout-status\][^[]*verify_jwt\s*=\s*true/)
  for (const name of ['order-checkout', 'order-confirm-payment']) {
    const source = readFileSync(new URL(`../../supabase/functions/${name}/index.ts`, import.meta.url), 'utf8')
    assert.match(source, /physical_order_payments_disabled/)
    assert.match(source, /410/)
  }
})
