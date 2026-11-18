-- Extend the configured password hook without changing its throttle decision.
begin;
create table growth_internal.security_password_events (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users(id) on delete set null,
  event_type text not null check (event_type in ('password_invalid', 'password_verified', 'password_throttled')),
  occurred_at timestamptz not null default clock_timestamp()
);
alter table growth_internal.security_password_events enable row level security;
revoke all on growth_internal.security_password_events from public, anon, authenticated, service_role;
revoke all on sequence growth_internal.security_password_events_id_seq from public, anon, authenticated, service_role;
create index security_password_events_recent_idx on growth_internal.security_password_events (occurred_at desc, id desc);
create index security_password_events_failures_idx on growth_internal.security_password_events (occurred_at desc, user_id) where event_type = 'password_invalid';

alter function public.hook_password_login_throttle(jsonb) rename to password_login_throttle_impl;
revoke all on function public.password_login_throttle_impl(jsonb) from public, anon, authenticated, service_role, supabase_auth_admin;
create function public.hook_password_login_throttle(event jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare decision jsonb; kind text;
begin
  decision := public.password_login_throttle_impl(event);
  kind := case when decision->>'decision' = 'reject' then 'password_throttled'
               when (event->>'valid')::boolean then 'password_verified'
               else 'password_invalid' end;
  insert into growth_internal.security_password_events(user_id, event_type)
    values ((event->>'user_id')::uuid, kind);
  return decision;
end $$;
revoke all on function public.hook_password_login_throttle(jsonb) from public, anon, authenticated, service_role;
grant execute on function public.hook_password_login_throttle(jsonb) to supabase_auth_admin;

-- Intended for an owner-scheduled daily job; app roles cannot erase the trail.
create function growth_internal.prune_security_password_events() returns bigint
language plpgsql security definer set search_path = '' as $$
declare removed bigint;
begin
  delete from growth_internal.security_password_events where occurred_at < clock_timestamp() - interval '90 days';
  get diagnostics removed = row_count;
  return removed;
end $$;
revoke all on function growth_internal.prune_security_password_events() from public, anon, authenticated, service_role, supabase_auth_admin;

-- Only MFA-verified administrators can inspect the security trail.
create function public.admin_security_activity(p_offset integer default 0, p_limit integer default 50)
returns table(event_at timestamptz, user_id uuid, event_type text)
language plpgsql security definer set search_path = '' as $$
begin
  perform growth_internal.require_admin();
  if p_offset is null or p_offset < 0 or p_limit is null or p_limit not between 1 and 100 then
    raise exception 'Invalid page.' using errcode = 'P0001';
  end if;
  return query select e.occurred_at, e.user_id, e.event_type
    from growth_internal.security_password_events e
    order by e.occurred_at desc, e.id desc limit p_limit offset p_offset;
end $$;
revoke all on function public.admin_security_activity(integer,integer) from public, anon;
grant execute on function public.admin_security_activity(integer,integer) to authenticated;

-- Preserve existing alert types and pagination; add an account-level signal.
create or replace function public.admin_alerts() returns table(kind text,subject text,activity bigint,observed_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_admin(); return query
 select 'pending'::text,cl.campaign_id::text,count(*)::bigint,min(cl.created_at) from public.campaign_claims cl join public.campaigns c on c.id=cl.campaign_id where cl.status='pending' and c.status='active' and cl.created_at<now()-make_interval(hours=>(select value from growth_internal.admin_alert_settings where key='pending_hours')) group by cl.campaign_id
 union all select 'coins',coalesce(u.email::text,l.user_id::text),sum(l.amount)::bigint,max(l."createdAt") from public.coin_ledger l left join auth.users u on u.id=l.user_id where l.amount>0 and l."createdAt">=now()-interval '24 hours' group by l.user_id,u.email having sum(l.amount)>=(select value from growth_internal.admin_alert_settings where key='coins_24h')
 union all select 'referrals',coalesce(u.email::text,r.referrer_id::text),count(*)::bigint,max(r.created_at) from growth_internal.referrals r left join auth.users u on u.id=r.referrer_id where r.created_at>=now()-interval '24 hours' group by r.referrer_id,u.email having count(*)>=(select value from growth_internal.admin_alert_settings where key='referrals_24h')
 union all select 'password_failures',coalesce(u.email::text,e.user_id::text),count(*)::bigint,max(e.occurred_at) from growth_internal.security_password_events e left join auth.users u on u.id=e.user_id where e.event_type='password_invalid' and e.user_id is not null and e.occurred_at>=now()-interval '15 minutes' group by e.user_id,u.email having count(*)>=5
 order by 4 desc limit 100; end $$;
commit;
