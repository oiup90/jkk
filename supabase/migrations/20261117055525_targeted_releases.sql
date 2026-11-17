begin;
-- Existing releases keep their global audience. Targeted releases never change
-- the public referral download link and are only offered to their recipient.
alter table public.app_releases add column target_user_id uuid references auth.users(id) on delete cascade;
create function public.app_release_admin() returns boolean language sql stable security definer set search_path='' as $$
 select public.admin_is_admin() and coalesce(auth.jwt()->>'aal','aal1')='aal2'
 and exists(select 1 from auth.mfa_factors where user_id=auth.uid() and status='verified');
$$;
revoke all on function public.app_release_admin() from public,anon;
grant execute on function public.app_release_admin() to authenticated;
drop policy releases_read on public.app_releases;
create policy releases_read on public.app_releases for select to authenticated using(
 public.account_access_allowed() and (target_user_id is null or target_user_id=auth.uid() or public.app_release_admin())
);
create or replace function growth_internal.notify_app_update() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.notifications(user_id,kind,release_id)
 select id,'app_update',new.id from public.wallets
 where (new.target_user_id is null or id=new.target_user_id)
 and not exists(select 1 from public.user_access a where a.user_id=wallets.id and a.blocked);
 return new;
end $$;
create function public.publish_r2_app_release_scoped(
 p_user_id uuid,p_version_code bigint,p_version_name text,p_path text,
 p_sha256 text,p_size bigint,p_notes text,p_url text,p_target_user uuid default null
) returns uuid language plpgsql security definer set search_path='' as $$
declare release_id uuid;
begin
 perform pg_catalog.pg_advisory_xact_lock(89110412);
 if p_target_user is null then
  return public.publish_r2_app_release_with_referral(p_user_id,p_version_code,p_version_name,p_path,p_sha256,p_size,p_notes,p_url);
 end if;
 if not exists(select 1 from public.wallets where id=p_target_user) or exists(select 1 from public.user_access where user_id=p_target_user and blocked) then
  raise exception 'Choose an active member.';
 end if;
 if p_version_code<=coalesce((select max(version_code) from public.app_releases),0) then raise exception 'Version code must increase.'; end if;
 insert into public.app_releases(version_code,version_name,apk_path,sha256,size_bytes,notes,created_by,storage_provider,download_url,target_user_id)
 values(p_version_code,p_version_name,p_path,p_sha256,p_size,coalesce(p_notes,''),p_user_id,'r2',p_url,p_target_user) returning id into release_id;
 insert into growth_internal.admin_operations_audit(actor_id,action,subject_id) values(p_user_id,'Targeted app release published',p_target_user);
 return release_id;
end $$;
revoke all on function public.publish_r2_app_release_scoped(uuid,bigint,text,text,text,bigint,text,text,uuid) from public,anon,authenticated;
grant execute on function public.publish_r2_app_release_scoped(uuid,bigint,text,text,text,bigint,text,text,uuid) to service_role;

create table public.app_installations(
 user_id uuid primary key references auth.users(id) on delete cascade,
 version_code bigint not null check(version_code between 1 and 2100000000),
 version_reported_at timestamptz not null default now(),
 last_seen_at timestamptz not null default now()
);
alter table public.app_installations enable row level security;
revoke all on public.app_installations from public,anon,authenticated;
grant select on public.app_installations to authenticated;
create policy installation_admin_read on public.app_installations for select to authenticated using(public.app_release_admin());
create function public.report_app_version(p_version_code bigint) returns void language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_active();
 if p_version_code is null or p_version_code not between 1 and 2100000000 then raise exception 'Invalid version.'; end if;
 insert into public.app_installations(user_id,version_code) values(auth.uid(),p_version_code)
 on conflict(user_id) do update set version_code=excluded.version_code,
 version_reported_at=case when app_installations.version_code<>excluded.version_code then now() else app_installations.version_reported_at end,
 last_seen_at=now();
end $$;
revoke all on function public.report_app_version(bigint) from public,anon;
grant execute on function public.report_app_version(bigint) to authenticated;
create function public.admin_release_installations(p_release uuid,p_offset integer default 0)
returns table(user_id uuid,display_name text,email text,version_code bigint,version_reported_at timestamptz,last_seen_at timestamptz,updated boolean)
language plpgsql security definer set search_path='' as $$
declare target uuid; required_version bigint;
begin
 perform growth_internal.require_admin();
 select r.target_user_id,r.version_code into target,required_version from public.app_releases r where r.id=p_release;
 if not found then raise exception 'Release unavailable.'; end if;
 return query select u.id,coalesce(u.raw_user_meta_data->>'full_name',''),u.email::text,i.version_code,i.version_reported_at,i.last_seen_at,
 coalesce(i.version_code>=required_version,false)
 from auth.users u join public.wallets w on w.id=u.id left join public.app_installations i on i.user_id=u.id
 where (target is null or u.id=target) and not exists(select 1 from public.user_access a where a.user_id=u.id and a.blocked)
 order by i.last_seen_at desc nulls last,u.id limit 50 offset greatest(0,least(coalesce(p_offset,0),100000));
end $$;
revoke all on function public.admin_release_installations(uuid,integer) from public,anon;
grant execute on function public.admin_release_installations(uuid,integer) to authenticated;
alter publication supabase_realtime add table public.app_installations;
commit;
