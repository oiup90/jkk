<!-- coderabbit-ai-generated:v1 -->

# Instamojo coin purchases

## Initial plans

| Coins | Price (INR) |
| --- | --- |
| 100 | ₹49 |
| 300 | ₹129 |
| 1,000 | ₹399 |

Plans are stored in `public.coin_purchase_plans`. Existing orders retain their original price and coin quantity after plan changes.

## Merchant activation

Use an approved Instamojo merchant account and its v2 application credentials. In Supabase Dashboard → Edge Functions → Secrets, set:

- `INSTAMOJO_CLIENT_ID`
- `INSTAMOJO_CLIENT_SECRET`

Never put these values in Flutter defines, source files, screenshots or chat. Standard Supabase URL/anon/service environment variables are provided by the Edge runtime. Deploy `coin-purchase` with JWT verification enabled. Missing merchant configuration fails closed; having the Supabase connection does not supply Instamojo credentials.

## User flow

Wallet → Buy coins → choose server plan → Instamojo opens in the browser. After paying, return to the purchase page. The app checks pending payments on resume and provides Check payment. Saved pending orders are available after reopening the page. When needed, Open checkout first checks whether the order is already paid.

There is no payment webhook in this version. If the app stays closed, credit waits until the user returns and checks the payment. The user must not pay again merely because verification is temporarily unavailable. Up to 100 oldest pending orders are shown; credited entries disappear on refresh, revealing further pending orders. Coin history records successful purchases.

## Verification and data integrity

The server generates a single-use Instamojo payment request from an immutable order snapshot. It verifies the request ID, order purpose, amount, payment's associated request, INR currency and boolean successful status through Instamojo's API. Client status, amounts and redirect parameters never authorize credits.

Only the service role can attach a checkout or credit an order. Credit locks the order, preserves the existing blocked-account guard, updates the wallet and adds one unique purchase ledger entry in one transaction. Provider payment IDs and purchase ledger order IDs are unique. Repeated verification does not add coins twice. This intentionally adds the `purchase` ledger reason; existing wallet write permissions remain unchanged.

Concurrent creation reuses a reservation for ten minutes; only its creator calls the provider. Failed, unexposed requests remain in audit history. A lost request can safely be retried; an already attached checkout is recovered from saved orders. Orders are rate limited to ten new attempts per user per hour.

## Validation

- `node --test supabase/functions/coin-purchase/*.test.mjs`
- In an isolated PostgreSQL database with repo bootstrap/base/owner_review/admin_access/wallet number/purchase/notification migrations: `python3 supabase/tests/coin_purchase_integration.py <database>`
- `flutter test --no-pub test/coin_purchase_test.dart test/wallet_balance_test.dart test/app_layout_test.dart test/user_features_test.dart`
- `flutter analyze --no-pub`

Mocks and database fixtures do not verify merchant onboarding, live checkout or settlement. Complete a merchant-authorized payment on an installed build before enabling purchases for users. No production payment or coin credit was performed during implementation.

## Official API references

- [Application authentication](https://docs.instamojo.com/reference/generate-access-token-application-based-authentication)
- [Create payment request](https://docs.instamojo.com/reference/create-a-payment-request-1)
- [Retrieve payment request](https://docs.instamojo.com/reference/get-a-payment-request-1)
- [Retrieve payment details](https://docs.instamojo.com/reference/get-payment-details-1)
