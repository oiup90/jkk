begin;
-- Prevent concurrent inserts while existing campaigns receive permanent IDs.
lock table public.campaigns in share row exclusive mode;
alter table public.campaigns alter column "createdAt" set default clock_timestamp();
alter table public.campaigns add column order_id text;
update public.campaigns set order_id = growth_internal.allocate_reference('payment');
alter table public.campaigns alter column order_id set not null;
alter table public.campaigns add constraint campaigns_order_id_format check (order_id ~ '^[1-9][0-9]{11}$');
alter table public.campaigns add constraint campaigns_order_id_unique unique (order_id);
create function growth_internal.assign_campaign_order_id() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if tg_op='INSERT' then
    new.order_id := growth_internal.allocate_reference('payment');
  elsif new.order_id is distinct from old.order_id then
    raise exception 'Campaign order ID cannot be changed.';
  end if;
  return new;
end $$;
revoke all on function growth_internal.assign_campaign_order_id() from public,anon,authenticated;
create trigger campaign_order_id before insert or update of order_id on public.campaigns
for each row execute function growth_internal.assign_campaign_order_id();

-- Owners can see their own campaign immediately; other members must wait.
drop policy campaigns_read on public.campaigns;
create policy campaigns_read on public.campaigns for select to authenticated using (
  public.account_access_allowed() and
  ("ownerId"=auth.uid() or "createdAt" <= statement_timestamp()-interval '1 minute')
);

-- Lock first and check wall-clock time after acquiring the lock, so a request
-- that waits past the deadline cannot cancel a now-public campaign.
create or replace function public.cancel_campaign(p_campaign_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare c public.campaigns%rowtype;
begin
  perform growth_internal.require_active();
  select * into c from public.campaigns where id=p_campaign_id for update;
  if not found then raise exception 'Campaign not found.' using errcode='P0001'; end if;
  if c."ownerId" <> auth.uid() then raise exception 'Only the owner can cancel.' using errcode='P0001'; end if;
  if c."createdAt" + interval '1 minute' <= clock_timestamp() then
    raise exception 'The campaign cancellation period has ended.' using errcode='P0001';
  end if;
  perform growth_internal.cancel_campaign(p_campaign_id);
end $$;

create or replace function public.submit_claim(p_campaign_id uuid,p_instagram_handle text,p_mime text,p_evidence text) returns void
language plpgsql security definer set search_path='' as $$
declare c public.campaigns%rowtype;
begin
  perform growth_internal.require_active();
  select * into c from public.campaigns where id=p_campaign_id for update;
  if not found then raise exception 'Campaign not found.' using errcode='P0001'; end if;
  if c."createdAt" + interval '1 minute' > clock_timestamp() then
    raise exception 'Campaign is not yet available.' using errcode='P0001';
  end if;
  perform growth_internal.require_action_enabled(c.type);
  perform growth_internal.submit_claim(p_campaign_id,p_instagram_handle,p_mime,p_evidence);
end $$;

create or replace function public.set_task_saved(p_campaign uuid,p_saved boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
  perform growth_internal.require_active();
  if p_campaign is null or p_saved is null then raise exception 'Invalid saved task.' using errcode='P0001'; end if;
  if p_saved then
    if not exists(select 1 from public.campaigns where id=p_campaign and status='active' and "ownerId"<>auth.uid() and "createdAt" <= statement_timestamp()-interval '1 minute') then raise exception 'Task unavailable.' using errcode='P0001'; end if;
    insert into public.saved_tasks(user_id,campaign_id) values(auth.uid(),p_campaign) on conflict do nothing;
  else delete from public.saved_tasks where user_id=auth.uid() and campaign_id=p_campaign; end if;
end $$;

create or replace function public.report_campaign(p_campaign uuid,p_reason text) returns uuid
language plpgsql security definer set search_path='' as $$
declare rid uuid; reason text:=btrim(coalesce(p_reason,''));
begin
  perform growth_internal.require_active();
  if length(reason) not between 1 and 1000 or not exists(select 1 from public.campaigns c where c.id=p_campaign and c."ownerId"<>auth.uid() and c.status='active' and c."createdAt" <= statement_timestamp()-interval '1 minute') then raise exception 'Invalid report.' using errcode='P0001'; end if;
  insert into growth_internal.campaign_reports(campaign_id,reporter_id,reason) values(p_campaign,auth.uid(),reason) returning id into rid;
  insert into growth_internal.admin_events(kind,subject_id) values('campaign_report',rid); return rid;
end $$;
commit;
