<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:93a6464458e3c8c2454a3c1b3a181270a76742fe56b4dba6e33de50793e76d98 -->

# Administrator users and submission decisions

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:7e09a161f30ca9defd3a0007aa3a5d5444e6b5c14fb2362ff43fe8898f146ffe -->

Apply `supabase/migrations/20261119074241_admin_users_and_submission_decisions.sql` after all earlier migrations, then distribute the updated Windows administrator application and user application. This migration was applied to project `stpxbshwdiupigymakfy` on 2026-11-19. Publishing code does not apply migrations to other projects.

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->

The Users directory excludes administrator accounts before search and pagination. The **Admin users** menu lists administrators and their roles. Role provisioning remains a database operation.

From **Campaigns**, open pending submissions for an active campaign, or use **Pending submissions** to search across campaigns. After inspecting evidence, an MFA-verified editor can approve or reject a submission without the campaign owner's PIN. The decision is recorded in Admin activity. Viewers can inspect evidence but cannot decide. The owner's existing PIN-protected approval remains available. Either decision path completes the submission once, removes its evidence and applies the existing reward and notification rules.

Local tests use synthetic accounts and a disposable database. Verify deployment, administrator MFA and the Windows application in the target environment.
