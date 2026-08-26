# Yemen Commerce Local Build and Debug Guide

**Purpose:** This is the single operational guide for cloning the Yemen Commerce repository, configuring the public Supabase client values safely, running the customer/merchant and Creator Console Flutter apps, debugging them locally, and producing Web, Android, and iOS artifacts.

> The repository is a Flutter/Dart client system backed by Supabase. Flutter receives only the Supabase project URL and publishable/anon key at compile time. Never place a Supabase service-role key, provider API key, database password, private signing key, or private Storage credential in Flutter, JSON defines, source control, or a browser build.

## 1. What is in the repository?

The repository contains two active Flutter applications and shared Dart packages. The `flutter_app` project contains the customer and merchant experience selected by the authenticated user. The `creator_app` project is a separate owner/developer management console. `packages/commerce_core` and `packages/commerce_data` provide shared runtime configuration, typed models, and Supabase repositories. The `supabase` directory contains migrations, Edge Functions, tests, and database documentation.

| Local project | Use | Debug/build directory | Main release artifacts |
|---|---|---|---|
| `flutter_app` | Customer and merchant application | `flutter_app/` | `flutter_app/build/web`, APK/AAB under `flutter_app/build/app/outputs/`, iOS archive/IPA under `flutter_app/build/ios/` |
| `creator_app` | Creator/owner console | `creator_app/` | `creator_app/build/web`, APK/AAB under `creator_app/build/app/outputs/`, iOS archive/IPA under `creator_app/build/ios/` |
| `packages/commerce_core` | Shared core package | Package only | Not built as a standalone application |
| `packages/commerce_data` | Shared Supabase repository package | Package only | Not built as a standalone application |

Flutter’s official setup guidance covers installing the SDK and adding it to the command-line `PATH` [1]. The Web target requires the Flutter SDK and a supported browser [3]. iOS compilation and release require macOS with Xcode and Apple’s signing/developer tooling [4].

## 2. Install prerequisites on your computer

Install Git and the current Flutter **stable** channel. After installation, open a new terminal and run:

```bash
flutter --version
flutter doctor -v
```

Resolve the platform-specific warnings shown by `flutter doctor` before debugging a native target. For Web, install Chrome or use another supported browser. For Android, install Android Studio, an Android SDK, an emulator or USB-debuggable device, and accept the SDK licenses. For iOS, use a Mac with Xcode, a configured simulator or device, CocoaPods where required, and an Apple development team for signed device/release builds.

The repository’s Dart packages use Dart 3.13-compatible constraints. Use the Flutter stable release recommended by the official documentation rather than mixing an old Dart executable with a newer Flutter SDK. The helper scripts use the `flutter` executable from `PATH`; if it is installed elsewhere, set `FLUTTER_BIN` to its full path.

## 3. Clone the correct branch

The implemented AI-3 through AI-6 work is on the migration branch and must not be merged into `main` unless separately approved.

### macOS/Linux/Git Bash

```bash
git clone -b migration/flutter-supabase-foundation https://github.com/Aiman003516/yemen-commerce.git
cd yemen-commerce
git status
git branch --show-current
```

### Windows PowerShell

```powershell
git clone -b migration/flutter-supabase-foundation https://github.com/Aiman003516/yemen-commerce.git
Set-Location yemen-commerce
git status
git branch --show-current
```

The expected branch name is:

```text
migration/flutter-supabase-foundation
```

## 4. Create the local public build configuration

Copy the tracked, non-secret template and edit the local copy:

### macOS/Linux/Git Bash

```bash
cp config/flutter_defines.example.json config/flutter_defines.json
```

### Windows PowerShell

```powershell
Copy-Item config/flutter_defines.example.json config/flutter_defines.json
```

Open `config/flutter_defines.json` and replace the placeholders:

```json
{
  "SUPABASE_URL": "https://your-project-ref.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "your-public-supabase-publishable-or-anon-key",
  "SUPABASE_AUTH_REDIRECT_URL": "",
  "API_BASE_URL": ""
}
```

Use the public project URL and publishable/anon key from the Supabase project settings. `SUPABASE_AUTH_REDIRECT_URL` is optional; leave it empty for the default local Web origin or set an approved redirect URL for your environment. `API_BASE_URL` is optional for the current Flutter client and can remain empty unless a future client feature explicitly uses it.

The local file `config/flutter_defines.json` is ignored by Git. The helper scripts reject files containing strings associated with service-role keys, provider keys, private keys, or other private signing material. The public Supabase key is not a secret, but it is still environment-specific and should not be copied into issue reports or screenshots.

