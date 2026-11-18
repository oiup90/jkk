begin;
-- Pause reference-producing writes while existing IDs are reserved and triggers change.
lock table public.wallet_transfers, public.coin_ledger, growth_internal.wallet_payment_results in share row exclusive mode;
-- Preserve every previously issued reference and reserve future IDs permanently.
create table growth_internal.reference_reservations (reference_id text primary key);
insert into growth_internal.reference_reservations(reference_id)
 select reference_id from public.wallet_transfers union
 select reference_id from public.coin_ledger union
 select reference_id from growth_internal.wallet_payment_results;
alter table growth_internal.reference_reservations enable row level security;
revoke all on growth_internal.reference_reservations from public,anon,authenticated;
create function growth_internal.allocate_reference(p_kind text) returns text
language plpgsql security definer set search_path='' as $$
declare candidate text;
begin
 if p_kind not in ('payment','welcome','referral') or p_kind is null then raise exception 'Invalid reference type.'; end if;
 for i in 1..1000 loop
  if p_kind='payment' then
   candidate:=(100+growth_internal.secure_random_integer(900))::text || lpad(growth_internal.secure_random_integer(1000000000)::text,9,'0');
  else
   candidate:=case when p_kind='welcome' then 'RG' else 'RF' end || growth_internal.secure_random_integer(10)::text || lpad(growth_internal.secure_random_integer(1000000000)::text,9,'0');
  end if;
  insert into growth_internal.reference_reservations values(candidate) on conflict do nothing;
  if found then return candidate; end if;
 end loop;
 raise exception 'Unable to allocate a unique reference.';
end $$;
revoke all on function growth_internal.allocate_reference(text) from public,anon,authenticated;
create or replace function growth_internal.assign_transfer_reference() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' then new.reference_id:=growth_internal.allocate_reference('payment');
 elsif new.reference_id is distinct from old.reference_id then raise exception 'Transfer reference cannot be changed.'; end if;
 return new;
end $$;
create or replace function growth_internal.assign_ledger_reference() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_op='UPDATE' then
  if new.reference_id is distinct from old.reference_id then raise exception 'Ledger reference cannot be changed.'; end if;
  return new;
 end if;
 if new.reason in ('welcome','referral') then new.reference_id:=growth_internal.allocate_reference(new.reason);
 elsif new.transfer_id is not null then
  select reference_id into new.reference_id from public.wallet_transfers where id=new.transfer_id;
  if new.reference_id is null then raise exception 'Transfer reference unavailable.'; end if;
 else new.reference_id:=growth_internal.allocate_reference('payment'); end if;
 return new;
end $$;
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
      when 'Not enough available coins.' then 'insufficient_balance'
      when 'Wallet is inactive. Activate it before spending.' then 'wallet_inactive'
      else null end;
    if state is null then raise; end if;
  end;
  transfer_id := case when state='ok' then (transfer_result->>'id')::uuid else null end;
  if state='ok' then
    select t.reference_id into ref from public.wallet_transfers t where t.id=transfer_id;
  else
    ref := growth_internal.allocate_reference('payment');
  end if;
  completed_at := clock_timestamp();
  insert into growth_internal.wallet_payment_results(reference_id,sender_id,request_id,recipient_wallet,recipient_name,amount,status,failure_code,transfer_id,created_at)
    values(ref,uid,p_request,p_wallet,recipient_name,p_amount,case when state='ok' then 'success' else 'failure' end,
      case when state='ok' then null else state end,transfer_id,completed_at) returning * into previous;
  return jsonb_build_object('status',previous.status,'reference',previous.reference_id,'wallet',previous.recipient_wallet,
    'name',previous.recipient_name,'amount',previous.amount,'created_at',previous.created_at,'failure_code',previous.failure_code);
end $$;


-- Public sign-in links contain no user data. Editors alone can modify them.
create table public.official_social_links (
 platform text primary key check(platform in ('instagram','facebook','youtube','x')),
 url text not null check(length(url) <= 500), updated_at timestamptz not null default now()
);
alter table public.official_social_links enable row level security;
revoke all on public.official_social_links from public,anon,authenticated;
grant select(platform,url) on public.official_social_links to anon,authenticated;
create policy official_social_links_public_read on public.official_social_links for select to anon,authenticated using (true);
create function public.admin_set_social_link(p_platform text,p_url text) returns void
language plpgsql security definer set search_path='' as $$
declare u text:=btrim(coalesce(p_url,'')); host text;
begin
 perform growth_internal.require_admin_editor();
 if p_platform is null or p_platform not in ('instagram','facebook','youtube','x') then raise exception 'Invalid platform.'; end if;
 if u='' then delete from public.official_social_links where platform=p_platform;
 else
  if length(u)>500 or u !~ '^https://[A-Za-z0-9.-]+(/[^[:space:]?#]*)?(\?[^[:space:]#]*)?(#[^[:space:]]*)?$' then raise exception 'Enter a valid HTTPS social profile URL.'; end if;
  host:=lower(split_part(split_part(split_part(substr(u,9),'/',1),'?',1),'#',1));
  if not ((p_platform='instagram' and host in ('instagram.com','www.instagram.com')) or
          (p_platform='facebook' and host in ('facebook.com','www.facebook.com')) or
          (p_platform='youtube' and host in ('youtube.com','www.youtube.com','youtu.be')) or
          (p_platform='x' and host in ('x.com','www.x.com','twitter.com','www.twitter.com'))) then raise exception 'URL does not match platform.'; end if;
  insert into public.official_social_links(platform,url) values(p_platform,u)
   on conflict(platform) do update set url=excluded.url,updated_at=now();
 end if;
 insert into growth_internal.admin_operations_audit(actor_id,action,details) values(auth.uid(),'Official social link',p_platform);
end $$;
revoke all on function public.admin_set_social_link(text,text) from public,anon;
grant execute on function public.admin_set_social_link(text,text) to authenticated;
commit;
