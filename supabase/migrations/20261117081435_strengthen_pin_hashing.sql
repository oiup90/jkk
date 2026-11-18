-- Preserve existing PINs and lockout behavior while strengthening new hashes.
begin;

create or replace function growth_internal.pin_hash(p_pin text, p_salt text default null) returns text
language plpgsql security definer set search_path='' as $$
declare extension_schema text; result text;
begin
  select n.nspname into extension_schema from pg_catalog.pg_extension e
    join pg_catalog.pg_namespace n on n.oid=e.extnamespace where e.extname='pgcrypto';
  if extension_schema is null then raise exception 'pgcrypto is unavailable.'; end if;
  if p_salt is null then
    execute pg_catalog.format('select %1$I.crypt($1, %1$I.gen_salt(''bf'', 12))', extension_schema) into result using p_pin;
  else
    execute pg_catalog.format('select %I.crypt($1, $2)', extension_schema) into result using p_pin, p_salt;
  end if;
  return result;
end $$;
revoke all on function growth_internal.pin_hash(text,text) from public, anon, authenticated;

-- Only a successfully verified legacy PIN can be rehashed: the plaintext PIN
-- is never stored, and failed or locked attempts leave its hash unchanged.
create or replace function growth_internal.check_release_pin(p_pin text) returns text
language plpgsql security definer set search_path='' as $$
declare p growth_internal.release_pins%rowtype;
begin
  select * into p from growth_internal.release_pins where user_id=auth.uid() for update;
  if not found then return 'pin_missing'; end if;
  if p.locked_until > now() then return 'pin_locked'; end if;
  if p_pin is null or p_pin !~ '^[0-9]{4}$' or growth_internal.pin_hash(p_pin,p.pin_hash) <> p.pin_hash then
    update growth_internal.release_pins set failures=case when coalesce(locked_until, '-infinity'::timestamptz) <= now() and failures >= 5 then 1 else failures+1 end,
      locked_until=case when (case when coalesce(locked_until, '-infinity'::timestamptz) <= now() and failures >= 5 then 1 else failures+1 end) >= 5 then now()+interval '15 minutes' else null end
      where user_id=auth.uid();
    return 'invalid_pin';
  end if;
  update growth_internal.release_pins set
    pin_hash=case when p.pin_hash ~ '^\$2a\$(0[4-9]|1[01])\$' then growth_internal.pin_hash(p_pin) else p.pin_hash end,
    failures=0, locked_until=null where user_id=auth.uid();
  return 'ok';
end $$;
revoke all on function growth_internal.check_release_pin(text) from public, anon, authenticated;

commit;
