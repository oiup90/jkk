<!-- coderabbit-ai-generated:v1 -->

# Turnstile for Android and Windows authentication

The public site key is used by `turnstile/index.html`. The app opens that page in an embedded WebView to obtain a fresh token for each password login, signup, signup-code resend and password recovery request. Supabase verifies the token. Verification-code checks and session refresh use their existing Auth flow. The challenge is disabled by default in these builds until `AUTH_CAPTCHA_ENABLED=true` is provided at build time.

## Prepare and test

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:b553e720668e4a00ce18816074cef5f24372f9ed9fc6d0853a4ec7173a87076b -->

1. Deploy `turnstile/index.html` to `https://captcha.freelan.space/` or another HTTPS hostname under your control, and add that exact hostname to the Cloudflare widget. Configuring the widget does not publish this page or create DNS. Do not replace existing production sites or DNS records without checking them first. The site key is public; never add the Cloudflare secret key to this file, the app, source control or chat.

<!-- /coderabbit-ai-generated:v1 -->
<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:81ea18b1dcbf8d8de2862cd1e0b2aebee9ccb510adce7bbd853c42bfdd4c95e8 -->

2. For a staging project and staging widget, use that widget's site key in its own copy of the HTML page. Build the updated Android and Windows apps with `--dart-define=AUTH_CAPTCHA_ENABLED=true` and, if the staging page uses a different address, `--dart-define=AUTH_CAPTCHA_PAGE=https://your-staging-host/`. The page URL must use HTTPS without a query or fragment. Preserve the existing Android Supabase config and signing options. The Windows app also requires the Microsoft WebView2 runtime. The WebView plugin is a beta release chosen for compatibility with the repository's Android Gradle version; verify its Windows and Android behavior before release.

<!-- /coderabbit-ai-generated:v1 -->
3. Test login, signup, resend, recovery, cancellation, expired challenge, network failure and existing session refresh on real Android and Windows devices. Confirm the challenge loads from the intended hostname and the correct Supabase project.
4. In the staging Supabase project, configure Cloudflare Turnstile and the secret key in Authentication → Bot and Abuse Protection. Verify token validation, including a direct Auth call without a CAPTCHA token. The temporary site key alone does not protect Auth.

## Production rollout

Publish the production page at the widget's authorized hostname, then build and distribute both apps with the CAPTCHA flag enabled. Confirm the apps and page work before enabling CAPTCHA in the production Supabase project. Enabling the project-wide setting blocks login, signup, resend and recovery from older clients that cannot send CAPTCHA tokens. Plan an app update rollout and recovery path before activation. The Windows app can connect to other Supabase projects; those projects need matching CAPTCHA configuration or builds with this option disabled.

CAPTCHA limits automated abuse but does not implement the five-attempt account lockout or per-user audit trail: those migrations depend on the paid Password Verification Attempt hook. Continue using Supabase Auth and gateway logs for monitoring.

[Supabase CAPTCHA setup](https://supabase.com/docs/guides/auth/auth-captcha) · [Cloudflare mobile integration](https://developers.cloudflare.com/turnstile/get-started/mobile-implementation/) · [Cloudflare hostname configuration](https://developers.cloudflare.com/turnstile/additional-configuration/hostname-management/)