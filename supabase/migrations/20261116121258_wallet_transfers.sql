begin;
-- Coins remain server controlled; each transfer has balanced ledger entries.
create table public.wallet_transfers (
 id uuid primary key default gen_random_uuid(),
 sender_id uuid references auth.users(id) on delete set null,
 recipient_id uuid references auth.users(id) on delete set null,
 recipient_wallet text not null check(recipient_wallet ~ '^[1-9][0-9]{9}$'),
 request_id uuid not null,
 amount integer not null check(amount > 0),
 created_at timestamptz not null default now(),
 unique(sender_id,request_id),
 check(sender_id <> recipient_id)
);
alter table public.wallet_transfers enable row level security;
revoke all on public.wallet_transfers from public,anon,authenticated;
grant select on public.wallet_transfers to authenticated;
create policy transfer_participant_read on public.wallet_transfers for select to authenticated
 using(public.account_access_allowed() and auth.uid() in (sender_id,recipient_id));
alter table public.coin_ledger drop constraint coin_ledger_reason_check;
alter table public.coin_ledger add constraint coin_ledger_reason_check
 check(reason in ('welcome','campaign','task','refund','referral','admin_adjustment','purchase','transfer_sent','transfer_received'));
alter table public.coin_ledger add column transfer_id uuid references public.wallet_transfers(id) on delete set null;
create unique index ledger_transfer_once on public.coin_ledger(transfer_id,user_id) where transfer_id is not null;

create function public.transfer_wallet_coins(p_wallet text,p_amount integer,p_pin text,p_request uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); recipient uuid; receipt public.wallet_transfers; pin_status text; available integer; receiving integer;
begin
 perform growth_internal.require_active();
 if p_wallet is null or p_wallet !~ '^[1-9][0-9]{9}$' or p_amount is null or p_amount<=0 or p_request is null then
   raise exception 'Enter a valid wallet number and positive whole coin amount.';
 end if;
 -- Serialize retries without exposing other users or allowing a reused ID to change payment.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(uid::text||p_request::text,45192));
 select * into receipt from public.wallet_transfers where sender_id=uid and request_id=p_request;
 if found then
   if receipt.recipient_wallet<>p_wallet or receipt.amount<>p_amount then raise exception 'Transfer request changed.'; end if;
   return jsonb_build_object('status','ok','id',receipt.id);
 end if;
 select w.id into recipient from public.wallets w join auth.users u on u.id=w.id
 where w.wallet_number=p_wallet and u.email_confirmed_at is not null and nullif(u.email,'') is not null
 and not exists(select 1 from public.user_access a where a.user_id=w.id and a.blocked);
 if recipient is null or recipient=uid then raise exception 'Recipient wallet unavailable.'; end if;
 pin_status:=growth_internal.check_release_pin(p_pin);
 if pin_status<>'ok' then return jsonb_build_object('status',pin_status); end if;
 -- Always lock both wallets in the same order, including opposite-direction transfers.
 perform id from public.wallets where id in (uid,recipient) order by id for update;
 select balance into available from public.wallets where id=uid;
 select balance into receiving from public.wallets where id=recipient;
 if available is null or available<p_amount then raise exception 'Not enough coins.'; end if;
 if receiving is null or receiving::bigint+p_amount>2147483647 then raise exception 'Recipient wallet unavailable.'; end if;
 insert into public.wallet_transfers(sender_id,recipient_id,recipient_wallet,request_id,amount)
 values(uid,recipient,p_wallet,p_request,p_amount) returning * into receipt;
 update public.wallets set balance=balance-p_amount where id=uid;
 update public.wallets set balance=balance+p_amount where id=recipient;
 insert into public.coin_ledger(user_id,amount,reason,transfer_id) values
 (uid,-p_amount,'transfer_sent',receipt.id),(recipient,p_amount,'transfer_received',receipt.id);
 return jsonb_build_object('status','ok','id',receipt.id);
end $$;
revoke all on function public.transfer_wallet_coins(text,integer,text,uuid) from public,anon;
grant execute on function public.transfer_wallet_coins(text,integer,text,uuid) to authenticated;
commit;
