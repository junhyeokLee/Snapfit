import assert from 'node:assert/strict'
import {test} from 'node:test'
import {readFileSync} from 'node:fs'
import {pathToFileURL} from 'node:url'
const {PGlite}=await import(process.env.PGLITE_MODULE?pathToFileURL(process.env.PGLITE_MODULE).href:'@electric-sql/pglite')
const source=n=>readFileSync(new URL(`../../supabase/migrations/${n}`,import.meta.url),'utf8')
const foundation=source('20261013170241_portone_production_print_checkout_foundation.sql')
const ddl=foundation.slice(foundation.indexOf('create table private.print_sales_configuration'),foundation.indexOf('create table private.print_checkout_intents'))
const development=source('20261008064729_redprinting_development_tests.sql')
const sourceDdl=development.slice(development.indexOf('create table public.redprinting_dev_codes'),development.indexOf('insert into public.redprinting_dev_mappings'))
async function fixture(){const db=new PGlite()
 await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;create schema private;create schema auth;create table auth.users(id uuid primary key);
  ${ddl}${sourceDdl}alter table private.print_sales_configuration enable row level security;alter table private.print_sales_combinations enable row level security;
  revoke all on private.print_sales_configuration,private.print_sales_combinations,redprinting_dev_codes,redprinting_dev_mappings from public,anon,authenticated;
  grant usage on schema private,public to service_role;grant select on private.print_sales_configuration to service_role;
  grant select,insert,update on private.print_sales_combinations to service_role;grant select,update on redprinting_dev_codes,redprinting_dev_mappings to service_role;
  insert into redprinting_dev_codes(order_code,use_yn) values('SYNTHETIC_SOFT','Y'),('SYNTHETIC_HARD','Y'),('SYNTHETIC_INVALID','Y');`)
 for(const [id,pages,code,price] of [['REDP_200X150_SOFT',20,'SYNTHETIC_SOFT',{supplyPrice:19300,vatPrice:1930,totalPrice:21230,orderYn:'Y'}],
  ['REDP_300_HARD',80,'SYNTHETIC_HARD',{supplyPrice:92600,vatPrice:9260,totalPrice:101860,orderYn:'Y'}],
  ['REDP_200_SOFT',20,'SYNTHETIC_INVALID',{supplyPrice:19000,vatPrice:0,totalPrice:21230,orderYn:'Y'}]])
  await db.query("insert into redprinting_dev_mappings(product_id,page_count,order_code,exact_match_confirmed,vendor_use_yn,vendor_order_yn,price_snapshot,verified_at) values($1,$2,$3,true,'Y','Y',$4,now())",[id,pages,code,price])
 await db.exec(source('20261014145005_admin_print_sales_drafts.sql'));return db
}
const overview=async(db)=>(await db.query('select read_print_sales_draft_candidates() x')).rows[0].x
const save=async(db,c,v=null,retail=49900)=>(await db.query('select save_print_sales_draft($1,$2,$3,$4,$5,3500,500,$6) x',[c.productId,c.pageCount,c.sourceRevision,v,retail,'synthetic draft'])).rows[0].x
test('staged RPC denies customers and saves only false-approval DRAFT with current observed cost and closed config',async()=>{
 const db=await fixture();try{const rows=await overview(db);assert.equal(rows.length,2);const c=rows.find(x=>x.productId==='REDP_200X150_SOFT')
  const configBefore=(await db.query('select to_jsonb(c) x from private.print_sales_configuration c')).rows[0].x
  await db.exec('set role service_role;');const draft=await save(db,c);assert.equal(draft.draft.estimatedContribution,16680)
  const actual=(await db.query('select * from private.print_sales_combinations')).rows[0]
  for(const key of ['retail_final','supplier_cost_confirmed','shipping_confirmed','packaging_confirmed','spec_approved','file_approved','sample_approved'])assert.equal(actual[key],false)
  assert.equal(actual.cost_snapshot.estimatedPrintCost,21230);assert.equal(actual.cost_snapshot.draftOnly,true);assert.equal(actual.approved_spec,null)
  assert.equal(actual.approval_evidence,'');assert.deepEqual((await db.query('select to_jsonb(c) x from private.print_sales_configuration c')).rows[0].x,configBefore)
  await assert.rejects(db.query('update private.print_sales_configuration set business_ready=true'),/permission denied/)
  await db.exec('reset role;')
  for(const role of ['anon','authenticated']){await db.exec(`set role ${role};`)
   for(const sql of ['select read_print_sales_draft_candidates()',`select save_print_sales_draft('${c.productId}',20,'${c.sourceRevision}',null,49900,3500,500,'x')`,
    'select * from private.print_sales_combinations','select * from redprinting_dev_mappings'])await assert.rejects(db.query(sql),/permission denied/)
   await db.exec('reset role;')}
 }finally{await db.close()}
})
test('draft CAS refuses stale versions and updated provider cost, preserving existing notes until explicit reviewed save',async()=>{
 const db=await fixture();try{const c=(await overview(db)).find(x=>x.pageCount===20),first=await save(db,c)
  await assert.rejects(save(db,c,null),/print_sales_draft_conflict/)
  const next=await save(db,c,first.draft.version,51900);assert.notEqual(first.draft.version,next.draft.version)
  await assert.rejects(save(db,c,first.draft.version),/print_sales_draft_conflict/)
  await db.exec("update redprinting_dev_mappings set price_snapshot=jsonb_build_object('supplyPrice',20000,'vatPrice',2000,'totalPrice',22000,'orderYn','Y'),updated_at=now() where product_id='REDP_200X150_SOFT'")
  await assert.rejects(save(db,c,next.draft.version),/print_sales_draft_source_changed/)
  const updated=(await overview(db)).find(x=>x.productId===c.productId);assert.notEqual(updated.sourceRevision,updated.draft.sourceRevision)
  assert.equal(updated.draft.note,'synthetic draft');assert.equal(updated.observedPrintCost,22000)
  const refreshed=await save(db,updated,next.draft.version);assert.equal(refreshed.draft.sourceRevision,updated.sourceRevision)
 }finally{await db.close()}
})
test('any previously approved record is locked; staged saving cannot erase FINAL or partially reviewed approvals',async()=>{
 const db=await fixture();try{const c=(await overview(db)).find(x=>x.pageCount===20),first=await save(db,c)
  for(const flag of ['retail_final','sample_approved','shipping_confirmed']){
   await db.exec(`update private.print_sales_combinations set ${flag}=true,approval_evidence='synthetic prior real evidence';`)
   const before=(await db.query('select to_jsonb(c) x from private.print_sales_combinations c')).rows[0].x
   assert.equal((await overview(db)).find(x=>x.productId===c.productId).locked,true)
   await assert.rejects(save(db,c,first.draft.version),/print_sales_draft_locked/)
   assert.deepEqual((await db.query('select to_jsonb(c) x from private.print_sales_combinations c')).rows[0].x,before)
   await db.exec(`update private.print_sales_combinations set ${flag}=false;`)
  }
 }finally{await db.close()}
})
test('stale missing-row writer cannot clobber a concurrent first draft or newly approved FINAL at the atomic upsert',async()=>{
 const db=await fixture();try{const candidate=(await overview(db)).find(x=>x.pageCount===20)
  const migration=source('20261014145005_admin_print_sales_drafts.sql')
  const start=migration.indexOf(' insert into private.print_sales_combinations as current_draft(')
  const upsert=migration.slice(start,migration.indexOf(' returning * into c;',start)+' returning * into c;'.length)
  // PGlite has a single backend. Interleave the original missing-row read and
  // another committed writer before executing the exact migration write/CAS.
  // This exercises PostgreSQL's conditional ON CONFLICT, not a JS mock.
  const staleAtomicWrite=async()=>db.exec(`do $$declare m public.redprinting_dev_mappings;c private.print_sales_combinations;
   revision text:='${candidate.sourceRevision}';p_product_id text:='${candidate.productId}';p_page_count integer:=20;p_expected_version uuid:=null;
   p_retail_price integer:=99900;p_shipping_budget integer:=3500;p_packaging_budget integer:=500;p_note text:='stale overwrite';begin
   select * into m from redprinting_dev_mappings where product_id=p_product_id and page_count=p_page_count;
   ${upsert}
   insert into interleave_result values(found);
  end;$$`)
  await db.exec('create temporary table interleave_result(applied boolean)')
  assert.equal((await db.query('select * from private.print_sales_combinations')).rows.length,0)
  const first=await save(db,candidate)
  const beforeDraft=(await db.query('select to_jsonb(c) x from private.print_sales_combinations c')).rows[0].x
  await staleAtomicWrite()
  assert.equal((await db.query('select applied from interleave_result')).rows[0].applied,false)
  assert.deepEqual((await db.query('select to_jsonb(c) x from private.print_sales_combinations c')).rows[0].x,beforeDraft)
  assert.equal(beforeDraft.draft_version,first.draft.version)
  await db.exec('delete from private.print_sales_combinations;truncate interleave_result')
  assert.equal((await db.query('select * from private.print_sales_combinations')).rows.length,0)
  await db.query("insert into private.print_sales_combinations(product_id,page_count,final_price,price_version,retail_final,sample_approved,approval_evidence) values($1,20,49900,'FINAL_SYNTHETIC',true,true,'protected concurrent approval')",[candidate.productId])
  const beforeFinal=(await db.query('select to_jsonb(c) x from private.print_sales_combinations c')).rows[0].x
  await staleAtomicWrite()
  assert.equal((await db.query('select applied from interleave_result')).rows[0].applied,false)
  assert.deepEqual((await db.query('select to_jsonb(c) x from private.print_sales_combinations c')).rows[0].x,beforeFinal)
 }finally{await db.close()}
})
