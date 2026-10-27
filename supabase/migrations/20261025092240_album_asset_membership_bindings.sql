-- Private user assets are shared only by an authenticated editor's explicit save.
-- No existing document, path, owner, binary or bucket visibility is rewritten.
create table album_private.asset_bindings(
 album_id bigint not null references public.albums(id) on delete cascade,
 storage_path text not null,
 primary key(album_id,storage_path)
);
create index album_asset_bindings_path_idx on album_private.asset_bindings(storage_path,album_id);
alter table album_private.asset_bindings enable row level security;
revoke all on album_private.asset_bindings from public,anon,authenticated;

create function album_private.decode_path(p_text text) returns text
language plpgsql immutable strict security invoker set search_path='' as $$
declare result bytea:=''::bytea; pos integer:=1; part text;
begin
 while pos<=char_length(p_text) loop
  part:=substr(p_text,pos,1);
  if part='%' then
   part:=substr(p_text,pos+1,2);
   if part !~ '^[0-9a-fA-F]{2}$' then return null; end if;
   result:=result||decode(part,'hex');pos:=pos+3;
  else result:=result||convert_to(part,'UTF8');pos:=pos+1;
  end if;
 end loop;
 return convert_from(result,'UTF8');
exception when others then return null;
end;
$$;
create function album_private.asset_path(p_value text) returns text
language plpgsql immutable strict security invoker set search_path='' as $$
declare path text;
begin
 if p_value like 'supabase://album-assets/%' then path:=substr(p_value,25);
 elsif p_value ~ '^https://rrbhxdtriummqpztpjrk[.]supabase[.]co/storage/v1/object/(public|sign|authenticated)/album-assets/' then
  path:=regexp_replace(split_part(p_value,'?',1),'^https://rrbhxdtriummqpztpjrk[.]supabase[.]co/storage/v1/object/(public|sign|authenticated)/album-assets/','');
 else return null;
 end if;
 path:=album_private.decode_path(path);
 if path is null or path='' or path ~ '(^/|(^|/)[.][.]?(/|$)|[[:cntrl:]])' then return null; end if;
 return path;
end;
$$;
create function album_private.paths(p_doc jsonb) returns setof text
language sql immutable strict security invoker set search_path='' as $$
 select distinct album_private.asset_path(s.value#>>'{}') from jsonb_path_query(p_doc,'$.** ? (@.type() == "string")') s(value)
 where album_private.asset_path(s.value#>>'{}') is not null
$$;
create function album_private.album_doc(p_album public.albums) returns jsonb
language sql immutable security invoker set search_path='' as $$
 select jsonb_build_object('document',case when pg_input_is_valid(p_album.cover_layers_json,'jsonb') then p_album.cover_layers_json::jsonb else '{}'::jsonb end,
 'image',p_album.cover_image_url,'thumbnail',p_album.cover_thumbnail_url,'original',p_album.cover_original_url,'preview',p_album.cover_preview_url)
$$;
create function album_private.album_paths(p_id bigint) returns setof text
language sql stable security definer set search_path='' as $$
 select p from public.albums a cross join lateral album_private.paths(album_private.album_doc(a))p where a.id=p_id
 union select p from public.album_pages ap cross join lateral album_private.paths(to_jsonb(ap))p where ap.album_id=p_id
$$;
create function album_private.legacy_owner_reference(p_path text,p_album bigint) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.albums a where a.id=p_album
  and (split_part(p_path,'/',1)=a.owner_id::text or p_path like 'albums/%' and exists(
   select 1 from storage.objects o where o.bucket_id='album-assets' and o.name=p_path and coalesce(o.owner_id,o.owner::text)=a.owner_id::text))
  and p_path in(select album_private.album_paths(a.id)))
$$;
create function album_private.canonical_album(p_path text) returns bigint
language plpgsql immutable strict security invoker set search_path='' as $$
begin
 if p_path ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/albums/[1-9][0-9]*/(images|covers)/[^/].*$' then return split_part(p_path,'/',3)::bigint; end if;
 return null;
exception when numeric_value_out_of_range then return null;
end;
$$;
create function album_private.asset_allowed(p_path text,p_write boolean default false) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=auth.uid(); target bigint:=album_private.canonical_album(p_path);
begin
 if actor is null or not exists(select 1 from auth.users where id=actor) then return false; end if;
 if p_write then
  return split_part(p_path,'/',1)=actor::text and (target is null or album_private.can_edit_album(target));
 end if;
 if split_part(p_path,'/',1)=actor::text then return true; end if;
 if target is not null then return album_private.can_access_album(target); end if;
 return exists(select 1 from album_private.asset_bindings b where b.storage_path=p_path and album_private.can_access_album(b.album_id))
  or exists(select 1 from public.albums a where album_private.can_access_album(a.id) and album_private.legacy_owner_reference(p_path,a.id));
end;
$$;
create function album_private.asset_in_use(p_path text) returns boolean
language sql volatile security definer set search_path='' as $$
 select exists(select 1 from album_private.asset_bindings b where b.storage_path=p_path)
 or exists(select 1 from public.albums a where p_path in(select album_private.album_paths(a.id)))
$$;

create function album_private.sync_album_assets() returns trigger
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); path text; old_paths text[]:='{}'; paths text[]; target bigint;
begin
 if tg_op='UPDATE' then
  select coalesce(array_agg(p),'{}') into old_paths from album_private.paths(album_private.album_doc(old))p;
 end if;
 select coalesce(array_agg(distinct p order by p),'{}') into paths from(
  select p from album_private.paths(album_private.album_doc(new))p
  union select p from public.album_pages ap cross join lateral album_private.paths(to_jsonb(ap))p where ap.album_id=new.id)all_paths;
 foreach path in array paths loop
  perform 1 from storage.objects where bucket_id='album-assets' and name=path for key share;
  target:=album_private.canonical_album(path);
  if actor is not null then
   -- A guessed path in the JSON must never turn into an access grant.
   if not (
     (target is not null and target=new.id and exists(select 1 from storage.objects o where o.bucket_id='album-assets' and o.name=path)) or
     (target is null and split_part(path,'/',1)=actor::text and exists(select 1 from storage.objects o where o.bucket_id='album-assets' and o.name=path)) or
     (target is null and path like 'albums/%' and exists(select 1 from storage.objects o where o.bucket_id='album-assets' and o.name=path and coalesce(o.owner_id,o.owner::text)=actor::text)) or
     exists(select 1 from album_private.asset_bindings b where b.album_id=new.id and b.storage_path=path) or
     (path=any(old_paths) and split_part(path,'/',1)=new.owner_id::text)
    ) then raise exception 'album_asset_share_forbidden' using errcode='42501'; end if;
  end if;
  insert into album_private.asset_bindings values(new.id,path) on conflict do nothing;
 end loop;
 delete from album_private.asset_bindings where album_id=new.id and not(storage_path=any(paths));
 return new;
