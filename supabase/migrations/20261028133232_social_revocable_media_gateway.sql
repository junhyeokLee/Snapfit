-- Every new image request rechecks a short server-issued capability and current
-- publication state. Storage signing is no longer a client permission.
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create table social_private.media_key(singleton boolean primary key default true check(singleton),secret bytea not null);
insert into social_private.media_key values(true,extensions.gen_random_bytes(32));
create table social_private.media_epochs(work_id uuid primary key references public.social_works(id)on delete cascade,revision bigint not null default 1);
insert into social_private.media_epochs(work_id)select id from public.social_works;
alter table social_private.media_key enable row level security;
alter table social_private.media_epochs enable row level security;
revoke all on social_private.media_key,social_private.media_epochs from public,anon,authenticated,service_role;

create function social_private.bump_media_epoch()returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_table_name='social_works' then
  if tg_op='INSERT' then insert into social_private.media_epochs(work_id)values(new.id)on conflict do nothing;
  elsif old.status is distinct from new.status or old.moderation_hidden is distinct from new.moderation_hidden then
   update social_private.media_epochs set revision=revision+1 where work_id=new.id;
  end if;
 else
  if old.storage_path is distinct from new.storage_path then update social_private.media_epochs set revision=revision+1 where work_id=new.work_id;end if;
 end if;
 return new;
end;$$;
revoke all on function social_private.bump_media_epoch()from public,anon,authenticated,service_role;
create trigger social_media_work_epoch after insert or update of status,moderation_hidden on public.social_works for each row execute function social_private.bump_media_epoch();
create trigger social_media_path_epoch after update of storage_path on public.social_work_pages for each row execute function social_private.bump_media_epoch();

create function social_private.media_allowed(p_work uuid,p_viewer uuid)returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.social_works w where w.id=p_work and not social_private.work_restricted(w.id)
  and((w.status='published' and(w.kind='album' or social_private.moment_source_current(w.id)))or(w.author_id=p_viewer and w.status='private'))
  and(p_viewer is null or exists(select 1 from auth.users u where u.id=p_viewer and not u.is_anonymous and u.deleted_at is null and(u.banned_until is null or u.banned_until<=statement_timestamp())))
  and(p_viewer is null or not exists(select 1 from public.social_blocks b where(b.owner_id=p_viewer and b.target_id=w.author_id)or(b.owner_id=w.author_id and b.target_id=p_viewer))))
$$;
revoke all on function social_private.media_allowed(uuid,uuid)from public,anon,authenticated,service_role;
create function social_private.media_mac(p_payload text)returns text language sql stable security definer set search_path='' as $$
 select encode(extensions.hmac(convert_to(p_payload,'UTF8'),secret,'sha256'),'hex')from social_private.media_key where singleton
