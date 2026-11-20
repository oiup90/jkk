begin;
create table growth_internal.deleted_account_archives (
 id uuid primary key default gen_random_uuid(), user_id uuid not null,
 email text, display_name text, deleted_at timestamptz not null default clock_timestamp(),
 snapshot jsonb not null
);
alter table growth_internal.deleted_account_archives enable row level security;
revoke all on growth_internal.deleted_account_archives from public,anon,authenticated,service_role;
create index deleted_accounts_date on growth_internal.deleted_account_archives(deleted_at desc,id);

create function growth_internal.archive_deleted_account() returns trigger
language plpgsql security definer set search_path='' as $$
declare snapshot jsonb; section jsonb; relation text; campaign_ids text[]; ticket_ids text[]; transfer_ids text[];
 relations constant text[] := array[
 'public.wallets','public.instagram_accounts','public.campaigns','public.campaign_claims','public.claim_evidence',
 'public.submission_history','public.saved_tasks','public.coin_ledger','public.coin_purchase_orders','public.wallet_transfers',
 'public.notifications','public.user_access','public.account_block_status','public.admin_access_audit','public.app_installations','public.app_releases',
 'growth_internal.profile_photos','growth_internal.user_identifiers','growth_internal.referral_codes','growth_internal.legacy_referral_codes',
 'growth_internal.referrals','growth_internal.referral_milestones','growth_internal.support_tickets','growth_internal.support_messages',
 'growth_internal.campaign_reports','growth_internal.admin_notes','growth_internal.admin_events','growth_internal.admin_operations_audit',
 'growth_internal.admin_review_audit','growth_internal.coin_adjustments','growth_internal.wallet_operations','growth_internal.wallet_payment_results',
 'growth_internal.security_password_events'];
begin
 -- Capture only business records from a reviewed allowlist. Never copy Auth
 -- secrets, PIN hashes, OTP proofs, push tokens or user-controlled Auth metadata.
 snapshot := jsonb_build_object('schema_version',1,'account',jsonb_build_object(
   'id',old.id,'email',old.email,'phone',old.phone,'created_at',old.created_at,
   'email_confirmed_at',old.email_confirmed_at,'last_sign_in_at',old.last_sign_in_at,
   'display_name',old.raw_user_meta_data->>'full_name'));
 -- Freeze business writes until capture and cascading deletion commit together.
 foreach relation in array relations loop execute format('lock table %s in share row exclusive mode',relation); end loop;
 select coalesce(array_agg(id::text),'{}') into campaign_ids from public.campaigns where "ownerId"=old.id;
 select coalesce(array_agg(id::text),'{}') into ticket_ids from growth_internal.support_tickets where user_id=old.id;
 select coalesce(array_agg(id::text),'{}') into transfer_ids from public.wallet_transfers where sender_id=old.id or recipient_id=old.id;
 foreach relation in array relations loop
   execute format($q$select coalesce(jsonb_agg(j),'[]') from (select to_jsonb(t) j from %s t) rows
    where exists(select 1 from jsonb_each_text(j) e where e.key = any(array[
      'user_id','ownerId','sender_id','recipient_id','referrer_id','referred_id','actor_id','target_id','subject_id','author_id','reporter_id','admin_id','target_user_id']) and e.value=$1)
     or ($5='public.wallets' and j->>'id'=$1)
     or j->>'campaign_id'=any($2) or j->>'subject_id'=any($2)
     or j->>'ticket_id'=any($3) or j->>'transfer_id'=any($4)$q$,relation)
     into section using old.id::text,campaign_ids,ticket_ids,transfer_ids,relation;
   snapshot := snapshot || jsonb_build_object(relation,section);
 end loop;
 insert into growth_internal.deleted_account_archives(user_id,email,display_name,snapshot)
 values(old.id,old.email,old.raw_user_meta_data->>'full_name',snapshot);
 return old;
end $$;
revoke all on function growth_internal.archive_deleted_account() from public,anon,authenticated,service_role;
create trigger archive_before_account_deletion before delete on auth.users
 for each row execute function growth_internal.archive_deleted_account();

create function public.admin_deleted_accounts(p_query text default '',p_offset integer default 0)
returns table(id uuid,user_id uuid,email text,display_name text,deleted_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_admin();
 if p_offset is null or p_offset<0 or p_query is null or length(p_query)>200 then raise exception 'Invalid search'; end if;
 return query select a.id,a.user_id,a.email,a.display_name,a.deleted_at from growth_internal.deleted_account_archives a
 where p_query='' or a.email ilike '%'||p_query||'%' or a.display_name ilike '%'||p_query||'%' or a.user_id::text=p_query
 order by a.deleted_at desc,a.id limit 50 offset p_offset;
end $$;
create function public.admin_deleted_account_snapshot(p_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 perform growth_internal.require_admin();
 select jsonb_build_object('archive_id',a.id,'deleted_at',a.deleted_at,'data',a.snapshot) into result
 from growth_internal.deleted_account_archives a where id=p_id;
 if result is null then raise exception 'Archive not found'; end if;
 insert into growth_internal.admin_operations_audit(actor_id,action,subject_id) values(auth.uid(),'Deleted account archive viewed/exported',p_id);
 return result;
end $$;
revoke all on function public.admin_deleted_accounts(text,integer),public.admin_deleted_account_snapshot(uuid) from public,anon;
grant execute on function public.admin_deleted_accounts(text,integer),public.admin_deleted_account_snapshot(uuid) to authenticated;
commit;
