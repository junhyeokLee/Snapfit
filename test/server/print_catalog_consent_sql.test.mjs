// Real local PostgreSQL execution; synthetic intents only, no remote orders.
import assert from 'node:assert/strict'
import { test } from 'node:test'
import { readFileSync } from 'node:fs'
import { pathToFileURL } from 'node:url'
import { printCheckoutConsent } from '../../supabase/functions/_shared/print-checkout-consent.ts'
const { PGlite }=await import(process.env.PGLITE_MODULE?pathToFileURL(process.env.PGLITE_MODULE).href:'@electric-sql/pglite')
const migration=readFileSync(new URL('../../supabase/migrations/20261018183536_print_public_catalog_and_order_consent.sql',import.meta.url),'utf8')
const owner='11111111-1111-4111-8111-111111111111',other='22222222-2222-4222-8222-222222222222',id='33333333-3333-4333-8333-333333333333'
async function fixture(){const db=new PGlite();await db.exec(`
 create role anon;create role authenticated;create role service_role bypassrls;create schema private;
 create table private.print_supplier_quotes(product_id text,page_count integer,confirmed boolean,quantity integer);
 create table public.redprinting_dev_codes(order_code text primary key,use_yn text);
 create table public.redprinting_dev_mappings(product_id text,page_count integer,order_code text,exact_match_confirmed boolean,vendor_use_yn text,vendor_order_yn text);
 create table private.fixture_prices(product_id text,page_count integer,amount integer,approved boolean);
 create function public.print_combo_pricing_policy(p_product_id text,p_pages integer) returns jsonb language sql stable as $$
  select jsonb_build_object('amount',amount,'pricePolicyVersion','PLANNED_TEST_V1','supplierCostVerified',approved,'retailPriceStatus','PLANNED')
  from private.fixture_prices where product_id=p_product_id and page_count=p_pages $$;
 create table private.print_checkout_intents(id uuid primary key,user_id uuid,payment_id text,request_id uuid,reviewed_revision text,
  reviewed_spec_revision text,amount integer,status text,sdk_issued_at timestamptz);
 create function public.prepare_production_print_checkout(p_actor uuid,p_request_id uuid,p_album_id bigint,p_source_digest text,
  p_reviewed_revision text,p_reviewed_spec_revision text,p_expected_amount integer,p_page_count integer,p_recipient jsonb)
 returns jsonb language sql as $$select to_jsonb(i) from private.print_checkout_intents i where i.user_id=p_actor and i.request_id=p_request_id$$;
 grant usage on schema public,private to service_role;
 grant select,insert,update on all tables in schema private to service_role;
 grant select on public.redprinting_dev_codes,public.redprinting_dev_mappings to service_role;
 insert into private.print_checkout_intents values('${id}','${owner}','SFP_${id}','${id}',repeat('a',64),repeat('b',64),49900,'PREPARED',null);
 insert into private.print_supplier_quotes values('REDP_200_SOFT',20,true,1),('REDP_300_HARD',80,true,1),('REDP_200_SOFT',22,false,1);
 insert into private.fixture_prices values('REDP_200_SOFT',20,49900,true),('REDP_300_HARD',80,159900,true),('REDP_200_SOFT',22,59900,false);
 insert into public.redprinting_dev_codes values('private-code','Y');
 insert into public.redprinting_dev_mappings values('REDP_300_HARD',80,'private-code',true,'Y','Y');
 `);await db.exec(migration);return db}
const record=(db,actor=owner,consent=printCheckoutConsent)=>db.query('select public.record_print_checkout_consent($1,$2,$3)',[actor,`SFP_${id}`,JSON.stringify(consent)])
test('public projection follows exact source prices, includes only confirmed quotes and reveals no supplier costs/code',async()=>{
 const db=await fixture();try{
  const read=async()=>(await db.query('select public.read_print_public_catalog() value')).rows[0].value;
  let rows=await read();assert.equal(rows.length,2);assert.equal(rows[0].retailPrice,49900);assert.equal(rows[0].orderCodeApproved,false);
  assert.equal(rows[1].orderCodeApproved,true);assert.equal(JSON.stringify(rows).includes('private-code'),false);
  assert.equal(rows[0].shippingFee,0);assert.equal(rows[0].shippingIncluded,true);assert.equal(rows[0].priceIsEstimate,true);
  await db.exec("update private.fixture_prices set amount=50900 where product_id='REDP_200_SOFT' and page_count=20");rows=await read();assert.equal(rows[0].retailPrice,50900);
 }finally{await db.close()}
})
test('public/authenticated database callers cannot invoke service projections or read consent evidence',async()=>{
 const db=await fixture();try{
  for(const role of ['anon','authenticated'])for(const sql of ['select public.read_print_public_catalog()',`select public.record_print_checkout_consent('${owner}','SFP_${id}','{}')`,'select * from private.print_checkout_consents']){
   await db.exec('set role '+role);await assert.rejects(db.exec(sql),/permission denied/);await db.exec('reset role');
  }
 }finally{await db.close()}
})
test('consent binds server timestamps, immutable album/spec/price evidence and idempotence to the correct actor',async()=>{
 const db=await fixture();try{
  await assert.rejects(record(db,other),/print_checkout_not_found/);
  for(const consent of [{...printCheckoutConsent,policyAccepted:false},{...printCheckoutConsent,customProductionAccepted:false},{...printCheckoutConsent,acceptedAt:'forged'}])
   await assert.rejects(record(db,owner,consent),/print_checkout_consent_required/);
  await db.exec('set role service_role');await record(db);await record(db);await db.exec('reset role');
  const c=(await db.query('select * from private.print_checkout_consents')).rows;assert.equal(c.length,1);assert.equal(c[0].user_id,owner);
  assert.deepEqual(c[0].consent,printCheckoutConsent);assert.equal(c[0].reviewed_revision,'a'.repeat(64));assert.equal(c[0].reviewed_spec_revision,'b'.repeat(64));assert.equal(c[0].amount,49900);
  assert.ok(Math.abs(Date.now()-new Date(c[0].accepted_at).getTime())<30000);
  await assert.rejects(db.exec('update private.print_checkout_consents set amount=1'),/print_consent_immutable/);
  await assert.rejects(db.exec('delete from private.print_checkout_consents'),/print_consent_immutable/);
 }finally{await db.close()}
})
test('no SDK authorization without complete bound consent, including alternate entry points',async()=>{
 const db=await fixture();try{
  await assert.rejects(db.exec("update private.print_checkout_intents set sdk_issued_at=now()"),/print_checkout_consent_required/);
  await record(db);await db.exec("update private.print_checkout_intents set sdk_issued_at=now()");
  assert.ok((await db.query('select sdk_issued_at from private.print_checkout_intents')).rows[0].sdk_issued_at);
 }finally{await db.close()}
})
