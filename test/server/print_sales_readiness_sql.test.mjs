import assert from 'node:assert/strict'
import {test} from 'node:test'
import {readFileSync} from 'node:fs'
import {pathToFileURL} from 'node:url'
const {PGlite}=await import(process.env.PGLITE_MODULE?pathToFileURL(process.env.PGLITE_MODULE).href:'@electric-sql/pglite')
const source=n=>readFileSync(new URL(`../../supabase/migrations/${n}`,import.meta.url),'utf8')
const foundation=source('20261013170241_portone_production_print_checkout_foundation.sql')
const ddl=foundation.slice(foundation.indexOf('create table private.print_sales_configuration'),foundation.indexOf('create table private.print_checkout_intents'))
test('readiness RPC is invoker SELECT-only, returns route equality facts without identity/PII and denies all customer roles',async()=>{
  const db=new PGlite();try{
    await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;create schema private;${ddl}
      create table public.redprinting_dev_settings(id integer,sender_name text,sender_tel text,sender_zipcode text,sender_address text,sender_address_detail text);
      insert into public.redprinting_dev_settings values(1,'스냅핏','02-0000-0000','12345','synthetic sender address','synthetic detail');
      alter table private.print_sales_configuration enable row level security;alter table private.print_sales_combinations enable row level security;
      grant usage on schema public,private to service_role;
      grant select on private.print_sales_configuration,private.print_sales_combinations,public.redprinting_dev_settings to service_role;`)
    await db.exec(source('20261014134738_admin_print_sales_readiness_readonly.sql'))
    await db.exec("update private.print_sales_configuration set store_id='store-synthetic-live',channel_key='channel-key-synthetic-live';")
    const before=(await db.query('select to_jsonb(c) v from private.print_sales_configuration c')).rows[0].v
    await db.exec('set role service_role;')
    const report=(await db.query("select read_print_sales_readiness('store-synthetic-live','channel-key-synthetic-live') r")).rows[0].r
    assert.equal(report.configuration.present,true);assert.equal(report.configuration.enabled,false)
    assert.equal(report.configuration.routeConfigured,true);assert.equal(report.configuration.routeMatchesRuntime,true);assert.equal(report.senderConfigured,true)
    assert.deepEqual(report.combinations,[])
    assert.doesNotMatch(JSON.stringify(report),/store-synthetic|channel-key-synthetic|02-0000|12345|synthetic sender|synthetic detail/)
    assert.deepEqual((await db.query('select to_jsonb(c) v from private.print_sales_configuration c')).rows[0].v,before)
    await assert.rejects(db.query('update private.print_sales_configuration set enabled=true'),/permission denied/)
    await db.exec('reset role;')
    await db.exec("update public.redprinting_dev_settings set sender_tel='12345678901';")
    assert.equal((await db.query('select read_print_sales_readiness() r')).rows[0].r.senderConfigured,false)
    await db.exec("update public.redprinting_dev_settings set sender_tel='010-0000-0000';")
    assert.equal((await db.query('select read_print_sales_readiness() r')).rows[0].r.senderConfigured,true)
    for(const role of ['authenticated','anon']){
      await db.exec(`set role ${role};`)
      await assert.rejects(db.query('select read_print_sales_readiness()'),/permission denied/)
      await db.exec('reset role;')
    }
    const f=(await db.query("select prosecdef,provolatile,proconfig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='read_print_sales_readiness'")).rows[0]
    assert.equal(f.prosecdef,false);assert.equal(f.provolatile,'s');assert.deepEqual(f.proconfig,['search_path=""'])
    assert.doesNotMatch(source('20261014134738_admin_print_sales_readiness_readonly.sql'),/\b(update|insert|delete|create table|alter table)\b/i)
  }finally{await db.close()}
})
