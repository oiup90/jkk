-- Wallet numbers are public identifiers, never authentication credentials.
-- Cryptographic randomness plus a unique constraint protects concurrent allocation.
alter table public.wallets add column wallet_number text;
alter table public.wallets add constraint wallets_number_format
  check (wallet_number ~ '^[1-9][0-9]{9}$');
alter table public.wallets add constraint wallets_number_unique unique (wallet_number);

create function growth_internal.assign_wallet_number() returns trigger
language plpgsql security definer set search_path = '' as $$
declare candidate text; sample bigint; attempts integer := 0;
begin
  if TG_OP = 'UPDATE' and old.wallet_number is not null then
    if new.wallet_number is distinct from old.wallet_number then
      raise exception 'Wallet numbers cannot be changed.' using errcode='23514';
    end if;
    return new;
  end if;
  loop
    attempts := attempts + 1;
    if attempts > 1000 then raise exception 'Wallet number allocation unavailable.'; end if;
    sample := ('x' || encode(extensions.gen_random_bytes(5), 'hex'))::bit(40)::bigint;
    -- Rejection sampling avoids modulo bias across the nine billion numbers.
    if sample >= 1098000000000 then continue; end if;
    candidate := (1000000000 + sample % 9000000000)::text;
    -- Hold the candidate lock until commit; collisions retry before insert.
    perform pg_catalog.pg_advisory_xact_lock(candidate::bigint);
    if not exists(select 1 from public.wallets where wallet_number = candidate) then
      new.wallet_number := candidate;
      return new;
    end if;
  end loop;
end $$;
revoke all on function growth_internal.assign_wallet_number() from public, anon, authenticated;
create trigger assign_wallet_number before insert or update of wallet_number
  on public.wallets for each row execute function growth_internal.assign_wallet_number();
-- Preserve all existing balances and owner/read policies while backfilling.
update public.wallets set wallet_number = null where wallet_number is null;
alter table public.wallets alter column wallet_number set not null;
