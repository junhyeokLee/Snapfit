-- New comments only: no backfill and no private source content enters a push.
create function private.social_comment_push_allowed(p_notification_id bigint)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(
  select 1 from public.notifications n
  join public.social_comments c on c.id=case when pg_input_is_valid(n.data->>'commentId','uuid')then(n.data->>'commentId')::uuid else null end
  join public.social_works w on w.id=c.work_id and w.id::text=n.data->>'workId' and w.author_id=n.user_id
  join auth.users writer on writer.id=c.author_id
  join auth.users recipient on recipient.id=w.author_id
  where n.id=p_notification_id and n.type='social_comment' and n.category='comment'
   and not c.moderation_hidden and c.author_id<>w.author_id
   and social_private.public_work_visible(w.id) and social_private.public_author_allowed(c.author_id)
   and writer.deleted_at is null and not writer.is_anonymous and(writer.banned_until is null or writer.banned_until<=statement_timestamp())
   and recipient.deleted_at is null and not recipient.is_anonymous and(recipient.banned_until is null or recipient.banned_until<=statement_timestamp())
   and not exists(select 1 from public.social_blocks b where
    (b.owner_id=c.author_id and b.target_id=w.author_id)or(b.owner_id=w.author_id and b.target_id=c.author_id)))
$$;
revoke all on function private.social_comment_push_allowed(bigint)from public,anon,authenticated,service_role;

create function private.social_comment_notification()returns trigger
language plpgsql security definer set search_path='' as $$
declare work public.social_works;
begin
 if new.moderation_hidden then return new;end if;
 select *into work from public.social_works w where w.id=new.work_id
  and w.author_id<>new.author_id and social_private.public_work_visible(w.id)
  and social_private.public_author_allowed(new.author_id)
  and not exists(select 1 from public.social_blocks b where
   (b.owner_id=new.author_id and b.target_id=w.author_id)or(b.owner_id=w.author_id and b.target_id=new.author_id))
  and exists(select 1 from auth.users u where u.id=new.author_id and not u.is_anonymous and u.deleted_at is null and(u.banned_until is null or u.banned_until<=statement_timestamp()))
  and exists(select 1 from auth.users u where u.id=w.author_id and not u.is_anonymous and u.deleted_at is null and(u.banned_until is null or u.banned_until<=statement_timestamp()));
 if not found then return new;end if;
 insert into public.notifications(user_id,type,category,title,body,deeplink,data,event_key)
 values(work.author_id,'social_comment','comment','내 공개 작품에 새 댓글이 달렸어요','스냅핏에서 댓글을 확인해 보세요.',
  'snapfit://work?workId='||work.id::text||'&comments=1',
  jsonb_build_object('workId',work.id,'commentId',new.id,'showComments',true),'social:comment:'||new.id::text)
 on conflict do nothing;
 return new;
end;$$;
revoke all on function private.social_comment_notification()from public,anon,authenticated,service_role;
create trigger social_comments_notify after insert on public.social_comments
 for each row execute function private.social_comment_notification();

-- A stale worker must not contact FCM after another worker reclaimed its row.
-- DB time and a row lock decide ownership; the new lease comfortably covers
-- the dispatcher's bounded 10-second FCM request.
create function public.prepare_push_delivery(p_id bigint,p_lease_token uuid)returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare delivery public.push_outbox;device public.push_devices;notification public.notifications;
 prefs public.push_preferences;now_at timestamptz;local_now timestamp;expires_at timestamptz;
 local_hour integer;created_hour integer;allowed boolean;
begin
 select *into delivery from public.push_outbox where id=p_id for update;
 now_at:=clock_timestamp();
 if not found or delivery.status<>'processing' or delivery.lease_token is distinct from p_lease_token
  or p_lease_token is null or delivery.locked_until is null or delivery.locked_until<=now_at then return jsonb_build_object('allowed',false);end if;
 select *into device from public.push_devices where token=delivery.token and user_id=delivery.user_id
  and enabled and updated_at>=now_at-interval'90 days'
  and exists(select 1 from auth.users u where u.id=delivery.user_id and not u.is_anonymous
   and u.deleted_at is null and(u.banned_until is null or u.banned_until<=now_at));
 select *into notification from public.notifications where id=delivery.notification_id and user_id=delivery.user_id
  and created_at>=now_at-interval'90 days';
 if device.token is null or notification.id is null then
  update public.push_outbox set status='discarded',locked_until=null,last_error='recipient_unavailable'where id=delivery.id;
  return jsonb_build_object('allowed',false);
 end if;
 select *into prefs from public.push_preferences where user_id=delivery.user_id;
 local_now:=(now_at at time zone'UTC')+device.timezone_offset_minutes*interval'1 minute';
 local_hour:=extract(hour from local_now);
 created_hour:=extract(hour from(notification.created_at at time zone'UTC')+device.timezone_offset_minutes*interval'1 minute');
 allowed:=coalesce(prefs.all_enabled,true)and case notification.category
  when'order'then coalesce(prefs.order_enabled,true)when'invite'then coalesce(prefs.invite_enabled,true)
  when'comment'then coalesce(prefs.comment_enabled,true)when'marketing'then coalesce(prefs.marketing_enabled,false)
  when'new_template'then coalesce(prefs.new_template_enabled,true)else true end
  and(not coalesce(prefs.night_mute,false)or(local_hour>=8 and local_hour<22 and created_hour>=8 and created_hour<22));
 if not allowed or(notification.type='social_comment'and not private.social_comment_push_allowed(notification.id))then
  update public.push_outbox set status='discarded',locked_until=null,last_error=case when allowed then'social_comment_unavailable'else'notification_preferences'end where id=delivery.id;
  return jsonb_build_object('allowed',false);
 end if;
 -- Return an absolute deadline from this same locked, current-policy decision.
 -- The dispatcher deducts RPC/network time instead of reusing stale preferences.
 expires_at:=now_at+interval'5 minutes';
 if coalesce(prefs.night_mute,false)then
  expires_at:=now_at+least(300,extract(epoch from(date_trunc('day',local_now)+interval'22 hours'-local_now)))*interval'1 second';
 end if;
 update public.push_outbox set locked_until=clock_timestamp()+interval'2 minutes'where id=delivery.id;
 return jsonb_build_object('allowed',true,'expiresAt',expires_at);
end;$$;
revoke all on function public.prepare_push_delivery(bigint,uuid)from public,anon,authenticated;
grant execute on function public.prepare_push_delivery(bigint,uuid)to service_role;