$$;
revoke all on function social_private.media_mac(text)from public,anon,authenticated,service_role;
create function social_private.media_equal(p_left text,p_right text)returns boolean language plpgsql immutable set search_path='' as $$
declare diff integer:=0;i integer;
begin
 if p_left is null or p_right is null or length(p_left)<>64 or length(p_right)<>64 then return false;end if;
 for i in 1..64 loop diff:=diff |(ascii(substr(p_left,i,1))#ascii(substr(p_right,i,1)));end loop;
 return diff=0;
end;$$;
revoke all on function social_private.media_equal(text,text)from public,anon,authenticated,service_role;
create function social_private.media_tokens(p_work uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare viewer uuid:=auth.uid();epoch bigint;expiry bigint;result jsonb;
begin
 if not social_private.media_allowed(p_work,viewer)then return '[]'::jsonb;end if;
 select revision into epoch from social_private.media_epochs where work_id=p_work;
 expiry:=floor(extract(epoch from statement_timestamp()))::bigint+60;
 select coalesce(jsonb_agg(jsonb_build_object('position',p.position,'expiresAt',to_timestamp(expiry),
  'token','v1.'||expiry::text||'.'||epoch::text||'.'||coalesce(viewer::text,'-')||'.'||social_private.media_mac('image|'||p_work::text||'|'||p.position::text||'|'||coalesce(viewer::text,'-')||'|'||epoch::text||'|'||expiry::text))order by p.position),'[]'::jsonb)into result
 from public.social_work_pages p where p.work_id=p_work;
 return result;
end;$$;
revoke all on function social_private.media_tokens(uuid)from public,anon,authenticated,service_role;

create or replace function social_private.social_work_json(p_id uuid)returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('id',w.id,'author',social_private.social_profile_json(w.author_id),
  'title',w.title,'caption',w.caption,'topic',w.topic,'status',w.status,'aspectRatio',w.aspect_ratio,
  'kind',w.kind,'recordDate',w.record_date,'createdAt',coalesce(w.published_at,w.created_at),
  'imagePaths',coalesce((select jsonb_agg(p.storage_path order by p.position)from public.social_work_pages p where p.work_id=w.id),'[]'::jsonb),
  'mediaVersion',2,'mediaTokens',social_private.media_tokens(w.id),
  'likeCount',(select count(*)from public.social_likes l where l.work_id=w.id),
  'commentCount',(select count(*)from public.social_comments c where c.work_id=w.id and not c.moderation_hidden and not social_private.social_blocked(c.author_id)),
  'isLiked',exists(select 1 from public.social_likes l where l.work_id=w.id and l.user_id=auth.uid()),
  'isSaved',exists(select 1 from public.social_saves s where s.work_id=w.id and s.user_id=auth.uid()),
  'sourceTemplate',case when w.kind='album' then social_private.work_template_source(w.id)else null end,
  'publicationRevision',case when w.kind='moment' and w.author_id=auth.uid()then(select s.revision from moments_private.publications s join social_private.moment_publication_sources b on b.record_id=s.record_id where b.work_id=w.id and s.current_work_id=w.id)else null end)
 from public.social_works w where w.id=p_id
$$;
revoke all on function social_private.social_work_json(uuid)from public,anon,authenticated,service_role;

create function public.social_media_descriptor(p_work_id uuid,p_position integer,p_token text)returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare parts text[];expiry bigint;epoch bigint;viewer uuid;path text;now_epoch bigint:=floor(extract(epoch from statement_timestamp()))::bigint;sig text;
begin
 if p_work_id is null or p_position not between 0 and 19 or p_token is null or length(p_token)>256 then return null;end if;
 parts:=string_to_array(p_token,'.');
 if cardinality(parts)<>5 or parts[1]<>'v1' or parts[2]!~'^[0-9]{1,12}$'or parts[3]!~'^[0-9]{1,19}$'or parts[5]!~'^[0-9a-f]{64}$'then return null;end if;
 expiry:=parts[2]::bigint;epoch:=parts[3]::bigint;
 if expiry<=now_epoch or expiry>now_epoch+60 then return null;end if;
 if parts[4]<>'-'then viewer:=parts[4]::uuid;end if;
 sig:=social_private.media_mac('image|'||p_work_id::text||'|'||p_position::text||'|'||parts[4]||'|'||epoch::text||'|'||expiry::text);
 if not social_private.media_equal(sig,parts[5])or not exists(select 1 from social_private.media_epochs e where e.work_id=p_work_id and e.revision=epoch)or not social_private.media_allowed(p_work_id,viewer)then return null;end if;
 select p.storage_path into path from public.social_work_pages p where p.work_id=p_work_id and p.position=p_position;
 if path is null or path!~'^[0-9a-f-]{36}/[0-9a-f-]{36}/([0-9]|1[0-9])[.]png$'then return null;end if;
 return jsonb_build_object('path',path,'mime','image/png');
exception when others then return null;
end;$$;
revoke all on function public.social_media_descriptor(uuid,integer,text)from public,anon,authenticated;
grant execute on function public.social_media_descriptor(uuid,integer,text)to service_role;

-- INSERT/upload checks stay in place; no client can mint a long Storage URL.
drop policy if exists social_snapshot_read on storage.objects;
create policy social_snapshots_gateway_only on storage.objects as restrictive for select to anon,authenticated using(bucket_id<>'social-snapshots');

-- One-time, recoverable copy/CAS/delete of legacy keys invalidates previously
-- issued Storage URLs. Source albums/photos never enter this queue.
create table social_private.media_rotations(
 id uuid primary key default gen_random_uuid(),work_id uuid not null references public.social_works(id)on delete cascade,
 position integer not null check(position between 0 and 19),old_path text not null unique,new_path text not null unique,
 expected_size bigint not null,expected_sha text check(expected_sha is null or expected_sha~'^[0-9a-f]{64}$'),
 state text not null default 'pending'check(state in('pending','cleanup','done')),lease_until timestamptz,finished_at timestamptz,
 foreign key(work_id,position)references public.social_work_pages(work_id,position)on delete cascade);
create table social_private.media_worker_caps(nonce uuid primary key,expires_at timestamptz not null,used_at timestamptz);
alter table social_private.media_rotations enable row level security;
alter table social_private.media_worker_caps enable row level security;
revoke all on social_private.media_rotations,social_private.media_worker_caps from public,anon,authenticated,service_role;
insert into social_private.media_rotations(work_id,position,old_path,new_path,expected_size)
 select p.work_id,p.position,p.storage_path,w.author_id::text||'/'||gen_random_uuid()::text||'/'||p.position::text||'.png',(o.metadata->>'size')::bigint
 from public.social_work_pages p join public.social_works w on w.id=p.work_id join storage.objects o on o.bucket_id='social-snapshots'and o.name=p.storage_path
 where w.status<>'draft'and o.metadata->>'mimetype'='image/png'and(o.metadata->>'size')::bigint between 24 and 8388608;
create index social_media_rotation_pending_idx on social_private.media_rotations(state,lease_until)where state<>'done';

create function social_private.make_media_worker_token()returns text language plpgsql volatile security definer set search_path=''as $$
declare nonce uuid:=gen_random_uuid();expiry bigint:=floor(extract(epoch from clock_timestamp()))::bigint+60;
begin
 delete from social_private.media_worker_caps where expires_at<clock_timestamp()-interval '1 hour';
 insert into social_private.media_worker_caps(nonce,expires_at)values(nonce,to_timestamp(expiry));
 return 'r1.'||nonce::text||'.'||expiry::text||'.'||social_private.media_mac('rotate|'||nonce::text||'|'||expiry::text);
end;$$;
revoke all on function social_private.make_media_worker_token()from public,anon,authenticated,service_role;
create function public.claim_social_media_rotations(p_token text)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare parts text[];v_nonce uuid;expiry bigint;result jsonb;
begin
 if p_token is null or length(p_token)>256 then raise exception 'media_worker_forbidden'using errcode='42501';end if;
 parts:=string_to_array(p_token,'.');
 if cardinality(parts)<>4 or parts[1]<>'r1'or parts[3]!~'^[0-9]{1,12}$'then raise exception 'media_worker_forbidden'using errcode='42501';end if;
 v_nonce:=parts[2]::uuid;expiry:=parts[3]::bigint;
 if expiry<=extract(epoch from clock_timestamp())or expiry>extract(epoch from clock_timestamp())+60 or not social_private.media_equal(parts[4],social_private.media_mac('rotate|'||v_nonce::text||'|'||expiry::text))then raise exception 'media_worker_forbidden'using errcode='42501';end if;
 update social_private.media_worker_caps set used_at=clock_timestamp()where media_worker_caps.nonce=v_nonce and used_at is null and expires_at>clock_timestamp();
 if not found then raise exception 'media_worker_forbidden'using errcode='42501';end if;
 with candidates as(select id from social_private.media_rotations where state<>'done'and(lease_until is null or lease_until<clock_timestamp())order by id for update skip locked limit 20),claimed as(
 update social_private.media_rotations j set lease_until=clock_timestamp()+interval '3 minutes'from candidates c where j.id=c.id returning j.*)
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'workId',work_id,'position',position,'oldPath',old_path,'newPath',new_path,'expectedSize',expected_size,'expectedSha',expected_sha)),'[]'::jsonb)into result from claimed;
 return result;
