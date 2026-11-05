---
tags: [foldable, architecture, ios, reference]
updated: 2026-11-05
---

# Foldable Hardware Capabilities

What Apple's SDK actually exposes for foldable iPhones. API shapes were read in
the installed SDK headers / Swift interfaces (rechecked on Xcode 27.2,
`iPhoneOS27.2.sdk`). Behaviour was observed on the **iPhone Duo simulator**
(iOS 27.2) or comes from Apple's iPhone Duo guidance, as marked. **Nothing has
been run on physical hardware.**

## What the SDK provides

| API | Where | Availability |
|---|---|---|
| `UIHinge` — `status` (`UIHinge.Status`) + `angle` (`CGFloat`, **radians**) | `UIKit/UIHinge.h` | iOS/tvOS/visionOS 27.1, not watchOS |
| `UIHinge.Status`: `unknown`=0, `closed`=1, `partiallyOpen`=2, `fullyOpen`=3 | `UIKit/UIHinge.h` | 27.1 |
| `UIHingeInteraction(updateHandler:)` + `isEnabled`; `Update.hinge` is `nil` when the view leaves a hierarchy that provides hinge updates | `UIKit/UIHingeInteraction.h` | 27.1 |
| SwiftUI `DeviceHinge` (`status`, `angle: Angle`), `DeviceHingeContext`, `View.onHingeChange(isEnabled:_:)` | `SwiftUICore.swiftinterface` | `anyAppleOS 27.1` |
| Simulator device type **iPhone Duo** (`com.apple.CoreSimulator.SimDeviceType.iPhone-Duo`) | `xcrun simctl list devicetypes` | Xcode 27.1 |

The header's own caveat: *"The rate and granularity of angle updates are
system policy … don't depend on a particular update frequency or precision.
If you only need to know whether the hinge is closed, partially open, or fully
open, prefer `status` over the angle."* — hence every angle check here uses a
generous tolerance and status-only fallbacks exist.

## What it does not provide

Searched the UIKit, SwiftUI and CoreMotion headers/interfaces for
display/fold identifiers: **no public API names the inner vs the cover
display**, and no fold-specific scene/lifecycle notification exists beyond
the hinge itself. `UIWindowSceneSessionRoleExternalDisplay*` is for external
monitors, not a cover screen.

## Observed on the iPhone Duo simulator (2026-11-05)

Measured on iOS 27.2 with the real `HingeController.swift`, moving the hinge
with Device Hub's Closed, Partially Open and Open buttons. These numbers come
from a simulator, so a real device may differ.

| What | Value |
|---|---|
| Boot state | closed, 0° |
| `status` flips to `partiallyOpen` | about 80–94° opening |
| `status` drops back to `closed` | about 58–75° closing |
| `status` is `fullyOpen` | 180° (174° still reads partial) |
| Partially Open pose rests at | about 129–134° |
| Size class on opening | `compact` → `regular` around 154° |
| Size class on closing | `regular` → `compact` around 75° |
| Angle updates while moving | one every 5–25° |
| Cover viewport | 466×678 pt, safe area 84 right, 34 bottom |
| Inner viewport | 951×669 pt, safe area 84 right, 34 bottom; rotated, the game is laid out for 669×951 |
| Cover sideways | framebuffer 2034×1398, so about 678×466 pt |

So `closed` does not mean shut: the phone can be well ajar and still report it.
DO NOT OPEN therefore also fails on the angle (`FoldThresholds.openedAbove`).

**A portrait-only app with `UIRequiresFullScreen` gets a letterboxed window.**
With that key the opened viewport was 469×669, still compact, with black bands.
Scoping it to `UIRequiresFullScreen~ipad` gave the 951×669 above. The inner
display also ignores the portrait lock: Flutter logs
`Failed to change device orientation` (code 101), which is harmless.

A Game Over screen stayed intact across a fold, and all five challenges pass
against the real hinge (`integration_test/iphone_duo_challenges_test.dart`).

## Apple's guidance (documented, not verified here)

From Apple's [Prepare your app](https://developer.apple.com/iphone-duo/prepare/)
page and [Tech Talk](https://developer.apple.com/videos/play/tech-talks/111461/):

- Outer display: compact width, like other iPhones. Inner: regular width and
  height. `UISupportedInterfaceOrientations` is **not honored on the inner
  display**, so a portrait lock doesn't hold there.
- `UIRequiresFullScreen` stays honored, but the app still resizes on fold.
- Hinge data is for interactions and effects, not layout.
- An Apple DTS [forum answer](https://developer.apple.com/forums/thread/847644)
  describes a fold as a size class change, not a scene disconnect. That is a
  forum post, not documentation.
- With the iOS 27.1+ SDK, apps extend edge to edge, and iPhone Duo screenshots
  can be submitted in App Store Connect.

## Capability matrix

| Capability | On iPhone Duo (iOS ≥ 27.1) | Our support level | Notes |
|---|---|---|---|
| Fold state (closed / partial / full) | `UIHinge.status` | **official** | Normalized 1:1 into `HingeStatus` |
| Hinge angle | `UIHinge.angle` | **official**, imprecise by contract | Tolerances in `FoldThresholds`; never inferred from other sensors |
| Fold-state notifications | `UIHingeInteraction` handler | **official** | Initial state + every change |
| Inner vs external display | none names the screen; `horizontalSizeClass` is the proxy | **official** as a layout class | Split View can also change it, so it does not identify the physical screen. For THE OTHER SIDE any such switch counts |
| Display configuration transitions | size class trait change | **official** | Seen in both directions on a fold |
| Orientation | viewport | **official** (Flutter `MediaQuery`/view size) | Exposed; no challenge requires it |
| Lifecycle continuity across folds | forum answer; seen on the simulator | **simulator only** | Clock gaps clamped (`GameEngine.safeDelta`) |
| Restrictions | none found in headers (no entitlement/permission) | — | Unverified on device |
| iOS < 27.1, conventional iPhones, Android | no hinge | **unavailable** | Bridge sends nothing → `DeviceCapabilities.none` |

Four buckets, as required:

- **Officially supported**: fold status, hinge angle (coarse), change
  notifications, size class as the display configuration.
- **Reliably approximated**: orientation, and the viewport fallback for the
  display configuration when no size class arrives.
- **Needs future SDK support**: naming the physical inner/cover display, and a
  documented lifecycle guarantee across folds.
- **Unavailable**: everything on iOS < 27.1 and non-foldable devices.

## How "is this a foldable?" is decided

Never by model name. `PlatformHingeProvider` starts at
`DeviceCapabilities.none` and upgrades only when the hinge reports a
**known** status. Whether a non-foldable iPhone on 27.1 calls the handler
with `nil`, `unknown`, or not at all is unverified — all three keep it
conventional.

Related: [[Foldable Architecture]], [[Unfold Your Brain]].
