// Isolated PostgreSQL fixtures; optional reviewed WEBSITE seed stays local to PGlite.
// Never contacts a supplier, PG or remote DB.
import assert from 'node:assert/strict'
import {test} from 'node:test'
import {readFileSync} from 'node:fs'
import {pathToFileURL} from 'node:url'
const {PGlite}=await import(process.env.PGLITE_MODULE?pathToFileURL(process.env.PGLITE_MODULE).href:'@electric-sql/pglite')
const migration=name=>readFileSync(new URL(`../../supabase/migrations/${name}`,import.meta.url),'utf8')
const revision='20261018174925_redprinting_supplier_quote_retail_matrix.sql'
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
    create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    grant usage on schema auth,public to authenticated,service_role;
    create table albums(id bigint primary key,owner_id uuid,title text,ratio text,cover_theme text,cover_layers_json text);
    create table album_pages(id bigint primary key,album_id bigint,page_index integer,layers_json jsonb);
    create table album_members(album_id bigint,user_id uuid,role text);
    create function can_access_album(aid bigint) returns boolean language sql security definer stable as $$select exists(select 1 from public.albums where id=aid and owner_id=auth.uid())$$;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    insert into auth.users values('${owner}'),('${other}');${ordersDdl}
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
  if(apply)await db.exec(migration(revision))
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

test('empty observation table preserves all 310 fallback policies and unknown prices remain unverified',async()=>{
  const db=await fixture({apply:false})
  try{
    const previous=new Map()
    for(const [id]of products)for(let pages=20;pages<=80;pages+=2)previous.set(`${id}:${pages}`,await policy(db,id,pages))
    const beforeConfig=(await db.query('select to_jsonb(c) q from private.print_sales_configuration c')).rows[0].q
    await db.exec(migration(revision))
    for(const [id]of products)for(let pages=20;pages<=80;pages+=2)assert.deepEqual(await policy(db,id,pages),previous.get(`${id}:${pages}`))
    const pending=await quote(db,2,20)
    assert.equal(pending.retailPriceStatus,'PENDING_SUPPLIER_QUOTE');assert.equal(pending.supplierCostVerified,false)
    assert.equal((await policy(db,'REDP_200X150_SOFT',20)).amount,49900)
    assert.equal((await policy(db,'REDP_300_HARD',80)).amount,159900)
    assert.deepEqual((await db.query('select to_jsonb(c) q from private.print_sales_configuration c')).rows[0].q,beforeConfig)
    assert.equal((await db.query('select count(*) n from private.print_supplier_quotes')).rows[0].n,0)
  }finally{await db.close()}
})

test('310 exact one-copy observations give minimal 9900 tiers, at least 10000 and 20 percent contribution with monotone page prices',async()=>{
  const db=await fixture()
  try{
    await seed(db)
    assert.equal((await db.query('select count(*) n from private.print_supplier_quotes')).rows[0].n,310)
    for(const [index,[id]]of products.entries()){
      let previous=0
      for(let pages=20;pages<=80;pages+=2){
        const row=rows().find(v=>v.product_id===id&&v.page_count===pages),p=await policy(db,id,pages)
        const packaging=id.endsWith('_HARD')?1500:0,c=contribution(p.amount,row.total_price,3500,packaging)
        assert.equal(p.amount%10000,9900);assert.equal(p.estimatedContribution,c)
        assert.ok(c>=10000);assert.ok(c*5>=p.amount)
        const prior=p.amount-10000,priorContribution=contribution(prior,row.total_price,3500,packaging)
        assert.ok(priorContribution<10000||priorContribution*5<prior)
        assert.ok(p.amount>=previous);previous=p.amount
        assert.equal(p.estimatedPrintCost,row.total_price);assert.equal(p.estimatedShippingCost,3500);assert.equal(p.estimatedPackagingCost,packaging)
        assert.equal(p.paymentFeeRate,.05);assert.equal(p.reprintReserveRate,.05);assert.equal(p.supplierCostVerified,true)
        assert.equal(p.retailPriceStatus,'PLANNED');assert.equal(p.priceIsEstimate,true);assert.equal(p.paymentFeeConfirmed,false)
        if(id.endsWith('_HARD')){assert.equal(p.shippingCostVerified,false);assert.equal(p.packagingCostVerified,false)}
        const publicQuote=await quote(db,index+1,pages);assert.equal(publicQuote.amount,p.amount);assert.equal(publicQuote.retailPriceStatus,'PLANNED');assertNoPrivateQuote(publicQuote)
      }
    }
    assert.equal((await policy(db,'REDP_200X150_SOFT',20)).amount,49900)
    assert.equal((await policy(db,'REDP_300_HARD',80)).amount,159900)
  }finally{await db.close()}
})

