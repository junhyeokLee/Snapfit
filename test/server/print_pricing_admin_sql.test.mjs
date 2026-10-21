// Isolated PostgreSQL fixtures; optional reviewed WEBSITE seed stays local to PGlite.
// Never contacts a supplier, PG or remote DB.
import assert from 'node:assert/strict'
import {test} from 'node:test'
import {readFileSync} from 'node:fs'
import {pathToFileURL} from 'node:url'
const {PGlite}=await import(process.env.PGLITE_MODULE?pathToFileURL(process.env.PGLITE_MODULE).href:'@electric-sql/pglite')
const migration=name=>readFileSync(new URL(`../../supabase/migrations/${name}`,import.meta.url),'utf8')
const revision='20261018174925_redprinting_supplier_quote_retail_matrix.sql'
const adminRevision='20261018181356_admin_print_retail_price_overrides.sql'
const functions=['20260908094302_secure_print_order_payments.sql','20260908104605_redprinting_fulfillment_contract.sql',
  '20260908105146_remove_external_print_payment_integration.sql','20260908114757_redprinting_five_size_contract.sql',
  '20260908120849_redprinting_cover_types_contract.sql','20261013132908_redprinting_verified_combo_retail_policy.sql',
  '20261013170241_portone_production_print_checkout_foundation.sql']
const initial=migration('20260820140500_initial_snapfit_schema.sql')
const ordersDdl=initial.slice(initial.indexOf('create table if not exists public.orders ('),initial.indexOf('create trigger orders_set_updated_at'))
  .replace("('ord_' || encode(extensions.gen_random_bytes(12), 'hex'))","('ord_' || gen_random_uuid()::text)")
const owner='11111111-1111-4111-8111-111111111111',other='22222222-2222-4222-8222-222222222222'
const products=[['REDP_200X150_SOFT',200,150],['REDP_200_SOFT',200,200],['REDP_250X200_SOFT',250,200],['REDP_250_SOFT',250,250],['REDP_300_SOFT',300,300],
  ['REDP_200X150_HARD',200,150],['REDP_200_HARD',200,200],['REDP_250X200_HARD',250,200],['REDP_250_HARD',250,250],['REDP_300_HARD',300,300]]
const options={coverPaper:'synthetic cover stock',coverFinish:'synthetic matte',interiorPaper:'synthetic Glossy 285g',interiorPrint:'synthetic RGB color'}
const quoteRow=(id='REDP_200_SOFT',pages=20,total=21230,changes={})=>({product_id:id,page_count:pages,quantity:1,currency:'KRW',
  supply_price:Math.floor(total/1.1),vat_price:total-Math.floor(total/1.1),total_price:total,source:'WEBSITE',observed_at:new Date(Date.now()-10*60*1000).toISOString(),
  evidence:'Synthetic fixture observation, never a production quote',options,confirmed:true,...changes})
const rows=()=>products.flatMap(([id],index)=>Array.from({length:31},(_,page)=>quoteRow(id,20+page*2,
  id==='REDP_200X150_SOFT'&&page===0?21230:id==='REDP_300_HARD'&&page===30?101860:21230+index*5000+page*1000)))
