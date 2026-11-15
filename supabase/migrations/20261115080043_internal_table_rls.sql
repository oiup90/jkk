begin;
-- Match the existing hosted protection on fresh databases as well.
-- These private tables are accessed through guarded SECURITY DEFINER RPCs;
-- direct anon/authenticated grants stay revoked and no client policies are added.
-- Do not FORCE RLS: the existing RPC owners must retain their authorized access.
alter table growth_internal.admin_alert_settings enable row level security;
alter table growth_internal.admin_event_reads enable row level security;
alter table growth_internal.admin_events enable row level security;
alter table growth_internal.admin_notes enable row level security;
alter table growth_internal.admin_operations_audit enable row level security;
alter table growth_internal.admin_setting_audit enable row level security;
alter table growth_internal.campaign_reports enable row level security;
alter table growth_internal.coin_adjustments enable row level security;
alter table growth_internal.instagram_lookup_limits enable row level security;
alter table growth_internal.support_messages enable row level security;
alter table growth_internal.support_tickets enable row level security;
commit;
