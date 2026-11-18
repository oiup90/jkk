begin;

-- Holds reserve part of the total balance. Inactive wallets may still receive
-- earned coins/refunds; all outgoing spending is stopped at the wallet boundary.
alter table public.wallets add column held_balance integer not null default 0;
alter table public.wallets add column is_active boolean not null default true;
alter table public.wallets add constraint wallet_hold_within_balance
  check (held_balance between 0 and balance);
create function growth_internal.guard_wallet_spending() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.balance < old.balance and not old.is_active then
    raise exception 'Wallet is inactive. Activate it before spending.';
  end if;
  if new.balance < new.held_balance then raise exception 'Not enough available coins.'; end if;
  return new;
end $$;
revoke all on function growth_internal.guard_wallet_spending() from public,anon,authenticated;
create trigger guard_wallet_spending before update on public.wallets
  for each row execute function growth_internal.guard_wallet_spending();

create table growth_internal.wallet_operations (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id) on delete set null,
  request_id uuid not null,
  user_id uuid references auth.users(id) on delete set null,
  recipient_id uuid references auth.users(id) on delete set null,
  action text not null check(action in ('add','deduct','debit','hold','release','transfer','activate','deactivate')),
  amount integer not null,
  reason text not null,
  arguments jsonb not null,
  result jsonb not null,
  created_at timestamptz not null default clock_timestamp(),
  unique(actor_id,request_id)
);
alter table growth_internal.wallet_operations enable row level security;
revoke all on growth_internal.wallet_operations from public,anon,authenticated;
create index wallet_operations_user_date on growth_internal.wallet_operations(user_id,created_at desc);
create index wallet_operations_recipient_date on growth_internal.wallet_operations(recipient_id,created_at desc);

create function public.admin_wallets(p_query text default '',p_offset integer default 0,p_limit integer default 50)
returns table(user_id uuid,public_id text,display_name text,wallet_number text,balance integer,held_balance integer,available_balance integer,is_active boolean)
language plpgsql security definer set search_path='' as $$
begin
  perform growth_internal.require_admin();
  if p_offset is null or p_offset<0 or p_limit is null or p_limit not between 1 and 100 or length(coalesce(p_query,''))>100 then
    raise exception 'Invalid search or page.';
  end if;
  return query select w.id,i.public_id,coalesce(nullif(btrim(u.raw_user_meta_data->>'full_name'),''),'Member'),
    w.wallet_number,w.balance,w.held_balance,w.balance-w.held_balance,w.is_active
    from public.wallets w join auth.users u on u.id=w.id
    join growth_internal.user_identifiers i on i.user_id=w.id
    where strpos(lower(w.wallet_number||' '||i.public_id||' '||coalesce(u.raw_user_meta_data->>'full_name','')),lower(btrim(coalesce(p_query,''))))>0
    order by w."createdAt" desc,w.id limit p_limit offset p_offset;
end $$;