Dart compile-time declarations are read by `String.fromEnvironment` and must be supplied at compile time; the official Dart guidance documents this behavior and the Flutter `--dart-define` mechanism [2]. Changing this file requires a new `flutter run` or `flutter build`; it is not a runtime `.env` loader.

## 5. Use the reusable helper script

The repository includes:

```text
tools/flutter_yemen.sh
 tools/flutter_yemen.ps1
```

The Bash version works on macOS, Linux, and Git Bash/WSL on Windows. The PowerShell version is intended for Windows PowerShell or PowerShell 7. Both scripts use the same public defines file and the same app/target vocabulary.

### First-time dependency setup

```bash
tools/flutter_yemen.sh setup all
```

```powershell
.\tools\flutter_yemen.ps1 -Command setup -App all
```

### Verify the local SDK and devices

```bash
tools/flutter_yemen.sh doctor
flutter devices
```

```powershell
.\tools\flutter_yemen.ps1 -Command doctor
flutter devices
```

### Analyze and test

Run both apps:

```bash
tools/flutter_yemen.sh analyze all
tools/flutter_yemen.sh test all
```

Run one app:

```bash
tools/flutter_yemen.sh analyze customer
tools/flutter_yemen.sh test creator
```

PowerShell equivalents:

```powershell
.\tools\flutter_yemen.ps1 -Command analyze -App all
.\tools\flutter_yemen.ps1 -Command test -App all
```

These commands do not need Supabase defines because analysis and tests should not require a live authenticated session.

## 6. Run and debug locally

### Customer/merchant Web debug

```bash
tools/flutter_yemen.sh run customer web debug
```

```powershell
.\tools\flutter_yemen.ps1 -Command run -App customer -Target web -Mode debug
```

Flutter launches Chrome with hot reload. Flutter’s Web guide documents `flutter run -d chrome` for browser debugging and `flutter build web` for a release artifact [3].

### Creator Console Web debug

```bash
tools/flutter_yemen.sh run creator web debug
```

```powershell
.\tools\flutter_yemen.ps1 -Command run -App creator -Target web -Mode debug
```

### Android debug

Start an emulator or connect an Android device, confirm it appears in `flutter devices`, then run:

```bash
tools/flutter_yemen.sh run customer android debug
tools/flutter_yemen.sh run creator android debug
```

For a specific device, use Flutter directly from the selected app directory:

```bash
cd flutter_app
flutter devices
flutter run -d <device-id> --dart-define-from-file=../config/flutter_defines.json
```

The same pattern applies to `creator_app`. USB debugging, Android SDK licenses, and device authorization must be completed on the computer before Flutter can install the debug APK.

### iOS debug

On macOS with a simulator or trusted development device:

```bash
tools/flutter_yemen.sh run customer ios debug
tools/flutter_yemen.sh run creator ios debug
```

The helper maps the `ios` target to the default iOS device/simulator. If Xcode signing or provisioning is requested, open the corresponding `ios/Runner.xcworkspace`, select the Runner target, choose the Apple development team, and run again. Do not commit provisioning profiles, certificates, `.p12` files, or private keys.

## 7. Build artifacts for distribution or QA

The helper intentionally separates `run` from `build`. `run` is for an interactive debug/profile session; `build` creates an artifact.

| Goal | Command | Output |
|---|---|---|
| Customer Web release | `tools/flutter_yemen.sh build customer web release` | `flutter_app/build/web/` |
| Creator Web release | `tools/flutter_yemen.sh build creator web release` | `creator_app/build/web/` |
| Customer Android APK | `tools/flutter_yemen.sh build customer apk release` | `flutter_app/build/app/outputs/flutter-apk/app-release.apk` |
| Creator Android APK | `tools/flutter_yemen.sh build creator apk release` | `creator_app/build/app/outputs/flutter-apk/app-release.apk` |
| Customer Android App Bundle | `tools/flutter_yemen.sh build customer appbundle release` | `flutter_app/build/app/outputs/bundle/release/app-release.aab` |
| Creator Android App Bundle | `tools/flutter_yemen.sh build creator appbundle release` | `creator_app/build/app/outputs/bundle/release/app-release.aab` |
| Customer iOS IPA | `tools/flutter_yemen.sh build customer ios release` | `flutter_app/build/ios/ipa/*.ipa` when signing/export succeeds |
| Creator iOS IPA | `tools/flutter_yemen.sh build creator ios release` | `creator_app/build/ios/ipa/*.ipa` when signing/export succeeds |

