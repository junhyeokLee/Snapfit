// Exact retail/cost policy validation in isolated PostgreSQL; no supplier or payment calls.
import assert from 'node:assert/strict'
import {test} from 'node:test'
import {readFileSync} from 'node:fs'
import {pathToFileURL} from 'node:url'
const {PGlite}=await import(process.env.PGLITE_MODULE?pathToFileURL(process.env.PGLITE_MODULE).href:'@electric-sql/pglite')
const migration=name=>readFileSync(new URL(`../../supabase/migrations/${name}`,import.meta.url),'utf8')
const initial=migration('20260820140500_initial_snapfit_schema.sql')
const ordersDdl=initial.slice(initial.indexOf('create table if not exists public.orders ('),initial.indexOf('create trigger orders_set_updated_at')).replace("('ord_' || encode(extensions.gen_random_bytes(12), 'hex'))","('ord_' || gen_random_uuid()::text)")
const owner='11111111-1111-1111-1111-111111111111',other='22222222-2222-2222-2222-222222222222'
const products=[
  ['REDP_200X150_SOFT',200,150,49900,2400,22000,1800],
  ['REDP_200_SOFT',200,200,49900,2400,22600,1800],
  ['REDP_250X200_SOFT',250,200,64900,3600,34000,2600],
  ['REDP_250_SOFT',250,250,79900,4400,44000,3200],
  ['REDP_300_SOFT',300,300,99900,6000,60000,4400],
  ['REDP_200X150_HARD',200,150,69900,2400,34000,1800],
  ['REDP_200_HARD',200,200,69900,2400,34600,1800],
  ['REDP_250X200_HARD',250,200,84900,3600,46000,2600],
  ['REDP_250_HARD',250,250,99900,4400,56000,3200],
  ['REDP_300_HARD',300,300,129900,6000,80000,4400],
]
const document=(product)=>JSON.stringify({pages:Array.from({length:20},(_,index)=>({index,isCover:index===0,layers:[]})),...(product?{printProduct:product}:{})})
async function base(db){
  await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;
    create schema auth;create schema storage;create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    grant usage on schema auth,public to authenticated,service_role;
    create table albums(id bigint primary key,owner_id uuid,title text,ratio text,cover_layers_json text);
    create table album_pages(id bigint primary key,album_id bigint,page_index integer,layers_json jsonb);
    create function can_access_album(aid bigint) returns boolean language sql security definer stable as $$select exists(select 1 from public.albums where id=aid and owner_id=auth.uid())$$;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    insert into auth.users values('${owner}'),('${other}');${ordersDdl}
    alter table orders enable row level security;
    create policy orders_own_or_admin_read on orders for select to authenticated using(user_id=auth.uid());`)
  await db.exec(migration('20260908094302_secure_print_order_payments.sql'))
  await db.exec(migration('20260908104605_redprinting_fulfillment_contract.sql'))
}


const v2='20260908114757_redprinting_five_size_contract.sql',v3='20260908120849_redprinting_cover_types_contract.sql',retirement='20260908105146_remove_external_print_payment_integration.sql'
const retail='20261013132908_redprinting_verified_combo_retail_policy.sql'
const exact=(id,pages)=>(id==='REDP_200X150_SOFT'&&pages===20)||(id==='REDP_300_HARD'&&pages===80)
async function ready(db){
  await base(db);await db.exec(migration(retirement));await db.exec(migration(v2));await db.exec(migration(v3))
  for(const [i,[id,w,h]]of products.entries())await db.query('insert into albums values($1,$2,$3,$4,$5)',[i+1,owner,id,String(w/h),document({id,trimWidthMm:w,trimHeightMm:h})])
  await db.exec(`select set_config('request.jwt.claim.sub','${owner}',false);`)
}

test('only two exact combinations get planned retail prices; 308 estimate amounts and every geometry stay frozen',async()=>{
  const db=new PGlite()
  try{
    await ready(db)
    const before=new Map()
    for(const [i,[id]]of products.entries())for(let pages=20;pages<=80;pages+=2){
      before.set(`${id}:${pages}`,(await db.query('select get_print_order_quote($1,$2) q',[i+1,pages])).rows[0].q)
    }
    await db.exec(migration(retail));await db.exec('set role authenticated;')
    let verified=0,unverified=0
    for(const [i,[id]]of products.entries())for(let pages=20;pages<=80;pages+=2){
      const old=before.get(`${id}:${pages}`),q=(await db.query('select get_print_order_quote($1,$2) q',[i+1,pages])).rows[0].q
      assert.equal(q.pricingVersion,'PRINT_REDP_COVERTYPE_V3');assert.equal(q.productCode,id)
      assert.deepEqual(q.spec,old.spec);assert.deepEqual(q.printProduct,old.printProduct)
      assert.equal(q.pageCount,pages);assert.equal(q.sourcePageCount,19);assert.equal(q.addedBlankPageCount,pages-19)
      assert.equal(q.shippingIncluded,true);assert.equal(q.priceIsEstimate,true)
      for(const privateKey of ['estimatedPrintCost','supplierSupplyPrice','supplierVat','supplierOrderCode','paymentFeeRate','print_cost_snapshot'])assert.equal(q[privateKey],undefined)
      if(exact(id,pages)){
        verified++;assert.equal(q.amount,pages===20?49900:159900)
        assert.equal(q.basePages,pages);assert.equal(q.basePrice,q.amount)
        assert.equal(q.extraPageCount,0);assert.equal(q.extraPagePrice,0);assert.equal(q.pricePerTwoPages,0)
        assert.equal(q.supplierCostVerified,true);assert.equal(q.retailPriceStatus,'PLANNED')
        assert.equal(q.pricePolicyVersion,'PRINT_REDP_VERIFIED_COMBO_20261013_V1')
        assert.equal(q.shippingCostVerified,pages===20);assert.equal(q.packagingCostVerified,pages===20)
        assert.match(q.priceNotice,/예정 판매가/)
        if(pages===80)assert.match(q.priceNotice,/배송·포장 비용은 최종 확인/)
      }else{
        unverified++;assert.equal(q.amount,old.amount);assert.equal(q.basePrice,old.basePrice)
        assert.equal(q.extraPageCount,old.extraPageCount);assert.equal(q.extraPagePrice,old.extraPagePrice)
        assert.equal(q.supplierCostVerified,false);assert.equal(q.retailPriceStatus,'PENDING_SUPPLIER_QUOTE')
        assert.equal(q.pricePolicyVersion,'PRINT_REDP_COVERTYPE_ESTIMATE_V3');assert.match(q.priceNotice,/견적 확인 후 판매가/)
      }
    }
    assert.equal(verified,2);assert.equal(unverified,308)
    await assert.rejects(db.query("select print_combo_pricing_policy('REDP_300_HARD',80)"),/permission denied/)
    await db.exec(`select set_config('request.jwt.claim.sub','${other}',false);`)
    await assert.rejects(db.query('select get_print_order_quote(1,20)'),/album_access_denied/)
    await db.exec('reset role;set role anon;')
    await assert.rejects(db.query('select get_print_order_quote(1,20)'),/permission denied/)
  }finally{await db.close()}
})

test('new private cost budgets reflect exact quotes while old snapshots and payment retirement remain unchanged',async()=>{
  const db=new PGlite()
  try{
    await ready(db)
    const historical=(await db.query("select create_print_order(10,80,309900,'UNCONFIGURED','fixture','01012345678','12345','fixture','','') o")).rows[0].o
    const oldOps=(await db.query('select print_cost_snapshot from print_order_operations where order_id=$1',[historical.order_id])).rows[0].print_cost_snapshot
    assert.equal(oldOps.paymentFeeRate,.04);assert.equal(oldOps.estimatedPrintCost,212000)
    await db.exec(migration(retail))
    const preserved=(await db.query('select * from orders where order_id=$1',[historical.order_id])).rows[0]
    assert.equal(preserved.amount,309900);assert.deepEqual(preserved.print_product_snapshot,historical.print_product_snapshot)
    assert.deepEqual((await db.query('select print_cost_snapshot from print_order_operations where order_id=$1',[historical.order_id])).rows[0].print_cost_snapshot,oldOps)
    for(const [album,price,printCost,shipping,packaging,known]of [[1,49900,21230,3500,0,true],[10,159900,101860,3500,1500,false]]){
      const row=(await db.query("select create_print_order($1,$2,$3,'UNCONFIGURED','fixture','01012345678','12345','fixture','','') o",[album,album===1?20:80,price])).rows[0].o
      const cost=(await db.query('select print_cost_snapshot from print_order_operations where order_id=$1',[row.order_id])).rows[0].print_cost_snapshot
      assert.equal(row.pricing_version,'PRINT_REDP_COVERTYPE_V3');assert.equal(row.amount,price)
      assert.equal(cost.version,'REDP_VERIFIED_COMBO_PLANNED_RETAIL_20261013_V1')
      assert.equal(cost.estimatedPrintCost,printCost);assert.equal(cost.estimatedShippingCost,shipping);assert.equal(cost.estimatedPackagingCost,packaging)
      assert.equal(cost.supplierCostVerified,true);assert.equal(cost.shippingCostVerified,known);assert.equal(cost.packagingCostVerified,known)
      assert.equal(cost.isEstimate,!known);assert.equal(cost.paymentFeeRate,.05);assert.equal(cost.reprintReserveRate,.05)
      assert.equal(cost.operationsReserve,3000);assert.equal(cost.minimumContribution,10000)
      assert.equal(cost.supplierQuoteDate,'2026-10-13');assert.equal(cost.supplierSupplyPrice+cost.supplierVat,printCost)
      assert.equal(cost.amount,undefined);assert.equal(cost.priceNotice,undefined)
      assert.ok(price-printCost-shipping-packaging-Math.ceil(price*.05)-Math.ceil(price*.05)-3000>=10000)
    }
    const pending=(await db.query("select print_combo_pricing_policy('REDP_300_HARD',78) p")).rows[0].p
    assert.equal(pending.amount,303900);assert.equal(pending.paymentFeeRate,.04);assert.equal(pending.supplierCostVerified,false)
    for(const pages of [null,19,21,82])await assert.rejects(db.query("select print_combo_pricing_policy('REDP_300_HARD',$1)",[pages]),/invalid_print_page_count/)
    for(const role of ['anon','authenticated','service_role']){
      assert.equal((await db.query("select has_function_privilege($1,'public.create_print_order(bigint,integer,integer,text,text,text,text,text,text,text)','EXECUTE') ok",[role])).rows[0].ok,false)
    }
    await db.exec('set role service_role;')
    const servicePolicy=(await db.query("select print_combo_pricing_policy('REDP_200X150_SOFT',20) p")).rows[0].p
    assert.equal(servicePolicy.estimatedPrintCost,21230)
    await assert.rejects(db.query("select create_print_order(1,20,49900,'UNCONFIGURED','fixture','01012345678','12345','fixture','','')"),/permission denied/)
    await assert.rejects(db.query("update orders set status='PAYMENT_COMPLETED',verified_payment_id='fake',verified_payment_provider='X',payment_confirmed_at=now() where order_id=$1",[historical.order_id]),/physical_order_payments_disabled/)
    assert.equal((await db.query("select to_regprocedure('public.confirm_verified_print_payment(text,text,integer,text)') p")).rows[0].p,null)
  }finally{await db.close()}
})
