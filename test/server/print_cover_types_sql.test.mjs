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
const hardGeometry={construction:'casewrap',bleedMm:20,widthMm:461.1,heightMm:196,
  back:{xMm:20,yMm:20,widthMm:206,heightMm:156},front:{xMm:235.1,yMm:20,widthMm:206,heightMm:156},trim:{xMm:20,yMm:20,widthMm:421.1,heightMm:156}}
test('V3 quotes ten cover/size choices without reopening payments or exposing costs',async()=>{
  const db=new PGlite()
  try{
    await base(db);await db.exec(migration(retirement));await db.exec(migration(v2));await db.exec(migration(v3))
    for(const [i,[id,w,h]]of products.entries())await db.query('insert into albums values($1,$2,$3,$4,$5)',[i+1,owner,id,String(w/h),document({id,trimWidthMm:w,trimHeightMm:h})])
    await db.exec(`set role authenticated;select set_config('request.jwt.claim.sub','${owner}',false);`)
    for(const [i,[id,w,h,price,extra,cost,costExtra]]of products.entries()){
      const q=(await db.query('select get_print_order_quote($1,22) q',[i+1])).rows[0].q
      const hard=id.endsWith('_HARD')
      assert.equal(q.pricingVersion,'PRINT_REDP_COVERTYPE_V3');assert.equal(q.productCode,id)
      assert.deepEqual(q.printProduct,{id,trimWidthMm:w,trimHeightMm:h});assert.equal(q.coverType,hard?'HARD':'SOFT');assert.equal(q.coverLabel,hard?'하드커버':'소프트커버')
      assert.equal(q.amount,price+extra);assert.equal(q.priceIsEstimate,true);assert.equal(q.supplierCostVerified,false)
      assert.equal(q.estimatedBasePrintCost,undefined);assert.equal(q.print_cost_snapshot,undefined)
      assert.equal(q.specMissing,false);assert.equal(q.printPdfAvailable,true)
      if(hard){
        assert.equal(q.printTemplateStatus,'REVIEW_REQUIRED');assert.equal(q.spec.verified,false)
        assert.equal(q.spec.specVersion,`${id}_REVIEW_V3_9.77`);assert.equal(q.spec.coverGeometrySource,'official_default')
        assert.equal(q.spec.cover.construction,'casewrap');assert.equal(q.spec.cover.bleedMm,20)
        assert.equal(q.spec.cover.widthMm,2*(w+6)+49.77);assert.equal(q.spec.cover.heightMm,h+46)
        assert.equal(q.spec.cover.front.widthMm,w+6);assert.equal(q.spec.cover.trim.widthMm,2*(w+6)+9.77)
        assert.equal(q.spec.geometryMeasured,id==='REDP_200X150_HARD')
        const q20=(await db.query('select get_print_order_quote($1,20) q',[i+1])).rows[0].q
        assert.equal(q20.spec.geometryMeasured,true);assert.equal(q20.spec.verified,false)
        assert.equal(q20.spec.cover.widthMm,2*(w+6)+49.1);assert.equal(q20.spec.cover.heightMm,h+46)
      }
      else {assert.equal(q.spec.specVersion,`${id}_REVIEW_V3_7.89`);assert.equal(q.spec.coverType,'SOFT');assert.equal(q.spec.cover.widthMm,w*2+17.89)}
      const q80=(await db.query('select get_print_order_quote($1,80) q',[i+1])).rows[0].q
      assert.equal(q80.amount,price+30*extra)
      if(hard)assert.equal(q80.spec.geometryMeasured,id==='REDP_300_HARD')
      for(const [amount,printCost]of [[price,cost],[price+30*extra,cost+30*costExtra]])assert.ok(amount-printCost-7000-1500-Math.ceil(amount*.04)-Math.ceil(amount*.05)-3000>=10000,id)
    }
    for(const action of ["select print_product_policy('REDP_200_HARD')","select validate_hardcover_geometry('{}')","select * from print_order_operations","select create_print_order(6,22,72300,'UNCONFIGURED','name','01012345678','12345','address','','')"])await assert.rejects(db.query(action),/permission denied/)
    await db.exec('reset role;')
    const row=(await db.query("select create_print_order(6,22,72300,'UNCONFIGURED','name','01012345678','12345','address','','') o")).rows[0].o
    assert.equal(row.pricing_version,'PRINT_REDP_COVERTYPE_V3');assert.equal(row.print_product_snapshot.id,'REDP_200X150_HARD')
    const ops=(await db.query('select print_cost_snapshot from print_order_operations where order_id=$1',[row.order_id])).rows[0].print_cost_snapshot
    assert.equal(ops.estimatedPrintCost,35800);assert.equal(ops.version,'REDP_COVERTYPE_COST_ESTIMATE_V3')
    await db.exec('set role service_role;')
    await assert.rejects(db.query("select create_print_order(6,22,72300,'UNCONFIGURED','name','01012345678','12345','address','','')"),/permission denied/)
    await assert.rejects(db.query("update orders set status='PAYMENT_COMPLETED',verified_payment_id='fake',verified_payment_provider='X',payment_confirmed_at=now() where order_id=$1",[row.order_id]),/physical_order_payments_disabled/)
    assert.equal((await db.query("select to_regprocedure('public.confirm_verified_print_payment(text,text,integer,text)') p")).rows[0].p,null)
  }finally{await db.close()}
})

