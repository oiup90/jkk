<!-- coderabbit-ai-generated:v1 -->

# Wallet payment lookup and receipts

Apply <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:55e636ff713827070501c1af3fec0b723dcf30d6c1402dc32f76e8de3434568c -->

`supabase/migrations/20261117040219_wallet_payment_receipts.sql`

<!-- /coderabbit-ai-generated:v1 --><!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:569e5d712142c9e5a3ffd81fe01ef9eab97c9a8fe22edf96f7108f6ba62c2e23 -->

 followed by `supabase/migrations/20261117040236_wallet_history_references.sql` after earlier migrations before distributing the updated user app. The app's wallet lookup and payment flow require the new RPCs. Repository files alone do not deploy migrations to Supabase.

Coin history is available in Home's wallet and displays transaction references. Existing ledger rows are backfilled without changing amounts. Registration and referral bonuses use `RG` and `RF` followed by a unique ten-digit suffix. Transfer ledger entries share the same 12-digit reference as the successful payment receipt; other coin entries use 12-digit references.

<!-- /coderabbit-ai-generated:v1 -->

An authenticated, active user can check an exact 10-digit wallet number. The response contains the recipient's display name and public user ID, never their email or authentication UUID. Lookups are limited to 20 per user per minute. The public ID binds the payment to the person shown during confirmation; a changed recipient is rejected. Accounts without a name display `Member`. A blocked recipient can be identified but cannot receive a payment.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:9714b2e658f859fd290fc968fe281671becd664e5aebb7cc4d27352dbde27ed0 -->

The server preserves the existing PIN checks, wallet locks, coin ledger and request idempotency. After `20261118130000_random_references_social.sql`, new successful and failed payment references are randomly generated 12-digit values; registration and referral bonuses retain the `RG`/`RF` prefix with random ten-digit suffixes. Previously recorded references remain unchanged. A private reservation table prevents reuse of references recorded at migration time and newly issued references, including after later deletion of the associated rows. Transfer sender/recipient ledger rows and their receipt intentionally share one reference. A failed request cannot later be used through the older transfer RPC to move coins. Existing successful transfers can still be recovered by the original request ID.

<!-- /coderabbit-ai-generated:v1 -->

The processing screen remains visible for at least five seconds and waits for the server result. Network errors and timeouts are shown as unconfirmed, never as a definite failure. The request is stored locally without the PIN so it can be retried safely with the same details after reopening. A pre-upgrade pending request that has not completed and has no recipient identity is rejected; the user can verify the recipient and start a new request.

Run `python3 supabase/tests/run_integration.py` against a disposable local PostgreSQL instance and `flutter test --no-pub test/wallet_transfer_test.dart test/wallet_balance_test.dart test/app_layout_test.dart`. These tests use synthetic users and do not deploy or exercise a live project.
