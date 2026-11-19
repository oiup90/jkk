<!-- coderabbit-ai-generated:v1 -->

# Admin operations

Apply `supabase/migrations/20261107120000_admin_operations.sql` after all earlier migrations and distribute the updated user and admin applications. The SQL migration is separate from pushing the repository. The existing workspace migration through `20261107110000` is required.

## Support and reports

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:066e9a7c2d36e4658bc32d0c88f04fadb467795c4e47ebee03d239f9b7853587 -->

Members can start support chats and view replies. The updated admin application shows these conversations under **Users Supports**, where editors can reply or close chats. The former Admin operations sections, including campaign reports and alert settings, are no longer in that menu. Existing records and server APIs are retained.

<!-- /coderabbit-ai-generated:v1 --> <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:9216ac734a46e33bba67e2202c2bebb73b695d1a3a8e69c4655c6f80ac3ba082 -->

<!-- coderabbit-ai-generated-section:v1:4ade141373a4b3d5a9bdc6c1483da45006b7026a2bd8eed6bc6e7fc4a7801cc9 -->

Campaign owners can decide submissions; after `20261119074241_admin_users_and_submission_decisions.sql`, MFA-verified editors can also approve or reject them independently.

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 --> These administrator actions are recorded in the activity log. Both ticket and report lists show the latest 100 records.

## Notifications, alerts and analytics

The admin notifications button checks for <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:455930cd7165e1e3878f14770f88c34925d3c302114ffc7626e2ff1a78a30304 -->

unread ticket/report events and historical coin-request events

<!-- /coderabbit-ai-generated:v1 --> and current threshold signals when opened and every 60 seconds while the dashboard is visible. Marking an event read affects only the current administrator. These are in-app notifications, not device push. The latest 100 events are shown. Editors can change the pending hours, coins credited in 24 hours and referral count in 24 hours under Alert settings. Signals require human review and are not proof of abuse. Analytics displays daily registrations, campaign creations and credited coins for the latest 30 UTC days.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:6c2182e98264c7c7cfc029ec67b853a90e4fb7ced8bee3dbd735d78486f32e8f -->

## Wallets Management and notes

Apply `supabase/migrations/20261118120000_wallets_management.sql` after every earlier migration and distribute the updated user and Windows admin apps. **Wallets Management** replaces Wallet controls and the former coin correction approval screens. Search by member name, eight-digit User ID or ten-digit wallet number; results include total, available and held coins and active status, with pages of 50 wallets.

A single editor with a verified MFA session can add coins, deduct, debit, hold, release a hold, transfer between wallets, or activate/deactivate a wallet immediately. Deduct and debit both remove coins; their separate action names are retained in the audit. This intentionally replaces the previous requirement for a second editor. Viewers retain read access. The old request/approve RPC write path is revoked; historical requests remain stored and are not silently applied. Existing admin apps must be updated to make wallet changes.

Every operation requires a reason. Wallets are locked in a consistent order. Transfers write balanced ledger entries with a shared reference; changes, actor, reason and receipt are recorded atomically. A request ID prevents duplicate execution. The admin app saves an unresolved request per project/account before sending it and restores it after restart; retry that request to resolve a lost response before starting another operation.

A hold reserves part of the existing balance without changing the total. Available coins equal total minus held coins. Release hold makes those coins available again. Deactivation blocks outgoing spending, including campaigns and older transfer clients. Incoming credits, bonuses and refunds remain recorded. Activate before deducting/debiting/transferring from an inactive wallet. Holds and activation status are enforced in PostgreSQL for all balance decreases, not just in the UI. The user wallet shows the available balance, held coins and inactive status.

Every future positive ledger entry generates a receipt notification and queues push for registered devices in the same transaction. This includes referral bonuses, transfers, admin credits, task rewards, purchases and refunds. Deploy the updated `push-delivery` Edge Function after the migration; it uses service-only `claim_push_jobs_v3` to include the amount and credit source. Android notification permission and the user's existing push opt-in are required. Actual FCM delivery must be checked on a configured Android device.

Admin notes remain limited to administrators and reference a user or campaign ID. Notes, report decisions, ticket actions, threshold changes and wallet operations are recorded in the activity log.

<!-- /coderabbit-ai-generated:v1 -->

## Administrator MFA and sessions

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:4b493f45a6d2e397111ac49acc62da65cea89166a433a36946d2e2364ab43f4e -->

Administrator business APIs require a verified authenticator factor and an `aal2` session after `20261112134353_require_admin_mfa.sql`. Password sign-in and MFA enrollment remain available before enrollment; enroll and verify a factor before opening the console. This tightens the original optional-enrollment policy. Older administrator clients cannot complete the challenge, so distribute the updated administrator app. Supabase MFA must be enabled for the project, and enrollment and recovery need a real-provider acceptance check. The app does not log or store the displayed TOTP enrollment secret.

<!-- /coderabbit-ai-generated:v1 -->

## Local verification

Run `flutter analyze` and `flutter test`. Run `python3 supabase/tests/admin_operations_integration.py DATABASE_NAME` only against a disposable database with the test bootstrap and every migration, including a test-only mock of `auth.mfa_factors`. Never install test bootstrap objects in Supabase. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:9eb7b3b6fe47220bc3e50a2f6e40ac918263a63da49238c86b1b4e5bb22c2112 -->

Run `python3 supabase/tests/run_integration.py` for isolated database creation, all migrations and current-contract suites. The tests cover direct editor operations, retired approval RPCs, concurrent idempotent retries, wallet/ledger consistency, holds, inactive wallets, receipt notifications and push jobs, support isolation, refunds and AAL enforcement. They do not replace live Supabase Auth, SMTP, FCM or Windows release verification.

<!-- /coderabbit-ai-generated:v1 -->
