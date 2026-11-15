<!-- coderabbit-ai-generated:v1 -->

# Android release build: Supabase configuration

The user app reads `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` at compile time. An APK built without valid values shows “Supabase is not configured”. Updating Supabase or the admin download URL does not change configuration already compiled into an installed APK.

## Rebuild the affected update

From the updated repository root, run in PowerShell:

```powershell
flutter pub get --enforce-lockfile
flutter build apk --release --dart-define-from-file=config/production.json --build-name=1.1.9 --build-number=17
if ($LASTEXITCODE -ne 0) { throw 'Build failed. Do not upload an older APK.' }
Get-Item .\build\app\outputs\flutter-apk\app-release.apk | Select-Object FullName, LastWriteTime, Length
```

`config/production.json` contains only the connected Freelan Space project's public client URL and active publishable key. It contains no signing credentials or server keys. Keep Firebase's `android/app/google-services.json` and the existing `android/key.properties` / original release keystore configured as before. Do not create a replacement signing key.

The build defaults are now version1.1.9+17, above the affected1.1.8+16. If version17 has already been distributed, choose a higher unused build number. Install the newly generated APK over the existing installation and confirm the sign-in or home page appears. Existing sessions use the same Supabase project and app ID. No uninstall or user data deletion is required by this fix.

After testing, publish this exact APK through the admin release form with matching version name/code. Do not re-upload the broken build16 or a stale file left by a failed build. Publishing and production signing must use your existing release workflow.

## Other environments

For a different Supabase project, use its own JSON file with those two public keys, or explicitly pass both `--dart-define` values. Never put service-role keys, `sb_secret_` keys, Instamojo client secrets or signing passwords in Dart defines. The runtime still rejects unsafe configuration; it does not silently select a production project.

Android user release packaging now fails early if the compiled public configuration is missing, malformed or ambiguous. Debug builds can still display setup instructions. The Windows/admin entrypoint retains its interactive project setup.

## Verification

- `flutter test --no-pub test/secure_auth_storage_test.dart test/widget_test.dart test/auth_error_test.dart`
- `flutter analyze --no-pub`
- `bash android/gradlew -p test/gradle_client_config testClientConfiguration --console=plain` (use `android\gradlew.bat` in PowerShell)
- `flutter build apk --debug --no-pub --dart-define-from-file=config/production.json`

The cloud task can compile and test configuration but does not have your original production signing key or an attached Android phone. A debug build is not an update APK for users.
