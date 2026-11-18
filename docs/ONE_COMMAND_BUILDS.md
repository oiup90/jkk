<!-- coderabbit-ai-generated:v1 -->

# Visual Studio: ഓരോ app-നും ഒരു build command

## ആദ്യം ഒരിക്കൽ തയ്യാറാക്കുക

Windows 10/11 PC-യിൽ Flutter **3.47.9**, JDK 21, Android Studio/Android SDK, Visual Studio-യിലെ **Desktop development with C++** workload എന്നിവ install ചെയ്യുക. Flutter `bin` PATH-ൽ ഉണ്ടായിരിക്കണം. Android SDK licenses സ്വീകരിച്ചിട്ടുണ്ടാകണം. വിശദമായ installation steps: [Visual Studio build guide](VISUAL_STUDIO_BUILD_GUIDE.md).

Project-ന്റെ ഏറ്റവും പുതിയ files ഉൾപ്പെടുന്ന `jkk` folder Visual Studio-യിൽ **File → Open → Folder** വഴി തുറക്കുക. **View → Terminal** തുറന്ന് PowerShell-ൽ `pubspec.yaml` ഉള്ള project root-ൽ നിൽക്കുക.

User APK-ക്ക് ഒരു തവണ ഈ files ശരിയായ സ്ഥലത്ത് വയ്ക്കുക:

- `android/key.properties`: നിങ്ങളുടെ സുരക്ഷിതമായി സൂക്ഷിച്ച signing configuration. `storeFile` പഴയ release keystore-ന്റെ ശരിയായ absolute path ആയിരിക്കണം; `storePassword`, `keyAlias`, `keyPassword` പഴയതുതന്നെ ആയിരിക്കണം. Windows path-ൽ `/` ഉപയോഗിക്കാം. Keystore-ഉം passwords-ഉം GitHub-ൽ ഇടരുത്.
- `android/app/google-services.json`: `space.freelan.app`-ന് രജിസ്റ്റർ ചെയ്ത Firebase file. Repository-ൽ നിലവിലെ file ഉണ്ട്; നിങ്ങളുടെ Firebase project-ന് അനുയോജ്യമാണെന്ന് ഉറപ്പാക്കുക.
- `config/production.json`: repository-യിൽ ഉള്ള Supabase public URL/key. ഇത് compile ചെയ്യാതിരുന്നതാണ് മുമ്പത്തെ “Supabase is not configured” screen-ന്റെ കാരണം.

Repository-യിലെ പുതിയ `android/app/build.gradle.kts` ഉപയോഗിക്കുക. ഇത് signing, Firebase, Supabase configuration പരിശോധിക്കുന്നു; നിങ്ങളുടെ പഴയ saved Gradle file മാറ്റിവെക്കാം. `key.properties` അല്ലെങ്കിൽ keystore script മാറ്റുകയോ സൃഷ്ടിക്കുകയോ ചെയ്യില്ല.

## 1. User APK build

```powershell
.\build-user-apk.cmd
```

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:dd23c0e4cc4f94e54fdb601dbaa63f760316c52422d26c1a28a8ff67642bd7a2 -->

Locked dependencies എടുത്ത് Dart obfuscation ഉപയോഗിച്ച് signed release APK build ചെയ്യും. ഓരോ build-നും `release-symbols/`-ൽ വ്യത്യസ്ത folder സൃഷ്ടിച്ച് അതിന്റെ path കാണിക്കും. ആ folder സ്വകാര്യമായി APK-യോടൊപ്പം backup ചെയ്യുക; crash stack trace വായിക്കാൻ അതേ build-ന്റെ symbols ആവശ്യമാണ്. വിജയിച്ചാൽ:

<!-- /coderabbit-ai-generated:v1 -->

```text
build\app\outputs\flutter-apk\app-release.apk
```

Default version `pubspec.yaml`-ൽ നിന്നാണ് (ഇപ്പോൾ `1.1.9+17`). Update വിതരണം ചെയ്യുമ്പോൾ ഇതിനകം വിതരണം ചെയ്ത എല്ലാ version codes-നേക്കാളും വലിയ number വേണം. ഉദാഹരണത്തിന് 17 ഇതിനകം ഉപയോഗിച്ചിട്ടുണ്ടെങ്കിൽ:

```powershell
.\build-user-apk.cmd -BuildNumber 18 -BuildName 1.2.0
```

ഇത് ഒരു universal APK ആണ്. അതേ signing key ഉപയോഗിച്ചിട്ടുണ്ടെന്ന് `apksigner` ഉപയോഗിച്ച് പരിശോധിച്ച് ഫോണിൽ install ചെയ്ത ശേഷം admin release form-ൽ യഥാർത്ഥ version name/code നൽകി publish ചെയ്യുക. Publish ചെയ്യൽ build command സ്വയം ചെയ്യുന്നില്ല. ഒരു build പരാജയപ്പെട്ടാൽ പഴയ `app-release.apk` folder-ൽ ശേഷിച്ചേക്കാം; വിജയിച്ച run-ന്റെ output മാത്രം ഉപയോഗിക്കുക.

## 2. Admin Windows application build

```powershell
.\build-admin-windows.cmd
```

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:2a15316282b457c4ff1b0c187c0ff8ae609bd460b9925ba6cb4a406c387161b9 -->

വിജയിച്ചാൽ executable `build\windows\x64\runner\Release\freelan_space_admin.exe`-ലും share ചെയ്യാനുള്ള മുഴുവൻ files അടങ്ങിയ ZIP `build\freelan-space-admin-windows.zip`-ലും ലഭിക്കും. EXE മാത്രം copy ചെയ്യരുത്; ZIP മുഴുവൻ extract ചെയ്ത് EXE തുറക്കുക. ആദ്യ login-ൽ project URL, public key എന്നിവ നൽകണം.

<!-- /coderabbit-ai-generated:v1 -->

Build കഴിഞ്ഞ് ഇതേ PC-യിൽ admin app തുറക്കാനും വേണമെങ്കിൽ:

```powershell
.\build-admin-windows.cmd -Run
```

## പ്രശ്നം വന്നാൽ

Command failure-ൽ നിർത്തുകയും error കാണിക്കുകയും ചെയ്യും. Flutter, JDK, SDK അല്ലെങ്കിൽ Visual Studio tools സംബന്ധിച്ച പ്രശ്നങ്ങൾക്ക് `flutter doctor -v` പരിശോധിക്കുക. Signing error വന്നാൽ `android/key.properties`-ലുള്ള keystore path, alias, passwords പരിശോധിക്കുക. Internet, Android SDK licenses, C++ workload എന്നിവ build machine-ൽ ആവശ്യമാണ്; commands ഇവ install ചെയ്യില്ല. മുൻ build files delete ചെയ്യുന്നില്ല, അതിനാൽ success message ഇല്ലെങ്കിൽ പഴയ output ഉപയോഗിക്കരുത്.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:21bbd27e648c426bd468326e3531b7389ddec7c9f6e3ce053fdb99f625b467d7 -->

Cloud sandbox-ൽ PowerShell scripts-ന്റെ success/failure tests pass ആയി. Temporary test key ഉപയോഗിച്ച Android release build വിജയിച്ചു; APK signature, package, version, Supabase configuration എന്നിവ പരിശോധിച്ചു. Windows native build, നിങ്ങളുടെ യഥാർത്ഥ signing key, ഫോൺ installation എന്നിവ നിങ്ങളുടെ PC-യിൽ പരിശോധിക്കണം.

<!-- /coderabbit-ai-generated:v1 -->
