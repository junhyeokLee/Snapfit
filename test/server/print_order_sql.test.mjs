// Run with PGLITE_MODULE=/path/to/@electric-sql/pglite/dist/index.js node --test this-file.
// The database is isolated in memory; no Supabase credentials or network are used.
import assert from 'node:assert/strict'
import { test } from 'node:test'
import { readFileSync } from 'node:fs'
import { pathToFileURL } from 'node:url'

const { PGlite } = await import(process.env.PGLITE_MODULE ? pathToFileURL(process.env.PGLITE_MODULE).href : '@electric-sql/pglite')
const initial=readFileSync(new URL('../../supabase/migrations/20260820140500_initial_snapfit_schema.sql',import.meta.url),'utf8')
const ordersDdl=initial.slice(initial.indexOf('create table if not exists public.orders ('),initial.indexOf('create trigger orders_set_updated_at')).replace("('ord_' || encode(extensions.gen_random_bytes(12), 'hex'))", "('ord_' || gen_random_uuid()::text)")
const migration=readFileSync(new URL('../../supabase/migrations/20260908094302_secure_print_order_payments.sql',import.meta.url),'utf8')
const retirement=readFileSync(new URL('../../supabase/migrations/20260908105146_remove_external_print_payment_integration.sql',import.meta.url),'utf8')
const owner='11111111-1111-1111-1111-111111111111',other='22222222-2222-2222-2222-222222222222'

