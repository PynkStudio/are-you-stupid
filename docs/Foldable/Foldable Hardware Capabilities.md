---
tags: [foldable, architecture, ios, reference]
updated: 2026-11-04
---

# Foldable Hardware Capabilities

What Apple's SDK actually exposes for foldable iPhones. API shapes were read in
the installed SDK headers / Swift interfaces (rechecked 2026-11-04 on Xcode 27.2,
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

## Observed on the iPhone Duo simulator (2026-11-04)

`integration_test/iphone_duo_hinge_test.dart`, run inside the simulator against
the real `HingeController.swift`:

- The hinge reaches Dart: `closed, 0°, compact`, capabilities upgraded to
  `platform`. The device boots closed.
- The closed viewport is **466×678 pt**. The inner screen is 2007×2853 px at
  scale 3 (669×951 pt, from `simctl io enumerate`), not yet seen as a viewport.
- Both displays are close to the same shape (aspect 1.45 and 1.42), so aspect
  ratio cannot tell them apart. See [[Decision Log]].

**Not yet observed:** any fold or unfold. Moving the hinge needs Device Hub, and
the session had no access to it. Until a run covers that, the angle while
moving, size class changes and state surviving a fold are all unverified.

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
| Inner vs external display | none names the screen; `horizontalSizeClass` is the proxy | **approximated** | The bridge sends the size class, which Split View can also change, so it is a layout class and not a screen identity. Judged only by templates that opt in — none do today |
| Display configuration transitions | size class trait change | **approximated** until seen on a fold | Promote to official once a fold run confirms it; THE OTHER SIDE then leaves the simulator |
| Orientation | viewport | **official** (Flutter `MediaQuery`/view size) | Exposed; no challenge requires it |
| Lifecycle continuity across folds | forum answer only | **unverified** | Clock gaps clamped (`GameEngine.safeDelta`) |
| Restrictions | none found in headers (no entitlement/permission) | — | Unverified on device |
| iOS < 27.1, conventional iPhones, Android | no hinge | **unavailable** | Bridge sends nothing → `DeviceCapabilities.none` |

Four buckets, as required:

- **Officially supported**: fold status, hinge angle (coarse), change
  notifications.
- **Reliably approximated**: orientation. *Display configuration* is
  approximated through the size class and **not yet trusted for judging**.
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
