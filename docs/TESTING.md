<!-- coderabbit-ai-generated:v1 -->

# Local database verification

From the repository root, with PostgreSQL running locally and the current database role having superuser access:

```sh
python3 supabase/tests/run_integration.py
```

Use `--socket /absolute/socket/directory --port 5432` for another local Unix socket. The runner accepts no remote host or existing destination database. It creates uniquely named disposable databases, applies all migrations in filename order, gives every test a clean schema, and drops its databases afterward. PostgreSQL client tools and Python 3 are required. Existing `anon`, `authenticated`, and `service_role` cluster roles are reused without changing their permissions; missing roles are created as NOLOGIN roles.

The local-only Auth/Storage/MFA/Vault/network fixtures simulate provider interfaces and must never be installed on Supabase. The identifier upgrade test seeds old IDs, referral relationships and balances before migration `20261111143302`, then verifies rotation, preserved balances and a single mock push wakeup. Wallet tests cover a fresh database, 120 concurrent allocations, forced collisions, immutable numbers, owner reads and denied client coin writes.

The runner executes <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:91e593aa01b39af160431cd269bc474183cf09c9d8c8712d16a663273a6011b8 -->

all 20 current-contract Python integration suites

<!-- /coderabbit-ai-generated:v1 --> and the public identifier SQL checks. Five historical suites (`integration`, `review`, `admin`, `profile`, `action_controls`) exercise earlier claim/PIN contracts and need their documented earlier schemas; they are excluded from the current-schema runner. They are not evidence of present-day app behavior.

Other repository checks:

```sh
flutter analyze --no-pub
flutter test --no-pub
node --test supabase/functions/*/*.test.mjs
```

The APK validator tests additionally require `TEST_APK`, `APKSIGNER`, `AAPT`, and a working Java runtime. Use a synthetic/debug signed APK for these local tests. Native Windows release compilation, Android installation, SMTP, push delivery, merchant checkout and real Cloudflare/R2 traffic require separate acceptance checks in their target environments.
