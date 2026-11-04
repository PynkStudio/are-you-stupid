---
tags: [foldable, architecture, ios, reference]
updated: 2026-10-30
---

# Foldable Hardware Capabilities

What Apple's SDK actually exposes for foldable iPhones, verified on
2026-10-30 against the **locally installed iOS 27.1 SDK** (Xcode 27.1,
build 27A9275, `iPhoneOS27.1.sdk`). No API below is assumed; each was read in
the SDK headers / Swift interfaces. Nothing has been run on physical hardware.

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

## Capability matrix

| Capability | On iPhone Duo (iOS ≥ 27.1) | Our support level | Notes |
|---|---|---|---|
| Fold state (closed / partial / full) | `UIHinge.status` | **official** | Normalized 1:1 into `HingeStatus` |
| Hinge angle | `UIHinge.angle` | **official**, imprecise by contract | Tolerances in `FoldThresholds`; never inferred from other sensors |
| Fold-state notifications | `UIHingeInteraction` handler | **official** | Initial state + every change |
| Inner vs external display | none | **approximated** | Viewport shape (`DisplayConfigurationProvider`): long/short ≤ 1.5 → expanded. Judged only by templates that opt in — none do today |
| Display configuration transitions | none dedicated | **approximated** | Flutter metrics changes (`didChangeMetrics`) |
| Orientation | viewport | **official** (Flutter `MediaQuery`/view size) | Exposed; no challenge requires it |
| Lifecycle continuity across folds | undocumented | **unverified** | Clock gaps clamped (`GameEngine.safeDelta`) |
| Restrictions | none found in headers (no entitlement/permission) | — | Unverified on device |
| iOS < 27.1, conventional iPhones, Android | no hinge | **unavailable** | Bridge sends nothing → `DeviceCapabilities.none` |

Four buckets, as required:

- **Officially supported**: fold status, hinge angle (coarse), change
  notifications.
- **Reliably approximated**: orientation. *Display configuration* is
  approximated but **not yet trusted for judging**.
- **Needs future SDK support**: inner/cover display identification and
  fold-aware lifecycle guarantees.
- **Unavailable**: everything on iOS < 27.1 and non-foldable devices.

## How "is this a foldable?" is decided

Never by model name. `PlatformHingeProvider` starts at
`DeviceCapabilities.none` and upgrades only when the hinge reports a
**known** status. Whether a non-foldable iPhone on 27.1 calls the handler
with `nil`, `unknown`, or not at all is unverified — all three keep it
conventional.

Related: [[Foldable Architecture]], [[Unfold Your Brain]].
