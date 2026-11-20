begin;
-- Allow editors to remove the original referral and earnings slides as well
-- as uploaded images. Keep existing MFA, locking, and audit protections.
create or replace function public.admin_delete_home_slide(p_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_admin_editor();
 perform pg_advisory_xact_lock(hashtext('freelan_home_slides'));
 delete from growth_internal.home_slides where id=p_id;
 if not found then raise exception 'Slide cannot be deleted' using errcode='P0001'; end if;
 insert into growth_internal.admin_operations_audit(actor_id,action) values (auth.uid(),'Home slide deleted');
end $$;
revoke all on function public.admin_delete_home_slide(uuid) from public, anon;
grant execute on function public.admin_delete_home_slide(uuid) to authenticated;
commit;
