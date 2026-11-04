---
tags: [foldable, development, tooling]
updated: 2026-10-30
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
| Slider 0°–180° (5° steps) | hinge angle; status derived by `FoldThresholds.statusForAngle` (< 8° closed, > 172° fully open) |
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
`DeviceCapabilities.simulated`, which is why THE OTHER SIDE is playable here
but not yet on real hardware ([[Foldable Hardware Capabilities]]).

## Trying each challenge

Foldable rounds start at level 4 and never back to back, so play a few
classic rounds. Starting states matter: CLOSE the phone between rounds to get
DO NOT OPEN; leave it OPEN for CRACK THE CODE / OPEN YOUR MIND.

Apple's **iPhone Duo** device type exists in Xcode 27.1, but creating one
needs the **iOS 27.1 simulator runtime**, which is not installed on the dev
machine (only 26.5 and 27.0; `simctl create` reports "Incompatible device").
Until it is, the native `UIHingeInteraction` path is unexercised even in
Apple's simulator — this Dart simulator is the only way to play.