end;$$;
revoke all on function public.claim_social_media_rotations(text)from public,anon,authenticated;
grant execute on function public.claim_social_media_rotations(text)to service_role;
create function public.mark_social_media_rotation_digest(p_id uuid,p_sha256 text,p_size bigint)returns boolean language plpgsql security definer set search_path=''as $$
begin
 if p_sha256 is null or p_sha256!~'^[0-9a-f]{64}$'then return false;end if;
 update social_private.media_rotations set expected_sha=p_sha256 where id=p_id and state<>'done'and lease_until>clock_timestamp()and expected_size=p_size and(expected_sha is null or expected_sha=p_sha256);
 return found;
end;$$;
create function public.commit_social_media_rotation(p_id uuid,p_sha256 text)returns boolean language plpgsql security definer set search_path=''as $$
declare job social_private.media_rotations;
begin
 select *into job from social_private.media_rotations where id=p_id for update;
 if not found or job.expected_sha is distinct from p_sha256 or p_sha256 is null or(job.state<>'done'and(job.lease_until is null or job.lease_until<clock_timestamp()))then return false;end if;
 if not exists(select 1 from storage.objects o where o.bucket_id='social-snapshots'and o.name=job.new_path and o.metadata->>'mimetype'='image/png'and(o.metadata->>'size')::bigint=job.expected_size)then return false;end if;
 update public.social_work_pages set storage_path=job.new_path where work_id=job.work_id and position=job.position and storage_path in(job.old_path,job.new_path);
 if not found then return false;end if;
 update social_private.media_rotations set state=case when state='done'then'done'else'cleanup'end where id=job.id;
 return true;
