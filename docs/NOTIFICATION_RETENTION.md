<!-- coderabbit-ai-generated:v1 -->

# User notification retention

Apply all prior migrations followed by <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:64e259e02f6eb079c0f4c83e38a4991ee8e835accf2b15f4c80a71ccd6a955de -->

`20261119133853_notification_retention.sql`

<!-- /coderabbit-ai-generated:v1 --> to the intended Supabase project. Notifications shown in the user app, whether read or unread, are permanently removed from `public.notifications` once they are at least 72 hours old. Existing notifications are included. Push-only records are outside this inbox retention rule. Deleting an inbox record also cascades to its push jobs, so undelivered pushes for that record stop retrying; wallet, campaign, support and admin audit data are unaffected.

The migration schedules the cleanup every minute if `pg_cron` is already enabled. Otherwise, enable Supabase Cron and run `supabase/setup_notification_retention.sql` as the database owner that applied the migration. Re-running that script as the same owner updates the named schedule. Confirm that exactly one active `freelan-user-notification-retention` job exists and inspect `cron.job_run_details` for successful runs. A failed or delayed scheduler means cleanup is delayed; expiry is checked at the next successful run, normally within a minute. The migration and schedule must be deployed to the target project; repository changes alone do not activate deletion.

This removes records from the live database, not from database backups or notifications already delivered to Android's system tray. Users may need to reopen the inbox to refresh a cached list if a realtime delete was missed.

Verify against a disposable PostgreSQL database with all migrations using `python3 supabase/tests/notification_retention_integration.py DATABASE_NAME`. Separately verify the scheduled job on an isolated pg_cron-enabled instance and monitor its first run in the target environment.
