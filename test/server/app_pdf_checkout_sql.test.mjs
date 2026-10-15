import test from 'node:test'
import assert from 'node:assert/strict'
import { fixture, prepare, commit, receipt, owner, worker } from './fixtures/app_pdf_database.mjs'

// Logical database proof fixtures only. Real raster bytes go through the actual
// owner API/strict inspector in print_prepayment_sql.test.mjs.
async function readyPackage(db, i) {
  const refs=[owner,i.request_id,i.order_id,i.payment_id]
  const fingerprint='f'.repeat(64), spec=i.approved_spec
  const report={renderer:'flutter-layer-builder-raster-v1',sourceFingerprint:fingerprint,specVersion:spec.specVersion,
    productId:i.product.id,coverType:spec.coverType,pageCount:i.page_count,dpi:300,colorSpace:'sRGB',iccProfileEmbedded:true,
    missingAssets:[],warnings:[],declaredFiles:{cover:{bytes:512,sha256:'a'.repeat(64)},interior:{bytes:1024,sha256:'b'.repeat(64)}}}
  const created=(await db.query("select print_prepayment_package($1,'uploads',$2,$3,$4,null,null,$5,$6) x",[
    ...refs,{sourceFingerprint:fingerprint,specVersion:spec.specVersion},report])).rows[0].x.package
  for(const kind of ['cover','interior']) {
    const hard=kind==='cover', result={pageCount:hard?1:i.page_count,widthMm:hard?spec.cover.widthMm:spec.interior.trimWidthMm+2*spec.interior.bleedMm,
      heightMm:hard?spec.cover.heightMm:spec.interior.trimHeightMm+2*spec.interior.bleedMm,byteLength:report.declaredFiles[kind].bytes,sha256:report.declaredFiles[kind].sha256}
    await db.query("select print_prepayment_package($1,'finalize',$2,$3,$4,$5,$6,$7,$8)",[...refs,created.id,kind,result,report])
  }
  return (await db.query("select print_prepayment_package($1,'seal',$2,$3,$4,$5) x",[...refs,created.id])).rows[0].x.package
}

test('an authoritative late payment without issued SDK files is recorded for review and never manufactured',async()=>{
  const db=await fixture();try {
    const i=await prepare(db), paid=await commit(db,i)
    assert.equal(paid.status,'PAID')
    const order=(await db.query('select * from orders')).rows[0]
    assert.equal(order.status,'PAYMENT_COMPLETED');assert.equal(order.print_requires_action,true)
    assert.equal((await db.query('select count(*) n from private.print_fulfillment_outbox')).rows[0].n,0)
    assert.equal((await db.query('select claim_print_app_pdf_fulfillment_job($1,1,120,true) x',[worker])).rows[0].x,null)
  }finally{await db.close()}
})
test('a cancellation racing an already issued SDK retains the payment receipt and holds new manufacturing',async()=>{
  const db=await fixture();try {
    const i=await prepare(db);await readyPackage(db,i)
    await db.query('select authorize_print_app_pdf_checkout($1,$2)',[owner,i.payment_id])
    await db.query("select create_owned_print_order_request($1,$2,'CANCEL','synthetic pending request',$3,null,null)",[
      owner,'77777777-7777-4777-8777-777777777777',i.order_id])
    const paid=await commit(db,i);assert.equal(paid.status,'PAID')
    const order=(await db.query('select * from orders')).rows[0]
    assert.equal(order.status,'PAYMENT_COMPLETED');assert.equal(order.print_customer_request_hold,true)
    assert.equal(order.print_requires_action,true)
    assert.equal((await db.query('select count(*) n from private.print_fulfillment_outbox')).rows[0].n,0)
  }finally{await db.close()}
})
test('the app PDF scheduler never claims a RENDER stage and cannot use a stale private artifact',async()=>{
  const db=await fixture();try {
    const i=await prepare(db);await readyPackage(db,i);await db.query('select authorize_print_app_pdf_checkout($1,$2)',[owner,i.payment_id]);await commit(db,i)
    await db.exec("update private.print_fulfillment_outbox set event_type='RENDER'")
    assert.equal((await db.query('select claim_print_app_pdf_fulfillment_job($1,1,120,true) x',[worker])).rows[0].x,null)
    await db.exec("update private.print_fulfillment_outbox set event_type='SUBMIT'")
    const claim=(await db.query('select claim_print_app_pdf_fulfillment_job($1,1,120,true) x',[worker])).rows[0].x
    assert.equal(claim.job.event_type,'SUBMIT');assert.equal(claim.order.print_fulfillment_status,'READY')
    await assert.rejects(db.query("update orders set print_manifest=jsonb_set(print_manifest,'{interior,sha256}','\"forged\"') where order_id=$1",[i.order_id]),/print_paid_file_binding_immutable/)
    await assert.rejects(db.exec("update private.print_prepayment_packages set renderer_manifest='{}'"),/print_prepayment_immutable/)
  }finally{await db.close()}
})
test('TTL cleanup keeps all paid files and any expired invoice for which an SDK was issued',async()=>{
  const db=await fixture();try {
    const paid=await prepare(db);await readyPackage(db,paid);await db.query('select authorize_print_app_pdf_checkout($1,$2)',[owner,paid.payment_id]);await commit(db,paid)
    const uncertain=await prepare(db,{request:'88888888-8888-4888-8888-888888888888'});await readyPackage(db,uncertain)
    await db.query('select authorize_print_app_pdf_checkout($1,$2)',[owner,uncertain.payment_id])
    const unissued=await prepare(db,{request:'99999999-9999-4999-8999-999999999999'});const removable=await readyPackage(db,unissued)
    // Clock-advance fixture only; production purchase expiry cannot be edited.
    await db.exec("alter table private.print_checkout_intents disable trigger user;alter table private.print_prepayment_packages disable trigger user;")
    await db.exec("update private.print_checkout_intents set expires_at=now()-interval '2 hours';update private.print_prepayment_packages set expires_at=now()-interval '2 hours';")
    await db.exec('alter table private.print_checkout_intents enable trigger user;alter table private.print_prepayment_packages enable trigger user;')
    const selected=(await db.query('select claim_abandoned_print_prepayment_packages(1) x')).rows[0].x
    assert.equal(selected.length,1);assert.equal(selected[0].id,removable.id)
    assert.equal(selected[0].paths.length,3)
    await db.query('select finish_abandoned_print_prepayment_package($1,true)',[removable.id])
    assert.deepEqual((await db.query('select claim_abandoned_print_prepayment_packages(1) x')).rows[0].x,[])
    assert.deepEqual((await db.query("select state from private.print_prepayment_packages where id<>$1 order by id",[removable.id])).rows.map(v=>v.state),['READY','READY'])
  }finally{await db.close()}
})
