begin;
create table public.coin_purchase_plans (
 id text primary key, coins integer not null check(coins between 1 and 100000),
 amount_paise integer not null check(amount_paise between 900 and 20000000),
 currency text not null default 'INR' check(currency='INR'), active boolean not null default true
);
insert into public.coin_purchase_plans(id,coins,amount_paise) values
 ('starter',100,4900),('popular',300,12900),('value',1000,39900);
alter table public.coin_purchase_plans enable row level security;
revoke all on public.coin_purchase_plans from public,anon,authenticated;
grant select on public.coin_purchase_plans to authenticated;
create policy coin_plans_read on public.coin_purchase_plans for select to authenticated
 using(public.account_access_allowed() and active);
create table public.coin_purchase_orders (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id),
 plan_id text not null references public.coin_purchase_plans(id),
 coins integer not null check(coins between 1 and 100000),
 amount_paise integer not null check(amount_paise between 900 and 20000000),
 currency text not null default 'INR' check(currency='INR'),
 status text not null default 'creating' check(status in ('creating','pending','credited','failed')),
 request_id text unique, checkout_url text, payment_id text unique,
 created_at timestamptz not null default now(), credited_at timestamptz,
 check(status in ('creating','failed') or (request_id is not null and checkout_url is not null)),
 check((status='credited')=(payment_id is not null and credited_at is not null))
);
create index coin_orders_owner_time on public.coin_purchase_orders(user_id,created_at desc);
alter table public.coin_purchase_orders enable row level security;
revoke all on public.coin_purchase_orders from public,anon,authenticated;
grant select on public.coin_purchase_orders to authenticated;
create policy coin_orders_read on public.coin_purchase_orders for select to authenticated
 using(public.account_access_allowed() and user_id=auth.uid());
alter table public.coin_ledger drop constraint coin_ledger_reason_check;
alter table public.coin_ledger add constraint coin_ledger_reason_check
 check(reason in ('welcome','campaign','task','refund','referral','admin_adjustment','purchase'));
alter table public.coin_ledger add column purchase_order_id uuid unique references public.coin_purchase_orders(id);

create function public.create_coin_purchase(p_plan text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); plan public.coin_purchase_plans; item public.coin_purchase_orders;
begin
 perform growth_internal.require_active();
 if not exists(select 1 from public.wallets where id=uid) then raise exception 'Wallet unavailable'; end if;
 select * into plan from public.coin_purchase_plans where id=p_plan and active;
 if not found then raise exception 'Plan unavailable'; end if;
 select * into item from public.coin_purchase_orders where user_id=uid and plan_id=p_plan
 and status in ('creating','pending') and created_at>now()-interval '10 minutes' order by created_at desc limit 1;
 if found then return jsonb_build_object('order',to_jsonb(item),'created',false); end if;
 if (select count(*) from public.coin_purchase_orders where user_id=uid and created_at>now()-interval '1 hour')>=10 then
  raise exception 'Too many checkout attempts. Try again later.';
 end if;
 insert into public.coin_purchase_orders(user_id,plan_id,coins,amount_paise)
 values(uid,plan.id,plan.coins,plan.amount_paise) returning * into item;
 return jsonb_build_object('order',to_jsonb(item),'created',true);
end $$;
revoke all on function public.create_coin_purchase(text) from public,anon;
grant execute on function public.create_coin_purchase(text) to authenticated;

create function public.attach_coin_checkout(p_order uuid,p_request text,p_url text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if p_request is null or p_url is null or p_request !~ '^[a-f0-9]{32}$' or p_url !~ '^https://www[.]instamojo[.]com/[^?#]+$' then raise exception 'Invalid checkout'; end if;
 update public.coin_purchase_orders set request_id=p_request,checkout_url=p_url,status='pending'
 where id=p_order and status='creating';
 if not found then raise exception 'Checkout unavailable'; end if;
end $$;
revoke all on function public.attach_coin_checkout(uuid,text,text) from public,anon,authenticated;
grant execute on function public.attach_coin_checkout(uuid,text,text) to service_role;

create function public.fail_coin_checkout(p_order uuid)
returns void language sql security definer set search_path='' as $$
 update public.coin_purchase_orders set status='failed' where id=p_order and status='creating';
$$;
revoke all on function public.fail_coin_checkout(uuid) from public,anon,authenticated;
grant execute on function public.fail_coin_checkout(uuid) to service_role;

create function public.credit_coin_purchase(p_order uuid,p_request text,p_payment text,p_amount integer)
returns boolean language plpgsql security definer set search_path='' as $$
declare item public.coin_purchase_orders;
begin
 select * into item from public.coin_purchase_orders where id=p_order for update;
 if not found or item.request_id is distinct from p_request or item.amount_paise is distinct from p_amount
 or p_payment is null or p_payment !~ '^[A-Za-z0-9_-]{1,100}$' then raise exception 'Payment mismatch'; end if;
 if item.status='credited' then
  if item.payment_id<>p_payment then raise exception 'Payment mismatch'; end if;
  return true;
 end if;
 if item.status<>'pending' then raise exception 'Order unavailable'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(item.user_id::text,314159));
 if exists(select 1 from public.user_access where user_id=item.user_id and blocked) then raise exception 'Account access blocked'; end if;
 update public.wallets set balance=balance+item.coins where id=item.user_id;
 if not found then raise exception 'Wallet unavailable'; end if;
 insert into public.coin_ledger(user_id,amount,reason,purchase_order_id)
 values(item.user_id,item.coins,'purchase',item.id);
 update public.coin_purchase_orders set status='credited',payment_id=p_payment,credited_at=now() where id=item.id;
 return true;
end $$;
revoke all on function public.credit_coin_purchase(uuid,text,text,integer) from public,anon,authenticated;
grant execute on function public.credit_coin_purchase(uuid,text,text,integer) to service_role;
commit;
