begin;
create table growth_internal.campaign_plan_settings (
  singleton boolean primary key default true check (singleton),
  campaign_count integer not null check (campaign_count between 1 and 100),
  window_hours integer not null check (window_hours between 1 and 720),
  base_tasks integer not null check (base_tasks between 1 and 100),
  referral_bonus integer not null check (referral_bonus between 0 and 99),
  check (base_tasks + referral_bonus <= 100)
);
insert into growth_internal.campaign_plan_settings values (true,1,24,3,5);
alter table growth_internal.campaign_plan_settings enable row level security;
revoke all on growth_internal.campaign_plan_settings from public,anon,authenticated;

create function public.admin_campaign_plan() returns jsonb language plpgsql security definer set search_path='' as $$
declare settings growth_internal.campaign_plan_settings%rowtype;
begin
 perform growth_internal.require_admin();
 select * into strict settings from growth_internal.campaign_plan_settings where singleton;
 return jsonb_build_object('campaign_count',settings.campaign_count,'window_hours',settings.window_hours,'base_tasks',settings.base_tasks,'referral_bonus',settings.referral_bonus);
end $$;

create function public.admin_set_campaign_plan(p_campaign_count integer,p_window_hours integer,p_base_tasks integer,p_referral_bonus integer)
returns void language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_admin_editor();
 if p_campaign_count is null or p_campaign_count not between 1 and 100
 or p_window_hours is null or p_window_hours not between 1 and 720
 or p_base_tasks is null or p_base_tasks not between 1 and 100
 or p_referral_bonus is null or p_referral_bonus not between 0 and 99
 or p_base_tasks + p_referral_bonus > 100 then
   raise exception 'Invalid campaign plan settings.' using errcode='P0001';
 end if;
 update growth_internal.campaign_plan_settings
 set campaign_count=p_campaign_count,window_hours=p_window_hours,base_tasks=p_base_tasks,referral_bonus=p_referral_bonus
 where singleton;
 if not found then raise exception 'Campaign plan unavailable.' using errcode='P0001'; end if;
 insert into growth_internal.admin_operations_audit(actor_id,action,details)
 values(auth.uid(),'Campaign plan updated',jsonb_build_object('campaign_count',p_campaign_count,'window_hours',p_window_hours,'base_tasks',p_base_tasks,'referral_bonus',p_referral_bonus)::text);
end $$;

create or replace function public.campaign_plan_limits() returns jsonb
language plpgsql security definer set search_path='' as $$
declare caller uuid := auth.uid(); threshold timestamptz; settings growth_internal.campaign_plan_settings%rowtype; max_tasks integer;
begin
 perform growth_internal.require_active();
 select * into strict settings from growth_internal.campaign_plan_settings where singleton for share;
 select c."createdAt" into threshold from public.campaigns c
   where c."ownerId"=caller order by c."createdAt" desc,c.id
   offset settings.campaign_count-1 limit 1;
 max_tasks := settings.base_tasks + case when exists(
   select 1 from growth_internal.referrals r where r.referrer_id=caller
 ) then settings.referral_bonus else 0 end;
 return jsonb_build_object('max_tasks',max_tasks,
   'next_campaign_at',case when threshold + make_interval(hours=>settings.window_hours) > clock_timestamp()
     then threshold + make_interval(hours=>settings.window_hours) else null end,
   'campaign_count',settings.campaign_count,'window_hours',settings.window_hours,
   'base_tasks',settings.base_tasks,'referral_bonus',settings.referral_bonus);
end $$;

revoke all on function public.admin_campaign_plan(),public.admin_set_campaign_plan(integer,integer,integer,integer) from public,anon;
grant execute on function public.admin_campaign_plan(),public.admin_set_campaign_plan(integer,integer,integer,integer) to authenticated;
commit;
