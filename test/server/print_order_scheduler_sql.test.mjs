import assert from 'node:assert/strict'
import { test } from 'node:test'
import { readFileSync } from 'node:fs'
import { createHmac } from 'node:crypto'
import { fixture as appFixture, prepare, owner } from './fixtures/app_pdf_database.mjs'
import { printSchedulerSignedPayload } from '../../supabase/functions/_shared/print-order-scheduler.ts'

const migration = readFileSync(new URL('../../supabase/migrations/20261014165854_print_order_scheduler_cron.sql', import.meta.url), 'utf8')
const rechecks = migration.slice(0, migration.indexOf('do $scheduler_install$'))
const ownName = 'snapfit-print-order-scheduler', project = 'https://rrbhxdtriummqpztpjrk.supabase.co'

/** PostgreSQL statements run in PGlite. Cron, Vault and HTTP are local adapters;
 * their synthetic inventory/credentials never enter a real project or network. */
async function cronFixture() {
  const db = await appFixture(false)
  await db.exec(`
    create schema cron; create schema net; create schema vault; create schema extensions;
    -- Local pgcrypto-compatible adapter using PostgreSQL core SHA-256. The
    -- queued result is independently checked against Node's HMAC implementation.
    create function extensions.hmac(data text,key text,kind text) returns bytea language plpgsql as $$
      declare material bytea:=convert_to(key,'UTF8');inner_pad bytea:=decode(repeat('00',64),'hex');outer_pad bytea:=inner_pad;index integer;
      begin
        if kind<>'sha256' or octet_length(material)<>64 then raise exception 'local_hmac_adapter_input';end if;
        for index in 0..63 loop
          inner_pad:=set_byte(inner_pad,index,get_byte(material,index)#54);
          outer_pad:=set_byte(outer_pad,index,get_byte(material,index)#92);
        end loop;
        return sha256(outer_pad||sha256(inner_pad||convert_to(data,'UTF8')));
      end;$$;
    create table cron.job(jobid bigserial primary key,jobname text,schedule text,command text,username text,active boolean,unique(jobname,username));
    create table cron.job_run_details(jobid bigint,end_time timestamptz);
    create function cron.schedule(job_name text,job_schedule text,job_command text) returns bigint language plpgsql as $$
      declare result bigint; begin
        insert into cron.job(jobname,schedule,command,username,active) values(job_name,job_schedule,job_command,current_user,true)
          on conflict(jobname,username) do update set schedule=excluded.schedule,command=excluded.command,active=true returning jobid into result;
        return result;
      end;$$;
    create table vault.secrets(name text primary key,value text);
    create view vault.decrypted_secrets as select name,value as decrypted_secret from vault.secrets;
    create table net.http_request_queue(id bigserial primary key,url text,headers jsonb,body jsonb,timeout_milliseconds integer);
    create function net.http_post(url text,body jsonb default '{}'::jsonb,params jsonb default '{}'::jsonb,
      headers jsonb default '{}'::jsonb,timeout_milliseconds integer default 2000) returns bigint language plpgsql as $$
      declare result bigint; begin
        insert into net.http_request_queue(url,body,headers,timeout_milliseconds) values(url,body,headers,timeout_milliseconds) returning id into result;
        return result;
      end;$$;
    grant usage on schema net to public;
    grant select on net.http_request_queue to public,anon,authenticated;
    insert into net.http_request_queue(url,headers,body,timeout_milliseconds) values('https://existing-local.invalid','{}','{}',2000);
    select cron.schedule('existing-local-job','0 0 * * *','select 1');
    insert into pg_catalog.pg_extension(oid,extname,extowner,extnamespace,extrelocatable,extversion)
      select 200000+ordinality::integer,name,(select oid from pg_roles where rolname=current_user),'public'::regnamespace,true,'local-adapter'
      from unnest(array['pg_cron','pg_net','supabase_vault']) with ordinality as extension(name,ordinality);
  `)
  await db.query('insert into vault.secrets values($1,$2),($3,$4)', ['snapfit_print_order_scheduler_secret', 'a'.repeat(64),
    'snapfit_print_order_scheduler_project_url', project])
  return db
}

