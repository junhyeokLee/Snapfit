import assert from 'node:assert/strict'
import { test } from 'node:test'
import { queryPortOnePrintPayment, PortOnePrintPaymentError } from '../../supabase/functions/_shared/portone-print-payment.ts'

// Synthetic provider-shaped fixtures; no merchant credentials or customer data.
const expected = (changes = {}) => ({ paymentId: 'print-fixture-payment-1', storeId: 'store-fixture',
  channelKey: 'channel-key-fixture', amount: 49900, currency: 'KRW', environment: 'test', ...changes })
const receipt = (changes = {}) => ({ status: 'PAID', id: 'print-fixture-payment-1', storeId: 'store-fixture',
  transactionId: 'transaction-fixture', version: 'V2', currency: 'KRW', paidAt: '2026-10-14T00:00:00Z',
  channel: { type: 'TEST', key: 'channel-key-fixture', id: 'channel-fixture', pgProvider: 'TOSSPAYMENTS' },
  amount: { total: 49900, taxFree: 0, paid: 49900, discount: 0, cancelled: 0, cancelledTaxFree: 0 },
  cancellations: [], ...changes })
const options = (payload, changes = {}) => ({ apiSecret: 'synthetic-secret-fixture',
  fetcher: async () => Response.json(payload), ...changes })
const rejectsCode = (promise, code, status = 409) => assert.rejects(promise, error => {
  assert.ok(error instanceof PortOnePrintPaymentError)
  assert.equal(error.code, code)
  assert.equal(error.message, code)
  assert.equal(error.status, status)
  return true
})

test('only GET on the fixed official origin is used, with encoded store query and redirect rejection', async () => {
  const calls = []
  const result = await queryPortOnePrintPayment(expected(), options(receipt(), {
    fetcher: async (url, init) => { calls.push({ url, init }); return Response.json(receipt()) },
  }))
  assert.equal(calls.length, 1)
  assert.equal(calls[0].url.origin, 'https://api.portone.io')
  assert.equal(calls[0].url.pathname, '/payments/print-fixture-payment-1')
  assert.equal(calls[0].url.searchParams.get('storeId'), 'store-fixture')
  assert.equal(calls[0].init.method, 'GET')
  assert.equal(calls[0].init.redirect, 'error')
  assert.equal(calls[0].init.headers.Authorization, 'PortOne synthetic-secret-fixture')
  assert.equal(calls[0].init.body, undefined)
  assert.equal(result.environment, 'test')
  assert.equal(result.isTest, true)
  assert.ok(Object.isFrozen(result))
})

test('a verified live observation requires the configured LIVE channel', async () => {
  const result = await queryPortOnePrintPayment(expected({ environment: 'live' }), options(receipt({
    channel: { type: 'LIVE', key: 'channel-key-fixture' },
  })))
  assert.equal(result.environment, 'live')
  assert.equal(result.isTest, false)
  assert.equal(result.amount, 49900)
})

test('test receipts cannot satisfy live expected payment even if arbitrary callback flags claim success', async () => {
  await rejectsCode(queryPortOnePrintPayment(expected({ environment: 'live' }), options(receipt({
    isTest: false, success: true, productionEnabled: true,
  }))), 'payment_environment_mismatch')
  await rejectsCode(queryPortOnePrintPayment(expected(), options(receipt({
    channel: { type: 'LIVE', key: 'channel-key-fixture' }, isTest: true,
  }))), 'payment_environment_mismatch')
})

test('payment identity and store binding cannot be borrowed from another purchase', async () => {
  for (const changes of [{ id: 'different-payment' }, { storeId: 'different-store' }, { id: undefined }]) {
    await rejectsCode(queryPortOnePrintPayment(expected(), options(receipt(changes))), 'payment_identity_mismatch')
  }
})

test('unknown, missing, or different channel keys and channel types fail closed', async () => {
  for (const channel of [null, {}, { type: 'TEST', key: 'other-channel' }, { type: 'TEST', id: 'channel-key-fixture' }]) {
    await rejectsCode(queryPortOnePrintPayment(expected(), options(receipt({ channel }))), 'payment_channel_mismatch')
  }
  for (const type of [undefined, 'UNRECOGNIZED', 'test', false]) {
    await rejectsCode(queryPortOnePrintPayment(expected(), options(receipt({ channel: { type, key: 'channel-key-fixture' } }))),
      'payment_environment_mismatch')
  }
})

