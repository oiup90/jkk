-- Auth alone may submit password verification events to the throttle/audit hook.
-- Preserve its definition, current lockouts and audit records.
begin;
grant execute on function public.hook_password_login_throttle(jsonb) to supabase_auth_admin;
revoke all on function public.hook_password_login_throttle(jsonb) from public, anon, authenticated, service_role;

do $$
begin
  if has_function_privilege('anon', 'public.hook_password_login_throttle(jsonb)', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.hook_password_login_throttle(jsonb)', 'EXECUTE')
     or has_function_privilege('service_role', 'public.hook_password_login_throttle(jsonb)', 'EXECUTE')
     or not has_function_privilege('supabase_auth_admin', 'public.hook_password_login_throttle(jsonb)', 'EXECUTE') then
    raise exception 'Password hook permissions do not match the Auth-only contract';
  end if;
end $$;
commit;