test('payment retirement preserves historical orders and prevents all new payment approvals',async()=>{
  const db=new PGlite()
  try {
    await db.exec(`
      create role anon; create role authenticated; create role service_role bypassrls;
      create schema auth;
      create table auth.users(id uuid primary key);
      create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
      grant usage on schema auth, public to authenticated, service_role;
      grant execute on function auth.uid() to authenticated, service_role;
      create table public.albums(id bigint primary key,owner_id uuid,title text);
      create table public.album_pages(id bigint primary key,album_id bigint,page_index integer,layers_json jsonb);
      create function public.can_access_album(aid bigint) returns boolean language sql security definer stable as $$
        select exists(select 1 from public.albums where id=aid and owner_id=auth.uid()) $$;
      insert into auth.users values ('${owner}'),('${other}');
      insert into albums values(1,'${owner}','16-page book'),(2,'${other}','private');
      insert into album_pages select n,1,n-1,'[]'::jsonb from generate_series(1,16) n;
      ${ordersDdl}
      alter table public.orders enable row level security;
      grant all on public.orders to authenticated;
      create policy orders_own_or_admin_read on public.orders for select to authenticated using (user_id=auth.uid());
      create policy orders_insert_own on public.orders for insert to authenticated with check (user_id=auth.uid());
      create policy orders_owner_limited_update on public.orders for update to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
      insert into public.orders(order_id,user_id,album_id,amount,status) values('legacy-order','${owner}',1,1,'PAYMENT_PENDING');
    `)
    await db.exec(migration)
    await db.exec(`set role authenticated; select set_config('request.jwt.claim.sub','${owner}',false);`)
    await assert.rejects(db.exec(`insert into public.orders(user_id,amount,status) values('${owner}',1,'IN_PRODUCTION')`),/permission denied/)
    await assert.rejects(db.exec(`update public.orders set status='PAYMENT_COMPLETED' where order_id='legacy-order'`),/permission denied/)
    await assert.rejects(db.query('select public.get_print_order_quote(2,12)'),/album_access_denied/)
    const quote=(await db.query('select public.get_print_order_quote(1,1) as q')).rows[0].q
    assert.equal(quote.pageCount,16); assert.equal(quote.amount,39700)
    await assert.rejects(db.query('select public.get_print_order_quote(1,51)'),/invalid_page_count/)
    const createSql=`select public.create_print_order(1,16,$1,'TOSS_PAYMENTS','name','01012345678','12345','address','','') as o`
    await assert.rejects(db.query(createSql,[1]),/order_quote_changed/)
    const row=(await db.query(createSql,[39700])).rows[0].o
    assert.equal(row.amount,39700);assert.equal(row.status,'PAYMENT_PENDING');assert.equal(row.print_content_snapshot.pages.length,16)
    await assert.rejects(db.query('select public.confirm_verified_print_payment($1,$1,39700,\'KRW\')',[row.order_id]),/permission denied/)
    await db.exec(`select set_config('request.jwt.claim.sub','${other}',false);`)
    assert.equal((await db.query('select * from orders where order_id=$1',[row.order_id])).rows.length,0)
    await db.exec('reset role; set role service_role;')
    await assert.rejects(db.query('select public.confirm_verified_print_payment($1,$1,1,\'KRW\')',[row.order_id]),/payment_order_mismatch/)
    await assert.rejects(db.query('select public.confirm_verified_print_payment(\'legacy-order\',\'legacy-order\',1,\'KRW\')'),/legacy_order_requires_review/)
    const confirm=()=>db.query('select public.confirm_verified_print_payment($1,$1,39700,\'KRW\') as o',[row.order_id])
    const confirmed=(await confirm()).rows[0].o
    assert.equal(confirmed.status,'PAYMENT_COMPLETED');assert.equal(confirmed.verified_payment_id,row.order_id)
    const repeated=(await confirm()).rows[0].o
    assert.equal(repeated.payment_confirmed_at,confirmed.payment_confirmed_at)
    await assert.rejects(db.query('update orders set amount=1 where order_id=$1',[row.order_id]),/order_purchase_details_immutable/)
    await assert.rejects(db.query("update orders set status='DELIVERED' where order_id=$1",[row.order_id]),/invalid_order_status_transition/)
    const token='33333333-3333-3333-3333-333333333333'
    assert.equal((await db.query('select claim_print_package($1,$2) as o',[row.order_id,token])).rows[0].o.print_package_lock_token,token)
    assert.equal((await db.query('select claim_print_package($1,gen_random_uuid()) as o',[row.order_id])).rows[0].o,null)
    await db.query("update orders set status='IN_PRODUCTION' where order_id=$1",[row.order_id])
    await db.query("update orders set status='SHIPPING' where order_id=$1",[row.order_id])
    await db.query("update orders set status='DELIVERED' where order_id=$1",[row.order_id])
    assert.equal((await confirm()).rows[0].o.status,'DELIVERED')
    await assert.rejects(db.query("update orders set status='IN_PRODUCTION' where order_id=$1",[row.order_id]),/invalid_order_status_transition/)
    // Reversed paid orders cannot start production, and a delayed Paid callback cannot reopen them.
    await db.exec(`reset role; set role authenticated; select set_config('request.jwt.claim.sub','${owner}',false);`)
    const refundable=(await db.query(createSql,[39700])).rows[0].o
    await db.exec('reset role; set role service_role;')
    await db.query("select confirm_verified_print_payment($1,$1,39700,'KRW')",[refundable.order_id])
    const reverseSql="select record_print_payment_reversal($1,$1,39700,'KRW','CANCELLED') as o"
    const reversal=(await db.query(reverseSql,[refundable.order_id])).rows[0].o
    assert.equal(reversal.status,'CANCELED')
    assert.equal((await db.query(reverseSql,[refundable.order_id])).rows[0].o.payment_reversed_at,reversal.payment_reversed_at)
    await assert.rejects(db.query("select confirm_verified_print_payment($1,$1,39700,'KRW')",[refundable.order_id]),/payment_reversed/)
    assert.equal((await db.query('select claim_print_package($1,gen_random_uuid()) as o',[refundable.order_id])).rows[0].o,null)
    const deliveredReversal=(await db.query(reverseSql,[row.order_id])).rows[0].o
    assert.equal(deliveredReversal.status,'DELIVERED')
    assert.ok(deliveredReversal.payment_reversed_at)
    // Establish paid/unpaid history using the old migration before retiring it.
    await db.exec(`reset role; set role authenticated; select set_config('request.jwt.claim.sub','${owner}',false);`)
    const existingPaid=(await db.query(createSql,[39700])).rows[0].o
    const existingPending=(await db.query(createSql,[39700])).rows[0].o
    await db.exec('reset role; set role service_role;')
    await db.query("select confirm_verified_print_payment($1,$1,39700,'KRW')",[existingPaid.order_id])
    await db.query("insert into orders(order_id,user_id,amount,status) values('unverified-history',$1,100,'PAYMENT_COMPLETED')",[owner])
    await db.exec('reset role;')
    const snapshot=JSON.stringify((await db.query('select * from orders order by order_id')).rows)
    await db.exec(retirement)
    assert.equal(JSON.stringify((await db.query('select * from orders order by order_id')).rows),snapshot)
    assert.equal((await db.query("select to_regprocedure('public.confirm_verified_print_payment(text,text,integer,text)') f")).rows[0].f,null)
    assert.equal((await db.query("select to_regprocedure('public.record_print_payment_reversal(text,text,integer,text,text)') f")).rows[0].f,null)
    const guard=(await db.query("select pg_get_functiondef('public.guard_print_order_update()'::regprocedure) definition")).rows[0].definition
    assert.equal(/portone/i.test(guard),false)

    await db.exec(`set role authenticated; select set_config('request.jwt.claim.sub','${owner}',false);`)
    await assert.rejects(db.query(createSql,[39700]),/permission denied/)
    await assert.rejects(db.query('update orders set amount=1 where order_id=$1',[existingPending.order_id]),/permission denied/)
    assert.equal((await db.query('select get_print_order_quote(1,16) q')).rows[0].q.amount,39700)
    await db.exec(`select set_config('request.jwt.claim.sub','${other}',false);`)
    assert.equal((await db.query('select * from orders where order_id=$1',[existingPaid.order_id])).rows.length,0)
    await db.exec('reset role; set role service_role;')
    await assert.rejects(db.query(createSql,[39700]),/permission denied/)
    await assert.rejects(db.query("select confirm_verified_print_payment($1,$1,39700,'KRW')",[existingPending.order_id]),/does not exist/)
    await assert.rejects(db.query("update orders set status='PAYMENT_COMPLETED' where order_id=$1",[existingPending.order_id]),/physical_order_payments_disabled/)
    await assert.rejects(db.query("update orders set verified_payment_id='forged',verified_payment_provider='forged',payment_confirmed_at=now() where order_id=$1",[existingPending.order_id]),/physical_order_payments_disabled/)
    await assert.rejects(db.query("update orders set verified_payment_id='replacement' where order_id=$1",[existingPaid.order_id]),/physical_order_payments_disabled/)
    await assert.rejects(db.query("insert into orders(user_id,amount,status) values($1,1,'PAYMENT_COMPLETED')",[owner]),/physical_order_payments_disabled/)
    await assert.rejects(db.query("insert into orders(user_id,amount,status,verified_payment_id) values($1,1,'PAYMENT_PENDING','forged')",[owner]),/physical_order_payments_disabled/)
    await assert.rejects(db.query("insert into orders(order_id,user_id,amount,status) values($1,$2,1,'PAYMENT_COMPLETED') on conflict(order_id) do update set status=excluded.status",[existingPending.order_id,owner]),/physical_order_payments_disabled/)
    assert.equal((await db.query('select claim_print_package($1,gen_random_uuid()) o',[existingPending.order_id])).rows[0].o,null)
    assert.equal((await db.query("select claim_print_package('unverified-history',gen_random_uuid()) o")).rows[0].o,null)
    await assert.rejects(db.query("update orders set status='IN_PRODUCTION' where order_id='unverified-history'"),/verified_payment_required/)
    // Previously verified fulfillment stays compatible; new approvals remain closed.
    assert.equal((await db.query('select claim_print_package($1,$2) o',[existingPaid.order_id,token])).rows[0].o.print_package_lock_token,token)
    assert.equal((await db.query('select claim_print_package($1,gen_random_uuid()) o',[existingPaid.order_id])).rows[0].o,null)
    for(const status of ['IN_PRODUCTION','SHIPPING','DELIVERED']) await db.query('update orders set status=$1 where order_id=$2',[status,existingPaid.order_id])
    await db.query("update orders set status='CANCELED' where order_id=$1",[existingPending.order_id])
    await db.exec('reset role; delete from albums where id=1;')
    assert.equal((await db.query('select album_id,print_content_snapshot from orders where order_id=$1',[row.order_id])).rows[0].album_id,null)
  } finally { await db.close() }
})
