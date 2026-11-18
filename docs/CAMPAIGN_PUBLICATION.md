<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:960fe63b02a4a7b34bd91e7b932dec2cc139d540fa190e4e143bd40373ca7a1a -->

# Campaign publication and order IDs

Apply `20261118192155_campaign_publication_orders.sql` after all earlier migrations and distribute the updated user app. The migration assigns a random unique 12-digit order ID to every existing campaign and allocates one to every new campaign. IDs are reserved permanently, including after deletion. The existing UUID remains the internal key.

A campaign is visible to its owner immediately and to other signed-in members after one minute. Submitting, saving and reporting it are also unavailable before then. The updated task list refreshes periodically, so a newly available campaign may appear up to about ten seconds after the minute. Older clients may need to reload their task list after the minute.

Owners may cancel only within the first minute. The server checks the deadline after acquiring the campaign lock; after it expires, even older clients cannot cancel. Existing campaigns older than a minute are affected immediately after migration. Early cancellation still refunds the unused reserved coins at the campaign's saved rate. Administrator handling of reported campaigns remains available.

The owner screen displays the order ID and offers filters by action and status. The cancellation button uses the device clock as a display hint; the server clock decides whether cancellation is accepted. Avoid deploying the migration without distributing the updated app, since older versions cannot show the order ID or the updated deadline.

Run `python3 supabase/tests/run_integration.py` against a disposable local PostgreSQL instance and `flutter test --no-pub test/campaign_publication_test.dart test/user_page_redesign_test.dart test/task_preview_test.dart test/economy_ui_test.dart`. Local tests use synthetic users and do not apply the migration to a live project.


<!-- /coderabbit-ai-generated:v1 -->