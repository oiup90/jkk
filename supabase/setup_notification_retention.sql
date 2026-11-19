-- Run as the same database owner that applied the migration, after enabling
-- pg_cron. Re-running under that owner updates the existing named schedule.
select cron.schedule(
  'freelan-user-notification-retention',
  '* * * * *',
  'select growth_internal.purge_expired_user_notifications()'
);
