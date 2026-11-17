begin;

-- Exact-number lookups expose only a display name, never email or account state.
create table growth_internal.wallet_lookup_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_started_at timestamptz not null,
  attempts integer not null
);
alter table growth_internal.wallet_lookup_limits enable row level security;
revoke all on growth_internal.wallet_lookup_limits from public, anon, authenticated;

create function public.lookup_wallet_recipient(p_wallet text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid := auth.uid(); quota growth_internal.wallet_lookup_limits%rowtype; recipient_name text; recipient_public_id text;
begin
  perform growth_internal.require_active();
  if p_wallet is null or p_wallet !~ '^[1-9][0-9]{9}$' then
    return jsonb_build_object('status','not_found');
  end if;
  insert into growth_internal.wallet_lookup_limits(user_id,window_started_at,attempts)
    values(uid,clock_timestamp(),0) on conflict(user_id) do nothing;
  select * into quota from growth_internal.wallet_lookup_limits where user_id=uid for update;
  if quota.window_started_at <= clock_timestamp() - interval '1 minute' then
    update growth_internal.wallet_lookup_limits set window_started_at=clock_timestamp(),attempts=1 where user_id=uid;
  elsif quota.attempts >= 20 then
    return jsonb_build_object('status','rate_limited');
  else
    update growth_internal.wallet_lookup_limits set attempts=attempts+1 where user_id=uid;
  end if;
  select coalesce(nullif(left(btrim(u.raw_user_meta_data->>'full_name'),80),''),'Member'), i.public_id
    into recipient_name,recipient_public_id from public.wallets w join auth.users u on u.id=w.id
    join growth_internal.user_identifiers i on i.user_id=u.id
    where w.wallet_number=p_wallet and u.email_confirmed_at is not null and nullif(u.email,'') is not null;
  if recipient_name is null then return jsonb_build_object('status','not_found'); end if;
  return jsonb_build_object('status','found','name',recipient_name,'recipient_id',recipient_public_id);
end $$;
revoke all on function public.lookup_wallet_recipient(text) from public, anon;
grant execute on function public.lookup_wallet_recipient(text) to authenticated;

-- The sequence never cycles or reuses values, including on transaction rollback.
create sequence growth_internal.wallet_payment_reference_seq
  as bigint minvalue 100000000000 maxvalue 999999999999 start 100000000000 no cycle;
revoke all on sequence growth_internal.wallet_payment_reference_seq from public, anon, authenticated;
create table growth_internal.wallet_payment_results (
  reference_id text primary key check (reference_id ~ '^[0-9]{12}$'),
  sender_id uuid references auth.users(id) on delete set null,
  request_id uuid not null,
  recipient_wallet text not null check (recipient_wallet ~ '^[1-9][0-9]{9}$'),
  recipient_name text not null,
  amount integer not null check (amount > 0),
  status text not null check (status in ('success','failure')),
  failure_code text,
  transfer_id uuid references public.wallet_transfers(id) on delete set null,
  created_at timestamptz not null default clock_timestamp(),
  unique(sender_id,request_id)
);
alter table growth_internal.wallet_payment_results enable row level security;
revoke all on growth_internal.wallet_payment_results from public, anon, authenticated;

-- Older clients must not turn a finalized failure into a later transfer with the same request.
create function growth_internal.prevent_failed_payment_reuse() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if exists(select 1 from growth_internal.wallet_payment_results r
      where r.sender_id=new.sender_id and r.request_id=new.request_id and r.status='failure') then
    raise exception 'Transfer request already finalized.';
  end if;
  return new;
end $$;
revoke all on function growth_internal.prevent_failed_payment_reuse() from public, anon, authenticated;
create trigger prevent_failed_payment_reuse before insert on public.wallet_transfers
  for each row execute function growth_internal.prevent_failed_payment_reuse();

create function public.pay_wallet_coins(p_wallet text,p_amount integer,p_pin text,p_request uuid,p_recipient_id text default null)
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
  ref := nextval('growth_internal.wallet_payment_reference_seq'::regclass)::text;
  completed_at := clock_timestamp();
  insert into growth_internal.wallet_payment_results(reference_id,sender_id,request_id,recipient_wallet,recipient_name,amount,status,failure_code,transfer_id,created_at)
    values(ref,uid,p_request,p_wallet,recipient_name,p_amount,case when state='ok' then 'success' else 'failure' end,
      case when state='ok' then null else state end,transfer_id,completed_at) returning * into previous;
  return jsonb_build_object('status',previous.status,'reference',previous.reference_id,'wallet',previous.recipient_wallet,
    'name',previous.recipient_name,'amount',previous.amount,'created_at',previous.created_at,'failure_code',previous.failure_code);
end $$;
revoke all on function public.pay_wallet_coins(text,integer,text,uuid,text) from public, anon;
grant execute on function public.pay_wallet_coins(text,integer,text,uuid,text) to authenticated;
commit;
