import assert from 'node:assert/strict'
import { test } from 'node:test'
import { readFileSync, existsSync } from 'node:fs'
import { stripTypeScriptTypes } from 'node:module'
import vm from 'node:vm'
import { prepareVerifiedOrder, advanceVerifiedOrder } from '../../supabase/functions/_shared/order-fulfillment.ts'

const order = { order_id: 'order-a', user_id: 'owner', status: 'PAYMENT_PENDING', amount: 34900,
  payment_currency: 'KRW', pricing_version: 'PRINT_2026_09', print_content_snapshot: {} }

function database(initial) {
  let row = structuredClone(initial)
  let claims = 0
  let updates = 0
  const db = {
    async rpc(name, args) {
      assert.equal(name, 'claim_print_package')
      claims++
      if (row.status !== 'PAYMENT_COMPLETED' || row.print_package_lock_token) return {data:null,error:null}
      row.print_package_lock_token = args.p_token
      return {data:structuredClone(row),error:null}
    },
    from(table) {
      assert.equal(table,'orders')
      const filters = []; let patch
      const query = {
        select(){return query}, eq(k,v){filters.push(['eq',k,v]);return query}, is(k,v){filters.push(['is',k,v]);return query},
        update(p){patch=p;return query},
        async maybeSingle(){return apply()},
        then(resolve,reject){return Promise.resolve(apply()).then(resolve,reject)},
      }
      function apply() {
        if (!filters.every(([op,k,v]) => (op === 'is' || (v != null && row[k] != null)) && (row[k] ?? null) === v)) return {data:null,error:null}
        if (patch) {row = {...row,...patch};updates++}
        return {data:structuredClone(row),error:null}
      }
      return query
    },
    get row(){return row},get claims(){return claims},get updates(){return updates},
  }
  return db
}
const paidOrder = () => ({...order,status:'PAYMENT_COMPLETED',verified_payment_id:order.order_id,verified_payment_provider:'HISTORICAL_VERIFIED',payment_confirmed_at:'2026-09-01T00:00:00Z'})

test('existing verified orders claim print work once and never regresses delivered orders', async () => {
  const db = database(paidOrder()); let builds=0
  let completeBuild
  const build = async () => {builds++;await new Promise(resolve => completeBuild=resolve);return {patch:{print_asset_count:2}}}
  const first = prepareVerifiedOrder(db, paidOrder(), build)
  await new Promise(resolve => setImmediate(resolve))
  const second = await prepareVerifiedOrder(db, paidOrder(), build)
  assert.equal(second.status,'PAYMENT_COMPLETED');assert.equal(builds,1)
  completeBuild();assert.equal((await first).print_asset_count,2)
  assert.equal(db.row.print_package_lock_token,null)
  const delivered = {...paidOrder(),status:'DELIVERED'}
  assert.equal((await prepareVerifiedOrder(db, delivered, build)).status,'DELIVERED')
  assert.equal(builds,1)
})

test('failed print generation keeps payment confirmed and releases claim for retry', async () => {
  const db=database(paidOrder())
  await assert.rejects(prepareVerifiedOrder(db,paidOrder(),async()=>{throw new Error('storage failed')}),/storage failed/)
  assert.equal(db.row.status,'PAYMENT_COMPLETED');assert.equal(db.row.print_package_lock_token,null)
  await prepareVerifiedOrder(db,paidOrder(),async()=>({patch:{print_asset_count:1}}))
  assert.equal(db.row.print_asset_count,1)
})

test('fulfillment refuses unverified payment and invalid shipping transitions',async()=>{
  const db=database(order)
  await assert.rejects(prepareVerifiedOrder(db,order),/verified_payment_required/)
  await assert.rejects(advanceVerifiedOrder(db,paidOrder(),'shipping',{}),/order_not_ready_for_shipping/)
  assert.equal(db.claims,0);assert.equal(db.updates,0)
})


test('incomplete historical evidence never claims print work or advances shipping', async () => {
  for (const missing of ['verified_payment_id', 'verified_payment_provider', 'payment_confirmed_at']) {
    const row = {...paidOrder(), [missing]: null}
    const db = database(row)
    await assert.rejects(prepareVerifiedOrder(db, row), /verified_payment_required/)
    await assert.rejects(advanceVerifiedOrder(db, {...row, status:'IN_PRODUCTION'}, 'shipping', {
      courier:'courier', trackingNumber:'tracking',
    }), /verified_payment_required/)
    assert.equal(db.claims, 0)
    assert.equal(db.updates, 0)
  }
})