test('integer numeric ceilings handle exact absolute/20-percent thresholds and adjacent 9900 tier boundaries',async()=>{
  const db=await fixture()
  try{
    for(const [cost,shipping,packaging,expected]of [[21230,3500,0,49900],[101860,3500,1500,159900],
      [28410,3500,0,49900],[28411,3500,0,59900],[103930,3500,1500,159900],[103931,3500,1500,169900]]){
      const result=await budget(db,cost,shipping,packaging)
      assert.equal(result.amount,expected);assert.equal(result.estimatedContribution,contribution(expected,cost,shipping,packaging))
      assert.equal(result.paymentFeeReserve,Number((BigInt(expected)+19n)/20n))
    }
    for(const [cost,shipping,packaging]of [[null,0,0],[0,0,0],[-1,0,0],[100000001,0,0],[1,-1,0],[1,0,-1]])
      await assert.rejects(budget(db,cost,shipping,packaging),/invalid_print_quote_cost/)
    for(const pages of [null,19,21,82])await assert.rejects(policy(db,'REDP_200_SOFT',pages),/invalid_print_page_count/)
    await assert.rejects(policy(db,'INVENTED_PRODUCT',20))
  }finally{await db.close()}
})

test('quotes require exact product, one copy, even pages, VAT sum, source and complete evidence/options; unconfirmed rows stay pending',async()=>{
  const db=await fixture()
  try{
    for(const changes of [{product_id:'INVENTED_PRODUCT'},{page_count:19},{page_count:21},{page_count:82},{quantity:2},{currency:'USD'},
      {vat_price:0},{total_price:0,supply_price:0,vat_price:0},{source:'GUESS'},{observed_at:null},{observed_at:'infinity'},{observed_at:new Date(Date.now()+60*60*1000).toISOString()},{evidence:'short'},
      {options:{}},{options:{...options,coverPaper:''}},{options:{...options,interiorPrint:null}},{options:[]}])
      await assert.rejects(seed(db,[quoteRow('REDP_200_SOFT',20,21230,changes)]),/constraint|not-null/)
    await seed(db,[quoteRow('REDP_200_SOFT',20,21230,{confirmed:false})])
    assert.equal((await policy(db,'REDP_200_SOFT',20)).retailPriceStatus,'PENDING_SUPPLIER_QUOTE')
    await db.exec("update private.print_supplier_quotes set confirmed=true where product_id='REDP_200_SOFT'")
    assert.equal((await policy(db,'REDP_200_SOFT',20)).retailPriceStatus,'PLANNED')
    assert.equal((await policy(db,'REDP_200_SOFT',22)).supplierCostVerified,false)
  }finally{await db.close()}
})

test('cost changes update live planned tier/revision without rewriting other combinations or stored orders',async()=>{
  const db=await fixture()
  try{
    await seed(db,[quoteRow('REDP_200_SOFT',20,28410)])
    const before=await policy(db,'REDP_200_SOFT',20),other=await policy(db,'REDP_200_SOFT',22)
    const unrelated=(await db.query('select to_jsonb(c) q from private.print_sales_configuration c')).rows[0].q
    await db.exec("update private.print_supplier_quotes set supply_price=supply_price+1,total_price=total_price+1 where product_id='REDP_200_SOFT'")
    const after=await policy(db,'REDP_200_SOFT',20)
    assert.equal(before.amount,49900);assert.equal(after.amount,59900);assert.notEqual(after.pricePolicyVersion,before.pricePolicyVersion)
    assert.deepEqual(await policy(db,'REDP_200_SOFT',22),other)
    assert.deepEqual((await db.query('select to_jsonb(c) q from private.print_sales_configuration c')).rows[0].q,unrelated)
    assert.equal((await db.query('select count(*) n from orders')).rows[0].n,0)
  }finally{await db.close()}
})

const finalCosts={estimatedPrintCost:21230,estimatedShippingCost:3500,estimatedPackagingCost:0,paymentFeeRate:.05,reprintReserveRate:.05,
  operationsReserve:3000,minimumContribution:10000,privateNote:'never expose internal procurement evidence'}
