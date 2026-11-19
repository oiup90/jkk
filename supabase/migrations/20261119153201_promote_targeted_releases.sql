begin;

-- User-app reads must not offer another member's targeted release, even when
-- the signed-in member also has an administrator role.
drop policy releases_read on public.app_releases;
create policy releases_read on public.app_releases for select to authenticated
  using (public.account_access_allowed() and
    (target_user_id is null or target_user_id = auth.uid()));

-- Administrators still need a complete release history in the Windows app.
create function public.admin_app_release_history()
returns setof public.app_releases language plpgsql security definer set search_path = '' as $$
begin
  perform growth_internal.require_admin();
  return query select * from public.app_releases order by version_code desc limit 20;
end $$;
revoke all on function public.admin_app_release_history() from public, anon;
grant execute on function public.admin_app_release_history() to authenticated;

-- The original storage policy checked references through app_releases RLS.
-- Check all releases as an editor so scoped rows cannot become deletable.
create function public.admin_release_object_unreferenced(p_path text)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  perform growth_internal.require_admin_editor();
  return not exists(select 1 from public.app_releases where apk_path = p_path);
end $$;
revoke all on function public.admin_release_object_unreferenced(text) from public, anon;
grant execute on function public.admin_release_object_unreferenced(text) to authenticated;
drop policy release_remove_orphan on storage.objects;
create policy release_remove_orphan on storage.objects for delete to authenticated
  using (bucket_id = 'app-releases' and public.app_release_editor()
    and public.admin_release_object_unreferenced(name));

-- Promote the same artifact and build atomically. Retrying after a lost
-- response is safe and does not resend notifications or reset the link.
create function public.admin_promote_app_release(p_release uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  release public.app_releases%rowtype;
begin
  perform growth_internal.require_admin_editor();
  perform pg_catalog.pg_advisory_xact_lock(89110412);
  select * into release from public.app_releases where id = p_release for update;
  if not found then raise exception 'Release unavailable.'; end if;
  if release.target_user_id is null then return; end if;
  if release.storage_provider <> 'r2' or release.download_url is null then
    raise exception 'Targeted release has no public download URL.';
  end if;
  if exists(select 1 from public.app_releases
            where target_user_id is null and version_code > release.version_code) then
    raise exception 'A newer release is already available to everyone.';
  end if;
  update public.app_releases set target_user_id = null where id = p_release;
  insert into public.referral_download_link(singleton, url) values (true, release.download_url)
    on conflict (singleton) do update set url = excluded.url;
  insert into public.notifications(user_id, kind, release_id)
    select w.id, 'app_update', p_release from public.wallets w
    where w.id <> release.target_user_id
      and not exists(select 1 from public.user_access a where a.user_id = w.id and a.blocked);
  insert into growth_internal.admin_operations_audit(actor_id, action, subject_id)
    values (auth.uid(), 'Targeted app release published to everyone', p_release);
end $$;
revoke all on function public.admin_promote_app_release(uuid) from public, anon;
grant execute on function public.admin_promote_app_release(uuid) to authenticated;

commit;
