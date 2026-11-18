begin;

-- Validate only new or changed names. Existing metadata must not prevent an
-- unrelated Auth update (for example sign-in or a password change).
create function growth_internal.validate_profile_name() returns trigger
language plpgsql set search_path = '' as $$
declare name_value jsonb; clean_name text;
begin
  if tg_op = 'UPDATE' and
     (new.raw_user_meta_data -> 'full_name') is not distinct from
     (old.raw_user_meta_data -> 'full_name') then
    return new;
  end if;
  name_value := new.raw_user_meta_data -> 'full_name';
  -- Signup may omit the optional name, and Auth may clear it with JSON null.
  if name_value is null or name_value = 'null'::jsonb then return new; end if;
  if jsonb_typeof(name_value) <> 'string' or length(name_value #>> '{}') > 4096 then
    raise exception 'Invalid profile name.' using errcode = 'P0001';
  end if;
  clean_name := regexp_replace(name_value #>> '{}', '^[[:space:]]+|[[:space:]]+$', '', 'g');
  if length(clean_name) not between 1 and 80 then
    raise exception 'Invalid profile name.' using errcode = 'P0001';
  end if;
  new.raw_user_meta_data := jsonb_set(new.raw_user_meta_data, '{full_name}', to_jsonb(clean_name));
  return new;
end $$;
revoke all on function growth_internal.validate_profile_name() from public, anon, authenticated;
create trigger validate_profile_name before insert or update of raw_user_meta_data
on auth.users for each row execute function growth_internal.validate_profile_name();
commit;