test('unpaid, issued, pending, failed, canceled and partly canceled payments are never paid proof', async () => {
  for (const status of ['READY', 'PENDING', 'VIRTUAL_ACCOUNT_ISSUED', 'FAILED', 'PAY_PENDING',
    'CANCELLED', 'PARTIAL_CANCELLED', 'UNRECOGNIZED', undefined]) {
    await rejectsCode(queryPortOnePrintPayment(expected(), options(receipt({ status }))), 'payment_not_paid')
  }
  await rejectsCode(queryPortOnePrintPayment(expected(), options({ success: true, paymentId: 'print-fixture-payment-1' })), 'payment_not_paid')
})

test('REST V2 version and KRW enum are checked, browser SDK currency aliases are not accepted', async () => {
  for (const version of ['V1', undefined, 'v2']) {
    await rejectsCode(queryPortOnePrintPayment(expected(), options(receipt({ version }))), 'payment_version_mismatch')
  }
  for (const currency of ['USD', 'CURRENCY_KRW', undefined]) {
    await rejectsCode(queryPortOnePrintPayment(expected(), options(receipt({ currency }))), 'payment_currency_mismatch')
  }
})

test('total, actual payment and discount must reconcile with the immutable server amount', async () => {
  const amount = receipt().amount
  for (const changes of [{ total: 49901 }, { paid: 49901 }, { paid: 40000, discount: 0 }, { paid: 49900, discount: 1000 },
    { paid: 0, discount: 49900 }]) {
    await rejectsCode(queryPortOnePrintPayment(expected(), options(receipt({ amount: { ...amount, ...changes } }))), 'payment_amount_mismatch')
  }
  const result = await queryPortOnePrintPayment(expected(), options(receipt({ amount: { ...amount, paid: 48900, discount: 1000 } })))
  assert.equal(result.paidAmount, 48900)
  assert.equal(result.discountAmount, 1000)
  assert.equal(result.amount, 49900)
})

test('missing, fractional, negative, string and unsafe financial fields fail closed', async () => {
  for (const key of ['total', 'paid', 'discount', 'cancelled', 'cancelledTaxFree']) {
    for (const value of [undefined, '0', -1, .5, Number.MAX_SAFE_INTEGER + 1]) {
      await rejectsCode(queryPortOnePrintPayment(expected(), options(receipt({ amount: { ...receipt().amount, [key]: value } }))),
        'invalid_payment_amount', 502)
    }
  }
})

test('PAID with reversed totals or any unresolved cancellation attempt is held for review', async () => {
  for (const key of ['cancelled', 'cancelledTaxFree']) {
    await rejectsCode(queryPortOnePrintPayment(expected(), options(receipt({ amount: { ...receipt().amount, [key]: 1 } }))), 'payment_reversed')
  }
  for (const cancellations of [{}, [{ status: 'REQUESTED' }], [{ status: 'SUCCEEDED', totalAmount: 1 }], [{ status: 'FAILED' }]]) {
    await rejectsCode(queryPortOnePrintPayment(expected(), options(receipt({ cancellations }))), 'payment_cancellation_review_required')
  }
})

test('malformed payment timestamp or missing transaction identity is not proof', async () => {
  for (const changes of [{ paidAt: '' }, { paidAt: 'tomorrow' }, { paidAt: '2026-10-14' },
    { paidAt: '2026-99-14T00:00:00Z' }, { transactionId: undefined }, { transactionId: '' }]) {
    await rejectsCode(queryPortOnePrintPayment(expected(), options(receipt(changes))), 'invalid_payment_response', 502)
  }
})

