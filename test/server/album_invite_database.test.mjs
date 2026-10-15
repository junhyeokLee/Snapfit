import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { pathToFileURL } from 'node:url'
import { test } from 'node:test'

// Optional isolated PostgreSQL runtime; never connects to a Snapfit server.
const runtime = process.env.SNAPFIT_PGLITE_ENTRY
const migration = readFileSync(new URL('../../supabase/migrations/20261008080526_album_invite_accept_atomic.sql', import.meta.url), 'utf8')
const owner = '00000000-0000-0000-0000-000000000001'
const first = '00000000-0000-0000-0000-000000000002'
const second = '00000000-0000-0000-0000-000000000003'

test('atomic invite SQL executes against isolated Postgres with permissions, retry and rollback checks', { skip: !runtime }, async () => {
  const { PGlite } = await import(pathToFileURL(runtime).href)
  const db = new PGlite()
  try {
    await db.exec(`
      create role anon; create role authenticated; create role service_role bypassrls;
      create schema auth;
      create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
      create function public.is_admin() returns boolean language sql stable as $$ select false $$;
      create table auth.users(id uuid primary key);
      create table public.albums(id bigint primary key, owner_id uuid references auth.users(id), title text default 'Original');
      create table public.album_pages(id bigint primary key, album_id bigint references public.albums(id), content text);
      create table public.album_invites(token text primary key, album_id bigint references public.albums(id) on delete cascade,
        created_by uuid references auth.users(id), role text not null check(role in ('EDITOR','VIEWER')),
        expires_at timestamptz, accepted_by uuid references auth.users(id), accepted_at timestamptz);
      create table public.album_members(album_id bigint references public.albums(id), user_id uuid references auth.users(id),
        role text not null check(role in ('OWNER','EDITOR','VIEWER')), status text not null check(status in ('PENDING','ACCEPTED')),
        invited_by uuid references auth.users(id), invite_token text, primary key(album_id,user_id));
      create unique index album_members_invite_token_key on public.album_members(invite_token) where invite_token is not null;
      grant usage on schema public to anon, authenticated, service_role;
      grant usage on schema auth to authenticated, service_role;
      grant all on all tables in schema public to service_role;
      grant select, update on public.albums to authenticated;
      grant all on public.album_pages to authenticated;
      alter table public.albums enable row level security;
      alter table public.album_pages enable row level security;
      create policy albums_read on public.albums for select to authenticated using (true);
    `)
    await db.exec(migration)
    await db.query('insert into auth.users(id) values ($1),($2),($3)', [owner, first, second])
    await db.query('insert into albums(id,owner_id) values (7,$1),(8,$1),(9,$1)', [owner])
    const invite = (token, album = 7, role = 'EDITOR', expires = '2099-01-01') => db.query(
      'insert into album_invites(token,album_id,created_by,role,expires_at) values ($1,$2,$3,$4,$5)', [token, album, owner, role, expires])
    const accept = async (token, user) => (await db.query('select public.accept_album_invite($1,$2) result', [token, user])).rows[0].result
    await invite('one')
    assert.deepEqual(await accept('one', first), { albumId: 7, role: 'EDITOR', success: true })
    assert.deepEqual(await accept('one', first), { albumId: 7, role: 'EDITOR', success: true })
    assert.deepEqual(await accept('one', second), { error: 'invite_used', status: 409 })
    assert.equal((await db.query('select count(*)::int n from album_members')).rows[0].n, 1)
    await invite('viewer', 7, 'VIEWER')
    assert.equal((await accept('viewer', first)).role, 'EDITOR')
    assert.equal((await accept('viewer', owner)).role, 'OWNER')
    assert.equal((await db.query("select accepted_at from album_invites where token='viewer'")).rows[0].accepted_at, null)
    assert.equal((await accept('viewer', second)).role, 'VIEWER')
    await db.query("insert into album_pages values (1,7,'original')")
    await db.query("select set_config('request.jwt.claim.sub', $1, false)", [second])
    await db.exec('set role authenticated')
    assert.equal((await db.query('select * from album_pages where id=1')).rows.length, 1)
    assert.equal((await db.query("update album_pages set content='forged' where id=1 returning id")).rows.length, 0)
    assert.equal((await db.query("update albums set title='forged' where id=7 returning id")).rows.length, 0)
    await assert.rejects(db.query("insert into album_pages values (2,7,'forged')"), /row-level security/)
    await db.query("select set_config('request.jwt.claim.sub', $1, false)", [first])
    assert.equal((await db.query("update album_pages set content='editor' where id=1 returning id")).rows.length, 1)
    assert.equal((await db.query("update albums set title='editor' where id=7 returning id")).rows.length, 1)
    await assert.rejects(db.query('update albums set owner_id=$1 where id=7', [first]), /album_owner_change_forbidden/)
    await db.exec('reset role')
    await db.query("select set_config('request.jwt.claim.sub', '', false)")
    await invite('expired', 8, 'EDITOR', '2020-01-01')
    assert.deepEqual(await accept('expired', first), { error: 'invite_expired', status: 410 })
    assert.deepEqual(await accept('missing', first), { error: 'invite_not_found', status: 404 })
    await db.query('delete from album_members where album_id=7 and user_id=$1', [first])
    assert.deepEqual(await accept('one', first), { error: 'invite_used', status: 409 })
    await invite('rollback', 9)
    await assert.rejects(accept('rollback', '00000000-0000-0000-0000-000000000099'))
    assert.equal((await db.query("select accepted_at from album_invites where token='rollback'")).rows[0].accepted_at, null)
    assert.equal((await db.query('select count(*)::int n from album_members where album_id=9')).rows[0].n, 0)
    await db.exec('set role authenticated')
    await assert.rejects(accept('rollback', first), /permission denied/)
    await db.exec('reset role; set role anon')
    await assert.rejects(accept('rollback', first), /permission denied/)
    await db.exec('reset role; set role service_role')
    assert.equal((await accept('rollback', first)).success, true)
    await db.exec('reset role')
    await invite('update-failure', 8)
    await db.exec(`create function public.fail_consume() returns trigger language plpgsql as $$
      begin raise exception 'fixture consumption failure'; end; $$;
      create trigger fail_consume before update on public.album_invites for each row execute function public.fail_consume();`)
    await assert.rejects(accept('update-failure', second), /fixture consumption failure/)
    assert.equal((await db.query('select count(*)::int n from album_members where album_id=8')).rows[0].n, 0)
    assert.equal((await db.query("select accepted_at from album_invites where token='update-failure'")).rows[0].accepted_at, null)
  } finally { await db.close() }
})