create function public.admin_wallet_operate(p_request uuid,p_user uuid,p_action text,p_amount integer,p_reason text,p_recipient_wallet text default null,p_recipient uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  actor uuid:=auth.uid(); args jsonb; previous growth_internal.wallet_operations%rowtype;
  source public.wallets%rowtype; target public.wallets%rowtype;
  recipient uuid; tid uuid; ref text; operation_id uuid:=gen_random_uuid(); result jsonb;
  clean_reason text:=btrim(coalesce(p_reason,''));
begin
  -- One editor completes the operation in their existing verified session.
  perform growth_internal.require_admin_editor();
  if p_request is null or p_user is null or p_action is null or
     p_action not in ('add','deduct','debit','hold','release','transfer','activate','deactivate') or
     p_amount is null or length(clean_reason) not between 1 and 1000 then raise exception 'Invalid wallet operation.'; end if;
  if (p_action in ('activate','deactivate') and p_amount<>0) or
     (p_action not in ('activate','deactivate') and p_amount<=0) or
     (p_action<>'transfer' and (p_recipient_wallet is not null or p_recipient is not null)) or
     (p_action='transfer' and (p_recipient_wallet is null or p_recipient_wallet !~ '^[1-9][0-9]{9}$' or p_recipient is null)) then
    raise exception 'Enter valid operation details.';
  end if;
  args:=jsonb_build_object('user',p_user,'action',p_action,'amount',p_amount,'reason',clean_reason,'wallet',p_recipient_wallet,'recipient',p_recipient);
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(actor::text||p_request::text,57822));
  select * into previous from growth_internal.wallet_operations where actor_id=actor and request_id=p_request;
  if found then
    if previous.arguments<>args then raise exception 'Request ID already used.'; end if;
    return previous.result;
  end if;
  if p_action='transfer' then
    select w.id into recipient from public.wallets w where w.wallet_number=p_recipient_wallet and w.id=p_recipient;
    if recipient is null or recipient=p_user then raise exception 'Choose another valid recipient wallet.'; end if;
  end if;
  -- The same ordering as member transfers prevents opposing-transfer deadlocks.
  perform w.id from public.wallets w where w.id in (p_user,recipient) order by w.id for update;
  select * into source from public.wallets where id=p_user;
  if not found then raise exception 'Wallet unavailable.'; end if;
  if p_action='transfer' then
    select * into target from public.wallets where id=recipient and wallet_number=p_recipient_wallet;
    if not found then raise exception 'Recipient wallet unavailable.'; end if;
  end if;
  if p_action in ('deduct','debit','transfer','hold') and p_amount>source.balance-source.held_balance then
    raise exception 'Not enough available coins.';
  end if;
  if p_action='release' and p_amount>source.held_balance then raise exception 'Amount exceeds held coins.'; end if;
  if (p_action='add' and source.balance::bigint+p_amount>2147483647) or
     (p_action='transfer' and target.balance::bigint+p_amount>2147483647) then raise exception 'Wallet balance limit exceeded.'; end if;
  case p_action
    when 'add' then update public.wallets set balance=balance+p_amount where id=p_user;
    when 'deduct','debit' then update public.wallets set balance=balance-p_amount where id=p_user;
    when 'hold' then update public.wallets set held_balance=held_balance+p_amount where id=p_user;
    when 'release' then update public.wallets set held_balance=held_balance-p_amount where id=p_user;
    when 'activate' then update public.wallets set is_active=true where id=p_user;
    when 'deactivate' then update public.wallets set is_active=false where id=p_user;
    when 'transfer' then
      insert into public.wallet_transfers(sender_id,recipient_id,recipient_wallet,request_id,amount)
        values(p_user,recipient,p_recipient_wallet,operation_id,p_amount) returning id,reference_id into tid,ref;
      update public.wallets set balance=balance-p_amount where id=p_user;
      update public.wallets set balance=balance+p_amount where id=recipient;
      insert into public.coin_ledger(user_id,amount,reason,transfer_id) values
        (p_user,-p_amount,'transfer_sent',tid),(recipient,p_amount,'transfer_received',tid);
  end case;
  if p_action in ('add','deduct','debit') then
    insert into public.coin_ledger(user_id,amount,reason)
      values(p_user,case when p_action='add' then p_amount else -p_amount end,'admin_adjustment') returning reference_id into ref;
  end if;
  result:=jsonb_build_object('id',operation_id,'reference',ref,'balance_before',source.balance,'held_before',source.held_balance,
    'balance',(select balance from public.wallets where id=p_user),'held_balance',(select held_balance from public.wallets where id=p_user));
  insert into growth_internal.wallet_operations(id,actor_id,request_id,user_id,recipient_id,action,amount,reason,arguments,result)
    values(operation_id,actor,p_request,p_user,recipient,p_action,p_amount,clean_reason,args,result);
  insert into growth_internal.admin_operations_audit(actor_id,action,subject_id,details)
    values(actor,'Wallet '||p_action,p_user,concat(operation_id,': ',p_amount,' coins; ',clean_reason));
  return result;
end $$;

create function public.admin_wallet_history(p_user uuid,p_offset integer default 0)
returns table(id uuid,action text,amount integer,reason text,actor text,created_at timestamptz,result jsonb)
language plpgsql security definer set search_path='' as $$
begin
  perform growth_internal.require_admin();
  if p_user is null or p_offset is null or p_offset<0 then raise exception 'Invalid history page.'; end if;
  return query select o.id,case when o.recipient_id=p_user then 'transfer_received' else o.action end,
    o.amount,o.reason,coalesce(u.email::text,'Deleted administrator'),o.created_at,o.result
    from growth_internal.wallet_operations o left join auth.users u on u.id=o.actor_id
    where p_user in (o.user_id,o.recipient_id) order by o.created_at desc,o.id desc limit 50 offset p_offset;
end $$;

revoke all on function public.admin_wallets(text,integer,integer),public.admin_wallet_operate(uuid,uuid,text,integer,text,text,uuid),public.admin_wallet_history(uuid,integer) from public,anon;
grant execute on function public.admin_wallets(text,integer,integer),public.admin_wallet_operate(uuid,uuid,text,integer,text,text,uuid),public.admin_wallet_history(uuid,integer) to authenticated;
-- Retire the former two-editor write path. Historical requests remain intact.
revoke all on function public.admin_request_adjustment(uuid,integer,text),public.admin_request_wallet_adjustment(text,integer,text),public.admin_decide_adjustment(uuid,boolean) from public,anon,authenticated;

-- Every future positive ledger entry generates exactly one receipt notification,
-- including referral/welcome bonuses, purchases, refunds and user/admin transfers.
alter table public.notifications add column credit_source text;
create or replace function growth_internal.notify_coins_received() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.amount>0 then
    insert into public.notifications(user_id,kind,amount,credit_source)
      values(new.user_id,'coins_received',new.amount,new.reason);
  end if;
  return new;
end $$;

-- v1/v2 workers remain usable. v3 exposes only the credit amount and source
-- required to render the receipt message, and is service-role-only.
create function public.claim_push_jobs_v3(p_limit integer default 50)
returns table(job_id uuid,lease_id uuid,token text,kind text,title text,body text,amount integer,source text)
language sql security definer set search_path='' as $$
  select c.job_id,c.lease_id,c.token,c.kind,c.title,c.body,n.amount,n.credit_source
  from public.claim_push_jobs_v2(p_limit) c
  join growth_internal.push_jobs j on j.id=c.job_id join public.notifications n on n.id=j.notification_id;
$$;

revoke all on function public.claim_push_jobs_v3(integer) from public,anon,authenticated;
grant execute on function public.claim_push_jobs_v3(integer) to service_role;

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
