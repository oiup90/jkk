<!-- coderabbit-ai-generated:v1 -->

# Security activity and monitoring

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:cc1ea52c13e1fc001d1c6d95dd57f14e8109af70e695d9d3b6d70c1099fe6a1e -->

Apply migrations through `20261118083123_security_activity.sql`, including `20261118083115_password_login_throttle.sql`. In Supabase Authentication → Hooks, enable **Password Verification Attempt** and select `public.hook_password_login_throttle`. If this hook is already configured for the throttle, the audit wrapper keeps the same function name and the same throttling decisions. Supabase supports one hook for this event: combine any other existing hook behavior before replacing it. Test in staging first. Applying the migration alone does not enable the hook.

<!-- /coderabbit-ai-generated:v1 -->

The hook records an account ID, timestamp and one of `password_invalid`, `password_verified`, or `password_throttled`. It records no passwords, session tokens, email addresses or IP addresses. A verified password does not guarantee a completed sign-in: Auth can still reject the request later. The records cover only attempts for existing accounts with passwords that reach this hook. Unknown accounts, other login methods, blocked accounts rejected earlier by Auth, and requests that fail before the hook are not represented. Failed writes cause the hook to fail, so monitor database capacity and Auth hook errors.

**Admin Workspace → Alerts** includes `password_failures` when an account has at least five invalid password checks in 15 minutes. The current dashboard polls alerts while open; this is an in-app signal, not an external notification or proof of abuse. Existing coin, referral and pending-submission alerts are preserved. Admins can inspect recent events through the authenticated `admin_security_activity(p_offset, p_limit)` RPC; the caller must be an active administrator with verified MFA, and each page is limited to 100. The private table and hook implementation are inaccessible to ordinary client roles. Existing admin action records remain in the Activity page.

## Retention

The migration creates an owner-only pruning function, but does not schedule a job. In the Supabase project, enable `pg_cron` and schedule the function as its database owner, after confirming your retention policy:

```sql
select cron.schedule(
  'security-password-events-retention', '17 3 * * *',
  $$select growth_internal.prune_security_password_events()$$
);
```

This removes records older than 90 days. Check `cron.job_run_details` for failures and database storage growth. Ensure the job is installed once and runs under the function owner; ordinary app roles cannot prune. Existing backups and platform logs have their own retention policies. Restrict operational access to these sensitive records.

## Operating and verification

In staging, generate invalid passwords for a disposable account and verify five failures appear in Alerts, an MFA-verified admin can read the RPC, other users cannot, and a valid password during the lockout is still rejected. Check that a different account remains usable. Confirm that the retention job and its execution history exist. Verify dashboard behavior and real Auth logs separately; local database tests use synthetic hook events.

Supabase provides [Auth audit logs](https://supabase.com/docs/guides/auth/audit-logs) and [Logs Explorer](https://supabase.com/docs/guides/observability/advanced-log-filtering) for broader authentication and gateway events. Review `auth_logs`, `auth_audit_logs` and gateway logs for activity outside this hook, such as unknown accounts and IP patterns, subject to the project's available fields and retention. Configure external alerting and delivery in your monitoring system if continuous or off-hours notifications are required; this change does not create an external alert destination. Avoid recording secrets or untrusted forwarding headers.