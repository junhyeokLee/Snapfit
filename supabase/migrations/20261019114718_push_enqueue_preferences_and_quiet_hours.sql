-- Suppressed events remain in the inbox, but never become a later push backlog.
-- Keep the existing trigger, security boundary, recipient and device freshness rules.
create or replace function private.queue_notification_push()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.push_outbox(notification_id, user_id, token)
  select new.id, new.user_id, d.token
  from public.push_devices d
  left join public.push_preferences p on p.user_id = new.user_id
  where d.user_id = new.user_id
    and d.enabled
    and d.updated_at >= now() - interval '90 days'
    and coalesce(p.all_enabled, true)
    and case new.category
      when 'order' then coalesce(p.order_enabled, true)
      when 'invite' then coalesce(p.invite_enabled, true)
      when 'comment' then coalesce(p.comment_enabled, true)
      when 'marketing' then coalesce(p.marketing_enabled, false)
      when 'new_template' then coalesce(p.new_template_enabled, true)
      else true
    end
    and (
      not coalesce(p.night_mute, false)
      or extract(hour from (
        (new.created_at at time zone 'UTC')
        + d.timezone_offset_minutes * interval '1 minute'
      )) >= 8 and extract(hour from (
        (new.created_at at time zone 'UTC')
        + d.timezone_offset_minutes * interval '1 minute'
      )) < 22
    )
  on conflict do nothing;
  return new;
end;
$$;
