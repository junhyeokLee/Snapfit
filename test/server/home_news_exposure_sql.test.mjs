// The real migration in disposable PostgreSQL. PGlite queues one connection;
// queued retry coverage is not a separate-session load/locking benchmark.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
import {pathToFileURL} from 'node:url';

const {PGlite} = await import(process.env.PGLITE_MODULE
  ? pathToFileURL(process.env.PGLITE_MODULE).href : '@electric-sql/pglite');
const migration = readFileSync(new URL(
  '../../supabase/migrations/20261027014355_home_news_exposure_policy.sql', import.meta.url), 'utf8');
const a = '11111111-1111-4111-8111-111111111111';
const b = '22222222-2222-4222-8222-222222222222';
const c = '33333333-3333-4333-8333-333333333333';

async function fixture() {
  const db = new PGlite();
  await db.exec(`create role anon; create role authenticated; create role service_role bypassrls;
    create schema auth; create schema attendance_private; create schema referral_private; create schema moments_private;
    create table auth.users(id uuid primary key,is_anonymous boolean not null default false,banned_until timestamptz,deleted_at timestamptz);
    create function auth.uid()returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    grant usage on schema public,auth to anon,authenticated,service_role;
    create table attendance_private.daily_attendance(user_id uuid,attendance_date date);
    create table referral_private.redemptions(invitee_id uuid,inviter_id uuid);
    create table public.point_ledger(user_id uuid,reason text);
    create table public.albums(id bigint primary key,owner_id uuid);
    create table moments_private.weekly_moments(owner_id uuid,record_date date,photos jsonb,deleted_at timestamptz);
    create table moments_private.month_albums(owner_id uuid,month date,album_id bigint);
    insert into auth.users(id)values('${a}'),('${b}'),('${c}');`);
  await db.exec(migration);
  await db.exec(`create schema test_clock; create table test_clock.current(instant timestamptz);
    insert into test_clock.current values('2026-10-26T03:00:00Z');
    create or replace function home_news_private.server_now()returns timestamptz
      language sql volatile security invoker set search_path=''as $$select instant from test_clock.current$$;`);
  return db;
}

async function login(db, actor = a, role = 'authenticated') {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,false)", [actor ?? '']);
  await db.exec(`set role ${role}`);
}
async function clock(db, at, actor = a) {
  await db.exec('reset role');
  await db.query('update test_clock.current set instant=$1', [at]);
  await login(db, actor);
}
const state = async db => (await db.query('select public.get_home_news_state() result')).rows[0].result;
const claim = async (db, id) => (await db.query('select public.claim_home_news_exposure($1) result', [id])).rows[0].result;
const interact = async (db, id, interaction) => (await db.query(
  'select public.record_home_news_interaction($1,$2) result', [id, interaction])).rows[0].result;

test('server delivery state has no private content and status does not create points or exposure rows', async () => {
  const db = await fixture();
  try {
    await login(db);
    const first = await state(db);
    assert.deepEqual(Object.keys(first).sort(), ['userId','serverNow','serverDate','weekStart','timezone','claimed',
      'dailyCount','weeklyCount','hasAttendanceEver','hasReferralReward','history'].sort());
    assert.equal(first.userId, a);
    assert.equal(first.serverDate, '2026-10-26');
    assert.equal(first.weekStart, '2026-10-26');
    assert.equal(first.timezone, 'Asia/Seoul');
    assert.equal(first.dailyCount, 0);
    assert.equal(first.weeklyCount, 0);
    assert.equal(first.hasAttendanceEver, false);
    assert.equal(first.hasReferralReward, false);
    assert.deepEqual(first.history, []);
    await db.exec('reset role');
    assert.equal((await db.query('select count(*)::int n from point_ledger')).rows[0].n, 0);
    assert.equal((await db.query('select count(*)::int n from home_news_private.exposures')).rows[0].n, 0);
  } finally { await db.close(); }
});

