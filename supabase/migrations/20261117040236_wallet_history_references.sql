begin;

-- A single non-cycling allocator makes the ten-digit suffix unique for bonuses.
create sequence growth_internal.coin_bonus_reference_seq as bigint minvalue 0 maxvalue 9999999999 start 0 no cycle;
revoke all on sequence growth_internal.coin_bonus_reference_seq from public, anon, authenticated;

-- A transfer's two ledger entries and successful receipt share one reference.
alter table public.wallet_transfers add column reference_id text;
update public.wallet_transfers t set reference_id=coalesce(
  (select r.reference_id from growth_internal.wallet_payment_results r where r.transfer_id=t.id and r.status='success' limit 1),
  nextval('growth_internal.wallet_payment_reference_seq'::regclass)::text
);
alter table public.wallet_transfers alter column reference_id set not null;
alter table public.wallet_transfers add constraint wallet_transfers_reference_format check(reference_id ~ '^[0-9]{12}$');
alter table public.wallet_transfers add constraint wallet_transfers_reference_unique unique(reference_id);

create function growth_internal.assign_transfer_reference() returns trigger language plpgsql security definer set search_path='' as $$
begin
  if tg_op='INSERT' then
    new.reference_id := nextval('growth_internal.wallet_payment_reference_seq'::regclass)::text;
  elsif new.reference_id is distinct from old.reference_id then
    raise exception 'Transfer reference cannot be changed.';
  end if;
  return new;
end $$;
revoke all on function growth_internal.assign_transfer_reference() from public, anon, authenticated;
create trigger assign_transfer_reference before insert or update of reference_id on public.wallet_transfers
  for each row execute function growth_internal.assign_transfer_reference();

alter table public.coin_ledger add column reference_id text;
update public.coin_ledger l set reference_id=case
  when l.reason='welcome' then 'RG'||lpad(nextval('growth_internal.coin_bonus_reference_seq'::regclass)::text,10,'0')
  when l.reason='referral' then 'RF'||lpad(nextval('growth_internal.coin_bonus_reference_seq'::regclass)::text,10,'0')
  when l.transfer_id is not null then (select t.reference_id from public.wallet_transfers t where t.id=l.transfer_id)
  else nextval('growth_internal.wallet_payment_reference_seq'::regclass)::text end;
alter table public.coin_ledger alter column reference_id set not null;
alter table public.coin_ledger add constraint coin_ledger_reference_format check(
  (reason='welcome' and reference_id ~ '^RG[0-9]{10}$') or
  (reason='referral' and reference_id ~ '^RF[0-9]{10}$') or
  (reason not in ('welcome','referral') and reference_id ~ '^[0-9]{12}$')
);
create unique index coin_ledger_nontransfer_reference_unique on public.coin_ledger(reference_id)
  where reason not in ('transfer_sent','transfer_received');

create function growth_internal.assign_ledger_reference() returns trigger language plpgsql security definer set search_path='' as $$
begin
  if tg_op='UPDATE' then
    if new.reference_id is distinct from old.reference_id then raise exception 'Ledger reference cannot be changed.'; end if;
    return new;
  end if;
  if new.reason='welcome' then
    new.reference_id := 'RG'||lpad(nextval('growth_internal.coin_bonus_reference_seq'::regclass)::text,10,'0');
  elsif new.reason='referral' then
    new.reference_id := 'RF'||lpad(nextval('growth_internal.coin_bonus_reference_seq'::regclass)::text,10,'0');
  elsif new.transfer_id is not null then
    select reference_id into new.reference_id from public.wallet_transfers where id=new.transfer_id;
    if new.reference_id is null then raise exception 'Transfer reference unavailable.'; end if;
  else
    new.reference_id := nextval('growth_internal.wallet_payment_reference_seq'::regclass)::text;
  end if;
  return new;
end $$;
revoke all on function growth_internal.assign_ledger_reference() from public, anon, authenticated;
create trigger assign_ledger_reference before insert or update of reference_id on public.coin_ledger
  for each row execute function growth_internal.assign_ledger_reference();

