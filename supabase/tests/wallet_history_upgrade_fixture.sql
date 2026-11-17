-- Synthetic fixture: applied only in a disposable test database before the history migration.
insert into auth.users(id) values ('90000000-0000-4000-8000-000000000101'),('90000000-0000-4000-8000-000000000102');
insert into public.wallets(id,balance) values ('90000000-0000-4000-8000-000000000101',100),('90000000-0000-4000-8000-000000000102',100);
insert into public.wallet_transfers(id,sender_id,recipient_id,recipient_wallet,request_id,amount)
  select '90000000-0000-4000-8000-000000000103','90000000-0000-4000-8000-000000000101','90000000-0000-4000-8000-000000000102',wallet_number,'90000000-0000-4000-8000-000000000104',3 from public.wallets where id='90000000-0000-4000-8000-000000000102';
insert into growth_internal.wallet_payment_results(reference_id,sender_id,request_id,recipient_wallet,recipient_name,amount,status,transfer_id)
  select nextval('growth_internal.wallet_payment_reference_seq'::regclass)::text,sender_id,request_id,recipient_wallet,'Fixture',amount,'success',id from public.wallet_transfers where id='90000000-0000-4000-8000-000000000103';
insert into public.coin_ledger(user_id,amount,reason,transfer_id) values
 ('90000000-0000-4000-8000-000000000101',10,'welcome',null),
 ('90000000-0000-4000-8000-000000000101',5,'referral',null),
 ('90000000-0000-4000-8000-000000000101',-3,'transfer_sent','90000000-0000-4000-8000-000000000103'),
 ('90000000-0000-4000-8000-000000000102',3,'transfer_received','90000000-0000-4000-8000-000000000103');
