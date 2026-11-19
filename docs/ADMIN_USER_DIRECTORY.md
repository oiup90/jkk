<!-- coderabbit-ai-generated:v1 -->

# Administrator user directory

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:1a62e31dfd339c893aef5ff86734f8bee89ceb161a55a1e0a555cca5289783d8 -->

Apply `supabase/migrations/20261119094519_admin_user_directory.sql` after earlier migrations and distribute the updated administrator application. This migration was applied to project `stpxbshwdiupigymakfy` on 2026-11-19. Publishing code does not apply it to other projects. The new directory uses administrator MFA checks; viewers can inspect data and editors can change access and send notifications.

<!-- /coderabbit-ai-generated:v1 -->

Search matches email, name or public user ID. Filters cover access status, join dates and last sign-in dates; date ranges are inclusive UTC days. Sorting applies to the complete server-side result before pages of 50 are returned. Last sign-in is an authentication timestamp, not an online indicator. Columns can be selected within the current session; name, details and actions remain available. Administrator accounts stay out of the member list.

User details show counts of campaigns, retained submission-history attempts and referrals, and the wallet's total, held, available and active status. The wallet shortcut opens the exact selected user's wallet; support chats show only that user's latest 100 conversations; notification composition starts with that user selected and retains its existing confirmation and delivery checks. Existing campaign, submission and ledger sections show up to 100 recent entries.

Editors must provide a reason when blocking a user; a reason is optional when restoring access. Each actual change is audited with actor, date and reason. Existing history and changes made through older clients remain visible with reason unavailable when no reason was recorded. Older clients retain the existing block API, and no historical reasons are invented.

Run `flutter analyze --no-pub`, `flutter test --no-pub`, and `python3 supabase/tests/run_integration.py` against a disposable local PostgreSQL instance. Verify the live deployment and Windows app separately.
