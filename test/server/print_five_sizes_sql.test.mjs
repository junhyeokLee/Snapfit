// Isolated PostgreSQL; these fixtures never create a live order or verify money.
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
]
const document=(product)=>JSON.stringify({pages:Array.from({length:22},(_,index)=>({index,isCover:index===0,layers:[]})),...(product?{printProduct:product}:{})})
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

test('all five saved products produce distinct geometry and conservative estimates; invalid formats fail without conversion',async()=>{
  const db=new PGlite()
  try {
    await base(db)
    await db.exec(migration('20260908105146_remove_external_print_payment_integration.sql'))
    await db.exec(migration('20260908114757_redprinting_five_size_contract.sql'))
    for(const [i,[id,w,h]]of products.entries())await db.query('insert into albums values($1,$2,$3,$4,$5)',[i+1,owner,id,String(w/h),document({id,trimWidthMm:w,trimHeightMm:h})])
    for(const [id,ratio,metadata]of [[6,'1',null],[7,'4:3',null],[8,'0.75',null],[9,'1',{id:'BAD',trimWidthMm:200,trimHeightMm:200}],[10,'1',{id:'REDP_200_SOFT',trimWidthMm:250,trimHeightMm:250}],[11,'1',{id:'REDP_250X200_SOFT',trimWidthMm:250,trimHeightMm:200}],[12,'',{id:'REDP_200_SOFT',trimWidthMm:200,trimHeightMm:200}]]){
      await db.query('insert into albums values($1,$2,$3,$4,$5)',[id,owner,'legacy',ratio,document(metadata)])
    }
    await db.query("insert into albums values(13,$1,'private','1',$2)",[other,document()])
    await db.exec(`set role authenticated;select set_config('request.jwt.claim.sub','${owner}',false);`)
    for(const [i,[id,w,h,basePrice,extra,cost,costExtra]]of products.entries()){
      const q=(await db.query('select get_print_order_quote($1,21) q',[i+1])).rows[0].q
      assert.equal(q.productCode,id);assert.deepEqual(q.printProduct,{id,trimWidthMm:w,trimHeightMm:h})
      assert.equal(q.amount,basePrice+extra);assert.equal(q.pageCount,22);assert.equal(q.addedBlankPageCount,1)
      assert.equal(q.priceIsEstimate,true);assert.equal(q.supplierCostVerified,false);assert.equal(q.pricingVersion,'PRINT_REDP_MULTISIZE_V2')
      assert.equal(q.spec.interior.trimWidthMm,w);assert.equal(q.spec.interior.trimHeightMm,h)
      assert.equal(q.spec.cover.widthMm,2*w+17.89);assert.equal(q.spec.cover.heightMm,h+10)
      assert.equal(q.spec.cover.front.xMm,w+12.89);assert.equal(q.spec.specVersion,`${id}_REVIEW_V2_7.89`)
      assert.equal(q.estimatedBasePrintCost,undefined);assert.equal(q.print_cost_snapshot,undefined)
      const q80=(await db.query('select get_print_order_quote($1,80) q',[i+1])).rows[0].q
      assert.equal(q80.amount,basePrice+30*extra)
      for(const [amount,totalCost]of [[basePrice,cost],[basePrice+30*extra,cost+30*costExtra]]){
        const margin=amount-totalCost-7000-1500-Math.ceil(amount*.04)-Math.ceil(amount*.05)-3000
        assert.ok(margin>=10000,`${id} conservative estimated margin ${margin}`)
      }
    }
    assert.equal((await db.query('select get_print_order_quote(6,null) q')).rows[0].q.productCode,'REDP_200_SOFT')
    assert.equal((await db.query('select get_print_order_quote(7,null) q')).rows[0].q.productCode,'REDP_200X150_SOFT')
    for(const [id,error]of [[8,/unsupported_print_product/],[9,/invalid_print_product/],[10,/invalid_print_product/],[11,/print_product_ratio_mismatch/],[12,/unsupported_print_product/],[13,/album_access_denied/]])await assert.rejects(db.query('select get_print_order_quote($1,20)',[id]),error)
    await assert.rejects(db.query("select print_product_policy('REDP_300_SOFT')"),/permission denied/)
    await assert.rejects(db.query("select create_print_order(1,22,52300,'UNCONFIGURED','name','01012345678','12345','address','','')"),/permission denied/)
    await db.exec('reset role;set role service_role;')
    await assert.rejects(db.query("select create_print_order(1,22,52300,'UNCONFIGURED','name','01012345678','12345','address','','')"),/permission denied/)
    const privileges=(await db.query("select to_regprocedure('public.confirm_verified_print_payment(text,text,integer,text)') verification,pg_get_functiondef('public.guard_print_order_update()'::regprocedure) definition")).rows[0]
    assert.equal(privileges.verification,null);assert.match(privileges.definition,/physical_order_payments_disabled/)
    // Fixture creation as database owner proves stored policy/snapshot consistency
    // without making this revoked function available to an application role.
    await db.exec('reset role;')
    const row=(await db.query("select create_print_order(4,22,84300,'UNCONFIGURED','name','01012345678','12345','address','','') o")).rows[0].o
    assert.deepEqual(row.print_product_snapshot,{id:'REDP_250_SOFT',trimWidthMm:250,trimHeightMm:250})
    assert.deepEqual(row.print_product_snapshot,row.print_content_snapshot.printProduct)
    const costs=(await db.query('select print_cost_snapshot from print_order_operations where order_id=$1',[row.order_id])).rows[0].print_cost_snapshot
    assert.equal(costs.estimatedPrintCost,47200);assert.equal(costs.productCode,'REDP_250_SOFT');assert.equal(costs.isEstimate,true)
    await db.query('update albums set cover_layers_json=$1 where id=4',[document({id:'REDP_300_SOFT',trimWidthMm:300,trimHeightMm:300})])
    assert.equal((await db.query('select print_product_snapshot from orders where order_id=$1',[row.order_id])).rows[0].print_product_snapshot.id,'REDP_250_SOFT')
    await db.exec('set role service_role;')
    await assert.rejects(db.query('update orders set print_product_snapshot=$1 where order_id=$2',[JSON.stringify({id:'REDP_300_SOFT',trimWidthMm:300,trimHeightMm:300}),row.order_id]),/order_print_product_immutable/)
    await assert.rejects(db.query("update orders set status='PAYMENT_COMPLETED',verified_payment_id='new',verified_payment_provider='X',payment_confirmed_at=now() where order_id=$1",[row.order_id]),/physical_order_payments_disabled/)
  }finally{await db.close()}
})

