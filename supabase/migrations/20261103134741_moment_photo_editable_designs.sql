-- Editable photo artwork stays in private journal metadata. Public feed APIs
-- continue returning isolated raster pages and never expose these layer maps.
create function moments_private.check_design_frame(p_key text,p_actor uuid)returns void
language plpgsql stable security invoker set search_path='' as $$
declare product public.point_shop_products; owned boolean;
begin
 if p_key is null or p_key='' then return;end if;
 if p_key !~ '^[a-zA-Z0-9_-]{1,120}$'then raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
 select *into product from public.point_shop_products where product_key='frame:'||p_key;
 if not found or product.kind is distinct from 'frame' or product.point_price is null or product.point_price<0 then
  raise exception 'MOMENTS_DESIGN_MATERIAL_UNAVAILABLE'using errcode='42501';end if;
 select exists(select 1 from public.point_shop_ownership o where o.user_id=p_actor and o.product_key=product.product_key)into owned;
 if not owned and (product.is_active is distinct from true or product.point_price>0)then
  raise exception 'MOMENTS_DESIGN_MATERIAL_UNAVAILABLE'using errcode='42501';end if;
end;$$;

create function moments_private.check_design_number(p_value jsonb,p_min numeric,p_max numeric,p_optional boolean default true)returns void
language plpgsql immutable security invoker set search_path='' as $$
begin
 if p_optional and(p_value is null or p_value='null'::jsonb)then return;end if;
 if jsonb_typeof(p_value)is distinct from'number'then raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
 if(p_value#>>'{}')::numeric not between p_min and p_max then raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
end;$$;

create function moments_private.check_design_color(p_value jsonb)returns void
language plpgsql immutable security invoker set search_path='' as $$
begin
 if p_value is null or p_value='null'::jsonb then return;end if;
 if jsonb_typeof(p_value)is distinct from'string'or(p_value#>>'{}')!~'^#[a-fA-F0-9]{6}([a-fA-F0-9]{2})?$'then
  raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
end;$$;

create function moments_private.check_design_pair(p_value jsonb,p_keys text[],p_min numeric,p_max numeric)returns void
language plpgsql immutable security invoker set search_path='' as $$
declare field text;
begin
 if p_value is null or p_value='null'::jsonb then return;end if;
 if jsonb_typeof(p_value)is distinct from'object'then raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
 if exists(select 1 from jsonb_object_keys(p_value)k where not(k=any(p_keys)))then raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
 foreach field in array p_keys loop perform moments_private.check_design_number(p_value->field,p_min,p_max,false);end loop;
end;$$;

create function moments_private.validate_design_text_style(p_style jsonb)returns void
language plpgsql immutable security invoker set search_path='' as $$
declare field text;shadow jsonb;
begin
 if p_style is null or p_style='null'::jsonb then return;end if;
 if jsonb_typeof(p_style)is distinct from'object'then raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
 if exists(select 1 from jsonb_object_keys(p_style)k where k not in
  ('fontSize','fontSizeRatio','fontWeight','fontStyle','fontFamily','color','letterSpacing','height','shadows'))then
  raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
 perform moments_private.check_design_number(p_style->'fontSize',.1,4096);
 perform moments_private.check_design_number(p_style->'fontSizeRatio',.00001,8);
 perform moments_private.check_design_number(p_style->'letterSpacing',-1000,1000);
 perform moments_private.check_design_number(p_style->'height',.01,20);
 foreach field in array array['fontWeight','fontStyle']loop
  if p_style->field is null or p_style->field='null'::jsonb then continue;end if;
  perform moments_private.check_design_number(p_style->field,0,case when field='fontStyle'then 1 else 8 end,false);
  if(p_style->>field)!~'^[0-9]$'then raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
 end loop;
 if p_style->'fontFamily' is not null and p_style->'fontFamily'<>'null'::jsonb then
  if jsonb_typeof(p_style->'fontFamily')is distinct from'string'or char_length(p_style->>'fontFamily')>100 then
   raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
 end if;
 perform moments_private.check_design_color(p_style->'color');
 if p_style->'shadows' is null or p_style->'shadows'='null'::jsonb then return;end if;
 if jsonb_typeof(p_style->'shadows')is distinct from'array'then raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
 if jsonb_array_length(p_style->'shadows')>8 then raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
 for shadow in select value from jsonb_array_elements(p_style->'shadows')loop
  if jsonb_typeof(shadow)is distinct from'object'then raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
  if exists(select 1 from jsonb_object_keys(shadow)k where k not in('color','blurRadius','blurRadiusRatio','offset','offsetRatio'))
   or shadow->'color'is null or shadow->'color'='null'::jsonb then raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
  perform moments_private.check_design_color(shadow->'color');
  perform moments_private.check_design_number(shadow->'blurRadius',0,4096);
  perform moments_private.check_design_number(shadow->'blurRadiusRatio',0,8);
  perform moments_private.check_design_pair(shadow->'offset',array['dx','dy'],-4096,4096);
  perform moments_private.check_design_pair(shadow->'offsetRatio',array['dx','dy'],-8,8);
 end loop;
end;$$;

create function moments_private.check_design_clip(p_clip jsonb)returns void
language plpgsql immutable security invoker set search_path='' as $$
begin
 if p_clip is null or p_clip='null'::jsonb then return;end if;
 if jsonb_typeof(p_clip)is distinct from'object'then raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
 if exists(select 1 from jsonb_object_keys(p_clip)k where k not in('x','y','width','height'))then raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
 perform moments_private.check_design_number(p_clip->'x',-4,4,false);
 perform moments_private.check_design_number(p_clip->'y',-4,4,false);
 perform moments_private.check_design_number(p_clip->'width',.00001,8,false);
 perform moments_private.check_design_number(p_clip->'height',.00001,8,false);
end;$$;

create function moments_private.validate_photo_design(p_design jsonb,p_actor uuid)returns void
language plpgsql stable security invoker set search_path='' as $$
declare canvas jsonb;layer jsonb;payload jsonb;field text;v text;seen text[]:='{}';has_original boolean:=false;layer_original boolean;allowed text[];
 free_stickers text[]:=array['stickerBlueStar','stickerHeartRed','stickerLeafGreen','stickerFlowerPink','stickerPaperClip','stickerTapeBeige','stickerCloudSoft','stickerCloverGreen'];
begin
 if jsonb_typeof(p_design)is distinct from'object'then raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
 if octet_length(p_design::text)>131072 or p_design->'version'is distinct from'1'::jsonb
  or exists(select 1 from jsonb_object_keys(p_design)k where k not in('version','canvas','backgroundColor','layers'))then
  raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
 canvas:=p_design->'canvas';
 if jsonb_typeof(canvas)is distinct from'object'then raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
 if exists(select 1 from jsonb_object_keys(canvas)k where k not in('width','height'))then raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
 perform moments_private.check_design_number(canvas->'width',64,4096,false);
 perform moments_private.check_design_number(canvas->'height',64,4096,false);
 if(canvas->>'width')::numeric/(canvas->>'height')::numeric not between .1 and 10
  or jsonb_typeof(p_design->'backgroundColor')is distinct from'string'or(p_design->>'backgroundColor')!~'^#[a-fA-F0-9]{8}$'then
  raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
 if jsonb_typeof(p_design->'layers')is distinct from'array'then raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
 if jsonb_array_length(p_design->'layers')not between 1 and 40 then raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
 for layer in select value from jsonb_array_elements(p_design->'layers')loop
  if jsonb_typeof(layer)is distinct from'object'then raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
  if exists(select 1 from jsonb_object_keys(layer)k where k not in
   ('id','type','zIndex','x','y','width','height','scale','rotation','opacity','templateContent','canvasClip','payload'))
   or jsonb_typeof(layer->'id')is distinct from'string'or char_length(layer->>'id')not between 1 and 128
   or(layer->>'id')=any(seen)or coalesce(layer->>'type','')not in('IMAGE','TEXT','DECORATION')then
   raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
  seen:=array_append(seen,layer->>'id');
  perform moments_private.check_design_number(layer->'x',-4,4,false);
  perform moments_private.check_design_number(layer->'y',-4,4,false);
  perform moments_private.check_design_number(layer->'width',.00001,8,false);
  perform moments_private.check_design_number(layer->'height',.00001,8,false);
  perform moments_private.check_design_number(layer->'scale',.01,20);
  perform moments_private.check_design_number(layer->'rotation',-3600,3600);
  perform moments_private.check_design_number(layer->'opacity',0,1);
  if layer?'zIndex'and layer->'zIndex'<>'null'::jsonb then
   perform moments_private.check_design_number(layer->'zIndex',-10000,10000,false);
   if(layer->>'zIndex')!~'^-?[0-9]{1,5}$'then raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
  end if;
  if layer?'templateContent'and jsonb_typeof(layer->'templateContent')not in('null','boolean')then raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
  perform moments_private.check_design_clip(layer->'canvasClip');
  payload:=layer->'payload';
  if jsonb_typeof(payload)is distinct from'object'then raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
  allowed:=case layer->>'type'
   when'IMAGE'then array['imageBackground','imageTemplate','imageZoom','imageOffsetRatio','originalUrl','previewUrl','imageUrl']
   when'DECORATION'then array['imageBackground','imageTemplate','fillColor','borderColor','borderWidth','cornerRadius','originalUrl','previewUrl','imageUrl']
   else array['text','textAlign','textStyleType','textBackground','textFillMode','textFillImageUrl','bubbleColor','textStyle']end;
  if exists(select 1 from jsonb_object_keys(payload)k where not(k=any(allowed)))then raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
  layer_original:=false;
  foreach field in array array['originalUrl','previewUrl','imageUrl','textFillImageUrl']loop
   if not(payload?field)or payload->field='null'::jsonb then continue;end if;
   if jsonb_typeof(payload->field)is distinct from'string'then raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
   v:=payload->>field;
   if v<>''and(v<>'moment-photo://original'or layer->>'type'='DECORATION')then
    raise exception 'MOMENTS_INVALID_DESIGN_SOURCE'using errcode='42501';end if;
   if layer->>'type'='IMAGE'and v='moment-photo://original'then layer_original:=true;has_original:=true;end if;
  end loop;
  foreach field in array array['imageBackground','imageTemplate','text','textAlign','textStyleType','textBackground','textFillMode']loop
   if payload?field and payload->field<>'null'::jsonb and(jsonb_typeof(payload->field)is distinct from'string'or char_length(payload->>field)>4000)then
    raise exception 'MOMENTS_INVALID_DESIGN'using errcode='22023';end if;
  end loop;
  if layer->>'type'='IMAGE'then
   if not layer_original then raise exception 'MOMENTS_INVALID_DESIGN_SOURCE'using errcode='42501';end if;
   perform moments_private.check_design_frame(payload->>'imageBackground',p_actor);
   perform moments_private.check_design_number(payload->'imageZoom',1,4);
   perform moments_private.check_design_pair(payload->'imageOffsetRatio',array['x','y'],-8,8);
  elsif layer->>'type'='DECORATION'and not coalesce((payload->>'imageBackground')=any(free_stickers),false)then
   raise exception 'MOMENTS_DESIGN_MATERIAL_UNAVAILABLE'using errcode='42501';end if;
  foreach field in array array['bubbleColor','fillColor','borderColor']loop perform moments_private.check_design_color(payload->field);end loop;
  perform moments_private.check_design_number(payload->'borderWidth',0,1000);
  perform moments_private.check_design_number(payload->'cornerRadius',0,4096);
  perform moments_private.validate_design_text_style(payload->'textStyle');
 end loop;
 if not has_original then raise exception 'MOMENTS_INVALID_DESIGN_SOURCE'using errcode='42501';end if;
end;$$;

-- The monthly transfer accepts canonical originals plus the same procedural
-- stickers. Recheck frame access rather than trusting a client-crafted album.
create function moments_private.check_album_design_materials(p_document jsonb,p_actor uuid)returns void
language plpgsql stable security invoker set search_path='' as $$
declare layer jsonb;key text;
begin
 for layer in select j.value from jsonb_path_query(p_document,'strict $.** ? (@.type() == "object")')j(value)loop
  if layer->>'type'not in('IMAGE','TEXT','DECORATION','STICKER')then continue;end if;
  perform moments_private.check_design_clip(layer->'canvasClip');
  key:=layer->'payload'->>'imageBackground';
  if layer->>'type'='IMAGE'then perform moments_private.check_design_frame(key,p_actor);
  elsif layer->>'type'in('DECORATION','STICKER')and nullif(key,'')is not null and key not in
   ('stickerBlueStar','stickerHeartRed','stickerLeafGreen','stickerFlowerPink','stickerPaperClip','stickerTapeBeige','stickerCloudSoft','stickerCloverGreen')then
   raise exception 'MOMENTS_DESIGN_MATERIAL_UNAVAILABLE'using errcode='42501';end if;
 end loop;
end;$$;

revoke all on function moments_private.check_design_frame(text,uuid),moments_private.check_design_number(jsonb,numeric,numeric,boolean),
 moments_private.check_design_color(jsonb),moments_private.check_design_pair(jsonb,text[],numeric,numeric),
 moments_private.validate_design_text_style(jsonb),moments_private.check_design_clip(jsonb),
 moments_private.validate_photo_design(jsonb,uuid),moments_private.check_album_design_materials(jsonb,uuid)
 from public,anon,authenticated,service_role;

create or replace function moments_private.save_record(p_id uuid,p_record_date date,p_caption text,p_photos jsonb,p_expected_revision integer) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=moments_private.actor(true); today date:=(moments_private.server_now() at time zone 'Asia/Seoul')::date;
 record moments_private.weekly_moments; photo jsonb; path text; photo_id uuid; v_caption text:=btrim(coalesce(p_caption,''));
begin
 if p_id is null or p_record_date is null or p_record_date>today or p_record_date<'1900-01-01'::date
  or char_length(v_caption)>200 or p_expected_revision is null or p_expected_revision<0 then
  raise exception 'MOMENTS_INVALID_RECORD' using errcode='22023'; end if;
 if jsonb_typeof(p_photos) is distinct from 'array' or octet_length(p_photos::text)>409600 then
  raise exception 'MOMENTS_INVALID_PHOTOS' using errcode='22023'; end if;
 if jsonb_array_length(p_photos) not between 1 and 3 then raise exception 'MOMENTS_INVALID_PHOTOS' using errcode='22023'; end if;
 select * into record from moments_private.weekly_moments where id=p_id for update;
 if found then
  if record.owner_id<>actor then raise exception 'MOMENTS_ACCESS_DENIED' using errcode='42501'; end if;
  if record.deleted_at is not null then raise exception 'MOMENTS_RECORD_DELETED' using errcode='PT409'; end if;
  -- A lost response may be retried with its original revision and payload.
  if record.record_date=p_record_date and record.caption=v_caption and record.photos=p_photos
   and p_expected_revision in(record.revision,record.revision-1) then return moments_private.record_json(record); end if;
  if record.revision<>p_expected_revision then raise exception 'MOMENTS_REVISION_CONFLICT' using errcode='PT409'; end if;
 elsif p_expected_revision<>0 then raise exception 'MOMENTS_REVISION_CONFLICT' using errcode='PT409'; end if;
 -- Bound list payloads and storage growth without blocking edits to an existing
 -- month. Actor serialization also makes concurrent final-slot saves atomic.
 if record.id is null or date_trunc('month',record.record_date)<>date_trunc('month',p_record_date) then
  if(select count(*) from moments_private.weekly_moments m where m.owner_id=actor and m.deleted_at is null and m.id<>p_id
   and m.record_date>=date_trunc('month',p_record_date)::date and m.record_date<(date_trunc('month',p_record_date)+interval '1 month')::date)>=100 then
   raise exception 'MOMENTS_MONTH_FULL' using errcode='22023'; end if;
 end if;
 for photo in select value from jsonb_array_elements(p_photos) loop
  if jsonb_typeof(photo) is distinct from 'object' or exists(select 1 from jsonb_object_keys(photo) k where k not in('id','path','width','height','design'))
   or jsonb_typeof(photo->'id') is distinct from 'string' or (photo->>'id') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
   or jsonb_typeof(photo->'path') is distinct from 'string'
   or jsonb_typeof(photo->'width') is distinct from 'number' or (photo->>'width') !~ '^[1-9][0-9]{0,4}$'
   or jsonb_typeof(photo->'height') is distinct from 'number' or (photo->>'height') !~ '^[1-9][0-9]{0,4}$' then
   raise exception 'MOMENTS_INVALID_PHOTOS' using errcode='22023'; end if;
  if photo?'design'then perform moments_private.validate_photo_design(photo->'design',actor);end if;
  photo_id:=(photo->>'id')::uuid; path:=photo->>'path';
  if path !~ ('^'||actor||'/moments/'||p_id||'/'||photo_id||'[.](jpg|jpeg|png|webp)$') then
   raise exception 'MOMENTS_INVALID_PHOTO_PATH' using errcode='42501'; end if;
  perform 1 from storage.objects o where o.bucket_id='album-assets' and o.name=path
   and coalesce(o.owner_id,o.owner::text)=actor::text
   and coalesce(o.metadata->>'mimetype','') in('image/jpeg','image/png','image/webp') for update;
  if not found then raise exception 'MOMENTS_PHOTO_UNAVAILABLE' using errcode='42501'; end if;
 end loop;
 if (select count(distinct value->>'id') from jsonb_array_elements(p_photos))<>jsonb_array_length(p_photos)
  or(select count(distinct value->>'path') from jsonb_array_elements(p_photos))<>jsonb_array_length(p_photos) then
  raise exception 'MOMENTS_DUPLICATE_PHOTO' using errcode='22023'; end if;
 if record.id is null then
  insert into moments_private.weekly_moments(id,owner_id,record_date,caption,photos) values(p_id,actor,p_record_date,v_caption,p_photos) returning * into record;
 else
  update moments_private.weekly_moments m set record_date=p_record_date,caption=v_caption,photos=p_photos,revision=m.revision+1,updated_at=moments_private.server_now()
   where m.id=p_id returning * into record;
 end if;
 return moments_private.record_json(record);
end;
$$;

create or replace function moments_private.create_month_album(p_month date,p_photo_ids uuid[],p_album jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=moments_private.actor(true); today date:=(moments_private.server_now() at time zone 'Asia/Seoul')::date;
 existing_id bigint; created_id bigint; paths text[]; used_paths text[]; document jsonb; all_document jsonb; field text; value text;
begin
 if p_month is null or extract(day from p_month)<>1 or p_month>date_trunc('month',today)::date or p_month<'1900-01-01'::date then
  raise exception 'MOMENTS_INVALID_MONTH' using errcode='22023'; end if;
 select ma.album_id into existing_id from moments_private.month_albums ma join public.albums a on a.id=ma.album_id and a.owner_id=actor where ma.owner_id=actor and ma.month=p_month;
 if existing_id is not null then return jsonb_build_object('albumId',existing_id,'created',false); end if;
 if p_photo_ids is null or cardinality(p_photo_ids) not between 1 and 9 or array_position(p_photo_ids,null) is not null
  or(select count(distinct p) from unnest(p_photo_ids)p)<>cardinality(p_photo_ids) then raise exception 'MOMENTS_INVALID_SELECTION' using errcode='22023'; end if;
 select array_agg(p.photo->>'path' order by p.photo->>'path') into paths from moments_private.weekly_moments m
  cross join lateral jsonb_array_elements(m.photos)p(photo)
  where m.owner_id=actor and m.deleted_at is null and m.record_date>=p_month and m.record_date<(p_month+interval '1 month')::date and(p.photo->>'id')::uuid=any(p_photo_ids);
 if coalesce(cardinality(paths),0)<>cardinality(p_photo_ids) then raise exception 'MOMENTS_SELECTION_CHANGED' using errcode='PT409'; end if;
 if jsonb_typeof(p_album) is distinct from 'object' or octet_length(p_album::text)>1048576
  or exists(select 1 from jsonb_object_keys(p_album) k where k not in('title','ratio','cover_layers_json','cover_image_url','cover_thumbnail_url','cover_original_url','cover_preview_url','cover_theme','target_pages','total_pages')) then
  raise exception 'MOMENTS_INVALID_ALBUM' using errcode='22023'; end if;
 if jsonb_typeof(p_album->'title') is distinct from 'string' or char_length(btrim(p_album->>'title')) not between 1 and 80
  or jsonb_typeof(p_album->'ratio') is distinct from 'string' or char_length(p_album->>'ratio') not between 1 and 50
  or jsonb_typeof(p_album->'cover_layers_json') is distinct from 'string'
  or not pg_input_is_valid(p_album->>'cover_layers_json','jsonb') then raise exception 'MOMENTS_INVALID_ALBUM' using errcode='22023'; end if;
 foreach field in array array['target_pages','total_pages'] loop
  if jsonb_typeof(p_album->field) is distinct from 'number' or(p_album->>field) !~ '^[1-9][0-9]?$' or(p_album->>field)::integer>80 then
   raise exception 'MOMENTS_INVALID_ALBUM' using errcode='22023'; end if;
 end loop;
 foreach field in array array['cover_image_url','cover_thumbnail_url','cover_original_url','cover_preview_url','cover_theme'] loop
  if p_album?field and jsonb_typeof(p_album->field) not in('string','null') then raise exception 'MOMENTS_INVALID_ALBUM' using errcode='22023'; end if;
 end loop;
 document:=(p_album->>'cover_layers_json')::jsonb;
 if jsonb_typeof(document) is distinct from 'object' then raise exception 'MOMENTS_INVALID_ALBUM' using errcode='22023'; end if;
 perform moments_private.check_album_design_materials(document,actor);
 all_document:=jsonb_build_object('document',document,'album',p_album-'cover_layers_json');
 select array_agg(p order by p) into used_paths from album_private.paths(all_document)p;
 if used_paths is distinct from paths then raise exception 'MOMENTS_ALBUM_PHOTOS_MISMATCH' using errcode='42501'; end if;
 -- Every URL-bearing image field must use one of the selected canonical paths.
 for value in select j.value#>>'{}' from jsonb_path_query(all_document,'strict $.** ? (@.type() == "object").keyvalue() ? (@.key like_regex "(url|uri|src|path)$" flag "i").value')j(value) where jsonb_typeof(j.value)='string' loop
  if value<>'' and not(value=any(select 'supabase://album-assets/'||p from unnest(paths)p)) and value!~'^deco:(stickerBlueStar|stickerHeartRed|stickerLeafGreen|stickerFlowerPink|stickerPaperClip|stickerTapeBeige|stickerCloudSoft|stickerCloverGreen)@[0-9.]+$'then
   raise exception 'MOMENTS_INVALID_ALBUM_IMAGE' using errcode='42501'; end if;
 end loop;
 insert into public.albums(owner_id,title,ratio,cover_layers_json,cover_image_url,cover_thumbnail_url,cover_original_url,cover_preview_url,cover_theme,target_pages,total_pages)
 values(actor,btrim(p_album->>'title'),p_album->>'ratio',p_album->>'cover_layers_json',nullif(p_album->>'cover_image_url',''),nullif(p_album->>'cover_thumbnail_url',''),nullif(p_album->>'cover_original_url',''),nullif(p_album->>'cover_preview_url',''),p_album->>'cover_theme',(p_album->>'target_pages')::integer,(p_album->>'total_pages')::integer) returning id into created_id;
 insert into moments_private.month_albums(owner_id,month,album_id)values(actor,p_month,created_id)
 on conflict(owner_id,month)do update set album_id=excluded.album_id,created_at=moments_private.server_now();
 return jsonb_build_object('albumId',created_id,'created',true);
end;
$$;

create or replace function moments_private.append_month_album(p_month date,p_album_id bigint,p_photo_ids uuid[],p_pages jsonb,p_expected_updated_at timestamptz) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=moments_private.actor(true); link moments_private.month_albums; a public.albums; paths text[]; used_paths text[]; doc jsonb; page jsonb; value text; appended jsonb; count_before integer; count_after integer;
begin
 if p_month is null or p_album_id is null then raise exception 'MOMENTS_INVALID_SELECTION' using errcode='22023'; end if;
 -- Album first matches editor/member locks. The actor lock serializes record edits
 -- and duplicate append attempts; collaborators still use album CAS normally.
 select * into a from public.albums where id=p_album_id and owner_id=actor for update;
 if not found then raise exception 'MOMENTS_ACCESS_DENIED' using errcode='42501'; end if;
 select * into link from moments_private.month_albums where owner_id=actor and month=p_month and album_id=a.id for update;
 if not found then raise exception 'MOMENTS_ALBUM_CHANGED' using errcode='PT409'; end if;
 if p_photo_ids is null or cardinality(p_photo_ids) not between 1 and 9 or array_position(p_photo_ids,null) is not null
  or(select count(distinct p) from unnest(p_photo_ids)p)<>cardinality(p_photo_ids) then raise exception 'MOMENTS_INVALID_SELECTION' using errcode='22023'; end if;
 -- Lost responses are safe even if the user edited the album afterwards. An
 -- intentionally removed imported photo is never silently added again.
 if p_photo_ids<@link.imported_photo_ids then return jsonb_build_object('albumId',a.id,'appended',false); end if;
 if p_photo_ids&&link.imported_photo_ids then raise exception 'MOMENTS_SELECTION_CHANGED' using errcode='PT409'; end if;
 if a.locked_by_id is not null and a.locked_by_id<>actor then raise exception 'MOMENTS_ALBUM_LOCKED' using errcode='PT409'; end if;
 if p_expected_updated_at is null or a.updated_at is distinct from p_expected_updated_at then raise exception 'MOMENTS_ALBUM_CHANGED' using errcode='PT409'; end if;
 select array_agg(p.photo->>'path' order by p.photo->>'path') into paths from moments_private.weekly_moments m
  cross join lateral jsonb_array_elements(m.photos)p(photo)
  where m.owner_id=actor and m.deleted_at is null and m.record_date>=p_month and m.record_date<(p_month+interval '1 month')::date and(p.photo->>'id')::uuid=any(p_photo_ids);
 if coalesce(cardinality(paths),0)<>cardinality(p_photo_ids) then raise exception 'MOMENTS_SELECTION_CHANGED' using errcode='PT409'; end if;
 if jsonb_typeof(p_pages) is distinct from 'array' or jsonb_array_length(p_pages) not between 1 and 18 or octet_length(p_pages::text)>1048576 then raise exception 'MOMENTS_INVALID_ALBUM' using errcode='22023'; end if;
 for page in select j.value from jsonb_array_elements(p_pages)j(value) loop
  if jsonb_typeof(page) is distinct from 'object' or jsonb_typeof(page->'layers') is distinct from 'array' or jsonb_array_length(page->'layers')>50
   or page->>'isCover' is distinct from 'false' then raise exception 'MOMENTS_INVALID_ALBUM' using errcode='22023'; end if;
 end loop;
 perform moments_private.check_album_design_materials(p_pages,actor);
 select array_agg(p order by p) into used_paths from album_private.paths(p_pages)p;
 if used_paths is distinct from paths then raise exception 'MOMENTS_ALBUM_PHOTOS_MISMATCH' using errcode='42501'; end if;
 for value in select j.value#>>'{}' from jsonb_path_query(p_pages,'strict $.** ? (@.type() == "object").keyvalue() ? (@.key like_regex "(url|uri|src|path)$" flag "i").value')j(value) where jsonb_typeof(j.value)='string' loop
  if value<>'' and not(value=any(select 'supabase://album-assets/'||p from unnest(paths)p)) and value!~'^deco:(stickerBlueStar|stickerHeartRed|stickerLeafGreen|stickerFlowerPink|stickerPaperClip|stickerTapeBeige|stickerCloudSoft|stickerCloverGreen)@[0-9.]+$'then raise exception 'MOMENTS_INVALID_ALBUM_IMAGE' using errcode='42501'; end if;
 end loop;
 foreach value in array paths loop
  perform 1 from storage.objects o where o.bucket_id='album-assets' and o.name=value and coalesce(o.owner_id,o.owner::text)=actor::text
   and coalesce(o.metadata->>'mimetype','') in('image/jpeg','image/png','image/webp') for key share;
  if not found then raise exception 'MOMENTS_PHOTO_UNAVAILABLE' using errcode='42501'; end if;
 end loop;
 if not pg_input_is_valid(a.cover_layers_json,'jsonb') then raise exception 'MOMENTS_ALBUM_CHANGED' using errcode='PT409'; end if;
 doc:=a.cover_layers_json::jsonb;
 if jsonb_typeof(doc) is distinct from 'object' or jsonb_typeof(doc->'pages') is distinct from 'array' then raise exception 'MOMENTS_ALBUM_CHANGED' using errcode='PT409'; end if;
 count_before:=jsonb_array_length(doc->'pages');count_after:=count_before+jsonb_array_length(p_pages);
 if count_before<1 or count_after>81 or greatest(coalesce(a.target_pages,0),count_after-1)>80 then raise exception 'MOMENTS_ALBUM_FULL' using errcode='22023'; end if;
 select jsonb_agg(jsonb_set(x.page,'{index}',to_jsonb((count_before+ordinality-1)::integer),true)order by ordinality) into appended from jsonb_array_elements(p_pages)with ordinality x(page,ordinality);
 doc:=jsonb_set(doc,'{pages}',(doc->'pages')||appended,false);
 if octet_length(doc::text)>8388608 then raise exception 'MOMENTS_INVALID_ALBUM' using errcode='22023'; end if;
 update public.albums set cover_layers_json=doc::text,total_pages=count_after-1,target_pages=greatest(coalesce(target_pages,0),count_after-1) where id=a.id;
 update moments_private.month_albums set imported_photo_ids=imported_photo_ids||p_photo_ids where owner_id=actor and month=p_month;
 insert into moments_private.activity(owner_id,event_id,event,month,occurred_at) values(actor,gen_random_uuid(),'album_appended',p_month,moments_private.server_now());
 return jsonb_build_object('albumId',a.id,'appended',true);
end;
$$;

-- The existing dispatcher retains all authorization, publication rate limits,
-- consent/revision fences and idempotency. Only the public raster's ratio uses
-- the saved artwork canvas; original private photo dimensions stay unchanged.
alter function social_private.social_api(text,jsonb)rename to social_api_before_photo_designs_v1;
revoke all on function social_private.social_api_before_photo_designs_v1(text,jsonb)from public,anon,authenticated,service_role;
create function social_private.social_api(p_action text,p_payload jsonb)returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;design jsonb;
begin
 result:=social_private.social_api_before_photo_designs_v1(p_action,p_payload);
 if p_action='beginMomentPublication'and result->>'status'='draft'then
  select p->'design'into design from moments_private.weekly_moments m
   cross join lateral jsonb_array_elements(m.photos)p
   where m.id=(p_payload->>'recordId')::uuid and m.owner_id=auth.uid()and m.deleted_at is null
    and(p->>'id')::uuid=(p_payload->>'photoId')::uuid;
  if design is not null then
   update public.social_works set aspect_ratio=(design->'canvas'->>'width')::numeric/(design->'canvas'->>'height')::numeric
    where id=(result->>'id')::uuid and author_id=auth.uid()and kind='moment'and status='draft';
  end if;
 end if;
 return result;
end;$$;
revoke all on function social_private.social_api(text,jsonb)from public,anon,authenticated,service_role;
grant execute on function social_private.social_api(text,jsonb)to anon,authenticated;
create or replace function public.social_api(p_action text,p_payload jsonb default '{}'::jsonb)returns jsonb
language sql security invoker set search_path=''as $$select social_private.social_api(p_action,p_payload)$$;
revoke all on function public.social_api(text,jsonb)from public,anon,authenticated,service_role;
grant execute on function public.social_api(text,jsonb)to anon,authenticated;