test('Korean daily and Monday-week caps survive app/web retries, month changes and campaign replay', async () => {
  const db = await fixture();
  try {
    await login(db);
    await db.exec("set timezone='Pacific/Kiritimati'");
    const replies = await Promise.all(Array.from({length: 12}, () => claim(db, 'monthly-design:2026-10')));
    assert.equal(replies.filter(reply => reply.claimed).length, 1);
    assert.equal((await claim(db, 'attendance-benefit:v1')).claimed, false);
    await clock(db, '2026-10-26T14:59:59Z');
    assert.equal((await state(db)).dailyCount, 1);
    await clock(db, '2026-10-26T15:00:00Z');
    const nextDay = await claim(db, 'attendance-benefit:v1');
    assert.equal(nextDay.claimed, true);
    assert.equal(nextDay.serverDate, '2026-10-27');
    assert.equal(nextDay.weeklyCount, 2);
    await clock(db, '2026-10-28T03:00:00Z');
    assert.equal((await claim(db, 'referral-benefit:v1')).claimed, false);
    await clock(db, '2026-11-01T14:59:59Z');
    assert.equal((await state(db)).weekStart, '2026-10-26');
    assert.equal((await claim(db, 'monthly-design:2026-11')).claimed, false);
    await clock(db, '2026-11-01T15:00:00Z');
    const monday = await claim(db, 'referral-benefit:v1');
    assert.equal(monday.claimed, true);
    assert.equal(monday.weekStart, '2026-11-02');
    assert.equal(monday.weeklyCount, 1);
    await clock(db, '2026-11-03T03:00:00Z');
    assert.equal((await claim(db, 'attendance-benefit:v1')).claimed, false);
    assert.equal((await claim(db, 'monthly-design:2026-10')).claimed, false);
    assert.equal((await claim(db, 'monthly-design:2026-11')).claimed, true);
  } finally { await db.close(); }
});

test('server clock is read again after the account delivery lock across midnight', async () => {
  const db = await fixture();
  try {
    await db.exec(`create table test_clock.calls(n int);insert into test_clock.calls values(0);
      create or replace function home_news_private.server_now()returns timestamptz
      language plpgsql volatile security invoker set search_path=''as $$declare n int;begin
        update test_clock.calls set n=test_clock.calls.n+1 returning test_clock.calls.n into n;
        return case when n=1 then '2026-10-31T14:59:59Z'::timestamptz else '2026-10-31T15:00:00Z'::timestamptz end;
      end$$;`);
    await login(db);
    const next = await claim(db, 'monthly-design:2026-11');
    assert.equal(next.claimed, true);
    assert.equal(next.serverDate, '2026-11-01');
    assert.equal(next.history[0].month, '2026-11-01');
  } finally { await db.close(); }
});

test('permanent accounts only; private tables/helpers and other owners are inaccessible', async () => {
  const db = await fixture();
  try {
    await login(db, null, 'anon');
    await assert.rejects(() => state(db), /permission denied/);
    await assert.rejects(() => claim(db, 'attendance-benefit:v1'), /permission denied/);
    await login(db, null);
    await assert.rejects(() => state(db), /HOME_NEWS_LOGIN_REQUIRED/);
    for (const patch of ['is_anonymous=true', "banned_until='2099-01-01'", "deleted_at='2026-10-01'"]) {
      await db.exec('reset role');
      await db.exec(`update auth.users set is_anonymous=false,banned_until=null,deleted_at=null where id='${a}';
        update auth.users set ${patch} where id='${a}';`);
      await login(db);
      await assert.rejects(() => claim(db, 'attendance-benefit:v1'), /HOME_NEWS_ACCOUNT_REQUIRED/);
    }
    await login(db, b);
    assert.equal((await claim(db, 'monthly-design:2026-10')).claimed, true);
    await login(db, c);
    assert.deepEqual((await state(db)).history, []);
    await assert.rejects(() => db.query('select * from home_news_private.exposures'), /permission denied/);
    await assert.rejects(() => db.query('select home_news_private.state_json($1,now(),false)', [b]), /permission denied/);
    await assert.rejects(() => db.query('select home_news_private.server_now()'), /permission denied/);
    await assert.rejects(() => db.query('select get_home_news_state($1)', [b]), /does not exist/);
  } finally { await db.close(); }
});