test('V3 validates default and overridden casewraps; historical V2 cannot acquire a hard SKU',async()=>{
  const db=new PGlite()
  try{
    await base(db);await db.exec(migration(v2));await db.exec(migration(v3))
    const product={id:'REDP_200X150_HARD',trimWidthMm:200,trimHeightMm:150}
    const snap={album:{ratio:'4:3',cover_layers_json:document(product)},pages:[],printProduct:product}
    const insert=version=>db.query(`insert into orders(order_id,user_id,amount,page_count,status,pricing_version,verified_payment_id,verified_payment_provider,payment_confirmed_at,print_content_snapshot,print_product_snapshot)
      values($1,$2,72300,22,'PAYMENT_COMPLETED',$3,$1,'HISTORICAL_PROVIDER',now(),$4,$5)`,[version,owner,version,JSON.stringify(snap),JSON.stringify(product)])
    await assert.rejects(insert('PRINT_REDP_MULTISIZE_V2'),/print_product_version_mismatch/)
    await insert('PRINT_REDP_COVERTYPE_V3');await db.exec(migration(retirement));await db.exec('set role service_role;')
    await db.query('update orders set print_spec_override=$1',[JSON.stringify({spineMm:9.77})])
    await assert.rejects(db.exec("update orders set print_fulfillment_status='RENDERING'"),/hardcover_template_required/)
    await db.query('update orders set print_spec_override=$1',[JSON.stringify({templateRevision:'invalid',coverGeometry:{...hardGeometry,trim:null}})])
    await assert.rejects(db.exec("update orders set print_fulfillment_status='RENDERING'"),/invalid_hardcover_geometry/)
    await db.query('update orders set print_spec_override=$1',[JSON.stringify({templateRevision:'official',coverGeometry:hardGeometry})])
    await db.exec("update orders set print_fulfillment_status='RENDERING'")
    await db.exec("update orders set print_spec_override=null,print_fulfillment_status='AWAITING_RENDER';update orders set print_fulfillment_status='RENDERING'")
    await assert.rejects(db.exec("update orders set status='IN_PRODUCTION'"),/vendor_acceptance_required/)
    await assert.rejects(db.query('update orders set print_product_snapshot=$1',[JSON.stringify({id:'REDP_200X150_SOFT',trimWidthMm:200,trimHeightMm:150})]),/order_print_product_immutable/)
    await assert.rejects(db.exec("update orders set verified_payment_id='replacement'"),/physical_order_payments_disabled/)
    for(const role of ['anon','authenticated','service_role'])assert.equal((await db.query("select has_function_privilege($1,'public.create_print_order(bigint,integer,integer,text,text,text,text,text,text,text)','EXECUTE') ok",[role])).rows[0].ok,false)
  }finally{await db.close()}
})
