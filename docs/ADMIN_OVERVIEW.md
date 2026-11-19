<!-- coderabbit-ai-generated:v1 -->

# Administrator overview dashboard

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:d23c21fafcd409e8f51784452c5d939f6be175bd7fe5b3ba6c684e763c10f019 -->

Apply `supabase/migrations/20261119092019_admin_overview_dashboard.sql` after all earlier migrations before distributing the updated administrator app. This migration was applied to project `stpxbshwdiupigymakfy` on 2026-11-19. Publishing code does not apply it to other projects. The dashboard uses the existing administrator and MFA checks; both editors and viewers can see the aggregates. Existing overview fields and their meaning remain available to older clients.

<!-- /coderabbit-ai-generated:v1 -->

The four original totals include all registered accounts, active campaigns, pending submissions on active campaigns, and all positive coin ledger entries. Coins credited are app credits, not revenue. Open support chats count tickets whose status is open. Oldest pending age is calculated on the device from the oldest pending submission on an active campaign; use Refresh to update the snapshot. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:a61ca0fd3c19f3e3ee852c759c98c0dfcb67b5848ce0125e0710498593ffcc19 -->

The three Today values use the current UTC day and count new non-administrator users, campaigns created, and retained submission-history approvals. The registrations chart follows the existing daily report and counts all registered accounts.

<!-- /coderabbit-ai-generated:v1 --> Submission attempts overwritten before the history migration cannot be recovered.

The chart shows 7 or 30 UTC calendar days including today, using the existing daily report. Switch between registrations, campaigns and coin credits/debits, and hover or select a day to see its exact values. Quick actions open pending submissions, Users Supports, and Wallets Management using the existing role permissions.

Verify the migration and Windows app in the target environment. Local database tests use synthetic users and an isolated PostgreSQL database; they do not exercise production Supabase or a Windows installation.