async function insertFinal(db,cost=finalCosts){
  await db.query(`insert into private.print_sales_combinations(product_id,page_count,final_price,price_version,retail_final,supplier_cost_confirmed,shipping_confirmed,
    packaging_confirmed,order_code,cost_snapshot,approval_evidence) values('REDP_200_SOFT',20,59900,'SYNTHETIC_FINAL_PRICE_V1',true,true,true,true,
    'SYNTHETIC_APPROVED_CODE',$1,'synthetic financial approval evidence only')`,[cost])
}
test('financial FINAL precedes observed PLANNED with sales disabled, while operational approval and payment stay blocked',async()=>{
  const db=await fixture()
  try{
    await seed(db,[quoteRow()]);await insertFinal(db)
    const internal=await policy(db,'REDP_200_SOFT',20)
    assert.equal(internal.retailPriceStatus,'FINAL');assert.equal(internal.amount,59900);assert.equal(internal.isEstimate,false)
    await db.exec('set role authenticated;')
    const publicQuote=await quote(db,2,20)
    assert.equal(publicQuote.retailPriceStatus,'FINAL');assert.equal(publicQuote.priceIsEstimate,false);assert.equal(publicQuote.amount,59900)
    assert.equal(publicQuote.spec.verified,false);assertNoPrivateQuote(publicQuote)
    assert.doesNotMatch(JSON.stringify(publicQuote),/SYNTHETIC_APPROVED_CODE|privateNote|procurement|financial approval/)
    await db.exec('reset role;set role service_role;')
    const context=(await db.query('select load_owned_print_checkout_context($1,2) q',[owner])).rows[0].q
    assert.equal(context.quote.retailPriceStatus,'FINAL');assert.equal(context.canPay,false);assert.equal(context.configuration.enabled,false)
    const recipient={name:'fixture',phone:'01000000000',zipCode:'12345',addressLine1:'fixture',addressLine2:'',deliveryMemo:''}
    await assert.rejects(db.query('select prepare_production_print_checkout($1,$2,2,$3,$4,$5,59900,20,$6)',
      [owner,'33333333-3333-4333-8333-333333333333',context.sourceDigest,'a'.repeat(64),'b'.repeat(64),recipient]),/print_sales_not_ready/)
    assert.equal((await db.query('select count(*) n from orders')).rows[0].n,0)
    await db.exec('reset role;')
  }finally{await db.close()}
})

test('DRAFT and partial/malformed financial records never claim FINAL and preserve planned/unknown fallbacks',async()=>{
  const db=await fixture()
  try{
    await seed(db,[quoteRow()]);await insertFinal(db)
    for(const update of ["retail_final=false","supplier_cost_confirmed=false","shipping_confirmed=false","packaging_confirmed=false", "price_version=''", "price_version='DRAFT_V1'", "order_code=''", "approval_evidence='short'",
      "cost_snapshot='{}'::jsonb", "cost_snapshot=jsonb_set(cost_snapshot,'{draftOnly}','true')", "cost_snapshot=jsonb_set(cost_snapshot,'{draftOnly}','null')",
      "cost_snapshot=jsonb_set(cost_snapshot,'{paymentFeeRate}','\"0.05\"')", "cost_snapshot=jsonb_set(cost_snapshot,'{estimatedPrintCost}','-1')",
      "cost_snapshot=jsonb_set(cost_snapshot,'{operationsReserve}','2999')", "cost_snapshot=jsonb_set(cost_snapshot,'{minimumContribution}','9999')",
      "final_price=29900"]){
      await db.query('update private.print_sales_combinations set final_price=59900,retail_final=true,supplier_cost_confirmed=true,shipping_confirmed=true,packaging_confirmed=true,price_version=$1,order_code=$2,approval_evidence=$3,cost_snapshot=$4',
        ['SYNTHETIC_FINAL_PRICE_V1','SYNTHETIC_APPROVED_CODE','synthetic financial approval evidence only',finalCosts])
      await db.exec(`update private.print_sales_combinations set ${update}`)
      assert.equal((await policy(db,'REDP_200_SOFT',20)).retailPriceStatus,'PLANNED',update)
    }
    await db.exec('delete from private.print_supplier_quotes')
    assert.equal((await policy(db,'REDP_200_SOFT',20)).retailPriceStatus,'PENDING_SUPPLIER_QUOTE')
  }finally{await db.close()}
})