end;$$;
create function public.finish_social_media_rotation(p_id uuid,p_sha256 text)returns boolean language plpgsql security definer set search_path=''as $$
declare job social_private.media_rotations;
begin
 select *into job from social_private.media_rotations where id=p_id for update;
 if not found or job.expected_sha is distinct from p_sha256 or p_sha256 is null or job.state not in('cleanup','done')then return false;end if;
 if not exists(select 1 from storage.objects where bucket_id='social-snapshots'and name=job.new_path and metadata->>'mimetype'='image/png'and(metadata->>'size')::bigint=job.expected_size)or exists(select 1 from storage.objects where bucket_id='social-snapshots'and name=job.old_path)or not exists(select 1 from public.social_work_pages where work_id=job.work_id and position=job.position and storage_path=job.new_path)then return false;end if;
 update social_private.media_rotations set state='done',lease_until=null,finished_at=coalesce(finished_at,clock_timestamp())where id=job.id;
 return true;
end;$$;
revoke all on function public.mark_social_media_rotation_digest(uuid,text,bigint),public.commit_social_media_rotation(uuid,text),public.finish_social_media_rotation(uuid,text)from public,anon,authenticated;
grant execute on function public.mark_social_media_rotation_digest(uuid,text,bigint),public.commit_social_media_rotation(uuid,text),public.finish_social_media_rotation(uuid,text)to service_role;
create function public.run_social_media_rotation_job()returns bigint language plpgsql security definer set search_path=''as $$
declare request_id bigint;
begin
 select net.http_post(url:='https://rrbhxdtriummqpztpjrk.supabase.co/functions/v1/social-media',headers:='{"Content-Type":"application/json"}'::jsonb,
 body:=jsonb_build_object('action','rotate','token',social_private.make_media_worker_token()),timeout_milliseconds:=60000)into request_id;
 return request_id;
end;$$;
revoke all on function public.run_social_media_rotation_job()from public,anon,authenticated,service_role;