test('month review requires current-month photos, the last seven days and no existing owned monthly album', async () => {
  const db = await fixture();
  try {
    await db.query(`insert into moments_private.weekly_moments values
      ($1,'2026-10-01','[{"path":"private/not-exposed.jpg"}]',null),
      ($2,'2026-10-10','[{"path":"private/also-not-exposed.jpg"}]',null),
      ($3,'2026-10-10','[]','2026-10-11')`, [a, b, c]);
    await db.query('insert into public.albums values(12,$1)', [b]);
    await db.query("insert into moments_private.month_albums values($1,'2026-10-01',12)", [b]);
    await clock(db, '2026-10-24T03:00:00Z');
    assert.equal((await claim(db, 'month-review:2026-10')).claimed, false);
    await clock(db, '2026-10-25T03:00:00Z');
    const shown = await claim(db, 'month-review:2026-10');
    assert.equal(shown.claimed, true);
    assert.equal(JSON.stringify(shown).includes('private/'), false);
    await login(db, b);
    assert.equal((await claim(db, 'month-review:2026-10')).claimed, false);
    await login(db, c);
    assert.equal((await claim(db, 'month-review:2026-10')).claimed, false);
    await clock(db, '2026-11-01T03:00:00Z', c);
    assert.equal((await claim(db, 'month-review:2026-10')).claimed, false);
    assert.equal((await claim(db, 'month-review:2026-11')).claimed, false);
  } finally { await db.close(); }
});

test('lifetime attendance and either side of real referral rewards suppress first-use benefit messages', async () => {
  const db = await fixture();
  try {
    await db.query("insert into attendance_private.daily_attendance values($1,'2025-01-01')", [a]);
    await db.query("insert into public.point_ledger values($1,'REFERRAL_INVITER')", [a]);
    await db.query('insert into referral_private.redemptions values($1,$2)', [b, c]);
    await login(db);
    const own = await state(db);
    assert.equal(own.hasAttendanceEver, true);
    assert.equal(own.hasReferralReward, true);
    assert.equal((await claim(db, 'attendance-benefit:v1')).claimed, false);
    assert.equal((await claim(db, 'referral-benefit:v1')).claimed, false);
    for (const actor of [b, c]) {
      await login(db, actor);
      assert.equal((await state(db)).hasReferralReward, true);
      assert.equal((await claim(db, 'referral-benefit:v1')).claimed, false);
    }
  } finally { await db.close(); }
});

test('dismiss/click are idempotent, cannot forge exposure history and never reset one-campaign suppression', async () => {
  const db = await fixture();
  try {
    await login(db);
    assert.deepEqual((await interact(db, 'monthly-design:2026-10', 'click')).history, []);
    await claim(db, 'monthly-design:2026-10');
    await clock(db, '2026-10-26T03:01:00Z');
    const dismissed = await interact(db, 'monthly-design:2026-10', 'dismiss');
    assert.equal(dismissed.history[0].dismissedAt, '2026-10-26T03:01:00+00:00');
    await clock(db, '2026-10-26T03:02:00Z');
    const clicked = await interact(db, 'monthly-design:2026-10', 'click');
    assert.equal(clicked.history[0].clickedAt, '2026-10-26T03:02:00+00:00');
    assert.equal(clicked.dailyCount, 1);
    assert.equal(clicked.weeklyCount, 1);
    assert.deepEqual((await interact(db, 'monthly-design:2026-10', 'dismiss')).history, clicked.history);
    await assert.rejects(() => interact(db, 'monthly-design:2026-10', 'unknown'), /HOME_NEWS_INVALID_INTERACTION/);
    await login(db, b);
    assert.deepEqual((await interact(db, 'monthly-design:2026-10', 'click')).history, []);
    await clock(db, '2026-11-03T03:00:00Z');
    assert.equal((await claim(db, 'monthly-design:2026-10')).claimed, false);
    await db.exec('reset role');
    await db.query('delete from auth.users where id=$1', [a]);
    assert.equal((await db.query('select count(*)::int n from home_news_private.exposures')).rows[0].n, 0);
  } finally { await db.close(); }
});
