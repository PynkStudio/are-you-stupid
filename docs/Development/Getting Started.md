---
tags: [development, setup, troubleshooting]
updated: 2026-09-07
---

# Getting Started

## Requirements

- Flutter **3.47+** / Dart **3.13+** (built and verified on 3.47.1 / 3.13.1)
- iOS: Xcode 26+, an iOS Simulator or device
- Android: Android SDK + a device/emulator

**AI director (spec — [[Dynamic AI Director]]):** Foundation Models needs
iOS 26 / Apple Intelligence on device. Faces `swiftc -typecheck` in CI via the
iPhoneOS 26 SDK; runtime generation cannot run in a simulator, so Dart `mocks`
cover it ([[Testing and Evaluation]]). Not needed to build or test the game —
the whole feature is off and scripted by default until Phase 2+
([[Feature Flags]]).

Dependencies: `shared_preferences` (persistence), `share_plus` (share sheet),
`google_mobile_ads` + `app_tracking_transparency` (ads, see [[Monetization and
Ads]]), `in_app_purchase` (the "remove ads" purchase, same doc), `url_launcher`
(the PynkStudio links in Settings, see [[Services]]). Every one earns its
place — no dependency added speculatively ([[Game Design Pillars]]).

## Run

```bash
flutter pub get
flutter run                 # attached device
flutter run -d <device-id>  # flutter devices to list them
```

## Verify

```bash
flutter analyze   # must report zero issues
flutter test      # 63 tests across 7 suites — see [[Testing]]
```

## Build

```bash
flutter build apk --release        # verified working
flutter build ios --release        # then archive in Xcode to ship
```

### Android release signing

`android/app/build.gradle.kts` reads `android/key.properties` (gitignored,
never commit it) and signs the release build with
`android/upload-keystore.jks` (also gitignored) when both are present;
otherwise it silently falls back to the debug key, which is why a fresh
checkout still builds. To reproduce the signing setup on a new machine or
generate a fresh upload key:

```bash
cd android
keytool -genkeypair -v -keystore upload-keystore.jks -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass <password> -keypass <password>   # same password for both — see below
cat > key.properties <<EOF
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=../upload-keystore.jks
EOF
```

**The store password and key password must be identical.** `keytool` defaults
to a PKCS12 keystore, and a PKCS12 keystore with a per-entry key password
different from the store password fails at read time with `KeytoolException:
Given final block not properly padded` — a decryption error that looks like a
corrupt file but is actually just this mismatch. See [[Decision Log]].

**Back up `upload-keystore.jks` and its password somewhere durable (password
manager, encrypted backup) outside this machine.** Losing it doesn't brick the
app on Google Play (Play App Signing lets you request an upload-key reset),
but it is real friction you don't want mid-release.

---

## Troubleshooting

### iOS: `Failed to codesign … Flutter.framework/Flutter with identity -.`

Full message: *"resource fork, Finder information, or similar detritus not
allowed"*.

**This bit us once and is fixed.** Keep the project out of synced folders and it
will not come back.

**Cause.** The project used to live in `~/Documents`, with iCloud Drive
Desktop & Documents enabled. The file provider stamps `com.apple.FinderInfo` on
the framework Flutter copies into `build/ios/`, and `codesign` refuses to sign
it. Clearing the attribute does not help: the file provider re-applies it
immediately. `xcodebuild` was unaffected because it signs inside DerivedData,
outside the synced tree.

**Fix.** The project now lives in `~/My project/AYS` — outside iCloud — and
`flutter run` works normally, hot reload included (verified 2026-09-05 on an
iPhone 17 Pro simulator, iOS 26.5).

If it ever reappears, check where you are:

```bash
xattr .                                                # the project root
xattr ~/Documents                                      # com.apple.icloud.desktop?
xattr build/ios/Debug-iphonesimulator/Flutter.framework # com.apple.FinderInfo?
```

Then move the checkout to any non-synced path (iCloud, Dropbox and Google Drive
all do this) and `flutter clean`. Avoid `?` in folder names too — it is a shell
glob and makes every command quoting-sensitive.

### Android: `cmdline-tools component is missing`

`flutter doctor` flags it, but it does **not** block the build:
`flutter build apk --debug` succeeds and pulls the missing SDK pieces itself
(verified 2026-09-05, ~5 min on the first run). To silence the warning, install
the command-line tools from Android Studio (SDK Manager → SDK Tools → Android
SDK Command-line Tools), then:

```bash
flutter doctor --android-licenses
```

### Tests hang on `pumpAndSettle()`

Expected. The game screen animates every frame on purpose. Advance the clock in
fixed steps instead — see [[Testing]].
