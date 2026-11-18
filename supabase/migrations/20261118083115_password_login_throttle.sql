-- Auth calls this hook after password verification and before issuing a session.
begin;
create table growth_internal.password_login_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_started_at timestamptz not null,
  failures integer not null check (failures between 1 and 5),
  locked_until timestamptz
);
alter table growth_internal.password_login_limits enable row level security;
revoke all on growth_internal.password_login_limits from public, anon, authenticated, service_role;

create function public.hook_password_login_throttle(event jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  account_id uuid := (event->>'user_id')::uuid;
  verified boolean;
  current_limit growth_internal.password_login_limits%rowtype;
  observed_at timestamptz;
begin
  if account_id is null or jsonb_typeof(event->'valid') is distinct from 'boolean' then
    raise exception 'Invalid password verification event';
  end if;
  verified := (event->>'valid')::boolean;
  -- Serialize first inserts, resets, and successes as well as existing rows.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(account_id::text, 771240));
  observed_at := pg_catalog.clock_timestamp();
  select * into current_limit from growth_internal.password_login_limits where user_id = account_id;
  if found and current_limit.locked_until > observed_at then
    -- Match Auth's invalid-credentials response without revoking existing sessions.
    return jsonb_build_object('decision', 'reject', 'message', 'Invalid login credentials', 'should_logout_user', false);
  end if;
  if verified then
    delete from growth_internal.password_login_limits where user_id = account_id;
  elsif current_limit.user_id is null or current_limit.locked_until is not null
        or current_limit.window_started_at <= observed_at - interval '15 minutes' then
    insert into growth_internal.password_login_limits(user_id, window_started_at, failures, locked_until)
    values (account_id, observed_at, 1, null)
    on conflict (user_id) do update set window_started_at = excluded.window_started_at, failures = 1, locked_until = null;
  else
    update growth_internal.password_login_limits
       set failures = failures + 1,
           locked_until = case when failures + 1 >= 5 then observed_at + interval '15 minutes' else null end
     where user_id = account_id;
  end if;
  return jsonb_build_object('decision', 'continue');
end $$;
revoke all on function public.hook_password_login_throttle(jsonb) from public, anon, authenticated, service_role;
grant execute on function public.hook_password_login_throttle(jsonb) to supabase_auth_admin;
commit;
