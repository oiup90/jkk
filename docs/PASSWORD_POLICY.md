<!-- coderabbit-ai-generated:v1 -->

# Password policy

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:bed45dbd8d98ee718ebe58867ce7862aa9abaa0cc62d786d44c8c9c8100c5659 -->

The app requires new passwords for signup and user or administrator recovery to have at least 12 Unicode code points, at most 72 UTF-8 bytes, an uppercase ASCII letter, a lowercase ASCII letter, a digit and a Supabase-supported symbol. Existing passwords are not checked by the app during sign-in. Passwords are not trimmed or modified. Supabase Auth v2.197.0 measures its length limits in UTF-8 bytes, so configuring a minimum of 12 on the server does not enforce 12 Unicode code points against a direct client; this stronger app rule can be bypassed.

<!-- /coderabbit-ai-generated:v1 -->

## Hosted enforcement required

Client checks can be bypassed. The linked Supabase connection does not expose Auth configuration, so the server settings have not been read or changed. Before relying on this policy, open [Email provider settings](https://supabase.com/dashboard/project/stpxbshwdiupigymakfy/auth/providers?provider=Email) and set minimum password length to 12 and required characters to digits, lowercase and uppercase letters, and symbols. Save the configuration. Supabase documents these settings and the allowed symbols in its [password security guide](https://supabase.com/docs/guides/auth/password-security).

After saving, verify with disposable accounts that direct Auth signup and password recovery reject passwords missing each requirement, accept a compliant password, and allow an existing weak password to sign in. Test both app recovery flows, the deployed Auth configuration and enabled identity providers before release. Do not use real credentials as test fixtures. Leaked-password protection is a separate Supabase feature and is not verified or enabled by this change.
