-- Extend the existing administrator overview without changing its four metrics.
begin;
create index submission_history_approved_reviewed_idx
  on public.submission_history (reviewed_at) where status='approved';
create or replace function public.admin_workspace_overview() returns jsonb
language plpgsql security definer set search_path='' as $$
declare today_start timestamptz := (date_trunc('day', statement_timestamp() at time zone 'UTC') at time zone 'UTC');
begin
 perform growth_internal.require_admin();
 return jsonb_build_object(
  'users',(select count(*) from auth.users),
  'active_campaigns',(select count(*) from public.campaigns where status='active'),
  'pending_submissions',(select count(*) from public.campaign_claims cl join public.campaigns c on c.id=cl.campaign_id where cl.status='pending' and c.status='active'),
  'coins_credited',(select coalesce(sum(amount),0) from public.coin_ledger where amount>0),
  'open_support_chats',(select count(*) from growth_internal.support_tickets where status='open'),
  'oldest_pending_at',(select min(cl.created_at) from public.campaign_claims cl join public.campaigns c on c.id=cl.campaign_id where cl.status='pending' and c.status='active'),
  'today_users',(select count(*) from auth.users u where u.created_at>=today_start and u.created_at<today_start+interval '1 day' and not exists(select 1 from public.admin_members m where m.user_id=u.id)),
  'today_campaigns',(select count(*) from public.campaigns where "createdAt">=today_start and "createdAt"<today_start+interval '1 day'),
  'today_approved',(select count(*) from public.submission_history where status='approved' and reviewed_at>=today_start and reviewed_at<today_start+interval '1 day')
 );
end $$;
commit;
