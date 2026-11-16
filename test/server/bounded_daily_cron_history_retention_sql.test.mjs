import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { pathToFileURL } from 'node:url'
import { test } from 'node:test'

const { PGlite } = await import(process.env.PGLITE_MODULE
  ? pathToFileURL(process.env.PGLITE_MODULE).href : '@electric-sql/pglite')
const read = name => readFileSync(new URL(`../../supabase/migrations/${name}`, import.meta.url), 'utf8')
const migration = read('20261101180044_bounded_daily_cron_history_retention.sql')
const repair = read('20261101180338_cron_history_background_worker_compatibility.sql')
const marker = '-- SnapFit history cleanup moved to bounded daily retention v1.'
const maintenanceName = 'snapfit-owned-cron-history-retention'
const sources = [
  ['snapfit-print-order-scheduler', '20261014165854_print_order_scheduler_cron.sql', 'scheduler_command', true, '*/2 * * * *'],
  ['snapfit-ai-template-worker', '20261020144841_ai_template_free_worker_cron.sql', 'ai_worker_command', false, '* * * * *'],
].map(([name, file, tag, active, schedule]) => {
  const command = read(file).match(new RegExp(`\\$${tag}\\$([\\s\\S]*?)\\$${tag}\\$`))[1]
  const fragment = command.match(/delete from cron\.job_run_details\b[\s\S]*?;/)[0]
  return { name, command, refined: command.replace(fragment, marker), active, schedule }
})

// This isolated PostgreSQL fixture has no production connection, credentials,
// Vault or HTTP implementation. It executes only the migration and retention SQL.
async function fixture({ restricted = false } = {}) {
  const db = new PGlite()
  await db.exec(`
    create schema cron;
    create table cron.job (
      jobid bigserial primary key, jobname text, schedule text, command text,
      username text not null default current_user, active boolean default true,
      database text default current_database(), nodename text default 'local',
      nodeport integer default 5432, unique(jobname, username)
    );
    create table cron.job_run_details (
      runid bigint generated always as identity primary key,
      jobid bigint not null, end_time timestamptz
    );
    create function cron.alter_job(job_id bigint, schedule text default null,
      command text default null, database text default null,
      username text default null, active boolean default null)
    returns void language plpgsql security definer set search_path=pg_catalog,cron as $$
    declare caller text:=case when current_setting('role')='none'
      then session_user else current_setting('role') end;
    begin
      if schedule is null and command is null and database is null
         and username is null and active is null then
        raise exception 'no updates specified';
      end if;
      update cron.job j set schedule=coalesce($2,j.schedule), command=coalesce($3,j.command),
        database=coalesce($4,j.database), username=coalesce($5,j.username), active=coalesce($6,j.active)
      where jobid=$1 and j.username=caller;
      if not found then raise exception 'job does not exist or you do not own it';end if;
    end;
    $$;
    create function cron.schedule(job_name text, job_schedule text, job_command text)
    returns bigint language plpgsql security definer set search_path=pg_catalog,cron as $$
      declare result bigint;caller text:=case when current_setting('role')='none'
        then session_user else current_setting('role') end;
      begin
        insert into cron.job(jobname,schedule,command,username) values(job_name,job_schedule,job_command,caller)
        on conflict(jobname,username) do update
          set schedule=excluded.schedule,command=excluded.command
        returning jobid into result;
        return result;
      end;
    $$;
    create table customer_sentinel(id integer primary key, unchanged boolean);
    insert into customer_sentinel values(1,true);
    insert into cron.job(jobname,schedule,command,active)
      values('other-local-job','0 * * * *','select 42',false);
  `)
  for (const source of sources) {
    await db.query('insert into cron.job(jobname,schedule,command,active) values($1,$2,$3,$4)',
      [source.name, source.schedule, source.command, source.active])
  }
  if (restricted) {
    await db.exec(`
      create role cron_operator;
      grant usage on schema cron to cron_operator;
      grant select on cron.job to cron_operator;
      grant select,delete on cron.job_run_details to cron_operator;
      grant execute on function cron.schedule(text,text,text),
        cron.alter_job(bigint,text,text,text,text,boolean) to cron_operator;
      update cron.job set username='cron_operator';
      set role cron_operator;
    `)
  }
  return db
}

const inventory = async db => (await db.query('select * from cron.job order by jobid')).rows
// Pg_cron's worker starts one transaction around all job statements. Transaction
// control is not part of the scheduled command itself (also valid for libpq mode).
const executeCron = (db, command) => {
  assert.doesNotMatch(command, /^\s*(begin|commit|rollback)\s*;/im,
    'background-worker jobs reject transaction-control statements')
  return db.transaction(tx => tx.exec(command))
}

