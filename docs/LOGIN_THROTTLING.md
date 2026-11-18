<!-- coderabbit-ai-generated:v1 -->

# Password login throttling

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:12c0b94d63504fda25c828a16ff7c8b53340fa8f6e36bb6d0ec3aef1ab65849b -->

Apply `20261118083115_password_login_throttle.sql`, then in Supabase Authentication → Hooks enable **Password Verification Attempt** and select the Postgres function `public.hook_password_login_throttle`. Applying the migration alone does not enable the hook. Test the configuration in a staging project before enabling it for production, including both Android and administrator sign-in. Check for an existing password verification hook before replacing it: Supabase allows one hook per event and existing behavior would need to be combined. Disable the hook in the dashboard to roll back enforcement.

<!-- /coderabbit-ai-generated:v1 -->

For each existing password account, five incorrect passwords within 15 minutes prevent password sign-in for 15 minutes from the fifth failure. A successful password before the limit clears the failure count. Expired windows start again. Requests from different devices share the same account limit, and existing sessions are not revoked. The response remains the generic invalid-credentials response, matching unknown accounts, so a locked user should wait 15 minutes and retry. An attacker can intentionally cause a temporary account lockout; monitor Auth logs and support requests.

The hook runs **after** Supabase has verified the password, so it does not reduce password hashing work. It only runs for existing accounts with passwords, and it does not limit unknown account names, signups, password recovery, other APIs, or requests by IP. Supabase Auth has separate rate limits for certain Auth endpoints; check the project’s [Auth rate limits](https://supabase.com/docs/guides/auth/rate-limits). If IP-based limits for password sign-in or broad API traffic are required, enforce them at a trusted gateway or WAF that covers every route to Supabase; do not trust client-provided forwarding headers. A client-side delay or an optional proxy cannot prevent direct calls to Auth.

The database tests exercise the hook with synthetic events. They do not verify hosted hook configuration, actual Supabase Auth responses, or provider-level IP limits. After enabling the hook, verify with a disposable account that five incorrect passwords lead to a rejected correct password, that login works after expiry, and that another account is unaffected. Never load-test production without approval. See the [Supabase hook documentation](https://supabase.com/docs/guides/auth/auth-hooks/password-verification-hook).