test('new fulfillment guard covers V2 while a historically paid V1 square remains unchanged',async()=>{
  const db=new PGlite()
  try{
    await base(db)
    await db.exec(migration('20260908114757_redprinting_five_size_contract.sql'))
    const product={id:'REDP_250_SOFT',trimWidthMm:250,trimHeightMm:250}
    const snap={album:{ratio:'1',cover_layers_json:document(product)},pages:[],printProduct:product}
    await db.query(`insert into orders(order_id,user_id,amount,page_count,status,pricing_version,verified_payment_id,verified_payment_provider,payment_confirmed_at,print_content_snapshot,print_product_snapshot)
      values('v2-paid',$1,84300,22,'PAYMENT_COMPLETED','PRINT_REDP_MULTISIZE_V2','history','HISTORICAL_PROVIDER',now(),$2,$3)`,[owner,JSON.stringify(snap),JSON.stringify(product)])
    await db.query(`insert into orders(order_id,user_id,amount,page_count,status,pricing_version,verified_payment_id,verified_payment_provider,payment_confirmed_at,print_content_snapshot)
      values('v1-paid',$1,49900,20,'PAYMENT_COMPLETED','PRINT_REDP_200_SOFT_V1','history-old','HISTORICAL_PROVIDER',now(),$2)`,[owner,JSON.stringify({album:{ratio:'.75',cover_layers_json:document()},pages:[]})])
    await db.exec(migration('20260908105146_remove_external_print_payment_integration.sql'))
    await db.exec('set role service_role;')
    await assert.rejects(db.exec("update orders set status='IN_PRODUCTION' where order_id='v2-paid'"),/vendor_acceptance_required/)
    await db.exec("update orders set print_fulfillment_status='RENDERING' where order_id in ('v1-paid','v2-paid')")
    await assert.rejects(db.exec("update orders set print_fulfillment_status='READY' where order_id='v2-paid'"),/invalid_print_fulfillment_transition/)
    const old=(await db.query("select amount,pricing_version,print_product_snapshot,print_content_snapshot from orders where order_id='v1-paid'")).rows[0]
    assert.equal(old.amount,49900);assert.equal(old.pricing_version,'PRINT_REDP_200_SOFT_V1');assert.equal(old.print_product_snapshot,null);assert.equal(old.print_content_snapshot.album.ratio,'.75')
    assert.equal((await db.query("select has_function_privilege('authenticated','public.create_print_order(bigint,integer,integer,text,text,text,text,text,text,text)','EXECUTE') allowed")).rows[0].allowed,false)
  }finally{await db.close()}
})