test('moves only the exact cleanup fragment and preserves every existing job field and inactive choice', async t => {
  const db = await fixture(); t.after(() => db.close())
  const before = await inventory(db)
  await db.exec(migration)
  const after = await inventory(db)
  assert.equal(after.length, before.length + 1)
  for (const previous of before) {
    const actual = after.find(job => job.jobid === previous.jobid)
    const source = sources.find(item => item.name === previous.jobname)
    assert.deepEqual(actual, { ...previous, command: source ? source.refined : previous.command })
  }
  const maintenance = after.find(job => job.jobname === maintenanceName)
  assert.equal(maintenance.schedule, '17 19 * * *')
  assert.equal(maintenance.active, true)
  assert.equal(maintenance.username, before[0].username)
  await db.query('update cron.job set active=false where jobid=$1', [maintenance.jobid])
  const disabledInventory = await inventory(db)
  await db.exec(migration)
  assert.deepEqual(await inventory(db), disabledInventory)
  assert.deepEqual((await db.query('select * from customer_sentinel')).rows, [{ id: 1, unchanged: true }])
})

test('daily SQL deletes at most 10000 completed old records of the two owned jobs', async t => {
  const db = await fixture(); t.after(() => db.close())
  await db.exec(migration)
  await db.exec(repair)
  const jobs = await inventory(db)
  const print = jobs.find(job => job.jobname === sources[0].name).jobid
  const ai = jobs.find(job => job.jobname === sources[1].name).jobid
  const other = jobs.find(job => job.jobname === 'other-local-job').jobid
  const maintenance = jobs.find(job => job.jobname === maintenanceName)
  await db.query(`insert into cron.job_run_details(jobid,end_time)
    select case when i<=6000 then $1::bigint else $2::bigint end,now()-interval '8 days'
    from generate_series(1,12000) i`, [print, ai])
  await db.query(`insert into cron.job_run_details(jobid,end_time)
    select $1,now()-interval '30 days' from generate_series(1,17)`, [other])
  await db.query(`insert into cron.job_run_details(jobid,end_time)
    select $1,now() from generate_series(1,11)`, [print])
  await db.query(`insert into cron.job_run_details(jobid,end_time)
    select $1,null from generate_series(1,13)`, [ai])
  await db.query(`insert into cron.job_run_details(jobid,end_time)
    select $1,now()-interval '30 days' from generate_series(1,5)`, [maintenance.jobid])
  await executeCron(db, maintenance.command)
  const counts = async () => (await db.query(`select
    count(*) filter(where jobid in($1,$2) and end_time<now()-interval '7 days')::integer old_target,
    count(*) filter(where jobid=$3)::integer other_job,
    count(*) filter(where end_time>=now()-interval '7 days')::integer recent,
    count(*) filter(where end_time is null)::integer running,
    count(*) filter(where jobid=$4)::integer maintenance_history
    from cron.job_run_details`, [print, ai, other, maintenance.jobid])).rows[0]
  assert.deepEqual(await counts(), { old_target: 2000, other_job: 17, recent: 11, running: 13, maintenance_history: 5 })
  await executeCron(db, maintenance.command)
  assert.deepEqual(await counts(), { old_target: 0, other_job: 17, recent: 11, running: 13, maintenance_history: 5 })
  assert.equal((await db.query('select unchanged from customer_sentinel')).rows[0].unchanged, true)
  assert.doesNotMatch(maintenance.command, /for update/i)
  assert.match(maintenance.command, /set local lock_timeout = '1s'/i)
  assert.match(maintenance.command, /set local statement_timeout = '5s'/i)
  assert.doesNotMatch(maintenance.command, /\b(begin|commit|rollback)\s*;/i)
})

test('managed ACLs allow installation and bounded DELETE without direct job UPDATE or history UPDATE', async t => {
  const db = await fixture({ restricted: true });t.after(() => db.close())
  await assert.rejects(db.exec('select * from cron.job for update'), /permission denied for table job/)
  await assert.rejects(db.exec("update cron.job set active=true"), /permission denied for table job/)
  await assert.rejects(db.exec('select * from cron.job_run_details for update'), /permission denied for table job_run_details/)
  await assert.rejects(db.exec('select cron.alter_job(1)'), /no updates specified/)
  const before = await inventory(db)
  await db.exec(migration)
  for (const previous of before) {
    const actual = (await inventory(db)).find(job => job.jobid === previous.jobid)
    const source = sources.find(item => item.name === previous.jobname)
    assert.deepEqual(actual, { ...previous, command: source ? source.refined : previous.command })
  }
  await db.exec(repair)
  const maintenance = (await inventory(db)).find(job => job.jobname === maintenanceName)
  await db.exec('reset role')
  await db.exec(`
    create table timeout_observations(lock_timeout text, statement_timeout text);
    create function observe_retention_timeouts() returns trigger language plpgsql security definer as $$
    begin insert into timeout_observations values(current_setting('lock_timeout'),current_setting('statement_timeout'));return null;end;$$;
    create trigger observe_retention_timeouts before delete on cron.job_run_details
      for each statement execute function observe_retention_timeouts();
  `)
  const sourceId = before.find(job => job.jobname === sources[0].name).jobid
  const otherId = before.find(job => job.jobname === 'other-local-job').jobid
  await db.query(`insert into cron.job_run_details(jobid,end_time) values
    ($1,now()-interval '8 days'),($1,now()),($1,null),($2,now()-interval '8 days')`, [sourceId, otherId])
  await db.exec('set role cron_operator')
  const settings = (await db.query("select current_setting('lock_timeout') lock_timeout,current_setting('statement_timeout') statement_timeout")).rows
  await executeCron(db, maintenance.command)
  assert.equal((await db.query('select count(*)::integer n from cron.job_run_details')).rows[0].n, 3)
  assert.deepEqual((await db.query("select current_setting('lock_timeout') lock_timeout,current_setting('statement_timeout') statement_timeout")).rows, settings)
  await db.exec('reset role')
  assert.deepEqual((await db.query('select * from timeout_observations')).rows,
    [{ lock_timeout: '1s', statement_timeout: '5s' }])
  await db.exec('set role cron_operator')
  await db.query('select cron.alter_job($1,active:=false)', [maintenance.jobid])
  const disabled = await inventory(db)
  await db.exec(repair)
  assert.deepEqual(await inventory(db), disabled)
  assert.equal((await db.query("select has_table_privilege(current_user,'cron.job','UPDATE') allowed")).rows[0].allowed, false)
  assert.equal((await db.query("select has_table_privilege(current_user,'cron.job_run_details','UPDATE') allowed")).rows[0].allowed, false)
})

