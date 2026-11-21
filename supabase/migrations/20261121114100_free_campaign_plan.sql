begin;

create index campaigns_owner_created_idx on public.campaigns ("ownerId", "createdAt" desc);

create function public.campaign_plan_limits() returns jsonb
language plpgsql security definer set search_path='' as $$
declare caller uuid := auth.uid(); latest timestamptz; max_tasks integer;
begin
  -- Same per-account lock used by all campaign creation entry points.
  perform growth_internal.require_active();
  select c."createdAt" into latest from public.campaigns c
    where c."ownerId"=caller order by c."createdAt" desc limit 1;
  max_tasks := case when exists(
    select 1 from growth_internal.referrals r where r.referrer_id=caller
  ) then 8 else 3 end;
  return jsonb_build_object('max_tasks', max_tasks,
    'next_campaign_at', latest + interval '24 hours');
end $$;

revoke all on function public.campaign_plan_limits() from public,anon;
grant execute on function public.campaign_plan_limits() to authenticated;

create or replace function growth_internal.create_campaign(p_type text, p_link text, p_count integer) returns uuid
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); clean text; path text; campaign uuid; available integer; reward integer; limits jsonb;
begin
  if uid is null then raise exception 'Please sign in.' using errcode = 'P0001'; end if;
  if p_type is null or p_type not in ('follow','like','comment','share') then raise exception 'Choose a task type.' using errcode = 'P0001'; end if;
  if p_count is null or p_count < 1 or p_count > 100 then raise exception 'Task count must be between 1 and 100.' using errcode = 'P0001'; end if;
  if p_link is null or length(p_link) > 500 then raise exception 'Invalid Instagram link.' using errcode = 'P0001'; end if;
  clean := regexp_replace(trim(p_link), '[?#].*$', '');
  if clean !~* '^https://(www\.)?instagram\.com/' then raise exception 'Invalid Instagram link.' using errcode = 'P0001'; end if;
  path := regexp_replace(clean, '^https://(www\.)?instagram\.com/', '', 'i');
  path := regexp_replace(path, '/+$', '');
  if p_type = 'follow' then
    if path !~ '^[A-Za-z0-9._]{1,30}$' or lower(path) in ('p','reel','reels','stories','explore','accounts') then raise exception 'Invalid Instagram link.' using errcode = 'P0001'; end if;
  else
    if path !~ '^(p|reel)/[A-Za-z0-9_-]+$' then raise exception 'Invalid Instagram link.' using errcode = 'P0001'; end if;
  end if;
  limits := public.campaign_plan_limits();
  if p_count > (limits->>'max_tasks')::integer then
    raise exception 'Task count exceeds your campaign plan limit.' using errcode='P0C02';
  end if;
  if (limits->>'next_campaign_at')::timestamptz > clock_timestamp() then
    raise exception 'Free Plan allows one campaign every 24 hours.' using errcode='P0C01';
  end if;
  select amount into reward from public.coin_settings where key=p_type;
  select balance into available from public.wallets where id = uid for update;
  if not found then raise exception 'Initialize your account first.' using errcode = 'P0001'; end if;
  if available < p_count*reward then raise exception 'Not enough coins.' using errcode = 'P0001'; end if;
  update public.wallets set balance = balance - p_count*reward where id = uid;
  insert into public.campaigns("ownerId",type,link,requested,remaining,status,reward_per_task)
    values (uid,p_type,'https://www.instagram.com/' || path || '/',p_count,p_count,'active',reward) returning id into campaign;
  insert into public.coin_ledger(user_id, amount, reason, campaign_id) values (uid, -p_count*reward, 'campaign', campaign);
  return campaign;
end $$;

commit;
