-- Synthetic pre-upgrade data, only in the runner's newly created local database.
insert into auth.users(id) values
 ('92000000-0000-4000-8000-000000000001'),
 ('92000000-0000-4000-8000-000000000002');
select set_config('request.jwt.claim.sub','92000000-0000-4000-8000-000000000001',false);
select public.initialize_wallet();
select public.referral_info();
select set_config('request.jwt.claim.sub','92000000-0000-4000-8000-000000000002',false);
select public.initialize_wallet();
select public.referral_info();
select public.apply_referral((select code from growth_internal.referral_codes
 where user_id='92000000-0000-4000-8000-000000000001'));
create table public.test_identifier_before as
 select user_id,public_id,code from growth_internal.user_identifiers
 join growth_internal.referral_codes using(user_id);
create table public.test_wallet_before as select id,balance from public.wallets;
-- Mock network wakeups locally; these schemas/functions never reach Supabase.
create schema vault;
create table vault.decrypted_secrets(name text,decrypted_secret text);
insert into vault.decrypted_secrets values ('push_delivery_url','https://synthetic.example.test'),
 ('push_anon_jwt','synthetic'),('push_worker_secret','synthetic');
create schema net;
create table public.test_wakeups(id bigint generated always as identity);
create function net.http_post(url text,headers jsonb,body jsonb,timeout_milliseconds integer)
 returns bigint language sql as $$
 insert into public.test_wakeups default values returning id;
$$;