end;
$$;
create trigger albums_sync_asset_bindings after insert or update on public.albums for each row execute function album_private.sync_album_assets();

create function album_private.protect_referenced_asset() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if old.bucket_id<>'album-assets' then return case when tg_op='DELETE' then old else new end; end if;
 if auth.uid() is null then return case when tg_op='DELETE' then old else new end; end if;
 if tg_op='UPDATE' and (to_jsonb(new)-array['last_accessed_at','updated_at'])=(to_jsonb(old)-array['last_accessed_at','updated_at']) then return new; end if;
 -- Serialize with saves before checking current references; a dangling save may
 -- fail safely if this deletion commits first. No referenced content is removed.
 perform 1 from storage.objects where bucket_id=old.bucket_id and name=old.name for update;
 if album_private.asset_in_use(old.name) then raise exception 'album_asset_in_use' using errcode='42501'; end if;
 return case when tg_op='DELETE' then old else new end;
end;
$$;
create trigger album_assets_protect_references before update or delete on storage.objects for each row execute function album_private.protect_referenced_asset();

-- Remove all broad legacy grants and replace their exact bucket scope.
drop policy if exists album_assets_legacy_authenticated_read on storage.objects;
drop policy if exists album_assets_legacy_authenticated_insert on storage.objects;
drop policy if exists album_assets_legacy_authenticated_update on storage.objects;
drop policy if exists album_assets_legacy_authenticated_delete on storage.objects;
drop policy if exists album_assets_own_or_admin_read on storage.objects;
drop policy if exists album_assets_own_insert on storage.objects;
drop policy if exists album_assets_own_or_admin_update on storage.objects;
drop policy if exists album_assets_own_or_admin_delete on storage.objects;
create policy album_assets_member_read on storage.objects for select to authenticated
 using(bucket_id='album-assets' and album_private.asset_allowed(name,false));
create policy album_assets_member_insert on storage.objects for insert to authenticated
 with check(bucket_id='album-assets' and album_private.asset_allowed(name,true));
create policy album_assets_uploader_update on storage.objects for update to authenticated
 using(bucket_id='album-assets' and split_part(name,'/',1)=(select auth.uid())::text)
 with check(bucket_id='album-assets' and split_part(name,'/',1)=(select auth.uid())::text and album_private.asset_allowed(name,true));
create policy album_assets_uploader_delete on storage.objects for delete to authenticated
 using(bucket_id='album-assets' and split_part(name,'/',1)=(select auth.uid())::text);

revoke all on all functions in schema album_private from public,anon,authenticated;
-- Public invoker wrappers and Storage/RLS policies need only these entry points.
grant execute on function album_private.can_access_album(bigint),album_private.can_edit_album(bigint),album_private.collaboration_api(text,jsonb),album_private.save_album(bigint,timestamptz,jsonb,uuid,uuid),album_private.asset_allowed(text,boolean) to authenticated;
grant execute on function album_private.can_access_album(bigint),album_private.can_edit_album(bigint) to service_role;
