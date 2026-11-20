<!-- coderabbit-ai-generated:v1 -->

# Home slideshow

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:acf6f1bf99302fa9d6776254991d85ca7f10bddc01c956cbf1f390ce6c27d5cc -->

The Home screen includes referral and campaign earnings slides. Tapping them opens referrals and tasks. A verified administrator editor can add up to eight PNG or JPEG slides (512 KiB each), change visibility and order, and permanently delete any slide, including the built-in ones. Deleted built-in slides cannot be restored from the admin app; use Hide to remove them temporarily. Administrators can download each slide as an image, including the two built-in slides. Admin changes require MFA; viewers can inspect and download slides. User Home refreshes slides approximately every 60 seconds and on app resume. While the service is unavailable, the last loaded slides remain visible; on the first failed load, bundled defaults appear.

<!-- /coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:91a5641e8ad724e14f1bd4297bd9941b655a8d30fbda483e2bd171a940e267d0 -->

Apply `supabase/migrations/20261120121454_home_slideshow.sql` to the intended Supabase project after earlier migrations, then distribute updated user and Windows admin builds. The migration creates two enabled defaults and does not modify campaigns or referral balances. Applied to project `stpxbshwdiupigymakfy` on 2026-11-20; the local filename matches hosted migration history. Existing updated clients can use it after refreshing the page. Images are stored in a private table; authenticated active users read enabled slides through an RPC, and administrator operations enforce MFA and editor role on the server. Check migration history before applying.

<!-- /coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:0759e76a506397fdfa1d20a96fa336e9e5e6570491c3bd41f75b554dd2cd6edd -->

Apply `supabase/migrations/20261120135541_delete_any_home_slide.sql` after earlier migrations, then distribute the updated Windows admin app to delete built-in slides. This migration was applied to project `stpxbshwdiupigymakfy` on 2026-11-20. Existing admin apps can continue deleting uploaded slides.

Use a wide image around a 2.25:1 aspect ratio for best results.

<!-- /coderabbit-ai-generated:v1 --> Uploaded images are validated on the client before display; the database checks file signature and size. The backend does not prove that uploaded content is suitable or accurate. Test actual sign-in, admin MFA, upload, download and Home refresh on Windows and Android after deployment.
