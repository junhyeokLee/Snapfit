-- New clients durably retain one immutable creation seed and request UUID before
-- calling this API. Existing albums INSERT grants/policies remain unchanged.
-- This permanent key ledger is deliberately not pruned: deleting an album must
-- never make an old, delayed creation request create it again.
create table album_private.creation_requests (
 actor_id uuid not null references auth.users(id) on delete cascade,
 request_id uuid not null,
 request_fingerprint text not null check (char_length(request_fingerprint)=64),
 album_id bigint references public.albums(id) on delete set null,
 initial_result jsonb,
 created_at timestamptz not null default clock_timestamp(),
 deleted_at timestamptz,
 primary key (actor_id,request_id),
 check (deleted_at is null or (album_id is null and initial_result is null))
);
create index album_creation_requests_album_idx
 on album_private.creation_requests(album_id) where album_id is not null;
alter table album_private.creation_requests enable row level security;
revoke all on album_private.creation_requests from public,anon,authenticated;

-- The FK keeps the request tombstone even if an album ID is later reused by a
-- legacy INSERT. Erase the deleted seed rather than retaining its private paths.
create function album_private.tombstone_creation_request() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if old.album_id is not null and new.album_id is null then
  new.initial_result:=null;
  new.deleted_at:=clock_timestamp();
 end if;
 return new;
end;
$$;
revoke all on function album_private.tombstone_creation_request()
 from public,anon,authenticated;
create trigger album_creation_request_tombstone
 before update of album_id on album_private.creation_requests
 for each row execute function album_private.tombstone_creation_request();

create function album_private.create_album(
 p_request_id uuid,p_expected_actor_id uuid,p_album jsonb
) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
 actor uuid:=auth.uid();
 saved album_private.creation_requests;
 current_owner uuid;
 fingerprint text;
 result jsonb;
 field text;
begin
 if actor is null then
  raise exception 'album_login_required' using errcode='42501';
 end if;
 if p_expected_actor_id is null or p_expected_actor_id<>actor then
  raise exception 'album_editor_session_changed' using errcode='42501';
 end if;
 if p_request_id is null or p_request_id='00000000-0000-0000-0000-000000000000'::uuid then
  raise exception 'album_creation_request_required' using errcode='22023';
 end if;
 -- A stale JWT of a removed or disabled account is insufficient. Key-share
 -- prevents account deletion midway through this transaction without locking
 -- unrelated creation requests for the same owner against each other.
 perform 1 from auth.users u where u.id=actor and u.deleted_at is null
  and (u.banned_until is null or u.banned_until<=now()) for key share;
 if not found then
  raise exception 'album_login_required' using errcode='42501';
 end if;
 if jsonb_typeof(p_album) is distinct from 'object' then
  raise exception 'album_invalid_creation' using errcode='22023';
 end if;
 if exists(
  select 1 from jsonb_object_keys(p_album) k where k not in(
   'title','ratio','cover_layers_json','cover_image_url','cover_thumbnail_url',
   'cover_original_url','cover_preview_url','cover_theme','target_pages'
  )
 ) then
  raise exception 'album_invalid_creation' using errcode='22023';
 end if;
 if octet_length(p_album::text)>8388608 then
  raise exception 'album_document_too_large' using errcode='22023';
 end if;
 foreach field in array array['title','ratio','cover_layers_json'] loop
  if jsonb_typeof(p_album->field) is distinct from 'string' then
   raise exception 'album_invalid_creation' using errcode='22023';
  end if;
 end loop;
 foreach field in array array['cover_image_url','cover_thumbnail_url','cover_original_url','cover_preview_url','cover_theme'] loop
  if p_album?field and jsonb_typeof(p_album->field) not in('string','null') then
   raise exception 'album_invalid_creation' using errcode='22023';
  end if;
 end loop;
 -- Empty titles and a zero target are supported by the existing create flow.
 -- Ordinary full-document saves continue to use their existing validation/CAS.
 if char_length(p_album->>'title')>80 or char_length(p_album->>'ratio') not between 1 and 50 then
  raise exception 'album_invalid_creation' using errcode='22023';
 end if;
 if p_album?'target_pages' and (
  jsonb_typeof(p_album->'target_pages') is distinct from 'number'
  or (p_album->>'target_pages') !~ '^(0|[1-9][0-9]*)$'
 ) then
  raise exception 'album_invalid_target_pages' using errcode='22023';
 end if;
 if p_album?'target_pages' and (p_album->>'target_pages')::numeric not between 0 and 80 then
  raise exception 'album_invalid_target_pages' using errcode='22023';
 end if;
 fingerprint:=encode(sha256(convert_to(p_album::text,'UTF8')),'hex');
 -- The unique key waits for a concurrent identical request to commit/rollback.
 -- No album is inserted before this key is claimed. Lock order is request first;
 -- replay reads the album without a row lock so FK deletion cannot deadlock it.
 insert into album_private.creation_requests(actor_id,request_id,request_fingerprint)
 values(actor,p_request_id,fingerprint) on conflict(actor_id,request_id) do nothing;
 select * into saved from album_private.creation_requests
  where actor_id=actor and request_id=p_request_id for update;
 if saved.request_fingerprint<>fingerprint then
  raise exception 'album_creation_request_conflict' using errcode='PT409';
 end if;
 if saved.deleted_at is not null then
  raise exception 'album_creation_deleted' using errcode='PT410';
 end if;
 if saved.initial_result is not null then
  select a.owner_id into current_owner from public.albums a where a.id=saved.album_id;
  if not found then
   raise exception 'album_creation_deleted' using errcode='PT410';
  end if;
  if current_owner<>actor then
   raise exception 'album_creation_access_denied' using errcode='42501';
  end if;
  -- Always replay the original revision, never a newer row. A stale client seed
  -- must fail existing save_album_document CAS after another tab has edited it.
  return saved.initial_result;
 end if;
 insert into public.albums(
  owner_id,title,ratio,cover_layers_json,cover_image_url,cover_thumbnail_url,
  cover_original_url,cover_preview_url,cover_theme,target_pages
 ) values(
  actor,p_album->>'title',p_album->>'ratio',p_album->>'cover_layers_json',
  p_album->>'cover_image_url',p_album->>'cover_thumbnail_url',
  p_album->>'cover_original_url',p_album->>'cover_preview_url',
  p_album->>'cover_theme',coalesce((p_album->>'target_pages')::integer,0)
 ) returning to_jsonb(albums.*) into result;
 update album_private.creation_requests set album_id=(result->>'id')::bigint,
  initial_result=result where actor_id=actor and request_id=p_request_id;
 return result;
end;
$$;
revoke all on function album_private.create_album(uuid,uuid,jsonb)
 from public,anon,authenticated;
grant execute on function album_private.create_album(uuid,uuid,jsonb) to authenticated;

create function public.create_album_document(
 p_request_id uuid,p_expected_actor_id uuid,p_album jsonb
) returns jsonb
language sql security invoker set search_path='' as $$
 select album_private.create_album(p_request_id,p_expected_actor_id,p_album)
$$;
revoke all on function public.create_album_document(uuid,uuid,jsonb) from public,anon;
grant execute on function public.create_album_document(uuid,uuid,jsonb) to authenticated;

comment on table album_private.creation_requests is
 'RPC-only permanent creation identities. No direct client policies or grants. Deleted albums keep a hash/key tombstone, never their seed document.';
comment on function public.create_album_document(uuid,uuid,jsonb) is
 'Create exactly one owner album per durable request key. Identical retries return the original row/revision; changed seeds and deleted requests cannot create another album.';
