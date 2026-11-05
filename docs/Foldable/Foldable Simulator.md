---
tags: [foldable, development, tooling]
updated: 2026-11-05
---

# Foldable Simulator

A development-only virtual hinge, so all of [[Unfold Your Brain]] can be
built and played without foldable hardware.

## Run it

```bash
flutter run --dart-define=AYS_FOLD_SIM=true
```

Works on any target (iOS Simulator, Android emulator, macOS, a normal phone).
`kFoldableSimulatorEnabled` is `kDebugMode && bool.fromEnvironment('AYS_FOLD_SIM')`,
a compile-time `false` in profile/release builds, so the panel and the
simulated provider can never reach production.

## Controls

A collapsible **FOLD SIM** panel sits at the bottom of the game screen (it
absorbs its own taps; they never count as game taps). Its header shows
angle · status · display.

| Control | Effect |
|---|---|
| Slider 0°–180° (5° steps) | hinge angle; status derived by `FoldThresholds.statusForAngle` (< 90° closed, > 175° fully open, matching Apple's simulator) |
| OPEN | 180° + expanded display |
| CLOSE | 0° + compact display |
| DISPLAY | toggles compact ↔ expanded |
| ROTATE | toggles orientation (the next real viewport change overrides it) |
| LOSE HINGE | hinge stops reporting → `hingeUnavailable` (tests the skip path) |
| RESET | 180°, expanded, portrait |

While the simulated display is **compact**, the game is squeezed into a
cover-sized column (yellow outline), so layouts get exercised at both sizes.

## How it stays honest

The simulator is just another `HingeStateProvider` (`SimulatedHingeProvider`)
plus the controller's `setDisplay` / `setOrientation`. Events flow through
the same `FoldableDeviceController` → `GameEngine.handleDeviceEvent` path as
the iOS bridge ([[Foldable Architecture]]). It reports
`DeviceCapabilities.simulated`. See [[Foldable Hardware Capabilities]] for how
the real hinge compares.

## Trying each challenge

Foldable rounds start at level 4 and never back to back, so play a few
classic rounds. Starting states matter: CLOSE the phone between rounds to get
DO NOT OPEN; leave it OPEN for CRACK THE CODE / OPEN YOUR MIND.

## Apple's iPhone Duo simulator

This panel only feeds Dart. To exercise the real `UIHingeInteraction` path, use
Apple's simulator in **Device Hub** (it replaces Simulator.app in Xcode 27), with
the iOS 27.2 runtime from `xcodebuild -downloadPlatform iOS`. Its bottom toolbar
folds and unfolds the device, and holding Option turns those buttons into a hinge
slider.

```bash
flutter test integration_test/iphone_duo_hinge_test.dart -d "AYS iPhone Duo"
```

That checks the hinge reaches Dart. To print every event while you fold by hand,
add the listening window:

```bash
flutter test integration_test/iphone_duo_hinge_test.dart -d "AYS iPhone Duo" --dart-define=AYS_WATCH_HINGE_SECONDS=60
```

To play the five challenges against the real hinge, run the test below and press
what each `[need]` and `[round]` line asks. Start the device Closed:

```bash
flutter test integration_test/iphone_duo_challenges_test.dart -d "AYS iPhone Duo"
```

`simctl io screenshot` needs `--display=1` (cover) or `--display=3` (inner) on
this device.
