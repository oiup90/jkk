<!-- coderabbit-ai-generated:v1 -->

# Targeted release promotion

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:51169611206c80371ac304c621c7dc57aa11bc4e230061c068fff0bafdbdb235 -->

Apply all migrations including `20261119153201_promote_targeted_releases.sql`, and distribute the updated Windows admin app. A specific-user release is offered only to that member by the user-app release query. Admins can inspect all releases in the new admin app's release history. Older admin builds may not show targeted releases belonging to other members after this migration.

<!-- /coderabbit-ai-generated:v1 -->

In App releases, an editor with verified MFA can select **Publish to all users** on a targeted release. Confirming promotes the existing release and APK, sends notifications to the other active users, and updates the referral download link atomically. The original recipient is not notified twice. Retrying a completed promotion does not resend notifications or overwrite the referral link. An older targeted build cannot be promoted over a newer global build. Reopen or refresh release history after an uncertain response.

Targeting controls the in-app offer and notification. The existing R2 download URLs are public; it does not make the APK a private file. Android installation still validates the APK and signing key. Applying this migration and distributing the admin build are separate deployment steps; building or committing the files does not perform either.
