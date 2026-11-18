<!-- coderabbit-ai-generated:v1 -->

# Android release build: Supabase configuration

The user app reads `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` at compile time. An APK built without valid values shows “Supabase is not configured”. Updating Supabase or the admin download URL does not change configuration already compiled into an installed APK.

## Rebuild the affected update

From the updated repository root, run in PowerShell:

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:3d15bd5e044ee395e79ec1f3eae52f4c03a466db4c86b1b6ae1099fc6a713dcf -->

<!-- coderabbit-ai-generated-section:v1:cc87953989c89bf7abbda581414e09f491e98e10cc07d3a365288c25a5efcb0d -->

```powershell
flutter pub get --enforce-lockfile
$Symbols = Join-Path (Join-Path (Get-Location) "release-symbols") ([guid]::NewGuid().ToString())
flutter build apk --release --dart-define-from-file=config/production.json --build-name=1.1.9 --build-number=17 --obfuscate "--split-debug-info=$Symbols"
if ($LASTEXITCODE -ne 0) { throw 'Build failed. Do not upload an older APK.' }
Get-Item .\build\app\outputs\flutter-apk\app-release.apk | Select-Object FullName, LastWriteTime, Length
```

<!-- /coderabbit-ai-generated:v1 -->

`config/production.json` contains only the connected Freelan Space project's public client URL and active publishable key. It contains no signing credentials or server keys. Keep Firebase's `android/app/google-services.json` and the existing `android/key.properties` / original release keystore configured as before. Do not create a replacement signing key.

The build defaults are now version1.1.9+17, above the affected1.1.8+16. If version17 has already been distributed, choose a higher unused build number. Install the newly generated APK over the existing installation and confirm the sign-in or home page appears. Existing sessions use the same Supabase project and app ID. No uninstall or user data deletion is required by this fix.

After testing, publish this exact APK through the admin release form with matching version name/code. Do not re-upload the broken build16 or a stale file left by a failed build. Publishing and production signing must use your existing release workflow.

## Other environments

For a different Supabase project, use its own JSON file with those two public keys, or explicitly pass both `--dart-define` values. Never put service-role keys, `sb_secret_` keys, Instamojo client secrets or signing passwords in Dart defines. The runtime still rejects unsafe configuration; it does not silently select a production project.

Android user release packaging now fails early if the compiled public configuration is missing, malformed or ambiguous. Debug builds can still display setup instructions. The Windows/admin entrypoint retains its interactive project setup.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:db4503ad55a231dc413c8b2319b81a777f66d82b93263bb51c1ca5a2636b2e7b -->

## Release optimization and obfuscation

Android release builds enable R8 code shrinking, optimization and obfuscation, along with resource shrinking. Flutter supplies its Android and plugin rules. Debug and profile builds are unaffected. The Flutter `--no-shrink` option disables these release optimizations for troubleshooting.

Keep `build/app/outputs/mapping/release/mapping.txt` privately for each published APK or app bundle. It is needed to decode obfuscated Android stack traces and is overwritten by later builds.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:dc8fbc8e40d7bb906be4467ee0fa10681c8afb66966030213df7a0bd8ae50668 -->

Android APK and app bundle release packaging requires Dart `--obfuscate` and `--split-debug-info` as well. Use a new directory for every build and retain its generated `.symbols` files privately with that exact APK or app bundle; use `flutter symbolize` with the matching architecture file to decode Dart stack traces. The one-command user APK build creates a unique directory under ignored `release-symbols/` and prints its path. Back it up outside the checkout before deleting the project. Debug and profile builds do not require these flags. Obfuscation makes analysis harder; it does not protect embedded secrets or prevent reverse engineering.

<!-- /coderabbit-ai-generated:v1 -->

## Verification

<!-- /coderabbit-ai-generated:v1 -->

- `flutter test --no-pub test/secure_auth_storage_test.dart test/widget_test.dart test/auth_error_test.dart`
- `flutter analyze --no-pub`
- `bash android/gradlew -p test/gradle_client_config testClientConfiguration --console=plain` (use `android\gradlew.bat` in PowerShell)
- `flutter build apk --debug --no-pub --dart-define-from-file=config/production.json`

The cloud task can compile and test configuration but does not have your original production signing key or an attached Android phone. A debug build is not an update APK for users.