test('private quotes/helpers and stable invoker policy deny customer access and keep RLS; public RPC stays owner-scoped',async()=>{
  const db=await fixture()
  try{
    await seed(db,[quoteRow()])
    const f=(await db.query("select prosecdef,provolatile,proconfig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='print_combo_pricing_policy'")).rows[0]
    assert.equal(f.prosecdef,false);assert.equal(f.provolatile,'s');assert.deepEqual(f.proconfig,['search_path=""'])
    assert.equal((await db.query("select relrowsecurity b from pg_class where oid='private.print_supplier_quotes'::regclass")).rows[0].b,true)
    for(const role of ['anon','authenticated']){
      await db.exec(`set role ${role};`)
      for(const sql of ['select * from private.print_supplier_quotes',"select print_combo_pricing_policy('REDP_200_SOFT',20)",
        'select private.print_quote_retail_budget(21230,3500,0)','select private.print_financial_price_valid(null::private.print_sales_combinations)',"select private.print_legacy_combo_pricing_policy('REDP_200_SOFT',20)",
        'delete from private.print_supplier_quotes'])await assert.rejects(db.query(sql),/permission denied/)
      if(role==='authenticated'){
        const q=await quote(db,2,20);assert.equal(q.retailPriceStatus,'PLANNED');assertNoPrivateQuote(q)
        await db.exec(`select set_config('request.jwt.claim.sub','${other}',false)`)
        await assert.rejects(quote(db,2,20),/album_access_denied/)
        await db.exec(`select set_config('request.jwt.claim.sub','${owner}',false)`)
      }
      await db.exec('reset role;')
    }
    await db.exec('set role service_role;')
    assert.equal((await policy(db,'REDP_200_SOFT',20)).amount,49900)
  }finally{await db.close()}
})

