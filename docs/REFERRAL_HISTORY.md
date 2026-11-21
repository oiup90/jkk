<!-- coderabbit-ai-generated:v1 -->

# Referral History

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:a7843fed99dd4e91596e27cb074d61a17c20b8b360045d80022dc3512b067896 -->

Apply `supabase/migrations/20261121045956_referral_history.sql` before distributing the updated user app. This migration was applied to project `stpxbshwdiupigymakfy` on 2026-11-21. The new RPC returns referral history only for the active caller, with masked names and emails and no account identifiers. It includes people who used the caller's code and the person whose code the caller used. Masking happens in PostgreSQL; missing names or emails are not inferred from other data.

<!-- /coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:58307c828aba01204ff6bbd588f762b32dc6f21e45bf870a39e294f48c1c0bac -->

The Profile pages use the existing referral code, share link, rewards, and PIN confirmation flow. The [Free Plan](CAMPAIGN_PLAN.md) defines creation limits.

<!-- /coderabbit-ai-generated:v1 -->
