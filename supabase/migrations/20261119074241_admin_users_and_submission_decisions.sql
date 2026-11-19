-- Separate administrators from the member directory and allow editors to decide submissions.
begin;
create or replace function public.admin_list_users_v2(p_query text default '',p_offset integer default 0,p_limit integer default 50)
returns table (id uuid,email text,display_name text,created_at timestamptz,last_sign_in_at timestamptz,coins integer,blocked boolean,is_admin boolean,public_id text)
language plpgsql security definer set search_path='' as $$
begin
  perform growth_internal.require_admin();
  if p_offset is null or p_offset < 0 or p_limit is null or p_limit < 1 or p_limit > 100 or length(coalesce(p_query,'')) > 100 then
    raise exception 'Invalid search or page.' using errcode='P0001';
  end if;
  return query select u.id,u.email::text,coalesce(u.raw_user_meta_data->>'full_name',''),u.created_at,u.last_sign_in_at,w.balance,
    coalesce(a.blocked,false),exists(select 1 from public.admin_members m where m.user_id=u.id),i.public_id
    from auth.users u left join growth_internal.user_identifiers i on i.user_id=u.id left join public.wallets w on w.id=u.id left join public.user_access a on a.user_id=u.id
    where not exists(select 1 from public.admin_members m where m.user_id=u.id)
      and pg_catalog.strpos(pg_catalog.lower(coalesce(u.email::text,'') || ' ' || coalesce(u.raw_user_meta_data->>'full_name','') || ' ' || coalesce(i.public_id,'')),pg_catalog.lower(coalesce(p_query,''))) > 0
    order by u.created_at desc,u.id limit p_limit offset p_offset;
end $$;


create function growth_internal.perform_review_claim(p_campaign_id uuid, p_user_id uuid, p_submission_id uuid, p_approve boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); c public.campaigns%rowtype; cl public.campaign_claims%rowtype;
begin
  if uid is null then raise exception 'Please sign in.' using errcode = 'P0001'; end if;
  if p_approve is null then raise exception 'Choose approve or reject.' using errcode = 'P0001'; end if;
  select * into c from public.campaigns where id=p_campaign_id for update;
  if not found then raise exception 'Campaign not found.' using errcode = 'P0001'; end if;
  if c.status <> 'active' or c.remaining <= 0 then raise exception 'Campaign is no longer active.' using errcode = 'P0001'; end if;
  select * into cl from public.campaign_claims where campaign_id=p_campaign_id and user_id=p_user_id for update;
  if not found or cl.status <> 'pending' or p_submission_id is null or cl.submission_id <> p_submission_id then raise exception 'This submission is no longer pending.' using errcode = 'P0001'; end if;
  if not exists(select 1 from public.claim_evidence where campaign_id=p_campaign_id and user_id=p_user_id) then raise exception 'Evidence is unavailable.' using errcode = 'P0001'; end if;
  if p_approve then
    update public.wallets set balance=balance+c.reward_per_task where id=p_user_id;
    if not found then raise exception 'Participant account is unavailable.' using errcode = 'P0001'; end if;
    update public.campaign_claims set status='approved',reviewed_at=now() where campaign_id=p_campaign_id and user_id=p_user_id;
    update public.campaigns set remaining=c.remaining-1, status=case when c.remaining=1 then 'completed' else 'active' end where id=p_campaign_id;
    insert into public.coin_ledger(user_id,amount,reason,campaign_id) values(p_user_id,c.reward_per_task,'task',p_campaign_id);
  else
    update public.campaign_claims set status='rejected',reviewed_at=now() where campaign_id=p_campaign_id and user_id=p_user_id;
  end if;
  delete from public.claim_evidence where campaign_id=p_campaign_id and user_id=p_user_id;
end $$;

revoke all on function growth_internal.perform_review_claim(uuid,uuid,uuid,boolean) from public,anon,authenticated;

-- Preserve the owner-only check on every existing user RPC.
create or replace function growth_internal.review_claim(p_campaign_id uuid,p_user_id uuid,p_submission_id uuid,p_approve boolean) returns void
language plpgsql security definer set search_path='' as $$
declare c public.campaigns%rowtype;
begin
 select * into c from public.campaigns where id=p_campaign_id for update;
 if not found then raise exception 'Campaign not found.' using errcode='P0001'; end if;
 if c."ownerId" is distinct from auth.uid() then raise exception 'Only the campaign owner can review.' using errcode='P0001'; end if;
 perform growth_internal.perform_review_claim(p_campaign_id,p_user_id,p_submission_id,p_approve);
end $$;

-- The owner's existing PIN-protected path is preserved. Admin decisions use the
-- same locked economy operation and never require the owner's credentials.
create function public.admin_decide_submission(p_campaign_id uuid,p_user_id uuid,p_submission_id uuid,p_approve boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_admin_editor();
 perform growth_internal.perform_review_claim(p_campaign_id,p_user_id,p_submission_id,p_approve);
 insert into growth_internal.admin_operations_audit(actor_id,action,subject_id,details)
 values(auth.uid(),case when p_approve then 'Submission approved' else 'Submission rejected' end,p_campaign_id,concat('Participant ',p_user_id,' / submission ',p_submission_id));
end $$;
revoke all on function public.admin_decide_submission(uuid,uuid,uuid,boolean) from public,anon;
grant execute on function public.admin_decide_submission(uuid,uuid,uuid,boolean) to authenticated;
commit;
