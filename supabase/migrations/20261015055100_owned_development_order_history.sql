-- Read-only TEST history for the current server-verified administrator.
-- Kept separate from customer/LIVE orders and all fulfillment write paths.
create function public.list_owned_print_dev_checkouts(p_actor uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('items',coalesce(jsonb_agg(v.item order by v.created_at desc,v.id desc),'[]'::jsonb))
 from (
  select c.id,c.created_at,jsonb_build_object(
   'checkout',(to_jsonb(c)-array['snapshot','recipient','source_asset_owners','source_digest','order_code'])
     ||jsonb_build_object('album_title',c.snapshot->'album'->>'title'),
   'package',case when p.id is null then null else
     to_jsonb(p)-array['renderer_manifest','pdf_manifest','file_parts','part_results'] end,
   'session',jsonb_build_object('owner_id',s.owner_id,'payment_id',s.payment_id,
     'store_id',s.store_id,'channel_key',s.channel_key,'environment',s.environment,
     'total_amount',s.total_amount,'status',s.status,'receipt',s.receipt,'verified_at',s.verified_at)
  ) item
  from private.print_dev_checkouts c
  join private.print_payment_test_sessions s on s.payment_id=c.payment_id and s.owner_id=p_actor
  left join private.print_dev_packages p on p.id=c.package_id and p.checkout_id=c.id
  where c.owner_id=p_actor
  order by c.created_at desc,c.id desc limit 50
 ) v;
$$;
revoke all on function public.list_owned_print_dev_checkouts(uuid) from public,anon,authenticated;
grant execute on function public.list_owned_print_dev_checkouts(uuid) to service_role;