const softDescription='내 파일로 만드는 포토북 소프트커버 아트지300g 무광코팅단면'
async function mapping(db,{total=28410,verifiedAt=new Date(Date.now()-5*60*1000).toISOString(),description=softDescription,...changes}={}){
  const data={product_id:'REDP_200_SOFT',page_count:20,order_code:'SYNTHETIC_API_CODE',exact_match_confirmed:true,vendor_use_yn:'Y',vendor_order_yn:'Y',
    detail_snapshot:{goodsDesc:description},price_snapshot:{supplyPrice:Math.floor(total/1.1),vatPrice:total-Math.floor(total/1.1),totalPrice:total,orderYn:'Y'},
    note:'사이트 및 코드 상세 대조: Glossy Canon 285g 양면, 내지 20쪽(10장)',verified_at:verifiedAt,...changes}
  await db.query(`insert into redprinting_dev_mappings(product_id,page_count,order_code,exact_match_confirmed,vendor_use_yn,vendor_order_yn,detail_snapshot,price_snapshot,note,verified_at)
    values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) on conflict(product_id,page_count) do update set order_code=excluded.order_code,
    exact_match_confirmed=excluded.exact_match_confirmed,vendor_use_yn=excluded.vendor_use_yn,vendor_order_yn=excluded.vendor_order_yn,
    detail_snapshot=excluded.detail_snapshot,price_snapshot=excluded.price_snapshot,note=excluded.note,verified_at=excluded.verified_at`,
    [data.product_id,data.page_count,data.order_code,data.exact_match_confirmed,data.vendor_use_yn,data.vendor_order_yn,data.detail_snapshot,data.price_snapshot,data.note,data.verified_at])
}
test('new verified one-copy API mappings refresh planned pricing atomically, without stale website overwrite or approval changes',async()=>{
  const db=await fixture()
  try{
    await seed(db,[quoteRow()])
    await db.query("insert into redprinting_dev_codes(order_code,use_yn,goods_desc) values('SYNTHETIC_API_CODE','Y',$1)",[softDescription])
    const configBefore=(await db.query('select to_jsonb(c) q from private.print_sales_configuration c')).rows[0].q
    const original=await policy(db,'REDP_200_SOFT',20)
    await db.exec('set role service_role;')
    await mapping(db)
    const first=await policy(db,'REDP_200_SOFT',20)
    assert.equal(first.supplierQuoteSource,'API');assert.equal(first.estimatedPrintCost,28410);assert.equal(first.amount,49900)
    assert.notEqual(first.pricePolicyVersion,original.pricePolicyVersion)
    await mapping(db,{total:28411,verifiedAt:new Date(Date.now()-60*1000).toISOString()})
    const increased=await policy(db,'REDP_200_SOFT',20)
    assert.equal(increased.amount,59900);assert.notEqual(increased.pricePolicyVersion,first.pricePolicyVersion)
    assert.ok(increased.estimatedContribution>=10000);assert.ok(increased.estimatedContribution*5>=increased.amount)
    const api=(await db.query('select to_jsonb(q) q from private.print_supplier_quotes q')).rows[0].q
    assert.equal(api.options.coverPaper,'아트지 300g');assert.equal(api.options.interiorPrint,'양면')
    // A more recent independent website observation wins over an older mapping refresh.
    await db.query("update private.print_supplier_quotes set supply_price=27000,vat_price=3000,total_price=30000,source='WEBSITE',observed_at=$1",[new Date(Date.now()-30*1000).toISOString()])
    const website=(await db.query('select to_jsonb(q) q from private.print_supplier_quotes q')).rows[0].q
    await mapping(db,{total:45000,verifiedAt:new Date(Date.now()-45*1000).toISOString()})
    assert.deepEqual((await db.query('select to_jsonb(q) q from private.print_supplier_quotes q')).rows[0].q,website)
    // Invalid/zero/unapproved/contradictory/future API observations preserve the last valid price.
    for(const change of [{total:0},{verifiedAt:new Date(Date.now()+60*60*1000).toISOString()},
      {exact_match_confirmed:false},{vendor_use_yn:'N'},{vendor_order_yn:'N'},
      {price_snapshot:{supplyPrice:19300,vatPrice:0,totalPrice:21230,orderYn:'Y'}},
      {price_snapshot:{supplyPrice:19300,vatPrice:1930,totalPrice:21230,orderYn:'Y',qty:2}},
      {description:'내 파일로 만드는 포토북 소프트커버 아트지250g 유광코팅단면'},
      {description:'내 파일로 만드는 포토북 하드커버 스노우지180g 무광코팅단면'},
      {note:'Glossy Canon 285g 단면, 내지 20쪽'}, {note:'Glossy Canon 285g 양면, 내지 22쪽'}]){
      await mapping(db,{verifiedAt:new Date(Date.now()).toISOString(),...change})
      assert.deepEqual((await db.query('select to_jsonb(q) q from private.print_supplier_quotes q')).rows[0].q,website)
    }
    await db.exec("update redprinting_dev_codes set use_yn='N'")
    await mapping(db,{total:45000,verifiedAt:new Date().toISOString()})
    assert.deepEqual((await db.query('select to_jsonb(q) q from private.print_supplier_quotes q')).rows[0].q,website)
    await db.exec('reset role;')
    assert.deepEqual((await db.query('select to_jsonb(c) q from private.print_sales_configuration c')).rows[0].q,configBefore)
    assert.equal((await db.query('select count(*) n from private.print_sales_combinations')).rows[0].n,0)
    assert.equal((await db.query('select count(*) n from orders')).rows[0].n,0)
    await insertFinal(db)
    const finalBefore=(await db.query('select to_jsonb(c) q from private.print_sales_combinations c')).rows[0].q
    await db.exec("update redprinting_dev_codes set use_yn='Y'")
    await mapping(db,{total:70000,verifiedAt:new Date().toISOString()})
    assert.equal((await policy(db,'REDP_200_SOFT',20)).retailPriceStatus,'FINAL')
    assert.equal((await policy(db,'REDP_200_SOFT',20)).amount,59900)
    assert.deepEqual((await db.query('select to_jsonb(c) q from private.print_sales_combinations c')).rows[0].q,finalBefore)
  }finally{await db.close()}
})

