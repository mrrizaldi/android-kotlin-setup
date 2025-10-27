# adrkt
Tiny CLI to make Android/Jetpack Compose development feel a bit like `flutter run`. It is not magic. It just wires Gradle + adb neatly.

## Install
Copy `adrkt.sh` into your project root (or into a directory on your PATH) and make it executable:
```bash
chmod +x adrkt.sh
# optional: ln -s /path/to/adrkt.sh ~/.local/bin/adrkt
```

Create a `.adrkt.conf` in your project root to store defaults:
```bash
MODULE=app
VARIANT=debug
PKG=com.aldi.sample
ACT=.MainActivity
```

## Quick start
From the project root (where `gradlew` lives):
```bash
./adrkt.sh run --pkg com.aldi.sample --act .MainActivity
```
This assembles, installs, restarts the activity, and tails logs.

## Commands
- `run`  
  Build + install + restart activity. Add `--watch` to rebuild on changes (needs `watchexec` or `entr`).  
  Options: `--no-log` to skip log tailing.

- `build`  
  Assemble variant, default `:app:assembleDebug`.

- `install`  
  Install variant, default `:app:installDebug`.

- `start`  
  Start the activity without force-stopping the process.

- `restart`  
  Force-stop then start the activity. Closest to Flutter's "hot restart".

- `reload`  
  Re-install the debug APK without restarting the activity. This is **not** true hot reload, but the nearest CLI equivalent.

- `logs`  
  Tail `adb logcat` filtered by your package name.

- `test:unit`  
  Run unit tests: `:app:testDebugUnitTest`.

- `test:connected`  
  Run instrumented tests: `:app:connectedDebugAndroidTest`.

- `devices`  
  List connected devices: `adb devices`.

## Global options
- `--pkg P` set app id. Omit to auto-detect from `app/build.gradle(.kts)`.
- `--act A` set activity name. Default `.MainActivity`.
- `--module M` Gradle module, default `app`.
- `--variant V` build variant, default `debug`.
- `--serial S` target a specific device id. You can also set `$ANDROID_SERIAL`.
- `--no-log` Skip logs in `run`.
- `--watch` Rebuild/install/restart on file changes. Needs `watchexec` or `entr` in PATH.
- `--gradle PATH` Path to gradle wrapper (default `./gradlew`).
- `--adb PATH` Path to adb (default `adb`).

## Mapping from Flutter
- `flutter run` → `adrkt run`
- hot reload → `adrkt reload` (approximation; true hot reload is IDE-only)
- hot restart → `adrkt restart`
- `flutter attach` → `adrkt logs`
- `flutter test` → `adrkt test:unit`
- `flutter drive` → `adrkt test:connected` (rough analogue)

## How it works
- Build/Install: calls Gradle tasks `assemble{Variant}` and `install{Variant}`.
- Start/Restart: uses `adb shell am start` with or without `-S` to stop before start.
- Logs: `adb logcat` piped with package grep. Basic, effective.
- Watch: `watchexec` or `entr` re-runs install+restart when files change.

## Requirements
- Android SDK tools in PATH (`adb`).
- Gradle wrapper `./gradlew` available.
- JDK 17 or 21 compatible with your AGP/Kotlin versions.
- For watch mode: `watchexec` or `entr` installed.

## Limitations
- No true "Apply Changes"/hot reload on the CLI. That's IDE territory.
- Activity detection is best-effort. Set `--act` in tricky setups.
- Multi-module setups may need `--module` and `--pkg` explicitly.

## Troubleshooting
- `sdkmanager` missing: add `cmdline-tools/latest/bin` to PATH.  
- Kotlin 2.0 + Compose: ensure root plugin `org.jetbrains.kotlin.plugin.compose` is applied.  
- Manifest parsing errors: make sure `<manifest ...>` has a closing `>`, remove `package="..."`.  
- `mipmap/ic_launcher` missing: add adaptive icon resources or set `android:icon="@android:drawable/sym_def_app_icon"` in manifest temporarily.