const document=product=>JSON.stringify({printProduct:product,pages:Array.from({length:21},(_,index)=>({index,isCover:index===0,layers:[]}))})
async function fixture({apply=true}={}){
  const db=new PGlite()
  await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;create schema auth;create schema storage;
    create table auth.users(id uuid primary key,raw_app_meta_data jsonb);
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    grant usage on schema auth,public to authenticated,service_role;
    create table albums(id bigint primary key,owner_id uuid,title text,ratio text,cover_theme text,cover_layers_json text);
    create table album_pages(id bigint primary key,album_id bigint,page_index integer,layers_json jsonb);
    create table album_members(album_id bigint,user_id uuid,role text);
    create function can_access_album(aid bigint) returns boolean language sql security definer stable as $$select exists(select 1 from public.albums where id=aid and owner_id=auth.uid())$$;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    insert into auth.users values('${owner}','{"role":"admin"}'),('${other}','{"role":"customer"}');${ordersDdl}
    alter table orders enable row level security;create policy own_order_read on orders for select to authenticated using(user_id=auth.uid());`)
  for(const name of functions)await db.exec(migration(name))
  for(const [index,[id,width,height]]of products.entries())await db.query('insert into albums values($1,$2,$3,$4,null,$5)',
    [index+1,owner,'synthetic quote album',String(width/height),document({id,trimWidthMm:width,trimHeightMm:height})])
  await db.exec(`grant select,update on albums to service_role;grant select on album_pages,album_members to service_role;
    select set_config('request.jwt.claim.sub','${owner}',false);`)
  const development=migration('20261008064729_redprinting_development_tests.sql')
  await db.exec(development.slice(development.indexOf('create table public.redprinting_dev_codes'),development.indexOf('insert into public.redprinting_dev_mappings')))
  await db.exec(`alter table redprinting_dev_codes enable row level security;alter table redprinting_dev_mappings enable row level security;
    revoke all on redprinting_dev_codes,redprinting_dev_mappings from public,anon,authenticated;
    grant select,insert,update,delete on redprinting_dev_codes,redprinting_dev_mappings to service_role;`)
  if(apply){await db.exec(migration(revision));await db.exec(migration(adminRevision))}
  return db
}
async function seed(db,observations=rows()){
  await db.query(`insert into private.print_supplier_quotes(product_id,page_count,quantity,currency,supply_price,vat_price,total_price,source,observed_at,evidence,options,confirmed)
    select product_id,page_count,quantity,currency,supply_price,vat_price,total_price,source,observed_at,evidence,options,confirmed
    from jsonb_to_recordset($1::jsonb) as q(product_id text,page_count integer,quantity integer,currency text,supply_price integer,vat_price integer,total_price integer,
      source text,observed_at timestamptz,evidence text,options jsonb,confirmed boolean)`,[JSON.stringify(observations)])
}
const policy=async(db,id,pages)=>(await db.query('select print_combo_pricing_policy($1,$2) q',[id,pages])).rows[0].q
const quote=async(db,id,pages)=>(await db.query('select get_print_order_quote($1,$2) q',[id,pages])).rows[0].q
const budget=async(db,cost,shipping=3500,packaging=0)=>(await db.query('select private.print_quote_retail_budget($1,$2,$3) q',[cost,shipping,packaging])).rows[0].q
const contribution=(retail,cost,shipping,packaging)=>retail-cost-shipping-packaging-2*Number((BigInt(retail)+19n)/20n)-3000
const assertNoPrivateQuote=q=>{
  for(const field of ['estimatedPrintCost','estimatedShippingCost','estimatedPackagingCost','supplierSupplyPrice','supplierVat','supplierOrderCode','supplierQuoteSource',
    'supplierQuoteQuantity','paymentFeeRate','paymentFeeReserve','estimatedContribution','minimumContributionRate','options','evidence','cost_snapshot'])assert.equal(q[field],undefined,field)
}

const overview=async(db,actor=owner)=>(await db.query('select read_print_pricing_admin($1) q',[actor])).rows[0].q
const one=async(db,id='REDP_200_SOFT',pages=20)=>(await overview(db)).find(x=>x.productId===id&&x.pageCount===pages)
const mutate=async(db,row,{actor=owner,action='save',retail=59900,shipping=3500,packaging=0,note='Synthetic audited price adjustment',source=row.source.revision,version=row.effective.priceVersion}={})=>
 (await db.query('select mutate_print_pricing_admin($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) q',[actor,action,row.productId,row.pageCount,source,version,
  action==='save'?retail:null,action==='save'?shipping:null,action==='save'?packaging:null,note])).rows[0].q
const frozen=async db=>(await db.query(`select jsonb_build_object('configuration',(select to_jsonb(c) from private.print_sales_configuration c),
 'combinations',(select coalesce(jsonb_agg(to_jsonb(c)),'[]') from private.print_sales_combinations c),'orders',(select count(*) from orders),
 'intents',(select count(*) from private.print_checkout_intents)) q`)).rows[0].q

test('all 310 actual supplier records list exact manufacture VAT, recommendation and private budget margins with unchanged closed gates',async()=>{
 const db=await fixture();try{
  await db.exec(migration('20261018180055_redprinting_supplier_quote_observations.sql'))
  const before=await frozen(db),all=await overview(db)
  assert.equal(all.length,310);assert.equal(new Set(all.map(x=>`${x.productId}:${x.pageCount}`)).size,310)
  for(const row of all){assert.equal(row.source.supplyPrice+row.source.vatPrice,row.source.totalPrice);assert.match(row.source.revision,/^[a-f0-9]{64}$/)
   assert.equal(row.effective.retailPriceStatus,'PLANNED');assert.equal(row.override,null);assert.equal(row.locked,false)
   assert.equal(row.recommended.retailPrice,row.effective.retailPrice);assert.ok(row.effective.estimatedContribution>=10000);assert.ok(row.effective.estimatedContribution*5>=row.effective.retailPrice)
   assert.equal(row.effective.estimatedContribution,contribution(row.effective.retailPrice,row.source.totalPrice,row.effective.shippingBudget,row.effective.packagingBudget))
  }
  const soft=all.find(x=>x.productId==='REDP_200_SOFT'&&x.pageCount===20),hard=all.find(x=>x.productId==='REDP_300_HARD'&&x.pageCount===80)
  assert.equal(soft.source.totalPrice,21230);assert.equal(soft.effective.retailPrice,49900);assert.equal(soft.effective.estimatedContribution,17180)
  assert.equal(hard.source.totalPrice,101860);assert.equal(hard.effective.retailPrice,159900);assert.equal(hard.effective.estimatedContribution,34050)
  assert.deepEqual(await frozen(db),before)
 }finally{await db.close()}
})

test('save updates new public owner quote and price version, budgets and audit but never sales approvals/order snapshots',async()=>{
 const db=await fixture();try{
  await seed(db,[quoteRow()]);const original=await one(db),before=await frozen(db)
  await db.exec('set role service_role')
  const saved=await mutate(db,original,{retail:59901,shipping:4000,packaging:500})
  assert.equal(saved.effective.retailPrice,59901);assert.equal(saved.effective.estimatedContribution,25179)
  assert.equal(saved.override.note,'Synthetic audited price adjustment');assert.equal(saved.override.stale,false)
  assert.notEqual(saved.effective.priceVersion,original.effective.priceVersion);assert.equal(saved.effective.retailPriceStatus,'PLANNED')
  await db.exec('reset role;set role authenticated')
  const publicQuote=await quote(db,2,20);assert.equal(publicQuote.amount,59901);assert.equal(publicQuote.pricePolicyVersion,saved.effective.priceVersion);assertNoPrivateQuote(publicQuote)
  assert.doesNotMatch(JSON.stringify(publicQuote),/Synthetic audited|sourceRevision|updatedBy|override|contributionRate|shippingBudget|packagingBudget/)
  await db.exec('reset role;set role service_role')
  const context=(await db.query('select load_owned_print_checkout_context($1,2) q',[owner])).rows[0].q
  assert.equal(context.quote.amount,59901);assert.equal(context.canPay,false);assert.equal(context.configuration.enabled,false)
  const history=(await db.query('select * from private.print_retail_price_audit')).rows[0]
  assert.equal(history.action,'SAVE');assert.equal(history.actor_id,owner);assert.equal(history.before_record,null);assert.equal(history.after_record.retail_price,59901)
  assert.deepEqual(await frozen(db),before)
 }finally{await db.close()}
})

test('optimistic price CAS blocks stale save/reset and exact-source change invalidates override instead of reusing stale costs',async()=>{
 const db=await fixture();try{
  await seed(db,[quoteRow()]);const original=await one(db),saved=await mutate(db,original)
  await assert.rejects(mutate(db,original),/print_pricing_conflict/)
  await assert.rejects(mutate(db,original,{action:'reset'}),/print_pricing_conflict/)
  await db.exec("update private.print_supplier_quotes set supply_price=supply_price+1000,vat_price=vat_price+100,total_price=total_price+1100,observed_at=clock_timestamp() where product_id='REDP_200_SOFT'")
  const refreshed=await one(db);assert.notEqual(refreshed.source.revision,saved.source.revision);assert.equal(refreshed.override.stale,true)
  assert.equal(refreshed.effective.retailPrice,refreshed.recommended.retailPrice);assert.notEqual(refreshed.effective.priceVersion,saved.effective.priceVersion)
  await assert.rejects(mutate(db,saved),/print_pricing_source_changed/)
  const renewed=await mutate(db,refreshed,{retail:69900});assert.equal(renewed.override.stale,false);assert.equal(renewed.effective.retailPrice,69900)
  assert.notEqual(renewed.override.version,saved.override.version)
  assert.equal((await db.query('select count(*) n from private.print_retail_price_audit')).rows[0].n,2)
 }finally{await db.close()}
})

test('reset uses current CAS and source to restore recommendation, records previous values, rejects reuse of old override version',async()=>{
 const db=await fixture();try{
  await seed(db,[quoteRow()]);const saved=await mutate(db,await one(db)),reset=await mutate(db,saved,{action:'reset',note:'Restore recommendation after review'})
  assert.equal(reset.override,null);assert.equal(reset.effective.retailPrice,49900);assert.equal(reset.effective.priceVersion,reset.recommended.priceVersion??(await policy(db,'REDP_200_SOFT',20)).pricePolicyVersion)
  await assert.rejects(mutate(db,saved,{retail:69900}),/print_pricing_conflict/)
  const history=(await db.query('select * from private.print_retail_price_audit order by created_at')).rows
  assert.equal(history.length,2);assert.equal(history[1].action,'RESET');assert.equal(history[1].before_record.retail_price,59900);assert.equal(history[1].after_record,null)
 }finally{await db.close()}
})

test('invalid money, blank reasons and both contribution limits are enforced atomically with no audit mutation',async()=>{
 const db=await fixture();try{
  await seed(db,[quoteRow()]);const original=await one(db)
  for(const change of [{retail:1},{retail:39900,shipping:3500,packaging:5000},{retail:100000000,shipping:10000000,packaging:10000000,note:''},
   {retail:0},{retail:100000001},{shipping:-1},{packaging:10000001},{note:' '.repeat(2)},{note:'x'.repeat(1001)},{source:'bad'},{version:'bad value'}])
   await assert.rejects(mutate(db,original,change),/invalid_print_pricing|print_pricing_margin_too_low/)
  // >=10,000 but <20% must fail as well: 49,900 -21,230 -3,500 -11,000 -4,990 -3,000=6,180; use higher source cost for boundary.
  await db.exec("update private.print_supplier_quotes set supply_price=60000,vat_price=6000,total_price=66000")
  const costly=await one(db);await assert.rejects(mutate(db,costly,{retail:99900,shipping:3500,packaging:5000}),/print_pricing_margin_too_low/)
  assert.equal((await db.query('select count(*) n from private.print_retail_price_audit')).rows[0].n,0)
  assert.equal((await db.query('select count(*) n from private.print_retail_price_overrides')).rows[0].n,0)
 }finally{await db.close()}
})

test('fresh DB app metadata authorization defeats revoked administrator and forged user-metadata access',async()=>{
 const db=await fixture();try{
  await seed(db,[quoteRow()]);const original=await one(db)
  await assert.rejects(overview(db,other),/forbidden/);await assert.rejects(mutate(db,original,{actor:other}),/forbidden/)
  await db.exec("update auth.users set raw_app_meta_data='{}' where id='11111111-1111-4111-8111-111111111111'")
  await assert.rejects(overview(db),/forbidden/);await assert.rejects(mutate(db,original),/forbidden/)
  assert.equal((await db.query('select count(*) n from private.print_retail_price_audit')).rows[0].n,0)
 }finally{await db.close()}
})

test('private tables/RPC grants deny customers and append-only audit rejects mutations even for table owner',async()=>{
 const db=await fixture();try{
  await seed(db,[quoteRow()]);await mutate(db,await one(db))
  for(const role of ['anon','authenticated']){
   await db.exec(`set role ${role}`)
   for(const sql of [`select read_print_pricing_admin('${owner}')`,`select mutate_print_pricing_admin('${owner}','reset','REDP_200_SOFT',20,'${'a'.repeat(64)}','V1',null,null,null,'reason')`,
    'select * from private.print_retail_price_overrides','select * from private.print_retail_price_audit','select private.print_pricing_admin_row(\'REDP_200_SOFT\',20)'])await assert.rejects(db.query(sql),/permission denied/)
   await db.exec('reset role')
  }
  await db.exec('set role service_role')
  for(const sql of ['delete from private.print_retail_price_overrides','update private.print_retail_price_audit set note=\'changed\'','delete from private.print_retail_price_audit'])
   await assert.rejects(db.query(sql),/permission denied/)
  await db.exec('reset role')
  for(const sql of ['update private.print_retail_price_audit set note=\'changed\'','delete from private.print_retail_price_audit'])await assert.rejects(db.query(sql),/print_pricing_audit_immutable/)
  for(const table of ['print_retail_price_overrides','print_retail_price_audit','print_retail_price_revisions'])assert.equal((await db.query(`select relrowsecurity b from pg_class where oid='private.${table}'::regclass`)).rows[0].b,true)
 }finally{await db.close()}
})

const finalCosts={estimatedPrintCost:21230,estimatedShippingCost:3500,estimatedPackagingCost:0,paymentFeeRate:.04,reprintReserveRate:.05,operationsReserve:3000,minimumContribution:10000}
test('valid FINAL financial record wins and is locked; old DRAFT record cannot suppress planned override',async()=>{
 const db=await fixture();try{
  await seed(db,[quoteRow()]);const saved=await mutate(db,await one(db))
  await db.query(`insert into private.print_sales_combinations(product_id,page_count,final_price,price_version,cost_snapshot) values('REDP_200_SOFT',20,199900,'DRAFT_V1',$1)`,[{...finalCosts,draftOnly:true}])
  assert.equal((await one(db)).effective.retailPrice,59900)
  await db.query(`update private.print_sales_combinations set final_price=69900,price_version='SYNTHETIC_FINAL_V1',retail_final=true,supplier_cost_confirmed=true,shipping_confirmed=true,
   packaging_confirmed=true,order_code='SYNTHETIC_FINAL_CODE',approval_evidence='Synthetic approved final financial record',cost_snapshot=$1`,[finalCosts])
  const final=await one(db);assert.equal(final.effective.retailPriceStatus,'FINAL');assert.equal(final.locked,true);assert.equal(final.effective.retailPrice,69900)
  assert.equal(final.effective.paymentFeeReserve,2796);assert.equal(final.effective.estimatedContribution,35879)
  await assert.rejects(mutate(db,saved),/print_pricing_locked/);await assert.rejects(mutate(db,final,{action:'reset'}),/print_pricing_locked/)
  assert.equal((await db.query('select count(*) n from private.print_retail_price_audit')).rows[0].n,1)
 }finally{await db.close()}
})

test('reset does not revive an original recommended CAS version, including repeated resets and changed-source defaults',async()=>{
 const db=await fixture();try{
  await seed(db,[quoteRow()]);const original=await one(db),saved=await mutate(db,original),reset=await mutate(db,saved,{action:'reset'})
  assert.notEqual(reset.effective.priceVersion,original.effective.priceVersion)
  await assert.rejects(mutate(db,original),/print_pricing_conflict/)
  const second=await mutate(db,reset,{action:'reset'});assert.notEqual(second.effective.priceVersion,reset.effective.priceVersion)
  await assert.rejects(mutate(db,reset),/print_pricing_conflict/)
  await db.exec("update private.print_supplier_quotes set supply_price=supply_price+1,total_price=total_price+1")
  const refreshed=await one(db);assert.notEqual(refreshed.effective.priceVersion,second.effective.priceVersion)
  assert.equal(refreshed.effective.retailPrice,refreshed.recommended.retailPrice)
 }finally{await db.close()}
})

test('catalog save/reset never rewrite an existing customer order or sealed checkout amount and snapshots',async()=>{
 const db=await fixture();try{
  await seed(db,[quoteRow()]);const original=await one(db)
  await db.query(`insert into orders(order_id,user_id,album_id,title,amount,page_count,status) values('ord_synthetic_frozen',$1,2,'Synthetic frozen customer order',49900,20,'PAYMENT_PENDING')`,[owner])
  await db.query(`insert into private.print_checkout_intents(user_id,request_id,order_id,album_id,request_fingerprint,source_digest,reviewed_revision,reviewed_spec_revision,
   delivery_snapshot,snapshot,product,approved_spec,cost_snapshot,source_asset_owners,order_code,store_id,channel_key,amount,page_count)
   values($1,'33333333-3333-4333-8333-333333333333','ord_synthetic_frozen',2,'synthetic-fingerprint','synthetic-source','synthetic-review','synthetic-spec',
    '{"fixture":"synthetic delivery"}','{"frozenAmount":49900}','{"id":"REDP_200_SOFT"}','{"fixture":"synthetic specification"}',
    '{"estimatedPrintCost":21230,"estimatedShippingCost":3500}',array[$1::uuid],'SYNTHETIC_ONLY','synthetic-store','synthetic-channel',49900,20)`,[owner])
  const snapshot=async()=>(await db.query(`select jsonb_build_object('order',(select to_jsonb(o) from orders o where order_id='ord_synthetic_frozen'),
   'intent',(select to_jsonb(i) from private.print_checkout_intents i where order_id='ord_synthetic_frozen')) q`)).rows[0].q
  const before=await snapshot(),saved=await mutate(db,original,{retail:69900})
  assert.equal((await quote(db,2,20)).amount,69900);assert.deepEqual(await snapshot(),before)
  await mutate(db,saved,{action:'reset'});assert.equal((await quote(db,2,20)).amount,49900);assert.deepEqual(await snapshot(),before)
 }finally{await db.close()}
})
