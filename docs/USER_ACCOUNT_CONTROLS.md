<!-- coderabbit-ai-generated:v1 -->

# User account controls

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:9569c1b364a2bcbc12ef601af4fbb7318178cb27682814371115875d5aa8a7e2 -->

- Settings → Permanently delete account: confirm an Auth-issued email code (five-minute expiry, five incorrect attempts). Login access is removed and coins forfeited. Before deletion, a separate private administrator audit archive captures the remaining profile and app business data, including campaigns, submissions/evidence, photos, wallet/ledger/payment/referral history, support threads and account audit events. Passwords, PIN hashes, OTPs, sessions and push tokens are excluded. This intentionally replaces the earlier erasure-only contract. The deletion confirmation and privacy page explain retention. Administrator accounts remain managed by the project owner.

<!-- /coderabbit-ai-generated:v1 -->
- Signup → Generate strong password: generates a 20-character password with cryptographically secure randomness and the existing password policy.
- Sign in → Save login securely on this device: enabled by default. After a successful login, the last email and password are stored using operating system protected storage, scoped to the Supabase host. Tap Email to select them; the password stays masked. Forget saved login removes that saved entry. Disabling Save login removes it after the next successful login. Storage errors never fall back to plaintext preferences.
- Wallet → Add coins: displays Service coming soon. The user app no longer opens checkout from this entry point; existing payment backend and order reconciliation remain intact.

Migration `20261120130857_user_account_deletion.sql` was applied to project `stpxbshwdiupigymakfy` on 2026-11-20. It changes the purchase-order account reference from required/restricting deletion to nullable/SET NULL to support intentional account deletion while preserving payment receipts. Other purchase behavior is preserved by the integration tests. Distribute an updated user build for these UI changes. Real Android protected storage and live email/deletion have not been exercised; no real user was deleted during development.