PowerShell example:

```powershell
.\tools\flutter_yemen.ps1 -Command build -App customer -Target web -Mode release
.\tools\flutter_yemen.ps1 -Command build -App customer -Target appbundle -Mode release
.\tools\flutter_yemen.ps1 -Command build -App creator -Target apk -Mode release
```

For profile builds used for performance inspection:

```bash
tools/flutter_yemen.sh build customer web profile
tools/flutter_yemen.sh run customer web profile
```

Do not use a profile build as the store artifact. Use `release` for distribution after the platform signing and environment review are complete.

## 8. Native signing boundaries

The helper can invoke release commands, but it does not create or manage signing credentials. This is deliberate.

For Android Play Store release, configure the keystore and Gradle signing values on the build machine or in a secret-managed CI system. Keep `key.properties`, keystore files, passwords, and upload keys outside Git; the repository ignore rules already exclude common signing-file extensions. A debug APK can be built without a production keystore, but a production-signed APK/AAB requires the Android signing configuration to be completed in the local Android project.

For iOS distribution, a Mac with Xcode, an Apple Developer account, a registered Bundle ID, certificates/profiles, and App Store Connect configuration are required. The official Flutter iOS release guide covers the Xcode archive and IPA flow [4]. Those credentials belong in Xcode/CI secret management, not in `config/flutter_defines.json` or Dart source.

## 9. Supabase environment and migration expectations

The apps connect to the Supabase project named by the public URL/key in the local defines file. The branch already contains the database migrations and Edge Function source for the Yemen Commerce AI roadmap. Pulling the repository does not copy database data to the computer; it copies source code and migration files. Supabase Auth users, Postgres data, Storage objects, RLS policies, and deployed Edge Functions remain in the configured Supabase project.

For a new Supabase environment, apply the committed migrations in order through the approved Supabase migration workflow and deploy the reviewed Edge Functions separately. Do not paste a service-role key into Flutter or run production migrations casually from a developer laptop. The Creator Console and merchant/customer apps depend on Supabase Auth and database authority, so a local app with an empty or different project will correctly show missing data or authorization errors.

AI provider calls, background workers, managed knowledge retrieval, and external-agent/MCP access remain disabled by default. Local UI and contract tests do not imply that those production gates are enabled.

## 10. Debugging checklist

When an app shows an unconfigured Supabase message, verify that the command was run through the helper or that `--dart-define-from-file` points to the correct absolute file. Inspect the file for `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`, but never print the key into a log.

When `flutter run` cannot find a device, run `flutter doctor -v`, `flutter devices`, start the emulator or simulator, and check USB authorization. When Web hot reload is stale, stop the process and run the command again; a compile-time define change always needs a fresh process.

When a Creator page returns an authorization error, confirm that the signed-in account is the creator or an explicitly delegated operator with the required capability. Do not work around an RLS/RPC denial by using a service-role key in the app. When merchant data is empty, confirm the signed-in merchant owns an approved shop in the same Supabase project.

When Android release builds fail, inspect Gradle/JDK/SDK diagnostics and signing configuration. When iOS builds fail, open the workspace in Xcode and inspect the selected team, Bundle ID, provisioning, deployment target, and CocoaPods state. When Web release builds fail, run `flutter clean`, `flutter pub get`, `flutter analyze`, and then rebuild; serve the complete `build/web` directory rather than a single generated file.

## 11. Useful direct commands

The helpers cover the normal workflow, but these direct commands are useful when debugging a single project:

```bash
cd flutter_app
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --dart-define-from-file=../config/flutter_defines.json
flutter build web --release --dart-define-from-file=../config/flutter_defines.json
```

```bash
cd creator_app
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --dart-define-from-file=../config/flutter_defines.json
flutter build web --release --dart-define-from-file=../config/flutter_defines.json
```

For verbose Flutter logs, append `-v` to the Flutter command. For browser performance work, use a profile build and browser DevTools; the official Web guide recommends profile builds for performance analysis [3].

## References

[1]: https://docs.flutter.dev/install "Flutter documentation — Install Flutter"
[2]: https://dart.dev/libraries/core/environment-declarations "Dart documentation — Compilation environment declarations"
[3]: https://docs.flutter.dev/platform-integration/web/building "Flutter documentation — Building a web application with Flutter"
[4]: https://docs.flutter.dev/deployment/ios "Flutter documentation — Build and release an iOS app"
