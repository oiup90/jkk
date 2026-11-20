begin;
-- Preserve payment receipts after self-deletion without a link to an account.
alter table public.coin_purchase_orders alter column user_id drop not null;
alter table public.coin_purchase_orders drop constraint coin_purchase_orders_user_id_fkey;
alter table public.coin_purchase_orders add constraint coin_purchase_orders_user_id_fkey foreign key(user_id) references auth.users(id) on delete set null;
-- Same five-minute Auth-issued nonce and five-attempt contract as PIN reauthentication.
create function public.delete_my_account(p_nonce text)
returns text language plpgsql security definer set search_path='' as $$
declare account auth.users%rowtype; attempts integer; claims jsonb := auth.jwt();
begin
 perform growth_internal.require_active();
 if exists(select 1 from public.admin_members where user_id=auth.uid()) then return 'admin_account'; end if;
 -- Lock serializes verification, resend and consumption across concurrent calls.
 select * into account from auth.users where id=auth.uid() for update;
 if account.email_confirmed_at is null or nullif(account.email,'') is null
    or lower(coalesce(claims->>'email','')) <> lower(account.email)
    or coalesce(account.phone,'') <> '' or coalesce(claims->>'phone','') <> '' then
  return 'email_otp_required';
 end if;
 if nullif(account.reauthentication_token,'') is null
    or account.reauthentication_sent_at is null
    or account.reauthentication_sent_at < now()-interval '5 minutes'
    or account.reauthentication_sent_at > now()+interval '30 seconds' then
  return 'otp_required';
 end if;
 insert into growth_internal.pin_reauthentication_attempts(user_id,sent_at,failures)
 values(auth.uid(),account.reauthentication_sent_at,0)
 on conflict(user_id) do update set sent_at=excluded.sent_at,failures=0
 where pin_reauthentication_attempts.sent_at <> excluded.sent_at;
 select failures into attempts from growth_internal.pin_reauthentication_attempts where user_id=auth.uid();
 if attempts>=5 then return 'otp_required'; end if;
 if p_nonce is null or p_nonce !~ '^[0-9]{6}$'
    or encode(extensions.digest(account.email || p_nonce,'sha224'),'hex') <> account.reauthentication_token then
  update growth_internal.pin_reauthentication_attempts set failures=failures+1 where user_id=auth.uid();
  if attempts>=4 then
   update auth.users set reauthentication_token='' where id=auth.uid();
   delete from auth.one_time_tokens where user_id=auth.uid() and token_type='reauthentication_token';
  end if;
  return 'otp_required';
 end if;
 update auth.users set reauthentication_token='' where id=auth.uid();
 delete from auth.one_time_tokens where user_id=auth.uid() and token_type='reauthentication_token';
 delete from auth.users where id=auth.uid();
 return 'ok';
end $$;
revoke all on function public.delete_my_account(text) from public,anon;
grant execute on function public.delete_my_account(text) to authenticated;
commit;
