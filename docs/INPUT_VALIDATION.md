<!-- coderabbit-ai-generated:v1 -->

# Input validation

Campaign creation validates Instagram links in the Flutter form and in the existing database RPC. Accepted post/reel links may include query strings or fragments; the database stores a canonical link without them. When opening a campaign or profile link, the app accepts only those same Instagram link shapes and opens their canonical form. Historical links with other shapes will no longer open through this action.

The profile name migration validates new or changed `auth.users` metadata. The optional name may be absent or null; a supplied name must be a string with 1–80 characters after trimming. The server bounds raw input and stores the trimmed value. Existing invalid names remain usable for unrelated account updates, but must meet the new rule when changed. This also applies to names supplied by external Auth providers, so verify any enabled provider against the rule before deployment.

Names and support messages are plain text, not HTML. Flutter displays them as text; any future HTML consumer must escape them for its output context. SQL injection protection depends on parameterized queries, bound values and safe identifier quoting, not on removing punctuation or HTML from user text. Existing RPC validation and authorization remain required for requests that bypass the app.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:d6d6b4fac7824e40b1f509fe362a20d51a2c51364336d9395b2ce989eb79182a -->

Migration `supabase/migrations/20261118070739_validate_profile_name.sql` has been applied to the linked project. Test hosted Auth signup, sign-in, metadata update and any enabled identity providers before releasing. Local tests use synthetic Auth fixtures and do not verify hosted behavior. This change does not establish that every application input has been audited.

<!-- /coderabbit-ai-generated:v1 -->
