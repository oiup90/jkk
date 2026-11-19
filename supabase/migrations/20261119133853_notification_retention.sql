-- The inbox is retained for 72 hours, including unread notifications.
begin;

create index notifications_in_app_created_idx
  on public.notifications (created_at) where show_in_app;

create function growth_internal.purge_expired_user_notifications()
returns bigint
language sql security definer set search_path = ''
as $$
  with deleted as (
    delete from public.notifications
    where show_in_app and created_at <= now() - interval '72 hours'
    returning 1
  )
  select count(*) from deleted;
$$;
revoke all on function growth_internal.purge_expired_user_notifications()
  from public, anon, authenticated, service_role;

-- A project without pg_cron can apply the migration, but must enable it and
-- run supabase/setup_notification_retention.sql before retention is active.
do $$
begin
  if exists (select 1 from pg_catalog.pg_extension where extname = 'pg_cron') then
    perform cron.schedule(
      'freelan-user-notification-retention',
      '* * * * *',
      'select growth_internal.purge_expired_user_notifications()'
    );
  else
    raise notice 'Enable pg_cron and run supabase/setup_notification_retention.sql to activate notification retention';
  end if;
end $$;

commit;
