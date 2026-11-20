<!-- coderabbit-ai-generated:v1 -->

# Home slideshow

The Home screen includes referral and campaign earnings slides. Tapping them opens referrals and tasks. A verified administrator editor can add up to eight PNG or JPEG slides (512 KiB each), change visibility and order, and delete uploaded slides. Administrators can download each slide as an image, including the two built-in slides. Admin changes require MFA; viewers can inspect and download slides. User Home refreshes slides approximately every 60 seconds and on app resume. While the service is unavailable, the last loaded slides remain visible; on the first failed load, bundled defaults appear.

Apply `supabase/migrations/20261120050000_home_slideshow.sql` to the intended Supabase project after earlier migrations, then distribute updated user and Windows admin builds. The migration creates two enabled defaults and does not modify campaigns or referral balances. It has not been applied by this change. Images are stored in a private table; authenticated active users read enabled slides through an RPC, and administrator operations enforce MFA and editor role on the server. Check migration history before applying.

Use a wide image around a 2.25:1 aspect ratio for best results. Uploaded images are validated on the client before display; the database checks file signature and size. The backend does not prove that uploaded content is suitable or accurate. Test actual sign-in, admin MFA, upload, download and Home refresh on Windows and Android after deployment.
