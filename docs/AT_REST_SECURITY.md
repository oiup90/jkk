<!-- coderabbit-ai-generated:v1 -->

# At-rest data protection

## Existing storage

The user and administrator apps authenticate with Supabase Auth. Supabase documents that passwords are stored as salted bcrypt hashes, not reversible ciphertext: [Password security](https://supabase.com/docs/guides/auth/password-security). Do not add a separate password table or hash passwords in the client.

Supabase states that hosted customer data is encrypted at rest with AES-256: [Supabase security](https://supabase.com/security). This is provider-managed storage encryption. Wallet balances, transaction amounts and related rows are still readable to authorized SQL/API callers and appear as plaintext in logical exports; storage encryption does not replace access control or encryption of exported backups. Confirm the hosted project's backup and encryption settings with the provider. Self-hosted databases and exports need their own managed storage encryption, access controls, protected keys and recovery procedure.

## PIN hash upgrade

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:366baf935b39a10d6c270e14bd15334df55147e9085244a339602e3bb10cea54 -->

Migration `supabase/migrations/20261117081435_strengthen_pin_hashing.sql` was applied to the Freelan Space Supabase project on 2026-11-17. Apply it after all earlier migrations in other environments.

<!-- /coderabbit-ai-generated:v1 --> New or reset four-digit PINs use randomly salted bcrypt cost 12. Cost-10 legacy PINs continue to work and are upgraded only after successful verification; untouched PINs retain their previous hashes until then. Failed and locked attempts keep their hashes and existing lockout rules. The increased cost adds CPU and latency: measure it under expected load in a staging environment before deployment.

A four-digit PIN has only 10,000 possibilities, so a stolen hash remains vulnerable to offline guessing even with bcrypt. Existing server-side attempt limits protect online attempts, not stolen hashes. Password hashing does not encrypt transaction amounts or provide reversible storage.

## Verification and rollout

Run `python3 supabase/tests/run_integration.py` only against disposable local PostgreSQL. It covers the PIN upgrade, concurrent checks, existing PIN and wallet contracts. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:de02e30bab0e2740b49e8c93c5025931be12a76ff3f2f898abd0a5839b1e253c -->

Confirm a recoverable, access-controlled backup and provider encryption settings before applying the migration in another environment. Repository changes alone do not update a hosted project.

<!-- /coderabbit-ai-generated:v1 --> Preserve existing signing keys and Supabase credentials. Never put encryption keys, passwords or PINs in the repository, client, logs or test fixtures containing real data.
