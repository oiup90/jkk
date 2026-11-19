-- Advanced member directory and reasoned account-access history.
begin;
alter table public.admin_access_audit add column reason text check (reason is null or length(reason) between 1 and 1000);

create function public.admin_list_users_v3(
 p_query text default '',p_status text default 'all',p_join_from date default null,p_join_to date default null,
 p_login_from date default null,p_login_to date default null,p_sort text default 'joined',p_desc boolean default true,
 p_offset integer default 0,p_limit integer default 50
) returns table(id uuid,email text,display_name text,created_at timestamptz,last_sign_in_at timestamptz,coins integer,blocked boolean,is_admin boolean,public_id text)
language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_admin();
 if length(coalesce(p_query,''))>100 or p_status is null or p_status not in ('all','active','blocked') or p_sort is null or p_sort not in ('joined','last_login') or p_desc is null or p_offset is null or p_offset<0 or p_limit is null or p_limit not between 1 and 100 or (p_join_from is not null and p_join_to is not null and p_join_from>p_join_to) or (p_login_from is not null and p_login_to is not null and p_login_from>p_login_to) then raise exception 'Invalid filter or page.' using errcode='P0001'; end if;
 return query select u.id,u.email::text,coalesce(u.raw_user_meta_data->>'full_name',''),u.created_at,u.last_sign_in_at,w.balance,coalesce(a.blocked,false),false,i.public_id
 from auth.users u left join growth_internal.user_identifiers i on i.user_id=u.id left join public.wallets w on w.id=u.id left join public.user_access a on a.user_id=u.id
 where not exists(select 1 from public.admin_members m where m.user_id=u.id)
 and strpos(lower(coalesce(u.email::text,'')||' '||coalesce(u.raw_user_meta_data->>'full_name','')||' '||coalesce(i.public_id,'')),lower(coalesce(p_query,'')))>0
 and (p_status='all' or coalesce(a.blocked,false)=(p_status='blocked'))
 and (p_join_from is null or u.created_at>=p_join_from::timestamp at time zone 'UTC')
 and (p_join_to is null or u.created_at<(p_join_to+1)::timestamp at time zone 'UTC')
 and (p_login_from is null or u.last_sign_in_at>=p_login_from::timestamp at time zone 'UTC')
 and (p_login_to is null or u.last_sign_in_at<(p_login_to+1)::timestamp at time zone 'UTC')
 order by case when p_sort='joined' and not p_desc then u.created_at end asc nulls last,
 case when p_sort='joined' and p_desc then u.created_at end desc nulls last,
 case when p_sort='last_login' and not p_desc then u.last_sign_in_at end asc nulls last,
 case when p_sort='last_login' and p_desc then u.last_sign_in_at end desc nulls last,u.id
 limit p_limit offset p_offset;
end $$;

-- The existing guarded operation keeps its account lock, admin protection and realtime trigger.
create function public.admin_set_blocked_with_reason(p_user_id uuid,p_blocked boolean,p_reason text default null) returns void
language plpgsql security definer set search_path='' as $$
declare prior boolean; clean text:=nullif(btrim(coalesce(p_reason,'')),'');
begin
 perform growth_internal.require_admin_editor();
 if p_user_id is null or p_blocked is null or (p_blocked and clean is null) or length(coalesce(clean,''))>1000 then raise exception 'Enter a valid reason.' using errcode='P0001'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_user_id::text,314159));
 select coalesce((select blocked from public.user_access where user_id=p_user_id),false) into prior;
 perform growth_internal.admin_set_blocked(p_user_id,p_blocked);
 if prior is distinct from p_blocked and clean is not null then
  update public.admin_access_audit set reason=clean where id=(select a.id from public.admin_access_audit a where a.target_id=p_user_id and a.actor_id=auth.uid() order by a.id desc limit 1);
 end if;
end $$;

create function public.admin_user_details_v2(p_user_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 perform growth_internal.require_admin();
 result:=public.admin_user_details(p_user_id);
 return result || jsonb_build_object(
 'campaign_count',(select count(*) from public.campaigns where "ownerId"=p_user_id),
 'submission_count',(select count(*) from public.submission_history where user_id=p_user_id),
 'wallet',(select jsonb_build_object('wallet_number',w.wallet_number,'balance',w.balance,'held_balance',w.held_balance,'available_balance',w.balance-w.held_balance,'is_active',w.is_active) from public.wallets w where w.id=p_user_id),
 'block_history',coalesce((select jsonb_agg(to_jsonb(x)) from (select a.blocked,a.reason,a.created_at,coalesce(u.email::text,'Deleted administrator') as actor from public.admin_access_audit a left join auth.users u on u.id=a.actor_id where a.target_id=p_user_id order by a.created_at desc,a.id desc limit 100) x),'[]'::jsonb));
end $$;

create function public.admin_support_tickets_for_user(p_user uuid) returns table(id uuid,user_id uuid,email text,subject text,status text,updated_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_admin();
 if p_user is null or not exists(select 1 from auth.users where auth.users.id=p_user) then raise exception 'User not found.' using errcode='P0001'; end if;
 return query select t.id,t.user_id,u.email::text,t.subject,t.status,t.updated_at from growth_internal.support_tickets t left join auth.users u on u.id=t.user_id where t.user_id=p_user order by t.updated_at desc,t.id limit 100;
end $$;
create function public.admin_wallet_for_user(p_user uuid) returns table(user_id uuid,public_id text,display_name text,wallet_number text,balance integer,held_balance integer,available_balance integer,is_active boolean)
language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_admin();
 return query select w.id,i.public_id,coalesce(nullif(btrim(u.raw_user_meta_data->>'full_name'),''),'Member'),w.wallet_number,w.balance,w.held_balance,w.balance-w.held_balance,w.is_active
 from public.wallets w join auth.users u on u.id=w.id left join growth_internal.user_identifiers i on i.user_id=w.id where w.id=p_user;
end $$;
revoke all on function public.admin_wallet_for_user(uuid) from public,anon;
grant execute on function public.admin_wallet_for_user(uuid) to authenticated;
revoke all on function public.admin_list_users_v3(text,text,date,date,date,date,text,boolean,integer,integer),public.admin_set_blocked_with_reason(uuid,boolean,text),public.admin_user_details_v2(uuid),public.admin_support_tickets_for_user(uuid) from public,anon;
grant execute on function public.admin_list_users_v3(text,text,date,date,date,date,text,boolean,integer,integer),public.admin_set_blocked_with_reason(uuid,boolean,text),public.admin_user_details_v2(uuid),public.admin_support_tickets_for_user(uuid) to authenticated;
commit;