test('Cron installation is idempotent, preserves extension ACLs/other jobs/queued requests/closed gates and protects private nonces', async t => {
  const db = await cronFixture(); t.after(() => db.close())
  const before = (await db.query('select * from cron.job where jobname=$1', ['existing-local-job'])).rows[0]
  for (const role of ['anon', 'authenticated']) assert.equal((await db.query("select has_table_privilege($1,'net.http_request_queue','SELECT') allowed", [role])).rows[0].allowed, true)
  await db.exec(migration); await db.exec(migration)
  const jobs = (await db.query('select * from cron.job where jobname=$1', [ownName])).rows
  assert.equal(jobs.length, 1); assert.equal(jobs[0].schedule, '*/2 * * * *'); assert.equal(jobs[0].active, true)
  assert.deepEqual((await db.query('select * from cron.job where jobname=$1', ['existing-local-job'])).rows[0], before)
  assert.equal((await db.query('select count(*)::integer n from net.http_request_queue')).rows[0].n, 1)
  for (const role of ['anon', 'authenticated']) {
    assert.equal((await db.query("select has_table_privilege($1,'net.http_request_queue','SELECT') allowed", [role])).rows[0].allowed, true)
    assert.equal((await db.query("select has_table_privilege($1,'vault.decrypted_secrets','SELECT') allowed", [role])).rows[0].allowed, false)
    assert.equal((await db.query("select has_table_privilege($1,'private.print_order_scheduler_nonces','SELECT') allowed", [role])).rows[0].allowed, false)
    assert.equal((await db.query("select has_function_privilege($1,'public.consume_print_order_scheduler_nonce(uuid,bigint)','EXECUTE') allowed", [role])).rows[0].allowed, false)
  }
  assert.equal((await db.query("select has_table_privilege(current_user,'net.http_request_queue','SELECT') allowed")).rows[0].allowed, true)
  assert.equal((await db.query('select enabled,business_ready,portone_live_ready,redprinting_live_ready from private.print_sales_configuration')).rows[0].enabled, false)
  assert.doesNotMatch(jobs[0].command, /a{64}|service_role|SUPABASE_SERVICE_ROLE_KEY|eyJ/)
})
test('scheduled SQL posts only the intended private endpoint/body/header/timeout and prunes only own old run metadata', async t => {
  const db = await cronFixture(); t.after(() => db.close()); await db.exec(migration)
  const own = (await db.query('select * from cron.job where jobname=$1', [ownName])).rows[0]
  const other = (await db.query('select * from cron.job where jobname=$1', ['existing-local-job'])).rows[0]
  await db.query("insert into cron.job_run_details values($1,now()-interval '8 days'),($1,now()),($2,now()-interval '8 days')", [own.jobid, other.jobid])
  await db.exec(own.command)
  const sent = (await db.query('select * from net.http_request_queue order by id desc limit 1')).rows[0]
  assert.equal(sent.url, `${project}/functions/v1/print-order-scheduler`)
  assert.deepEqual(sent.body, {}); assert.equal(sent.timeout_milliseconds, 125000)
  assert.deepEqual(Object.keys(sent.headers).sort(), ['Content-Type', 'X-Snapfit-Scheduler-Nonce', 'X-Snapfit-Scheduler-Signature', 'X-Snapfit-Scheduler-Timestamp'])
  const nonce=sent.headers['X-Snapfit-Scheduler-Nonce'],timestamp=Number(sent.headers['X-Snapfit-Scheduler-Timestamp'])
  assert.equal(sent.headers['X-Snapfit-Scheduler-Signature'],createHmac('sha256','a'.repeat(64)).update(printSchedulerSignedPayload(timestamp,nonce)).digest('hex'))
  assert.doesNotMatch(JSON.stringify(sent.headers),/a{64}|Scheduler-Secret|service_role|eyJ/)
  assert.equal((await db.query('select count(*)::integer n from private.print_order_scheduler_nonces where id=$1 and signed_at=$2',[nonce,timestamp])).rows[0].n,1)
  assert.equal((await db.query('select count(*)::integer n from cron.job_run_details where jobid=$1', [own.jobid])).rows[0].n, 1)
  assert.equal((await db.query('select count(*)::integer n from cron.job_run_details where jobid=$1', [other.jobid])).rows[0].n, 1)
})