test('follow-up changes only daily transaction control and preserves deployed workers and inactive choices', async t => {
  const db = await fixture({ restricted: true });t.after(() => db.close())
  await db.exec(migration)
  const before = await inventory(db)
  const maintenance = before.find(job => job.jobname === maintenanceName)
  assert.match(maintenance.command, /^begin;$/m)
  assert.match(maintenance.command, /^commit;$/m)
  await db.query('select cron.alter_job($1,active:=false)', [maintenance.jobid])
  const inactive = await inventory(db)
  await db.exec(repair)
  const after = await inventory(db)
  for (const previous of inactive) {
    assert.deepEqual(after.find(job => job.jobid === previous.jobid), previous.jobid === maintenance.jobid
      ? { ...previous, command: previous.command.replace('\nbegin;\n', '\n').replace('\ncommit;\n', '\n') }
      : previous)
  }
  await db.exec(repair)
  assert.deepEqual(await inventory(db), after)
  const compatible = after.find(job => job.jobname === maintenanceName)
  await executeCron(db, compatible.command)
  assert.doesNotMatch(compatible.command, /^\s*(begin|commit|rollback)\s*;/im)
})

test('follow-up refuses unknown daily definitions, missing jobs and foreign owners atomically', async t => {
  for (const [change, error] of [
    ["update cron.job set command=command||' select 99;' where jobname='snapfit-owned-cron-history-retention'", /compatibility_command_not_recognized/],
    ["update cron.job set username='another-operator' where jobname='snapfit-owned-cron-history-retention'", /compatibility_owner_conflict/],
    ["delete from cron.job where jobname='snapfit-owned-cron-history-retention'", /compatibility_job_missing_or_ambiguous/],
  ]) {
    const db = await fixture()
    try {
      await db.exec(migration)
      await db.exec(change)
      const before = await inventory(db)
      await assert.rejects(db.exec(repair), error)
      assert.deepEqual(await inventory(db), before)
    } finally { await db.close() }
  }
})

test('unknown source versions, ownership conflicts and missing jobs fail atomically', async t => {
  for (const [change, error] of [
    ["update cron.job set command=command||' select 99;' where jobname='snapfit-ai-template-worker'", /source_command_not_recognized/],
    ["update cron.job set username='another-operator' where jobname='snapfit-print-order-scheduler'", /source_owner_conflict/],
    ["delete from cron.job where jobname='snapfit-ai-template-worker'", /source_missing_or_ambiguous/],
    ["insert into cron.job(jobname,username) values('snapfit-ai-template-worker','another-operator')", /source_missing_or_ambiguous/],
    ["insert into cron.job(jobname,username,command) values('snapfit-owned-cron-history-retention','another-operator','select 1')", /maintenance_owner_conflict/],
    ["insert into cron.job(jobname,command) values('snapfit-owned-cron-history-retention','select 1')", /maintenance_definition_not_recognized/],
  ]) {
    const db = await fixture()
    try {
      await db.exec(change)
      const before = await inventory(db)
      await assert.rejects(db.exec(migration), error)
      assert.deepEqual(await inventory(db), before)
    } finally { await db.close() }
  }
})

test('does not alter managed extension DDL, privileges or unrelated history retention', () => {
  for (const source of [migration, repair])
    assert.doesNotMatch(source, /create\s+(unique\s+)?index|alter\s+(table|extension)|grant\s|revoke\s|vacuum|unschedule\s*\(/i)
  assert.match(migration, /limit 10000/i)
  assert.match(migration, /interval '7 days'/i)
  assert.match(migration, /username = current_user/)
  assert.doesNotMatch(migration, /service_role|Bearer |eyJ/)
})
