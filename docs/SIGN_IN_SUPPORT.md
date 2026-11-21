<!-- coderabbit-ai-generated:v1 -->

# Sign-in support chat

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:6ae164924046f3a46053440b7a167bde6a6d6d67cb30c394d559d7cf43a8fe34 -->

Apply `supabase/migrations/20261121024204_sign_in_support.sql` after the preceding migrations before distributing the updated user app. This migration was applied to project `stpxbshwdiupigymakfy` on 2026-11-21. The administrator inbox already lists these conversations and allows editors to reply or close them; viewers have read-only access. The guest's account email, if provided, is a claim and must be verified separately before account changes.

<!-- /coderabbit-ai-generated:v1 -->

The sign-in chat uses a random device-held key stored in protected storage. It is available only on that device and can be lost when app data is cleared. A closed conversation can be followed by a new chat. Guest chats are not linked to a user account and do not generate account notifications. The app polls for replies while the conversation is open.

The public guest RPCs limit message size, creation rate across the project, and reply rate per chat. These limits do not replace provider-level abuse controls for anonymous traffic. Local database and Flutter tests use synthetic fixtures; verify the migration and end-to-end behavior on the target Supabase project and devices before release.