test('private SQL consumes each signed nonce exactly once and rejects timestamp changes, missing and expired records', async t => {
  const db=await cronFixture();t.after(()=>db.close());await db.exec(migration)
  const command=(await db.query('select command from cron.job where jobname=$1',[ownName])).rows[0].command
  await db.exec(command)
  const record=(await db.query('select id,signed_at from private.print_order_scheduler_nonces')).rows[0]
  assert.equal((await db.query('select consume_print_order_scheduler_nonce($1,$2) ok',[record.id,Number(record.signed_at)+1])).rows[0].ok,false)
  const attempts=await Promise.all([db.query('select consume_print_order_scheduler_nonce($1,$2) ok',[record.id,record.signed_at]),
    db.query('select consume_print_order_scheduler_nonce($1,$2) ok',[record.id,record.signed_at])])
  assert.deepEqual(attempts.map(result=>result.rows[0].ok),[true,false])
  assert.equal((await db.query('select consume_print_order_scheduler_nonce(gen_random_uuid(),$1) ok',[record.signed_at])).rows[0].ok,false)
  await db.exec(command)
  const expired=(await db.query('select id,signed_at from private.print_order_scheduler_nonces where consumed_at is null')).rows[0]
  await db.query("update private.print_order_scheduler_nonces set expires_at=now()-interval '1 second' where id=$1",[expired.id])
  assert.equal((await db.query('select consume_print_order_scheduler_nonce($1,$2) ok',[expired.id,expired.signed_at])).rows[0].ok,false)
  assert.equal((await db.query("select has_function_privilege('service_role','public.consume_print_order_scheduler_nonce(uuid,bigint)','EXECUTE') allowed")).rows[0].allowed,true)
})
test('wrong/missing Vault configuration and owner conflicts never install or overwrite a scheduler', async t => {
  for (const change of ["delete from vault.secrets where name='snapfit_print_order_scheduler_secret'",
    "update vault.secrets set value='not-a-valid-private-capability' where name='snapfit_print_order_scheduler_secret'",
    "update vault.secrets set value='https://other-project.supabase.co' where name='snapfit_print_order_scheduler_project_url'"]) {
    const db = await cronFixture()
    try { await db.exec(change); await assert.rejects(db.exec(migration), /print_scheduler_vault_configuration_required/)
      assert.equal((await db.query('select count(*)::integer n from cron.job where jobname=$1', [ownName])).rows[0].n, 0)
    } finally { await db.close() }
  }
  const db = await cronFixture(); t.after(() => db.close())
  await db.query("insert into cron.job(jobname,schedule,command,username,active) values($1,'0 0 * * *','select 42','another-operator',false)", [ownName])
  await assert.rejects(db.exec(migration), /print_scheduler_job_owner_conflict/)
  assert.equal((await db.query('select command from cron.job where jobname=$1', [ownName])).rows[0].command, 'select 42')
})
test('removed/rotated invalid Vault entries stop HTTP at runtime without exposing values in Cron SQL', async t => {
  const db = await cronFixture(); t.after(() => db.close()); await db.exec(migration)
  const command = (await db.query('select command from cron.job where jobname=$1', [ownName])).rows[0].command
  await db.exec("update vault.secrets set value='invalid' where name='snapfit_print_order_scheduler_secret'")
  await db.exec(command)
  assert.equal((await db.query('select count(*)::integer n from net.http_request_queue')).rows[0].n, 1)
  await db.exec("delete from vault.secrets where name='snapfit_print_order_scheduler_project_url'")
  await db.exec(command)
  assert.equal((await db.query('select count(*)::integer n from net.http_request_queue')).rows[0].n, 1)
})

test('real SQL never polls unissued app PDF preparation, but recovers issued unknown payments after expiry and legacy invoices', async t => {
  const db = await appFixture(); t.after(() => db.close()); await db.exec(rechecks)
  const unissued = await prepare(db)
  assert.deepEqual((await db.query('select claim_production_print_payment_rechecks(3) x')).rows[0].x, [])
  assert.equal((await db.query('select last_checked_at from private.print_checkout_intents where id=$1', [unissued.id])).rows[0].last_checked_at, null)
  // These SQL fixtures isolate the polling selector. Actual SDK authorization,
  // prepayment proof and immutable binding are covered by app_pdf_checkout_sql.
  await db.query('update private.print_checkout_intents set sdk_issued_at=now() where id=$1', [unissued.id])
  assert.deepEqual((await db.query('select claim_production_print_payment_rechecks(3) x')).rows[0].x, [{ user_id: owner, payment_id: unissued.payment_id }])
  const legacy = await prepare(db, { request: '55555555-5555-4555-8555-555555555555' })
  await db.exec('alter table private.print_checkout_intents disable trigger user')
  await db.query("update private.print_checkout_intents set next_check_at=now()-interval '1 minute',expires_at=now()-interval '1 day' where id=$1", [unissued.id])
  await db.query("update private.print_checkout_intents set print_file_source='LEGACY_WORKER' where id=$1", [legacy.id])
  await db.exec('alter table private.print_checkout_intents enable trigger user')
  const selected = (await db.query('select claim_production_print_payment_rechecks(3) x')).rows[0].x
  assert.deepEqual(new Set(selected.map(row => row.payment_id)), new Set([unissued.payment_id, legacy.payment_id]))
  for (const role of ['anon', 'authenticated']) assert.equal((await db.query("select has_function_privilege($1,'public.claim_production_print_payment_rechecks(integer)','EXECUTE') allowed", [role])).rows[0].allowed, false)
  assert.equal((await db.query("select has_function_privilege('service_role','public.claim_production_print_payment_rechecks(integer)','EXECUTE') allowed")).rows[0].allowed, true)
})