for (const endpoint of ['order-checkout', 'order-confirm-payment']) {
  test(`${endpoint} is a non-mutating 410 for old clients and forged callbacks`, async () => {
    let handler
    let sideEffects = 0
    const forbidden = () => { sideEffects++; throw new Error('payment boundary must not be called') }
    const source = stripTypeScriptTypes(readFileSync(new URL(
      `../../supabase/functions/${endpoint}/index.ts`, import.meta.url), 'utf8').replace(/^import .*$/gm, ''))
    vm.runInNewContext(source, {
      Deno:{serve:f=>handler=f,env:{get:forbidden}}, adminClient:forbidden, getUser:forbidden,
      fetch:forbidden, Response, corsHeaders:{}, jsonResponse:(body,status=200)=>Response.json(body,{status}),
    })
    for (const body of [JSON.stringify({orderId:'order-a',action:'confirm',status:'PAID'}), '{malformed']) {
      const response = await handler(new Request('https://local.test', {method:'POST',body}))
      assert.equal(response.status, 410)
      assert.deepEqual(await response.json(), {error:'physical_order_payments_disabled'})
    }
    assert.equal((await handler(new Request('https://local.test', {method:'GET'}))).status, 410)
    assert.equal((await handler(new Request('https://local.test', {method:'OPTIONS'}))).status, 200)
    assert.equal(sideEffects, 0)
  })
}

test('external payment lookup and webhook entrypoint are removed', () => {
  for (const file of ['_shared/order-payment.ts','_shared/order-webhook.ts','order-payment-webhook/index.ts']) {
    assert.equal(existsSync(new URL(`../../supabase/functions/${file}`,import.meta.url)), false)
  }
})

test('refund already present during print build cannot publish artifacts',async()=>{
  const db=database(paidOrder())
  await assert.rejects(prepareVerifiedOrder(db,paidOrder(),async()=>{
    db.row.payment_reversed_at=new Date().toISOString()
    db.row.status='CANCELED'
    return {patch:{print_asset_count:1}}
  }),/payment_reversed/)
  assert.equal(db.row.status,'CANCELED')
  assert.equal(db.row.print_asset_count,undefined)
})

test('historically verified PRINTING and SHIPPING orders with NULL fulfillment can ship and complete', async () => {
  const original = {...paidOrder(), status:'PRINTING', print_fulfillment_status:null}
  const db = database(original)
  const shipped = await advanceVerifiedOrder(db, original, 'shipping', {courier:'CJ', trackingNumber:'1234567890'})
  assert.equal(shipped.status, 'SHIPPING')
  assert.equal(shipped.print_fulfillment_status, null)
  assert.equal(shipped.courier, 'CJ');assert.equal(shipped.tracking_number, '1234567890');assert.ok(shipped.shipped_at)
  const delivered = await advanceVerifiedOrder(db, shipped, 'delivered', {})
  assert.equal(delivered.status, 'DELIVERED');assert.equal(delivered.print_fulfillment_status, null);assert.ok(delivered.delivered_at)
  assert.equal(delivered.verified_payment_id, original.verified_payment_id);assert.equal(delivered.payment_confirmed_at, original.payment_confirmed_at)
  assert.equal(db.updates, 2)
})

test('NULL and non-NULL fulfillment CAS still reject concurrent status, fulfillment and payment changes', async () => {
  for (const fulfillment of [null, 'ACCEPTED']) {
    for (const [status, action] of [['PRINTING','shipping'], ['SHIPPING','delivered']]) {
      const snapshot = {...paidOrder(), status, print_fulfillment_status:fulfillment}
      const body = {courier:'CJ', trackingNumber:'1234567890'}
      const unchanged = database(snapshot)
      assert.equal((await advanceVerifiedOrder(unchanged, snapshot, action, body)).status, action === 'shipping' ? 'SHIPPING' : 'DELIVERED')
      for (const concurrent of [
        {status:'CANCELED'},
        {print_fulfillment_status:fulfillment == null ? 'AWAITING_RENDER' : null},
        {payment_reversed_at:'2026-09-08T12:00:00Z'},
      ]) {
        const db = database({...snapshot, ...concurrent})
        await assert.rejects(advanceVerifiedOrder(db, snapshot, action, body), error => error.message === 'print_state_changed' && error.status === 409)
        assert.equal(db.updates, 0)
      }
    }
  }
})
