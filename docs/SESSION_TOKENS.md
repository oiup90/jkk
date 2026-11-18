<!-- coderabbit-ai-generated:v1 -->

# Session tokens

The user and administrator apps use Supabase Auth access JWTs and refresh tokens. Automatic refresh is enabled; the user session is stored through `ProtectedAuthStorage`, and administrator sessions stay in memory. Android backups are disabled. See `SECURITY_HARDENING.md` for platform-storage and Firebase SDK limitations. Signing out removes the local session; already issued access JWTs may remain usable until they expire. Server authorization and account blocking remain necessary.

## Hosted configuration

The connected Supabase tools do not expose project Auth settings, so the hosted JWT lifetime, refresh rotation and reuse settings have not been verified or modified. In [JWT settings](https://supabase.com/dashboard/project/stpxbshwdiupigymakfy/settings/jwt/legacy), check the access token expiration and set it to 3,600 seconds unless the project has a documented reason for another value. Supabase [recommends one hour for most apps](https://supabase.com/docs/guides/auth/sessions) and advises against less than five minutes.

In [session settings](https://supabase.com/dashboard/project/stpxbshwdiupigymakfy/auth/sessions), verify refresh token rotation and reuse detection are enabled, retaining the default reuse interval unless there is a documented reason to change it. Access JWT expiry does not set a fixed session lifetime: refresh tokens normally allow sessions to continue until sign-out or revocation. Supabase's fixed lifetime and inactivity limits are separate settings that may require a paid plan. Decide these limits according to the desired sign-in experience before changing them. Session restrictions are applied on refresh, so an existing access JWT can remain valid until expiry.

After configuration, use a disposable account on the actual app to verify a JWT expires at the configured time, refresh replaces the token, an invalidated refresh requires sign-in again, and logout works. Never paste or log access tokens, refresh tokens or credentials. Local tests use synthetic tokens and do not verify hosted policy or native storage.