create or replace function public.pay_wallet_coins(p_wallet text,p_amount integer,p_pin text,p_request uuid,p_recipient_id text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  uid uuid := auth.uid(); recipient uuid; lock_id uuid;
  previous growth_internal.wallet_payment_results%rowtype;
  transfer_result jsonb; state text; recipient_name text; transfer_id uuid;
  ref text; completed_at timestamptz; recipient_public_id text; legacy_transfer boolean;
begin
  if uid is null then raise exception 'Please sign in.'; end if;
  if p_wallet is null or p_wallet !~ '^[1-9][0-9]{9}$' or p_amount is null or p_amount <= 0 or p_request is null then
    raise exception 'Enter a valid wallet number and positive whole coin amount.';
  end if;
  select w.id into recipient from public.wallets w where w.wallet_number=p_wallet;
  -- Coordinate with account blocking and order both account locks for opposite transfers.
  for lock_id in select distinct x from unnest(array[uid,recipient]) x where x is not null order by x loop
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(lock_id::text,314159));
  end loop;
  perform growth_internal.require_active();
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(uid::text||p_request::text,45192));
  select * into previous from growth_internal.wallet_payment_results where sender_id=uid and request_id=p_request;
  if found then
    if previous.recipient_wallet<>p_wallet or previous.amount<>p_amount then raise exception 'Transfer request changed.'; end if;
    return jsonb_build_object('status',previous.status,'reference',previous.reference_id,'wallet',previous.recipient_wallet,
      'name',previous.recipient_name,'amount',previous.amount,'created_at',previous.created_at,'failure_code',previous.failure_code);
  end if;
  select exists(select 1 from public.wallet_transfers where sender_id=uid and request_id=p_request) into legacy_transfer;
  if not legacy_transfer then
    -- Keep the looked-up wallet from being deleted or reassigned before transfer.
    perform w.id from public.wallets w where w.id in (uid,recipient) order by w.id for update;
  end if;
  select coalesce(nullif(left(btrim(u.raw_user_meta_data->>'full_name'),80),''),'Member'), i.public_id
    into recipient_name,recipient_public_id from public.wallets w join auth.users u on u.id=w.id
    left join growth_internal.user_identifiers i on i.user_id=u.id where w.id=recipient and w.wallet_number=p_wallet;
  recipient_name := coalesce(recipient_name,'Member');
  begin
    -- This retains the old RPC's PIN lockout, idempotency and balanced ledger behavior.
    if not legacy_transfer and (p_recipient_id is null or recipient_public_id is distinct from p_recipient_id) then
      state := 'recipient_changed';
    else
      transfer_result := public.transfer_wallet_coins(p_wallet,p_amount,p_pin,p_request);
      state := transfer_result->>'status';
    end if;
  exception when raise_exception then
    state := case sqlerrm
      when 'Recipient wallet unavailable.' then 'recipient_unavailable'
      when 'Not enough coins.' then 'insufficient_balance'
      else null end;
    if state is null then raise; end if;
  end;
  transfer_id := case when state='ok' then (transfer_result->>'id')::uuid else null end;
  if state='ok' then
    select t.reference_id into ref from public.wallet_transfers t where t.id=transfer_id;
  else
    ref := nextval('growth_internal.wallet_payment_reference_seq'::regclass)::text;
  end if;
  completed_at := clock_timestamp();
  insert into growth_internal.wallet_payment_results(reference_id,sender_id,request_id,recipient_wallet,recipient_name,amount,status,failure_code,transfer_id,created_at)
    values(ref,uid,p_request,p_wallet,recipient_name,p_amount,case when state='ok' then 'success' else 'failure' end,
      case when state='ok' then null else state end,transfer_id,completed_at) returning * into previous;
  return jsonb_build_object('status',previous.status,'reference',previous.reference_id,'wallet',previous.recipient_wallet,
    'name',previous.recipient_name,'amount',previous.amount,'created_at',previous.created_at,'failure_code',previous.failure_code);
end $$;
commit;
