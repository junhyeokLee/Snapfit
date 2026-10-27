-- Run only after 20261026142401_social_official_template_sources.sql is applied.
-- All synthetic users, bonus ledgers, albums, catalog rows and storage metadata
-- are isolated in this transaction and rolled back. No Storage files are uploaded.
begin;
do $test$
declare
 actor uuid:=gen_random_uuid(); viewer uuid:=gen_random_uuid();
 album_id bigint; work_id uuid; second_id uuid; request_id uuid:=gen_random_uuid();
 free_key text:='template:qa-source-'||gen_random_uuid()::text;
 paid_key text:='template:qa-paid-source-'||gen_random_uuid()::text;
 source jsonb; item jsonb; payload jsonb; doc text; path text;
 caught boolean;
begin
 insert into auth.users(id,email,raw_app_meta_data)
  values(actor,'qa-source-'||actor::text||'@example.invalid','{}'),
        (viewer,'qa-source-'||viewer::text||'@example.invalid','{}');
 insert into public.point_shop_products(product_key,asset_id,kind,title,point_price,is_active)
  values(free_key,split_part(free_key,':',2),'template','Runtime official free',0,true),
        (paid_key,split_part(paid_key,':',2),'template','Runtime official paid',1800,true);
 doc:=jsonb_build_object('pages',jsonb_build_array(jsonb_build_object('layers','[]'::jsonb)),
  'sourceTemplate',jsonb_build_object('productKey',free_key,'title','FORGED_TITLE'),
  'private','PRIVATE_SOURCE')::text;
 insert into public.albums(owner_id,title,ratio,cover_layers_json)
  values(actor,'Runtime source fixture','1:1',doc) returning id into album_id;
 perform set_config('request.jwt.claim.sub',actor::text,true);

 -- 1. The owner sees canonical catalog metadata, never the document's title.
 source:=public.social_api('albumTemplateSource',jsonb_build_object('albumId',album_id));
 if source is distinct from jsonb_build_object('productKey',free_key,'title','Runtime official free') then
  raise exception 'runtime_source_canonical_lookup_failed';
 end if;
 payload:=jsonb_build_object('albumId',album_id,'pageIndexes',jsonb_build_array(0),
  'title','Runtime publication','topic','일상','requestId',request_id,'includeSourceTemplate',true);
 item:=public.social_api('beginPublication',payload); work_id:=(item->>'id')::uuid;

 -- 2. Drafts never expose the selected source, even to their author.
 if public.social_api('resolveWorkTemplate',jsonb_build_object('id',work_id)) is not null then
  raise exception 'runtime_draft_source_leaked';
 end if;
 -- 3. Retried requests are stable, and cannot change opt-in consent.
 if public.social_api('beginPublication',payload)->>'id' is distinct from work_id::text then
  raise exception 'runtime_source_retry_not_idempotent';
 end if;
 caught:=false;
 begin
  perform public.social_api('beginPublication',payload||jsonb_build_object('includeSourceTemplate',false));
 exception when sqlstate '22023' then caught:=sqlerrm='social_publication_request_mismatch'; end;
 if not caught then raise exception 'runtime_source_retry_consent_changed'; end if;

 item:=public.social_api('publicationUploadPath',jsonb_build_object('id',work_id,'position',0));
 path:=item->>'path';
 insert into storage.objects(bucket_id,name,metadata)
  values('social-snapshots',path,jsonb_build_object('mimetype','image/png','size',1024));
 item:=public.social_api('finalizePublication',jsonb_build_object('id',work_id));
 -- 4. Finalization projects the selected canonical source without source content.
 if item->'sourceTemplate' is distinct from source or item::text like '%PRIVATE_SOURCE%'
  or item::text like '%FORGED_TITLE%' then raise exception 'runtime_public_source_projection_failed'; end if;
 perform set_config('request.jwt.claim.sub','',true);
 -- 5. Guests can resolve the public template identity, without an entitlement grant.
 if public.social_api('resolveWorkTemplate',jsonb_build_object('id',work_id)) is distinct from source then
  raise exception 'runtime_public_source_resolution_failed'; end if;

 -- 6. Author-private and deleted works have no source, including for the author.
 perform set_config('request.jwt.claim.sub',actor::text,true);
 perform public.social_api('visibility',jsonb_build_object('id',work_id,'published',false));
 if public.social_api('resolveWorkTemplate',jsonb_build_object('id',work_id)) is not null then
  raise exception 'runtime_private_source_leaked'; end if;
 perform public.social_api('visibility',jsonb_build_object('id',work_id,'published',true));

 -- 7. Blocks are rechecked at the moment of resolution.
 perform set_config('request.jwt.claim.sub',viewer::text,true);
 perform public.social_api('setBlocked',jsonb_build_object('userId',actor,'blocked',true));
 if public.social_api('resolveWorkTemplate',jsonb_build_object('id',work_id)) is not null then
  raise exception 'runtime_blocked_source_leaked'; end if;
 perform public.social_api('setBlocked',jsonb_build_object('userId',actor,'blocked',false));
 -- 8. Another user cannot inspect private album attribution.
 caught:=false;
 begin perform public.social_api('albumTemplateSource',jsonb_build_object('albumId',album_id));
 exception when sqlstate '42501' then caught:=sqlerrm='social_album_owner_required'; end;
 if not caught then raise exception 'runtime_album_source_owner_bypass'; end if;

 -- 9. Catalog withdrawal is reflected without waiting for cached feed metadata.
 update public.point_shop_products set is_active=false where product_key=free_key;
 if public.social_api('resolveWorkTemplate',jsonb_build_object('id',work_id)) is not null then
  raise exception 'runtime_inactive_source_resolved'; end if;
 update public.point_shop_products set is_active=true where product_key=free_key;
 perform set_config('request.jwt.claim.sub',actor::text,true);

 -- 10. Default opt-out ignores a forged payload attribution.
 item:=public.social_api('beginPublication',(payload-'requestId'-'includeSourceTemplate')||
  jsonb_build_object('sourceTemplate',jsonb_build_object('productKey',paid_key)));
 second_id:=(item->>'id')::uuid;
 if (select s.source_template_product_key from social_private.social_publication_sources s where s.work_id=second_id) is not null then
  raise exception 'runtime_default_opt_out_bypassed'; end if;
 -- 11. Malformed consent fails before creating another draft.
 caught:=false;
 begin perform public.social_api('beginPublication',(payload-'requestId')||jsonb_build_object('includeSourceTemplate','true'));
 exception when sqlstate '22023' then caught:=sqlerrm='social_invalid_template_source_opt_in'; end;
 if not caught then raise exception 'runtime_malformed_source_consent_accepted'; end if;

 -- 12. Claiming a paid source does not substitute for ownership.
 update public.albums set cover_layers_json=jsonb_build_object('pages',jsonb_build_array('{}'::jsonb),
  'sourceTemplate',jsonb_build_object('productKey',paid_key))::text where id=album_id;
 caught:=false;
 begin perform public.social_api('beginPublication',payload-'requestId');
 exception when sqlstate '22023' then caught:=sqlerrm='social_source_template_unavailable'; end;
 if not caught then raise exception 'runtime_paid_source_ownership_bypassed'; end if;
 -- 13. Legacy documents remain without attribution; public payload cannot invent it.
 update public.albums set cover_layers_json='{"pages":[{}]}' where id=album_id;
 if public.social_api('albumTemplateSource',jsonb_build_object('albumId',album_id)) is not null then
  raise exception 'runtime_legacy_source_fabricated'; end if;
 perform public.social_api('deleteWork',jsonb_build_object('id',work_id));
 if public.social_api('resolveWorkTemplate',jsonb_build_object('id',work_id)) is not null then
  raise exception 'runtime_deleted_source_leaked'; end if;

 -- 14. The internal helpers and private bindings remain inaccessible to clients.
 if has_function_privilege('authenticated','social_private.document_template_source(text,uuid)','EXECUTE')
  or has_function_privilege('anon','social_private.work_template_source(uuid)','EXECUTE')
  or has_table_privilege('authenticated','social_private.social_publication_sources','SELECT') then
  raise exception 'runtime_template_internal_grants_exposed'; end if;
end;
$test$;
rollback;
select jsonb_build_object('passed',true,'groups',14,'rolledBack',true) as social_template_sources_runtime;