test('optional reviewed 310-row WEBSITE seed matches public quotes, private budgets and closed payment gates',
  {skip:!process.env.SUPPLIER_QUOTE_SEED_SQL},async()=>{
  const db=await fixture()
  try{
    const seedSql=readFileSync(process.env.SUPPLIER_QUOTE_SEED_SQL,'utf8')
    const configBefore=(await db.query('select to_jsonb(c) q from private.print_sales_configuration c')).rows[0].q
    await db.exec('set role service_role;')
    await db.exec(seedSql)
    const captured=(await db.query('select * from private.print_supplier_quotes order by product_id,page_count')).rows
    assert.equal(captured.length,310)
    assert.equal(new Set(captured.map(row=>`${row.product_id}:${row.page_count}:${row.quantity}`)).size,310)
    for(const [index,[id]]of products.entries()){
      let priorCost=0,priorRetail=0
      for(let pages=20;pages<=80;pages+=2){
        const row=captured.find(value=>value.product_id===id&&value.page_count===pages)
        assert.ok(row,`${id}:${pages} missing from reviewed seed`)
        assert.equal(row.quantity,1);assert.equal(row.currency,'KRW');assert.equal(row.source,'WEBSITE');assert.equal(row.confirmed,true)
        assert.ok(row.supply_price>0&&row.vat_price>0);assert.equal(row.vat_price*10,row.supply_price)
        assert.equal(row.supply_price+row.vat_price,row.total_price)
        assert.match(row.evidence,/PHBKMYB/);assert.match(row.evidence,/rawCaptureSHA256=[a-f0-9]{64}/)
        assert.equal(row.options.optionContract,'PHBKMYB_GLOSSY285_MATTE_DUPLEX_V1')
        assert.equal(row.options.coverPaper,id.endsWith('_HARD')?'스노우지 180g':'아트지 300g')
        assert.equal(row.options.coverFinish,'단면 무광코팅');assert.equal(row.options.interiorPaper,'Glossy Canon 285g');assert.equal(row.options.interiorPrint,'양면')
        const packaging=id.endsWith('_HARD')?1500:0
        const b=await budget(db,row.total_price,3500,packaging),p=await policy(db,id,pages),q=await quote(db,index+1,pages)
        const expectedContribution=contribution(p.amount,row.total_price,3500,packaging)
        assert.equal(p.retailPriceStatus,'PLANNED');assert.equal(p.supplierCostVerified,true);assert.equal(p.estimatedPrintCost,row.total_price)
        assert.equal(p.amount,b.amount);assert.equal(p.estimatedContribution,b.estimatedContribution);assert.equal(p.estimatedContribution,expectedContribution)
        assert.equal(p.amount%10000,9900);assert.ok(expectedContribution>=10000);assert.ok(expectedContribution*5>=p.amount)
        const previousTier=p.amount-10000,previousContribution=contribution(previousTier,row.total_price,3500,packaging)
        assert.ok(previousContribution<10000||previousContribution*5<previousTier)
        assert.ok(row.total_price>=priorCost);assert.ok(p.amount>=priorRetail)
        priorCost=row.total_price;priorRetail=p.amount
        assert.equal(q.amount,p.amount);assert.equal(q.retailPriceStatus,'PLANNED');assert.equal(q.supplierCostVerified,true);assertNoPrivateQuote(q)
      }
      const context=(await db.query('select load_owned_print_checkout_context($1,$2) q',[owner,index+1])).rows[0].q
      assert.equal(context.canPay,false);assert.equal(context.configuration.enabled,false)
    }
    assert.equal((await policy(db,'REDP_200X150_SOFT',20)).amount,49900)
    assert.equal((await policy(db,'REDP_200_SOFT',20)).amount,49900)
    assert.equal((await policy(db,'REDP_300_HARD',80)).amount,159900)
    // Applying the identical observation twice is harmless and never finalizes prices.
    await db.exec(seedSql)
    assert.deepEqual((await db.query('select * from private.print_supplier_quotes order by product_id,page_count')).rows,captured)
    assert.deepEqual((await db.query('select to_jsonb(c) q from private.print_sales_configuration c')).rows[0].q,configBefore)
    assert.equal((await db.query('select count(*) n from private.print_sales_combinations')).rows[0].n,0)
    assert.equal((await db.query('select count(*) n from orders')).rows[0].n,0)
    await db.exec('reset role;')
    assert.equal((await db.query("select relrowsecurity b from pg_class where oid='private.print_supplier_quotes'::regclass")).rows[0].b,true)
    for(const role of ['anon','authenticated']){
      for(const privilege of ['SELECT','INSERT','UPDATE','DELETE'])assert.equal((await db.query('select has_table_privilege($1,$2,$3) b',
        [role,'private.print_supplier_quotes',privilege])).rows[0].b,false)
    }
    for(const privilege of ['SELECT','INSERT','UPDATE','DELETE'])assert.equal((await db.query('select has_table_privilege($1,$2,$3) b',
      ['service_role','private.print_supplier_quotes',privilege])).rows[0].b,true)
  }finally{await db.close()}
})