test('invalid or missing server configuration performs no API request', async () => {
  let calls = 0
  const fetcher = async () => { calls++; assert.fail('unconfigured provider was called') }
  for (const apiSecret of [undefined, '', 'short', 'secret\nfixture', ' secret-fixture']) {
    await rejectsCode(queryPortOnePrintPayment(expected(), { apiSecret, fetcher }), 'payment_provider_unconfigured', 503)
  }
  for (const changes of [{ paymentId: 'https://private.invalid' }, { storeId: 'store?secret' },
    { channelKey: '' }, { amount: 0 }, { amount: '49900' }, { currency: 'USD' }, { environment: 'production' }]) {
    await rejectsCode(queryPortOnePrintPayment(expected(changes), { apiSecret: 'synthetic-secret-fixture', fetcher }),
      'invalid_payment_expectation', 400)
  }
  await rejectsCode(queryPortOnePrintPayment(expected(), { apiSecret: 'synthetic-secret-fixture', fetcher, timeoutMs: 0 }),
    'invalid_payment_timeout', 400)
  assert.equal(calls, 0)
})

test('provider HTTP errors are sanitized without decoding customer data or credentials', async () => {
  for (const [status, code, responseStatus, retryable] of [[401, 'payment_provider_auth_failed', 503, false],
    [403, 'payment_provider_auth_failed', 503, false], [404, 'payment_not_found', 404, true],
    [429, 'payment_provider_unavailable', 503, true], [500, 'payment_provider_unavailable', 503, true],
    [400, 'payment_provider_request_failed', 502, false]]) {
    await assert.rejects(queryPortOnePrintPayment(expected(), options(null, {
      fetcher: async () => Response.json({ message: 'private provider error', customer: { private: true } }, { status }),
    })), error => {
      assert.equal(error.code, code); assert.equal(error.status, responseStatus); assert.equal(error.retryable, retryable)
      assert.doesNotMatch(JSON.stringify(error), /private|customer|secret-fixture/)
      assert.equal(error.message, code)
      return true
    })
  }
})

test('network failures, unexpected JSON, oversized bodies and private responses remain safe errors', async () => {
  await rejectsCode(queryPortOnePrintPayment(expected(), options(null, { fetcher: async () => {
    throw new Error('synthetic-secret-fixture private fetch failure')
  } })), 'payment_provider_unavailable', 503)
  for (const fetcher of [async () => new Response('private html'), async () => Response.json(null),
    async () => Response.json([]), async () => new Response(' '.repeat(1024 * 1024 + 1)),
    async () => new Response(new Uint8Array([0xc3, 0x28])),
    async () => new Response('{}', { headers: { 'Content-Length': '1048577' } })]) {
    await rejectsCode(queryPortOnePrintPayment(expected(), options(null, { fetcher })), 'invalid_payment_response', 502)
  }
})

test('a bounded timeout aborts the lookup and cannot turn it into a payment confirmation', async () => {
  await assert.rejects(queryPortOnePrintPayment(expected(), options(null, {
    timeoutMs: 5,
    fetcher: async (_url, init) => new Promise((_resolve, reject) => {
      init.signal.addEventListener('abort', () => reject(new Error('private timeout context')), { once: true })
    }),
  })), error => error.code === 'payment_lookup_timeout' && error.retryable === true)
})

test('caller mutations during network I/O cannot change the expected identity, amount or environment', async () => {
  const mutable = expected()
  const result = await queryPortOnePrintPayment(mutable, options(null, { fetcher: async () => {
    mutable.amount = 1; mutable.storeId = 'other-store'; mutable.environment = 'live'
    return Response.json(receipt())
  } }))
  assert.equal(result.amount, 49900)
  assert.equal(result.storeId, 'store-fixture')
  assert.equal(result.environment, 'test')
})

test('observations contain only necessary payment evidence and never retain raw customer, card or response fields', async () => {
  const result = await queryPortOnePrintPayment(expected(), options(receipt({ customer: { name: 'synthetic private buyer' },
    method: { type: 'CARD', card: { number: 'private fixture card' } }, pgResponse: 'private pg response',
    receiptUrl: 'https://private.invalid/receipt', customData: 'private album reference' })))
  assert.deepEqual(Object.keys(result).sort(), ['provider', 'version', 'status', 'paymentId', 'transactionId', 'storeId',
    'channelKey', 'amount', 'paidAmount', 'discountAmount', 'currency', 'paidAt', 'environment', 'isTest'].sort())
  assert.doesNotMatch(JSON.stringify(result), /private|customer|receiptUrl|pgResponse/)
})
