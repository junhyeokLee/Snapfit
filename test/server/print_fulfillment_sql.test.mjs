// Isolated PostgreSQL verification; no credentials, live payments or supplier orders.
import assert from 'node:assert/strict'
import { test } from 'node:test'
import { readFileSync } from 'node:fs'
import { pathToFileURL } from 'node:url'
const { PGlite } = await import(process.env.PGLITE_MODULE ? pathToFileURL(process.env.PGLITE_MODULE).href : '@electric-sql/pglite')
const migration = name => readFileSync(new URL(`../../supabase/migrations/${name}`,import.meta.url),'utf8')
const initial=migration('20260820140500_initial_snapfit_schema.sql')
const ordersDdl=initial.slice(initial.indexOf('create table if not exists public.orders ('),initial.indexOf('create trigger orders_set_updated_at')).replace("('ord_' || encode(extensions.gen_random_bytes(12), 'hex'))", "('ord_' || gen_random_uuid()::text)")
const owner='11111111-1111-1111-1111-111111111111'

test('physical SKU quotes full editor pages, keeps costs private, and requires review, profitable real submission and acceptance',async()=>{
  const db=new PGlite()
  try {
    await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;
      create schema auth;create schema storage;
      create table auth.users(id uuid primary key);
      create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
      create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
      grant usage on schema auth,public to authenticated,service_role;
      create table public.albums(id bigint primary key,owner_id uuid,title text,cover_layers_json text);
      create table public.album_pages(id bigint primary key,album_id bigint,page_index integer,layers_json jsonb);
      create function public.can_access_album(aid bigint) returns boolean language sql security definer stable as $$ select exists(select 1 from public.albums where id=aid and owner_id=auth.uid()) $$;
      insert into auth.users values('${owner}');
      ${ordersDdl}
      alter table public.orders enable row level security;
      create policy orders_own_or_admin_read on public.orders for select to authenticated using(user_id=auth.uid());
    `)
    const pages=Array.from({length:22},(_,index)=>({index,isCover:index===0,layers:[]}))
    await db.query("insert into albums values(1,$1,'21 inner pages',$2)",[owner,JSON.stringify({pages})])
    await db.exec(migration('20260908094302_secure_print_order_payments.sql'))
    await db.exec(migration('20260908104605_redprinting_fulfillment_contract.sql'))
    await db.exec(`set role authenticated;select set_config('request.jwt.claim.sub','${owner}',false);`)
    const quote=(await db.query('select get_print_order_quote(1,1) q')).rows[0].q
    assert.equal(quote.pageCount,22);assert.equal(quote.sourcePageCount,21);assert.equal(quote.addedBlankPageCount,1)
    assert.equal(quote.amount,52300);assert.equal(quote.spec.cover.widthMm,417.89)
    assert.equal(quote.spec.specVersion,'REDP_200_SOFT_REVIEW_V1_7.89')
    assert.equal((await db.query('select get_print_order_quote(1,80) q')).rows[0].q.amount,121900)
    await assert.rejects(db.query('select get_print_order_quote(1,81)'),/invalid_page_count/)
    const create="select create_print_order(1,22,$1,'UNCONFIGURED','name','01012345678','12345','address','','') o"
    await assert.rejects(db.query(create,[52300]),/permission denied/)
    await db.exec('reset role;') // Fixture creation as database owner only; no production grant.
    await assert.rejects(db.query(create,[49900]),/order_quote_changed/)
    const pending=(await db.query(create,[52300])).rows[0].o
    assert.equal(pending.print_cost_snapshot,undefined)
    await db.exec('set role authenticated;')
    await assert.rejects(db.query('select * from print_order_operations'),/permission denied/)
    // A pre-existing, already-verified historical record is the only payable
    // fixture. The retirement migration subsequently blocks attaching evidence.
    await db.exec('reset role;')
    await db.query(`insert into orders(order_id,user_id,album_id,title,amount,page_count,status,pricing_version,payment_method,
      verified_payment_id,verified_payment_provider,payment_confirmed_at,print_content_snapshot)
      select 'historical-paid',user_id,album_id,title,amount,page_count,'PAYMENT_COMPLETED',pricing_version,payment_method,
        'historic-evidence','HISTORICAL_PROVIDER',now(),print_content_snapshot from orders where order_id=$1`,[pending.order_id])
    await db.query("insert into print_order_operations(order_id,print_cost_snapshot) select 'historical-paid',print_cost_snapshot from print_order_operations where order_id=$1",[pending.order_id])
    await db.exec(migration('20260908105146_remove_external_print_payment_integration.sql'))
    await db.exec(`set role authenticated;`)
    await assert.rejects(db.query(create,[52300]),/permission denied/)
    assert.equal((await db.query('select get_print_order_quote(1,22) q')).rows[0].q.amount,52300)
    await db.exec('reset role;set role service_role;')
    await assert.rejects(db.query("update orders set status='PAYMENT_COMPLETED',verified_payment_id='new',verified_payment_provider='X',payment_confirmed_at=now() where order_id=$1",[pending.order_id]),/physical_order_payments_disabled|verified_payment_required/)
    await assert.rejects(db.query("update orders set status='IN_PRODUCTION' where order_id='historical-paid'"),/vendor_acceptance_required/)
    await db.exec("update orders set print_fulfillment_status='RENDERING' where order_id='historical-paid'")
    await assert.rejects(db.exec("update orders set print_fulfillment_status='READY' where order_id='historical-paid'"),/invalid_print_fulfillment_transition/)
    await db.exec("update orders set print_fulfillment_status='REVIEW_REQUIRED',print_cover_pdf_path='private/cover.pdf',print_interior_pdf_path='private/interior.pdf',print_manifest='{}'::jsonb where order_id='historical-paid'")
    assert.equal((await db.query("select status from orders where order_id='historical-paid'")).rows[0].status,'PAYMENT_COMPLETED')
    await assert.rejects(db.exec("update orders set print_fulfillment_status='READY' where order_id='historical-paid'"),/vendor_spec_review_required/)
    await db.exec("update orders set print_fulfillment_status='READY',print_spec_confirmed_at=now() where order_id='historical-paid'")
    const orderPatch={print_vendor_order_id:'RED-20260908-1234',fulfillment_method:'DIRECT',sender_label_confirmed:false,price_slip_omitted_confirmed:false}
    const costs={actual_print_cost:22880,actual_shipping_cost:3500,actual_packaging_cost:0,payment_fee_reserve:2092,reprint_reserve:2615,operations_reserve:3000,contribution_margin:18213}
    const submit=(op=orderPatch,cp=costs)=>db.query("select submit_print_vendor('historical-paid',$1::jsonb,$2::jsonb) o",[JSON.stringify(op),JSON.stringify(cp)])
    await assert.rejects(submit(),/direct_shipping_confirmation_required/)
    assert.equal((await db.query("select actual_print_cost from print_order_operations where order_id='historical-paid'")).rows[0].actual_print_cost,null)
    orderPatch.fulfillment_method='REPACK'
    await assert.rejects(submit(orderPatch,{...costs,actual_print_cost:44000}),/print_margin_below_minimum/)
    const submitted=(await submit()).rows[0].o
    assert.equal(submitted.status,'PAYMENT_COMPLETED');assert.equal(submitted.print_fulfillment_status,'SUBMITTED')
    await assert.rejects(db.exec("update print_order_operations set actual_print_cost=1 where order_id='historical-paid'"),/submitted_print_details_immutable/)
    await assert.rejects(db.exec("update orders set print_fulfillment_status='RENDERING' where order_id='historical-paid'"),/invalid_print_fulfillment_transition/)
    await db.exec("update orders set print_fulfillment_status='ACCEPTED',print_accepted_at=now(),status='IN_PRODUCTION' where order_id='historical-paid'")
    await assert.rejects(db.exec("update orders set status='SHIPPING' where order_id='historical-paid'"),/shipping_details_required/)
    await db.exec("update orders set status='SHIPPING',courier='CJ',tracking_number='123456' where order_id='historical-paid'")
    await db.exec("update orders set status='DELIVERED' where order_id='historical-paid'")
    assert.equal((await db.query("select status from orders where order_id='historical-paid'")).rows[0].status,'DELIVERED')
  } finally {await db.close()}
})

test('applying fulfillment after the already-installed payment retirement cannot reopen physical sales',async()=>{
  const db=new PGlite()
  try {
    await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;
      create schema auth;create schema storage;create table auth.users(id uuid primary key);
      create function auth.uid() returns uuid language sql stable as $$select null::uuid$$;
      create table albums(id bigint primary key,owner_id uuid,title text,cover_layers_json text);
      create table album_pages(id bigint primary key,album_id bigint,page_index integer,layers_json jsonb);
      create function can_access_album(bigint) returns boolean language sql as $$select false$$;
      create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
      ${ordersDdl}`)
    await db.exec(migration('20260908094302_secure_print_order_payments.sql'))
    await db.exec(migration('20260908105146_remove_external_print_payment_integration.sql'))
    await db.exec(migration('20260908104605_redprinting_fulfillment_contract.sql'))
    const result=await db.query(`select has_function_privilege('authenticated','public.create_print_order(bigint,integer,integer,text,text,text,text,text,text,text)','EXECUTE') customer,
      has_function_privilege('service_role','public.create_print_order(bigint,integer,integer,text,text,text,text,text,text,text)','EXECUTE') service,
      to_regprocedure('public.confirm_verified_print_payment(text,text,integer,text)') verification,
      pg_get_functiondef('public.guard_print_order_update()'::regprocedure) definition`)
    assert.equal(result.rows[0].customer,false);assert.equal(result.rows[0].service,false);assert.equal(result.rows[0].verification,null)
    assert.match(result.rows[0].definition,/physical_order_payments_disabled/)
  } finally {await db.close()}
})
