<!-- coderabbit-ai-generated:v1 -->

# Free Campaign Plan

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:1c4759565526f8dae34ab575df0457a7ea24ae92cee5dd8e29c4da85944f1e93 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:411452153a639a78726a5ebf7671e83c701806c2b92f38abde3c4db2280e443c -->

Migrations `supabase/migrations/20261121114100_free_campaign_plan.sql` and `supabase/migrations/20261121114107_admin_campaign_plan.sql` were applied to project `stpxbshwdiupigymakfy` on 2026-11-21. Distribute the updated user and admin apps. The Free Plan initially permits one campaign per rolling 24 hours across all creation APIs. A cancelled campaign still counts. Recent campaigns count in the window, including campaigns created before deployment. Existing campaigns keep their task counts.

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:eea6a6cebccab402a6c4fcbee9e058cf75064434fa0ab9e483bbd076792d2b8c -->

The default base limit is 3 tasks per campaign. Having at least one successful outgoing referral adds 5 tasks per campaign. Additional referrals do not stack. Extra tasks increase capacity; standard coin charges still apply. In the admin app, open Coin Settings → Campaign Limits to change the number of campaigns, window in hours, base tasks and referral bonus. Editors can save settings; viewers can read them. The server permits 1–100 campaigns, 1–720 hours and at most 100 combined tasks. Updates apply to future creation requests immediately.

<!-- /coderabbit-ai-generated:v1 -->

The creation form uses the signed-in user's limits from the server. Older clients still use the same creation APIs and will have requests above the new limits rejected.
