---
tags: [foldable, architecture]
updated: 2026-11-05
---

# Foldable Architecture

How [[Unfold Your Brain]] plugs into the existing engine without touching
classic behaviour. Challenges see one normalized vocabulary; whether an event
came from iOS, the [[Foldable Simulator]] or a test is invisible to them.

```
UIHingeInteraction (Swift)          SimulatedHingeProvider (debug)
  ios/Runner/Foldable/HingeController.swift      │
        │ EventChannel ays/foldable/hinge         │
  PlatformHingeProvider (lib/services/)           │
        └──────────── HingeStateProvider ─────────┘
                           │  + viewport reports (didChangeMetrics)
                 FoldableDeviceController (lib/core/foldable.dart)
                           │  FoldableEvent stream
       ┌───────────────────┼──────────────────────┐
 ChallengeGenerator   GameEngine.handleDeviceEvent   FoldableRoundTracker
 (eligibility)        → Challenge.onDeviceEvent      (host commentary)
```

## Layers (conceptual name → code)

| Brief | Code | Pure Dart? |
|---|---|---|
| `DeviceCapabilities` | `DeviceCapabilities` + `CapabilitySupport` (official / simulated / approximated / unavailable) | yes |
| `HingeStateProvider` | `HingeStateProvider`: `PlatformHingeProvider`, `SimulatedHingeProvider`, `NoHingeProvider` | interface yes; platform impl in `lib/services/foldable_bridge.dart` |
| `DisplayConfigurationProvider` | `DisplayConfigurationProvider` (viewport short side → compact/expanded): a fallback, retired as soon as the platform reports a size class | yes |
| `MotionInputProvider` | `DisplayConfigurationProvider.orientation` (viewport) — no motion sensors used | yes |
| `FoldableDeviceController` | `FoldableDeviceController` — merges both, diffs states into events, owns subscriptions | yes |
| `FoldableChallengeAdapter` | `FoldableChallenge` base + `Challenge.onDeviceEvent` | yes |

A first reading (from `unknown`) is `initialState`, never an action: the iOS
bridge's opening reading would otherwise look like the player closing the phone.

Normalized states: `HingeStatus {unknown, closed, partiallyOpen, fullyOpen}`
(1:1 with `UIHinge.Status`), `DisplayConfiguration {unknown, compact,
expanded}`, `FoldOrientation`. Events (`FoldableEventKind`): `initialState`
(synthetic, round start), `deviceOpened`, `deviceClosed`, `hingeAngleChanged`
(debounced by `angleChangeEpsilon` = 2°; partial↔full also counts),
`displayConfigurationChanged`, `deviceOrientationChanged`, `hingeUnavailable`.
`HingeNormalizer.diff` is the single place events are derived.

## Challenge specification

The existing `ChallengeTemplate` was extended, not replaced
([[Challenge System]]). The brief's fields map like this:

| Field | Where |
|---|---|
| required capabilities | `ChallengeTemplate.requires` → `DeviceRequirement.capabilities` |
| accepted approximation | `DeviceRequirement.allowApproximated` |
| initial conditions | `DeviceRequirement.initialStatus` (+ display must be known if required) |
| supported modes | solo only: templates live in `kFoldableChallengeTemplates`, appended by `soloTemplates()` in `game_screen.dart` |
| difficulty / duration | `minLevel`, `weight`; duration via `params.pace(base, floorMs: minPhysicalRound)` |
| success / failure conditions | the challenge's `onDeviceEvent` / `onTap` / `onTick` / `onTimeout` |
| thresholds | `FoldThresholds` |
| AI host reactions | `successQuip`, fail reasons, `ExpectedInteraction` → [[Unfold Your Brain]] → Host |
| fallback | status-only variants; `hingeUnavailable` → skip |

Eligibility (`ChallengeTemplate.eligibleOn`) is checked by
`ChallengeGenerator` at every pick, with the live capabilities and state
(`capabilities:` / `deviceState:` callbacks; default = conventional phone).
The generator also refuses a hardware template right after another one.

## Engine integration

- `GameEngine.deviceState` is kept current by `handleDeviceEvent`; each round
  receives it as an `initialState` event right after `onStart`.
- Device events reach the challenge only while `playing`, and **never touch
  the clock** — folding can't pause, extend or corrupt a timer.
- `GameEngine.safeDelta` clamps lifecycle/fold rendering gaps to one frame.
- Hardware visuals are pure data (`ChallengeView.device: DeviceVisual`);
  haptic ticks are a `pulse` counter the screen watches, so `lib/core` and
  `lib/challenges` stay Flutter-free ([[Rendering Pipeline]]).

## Native bridge

`HingeController.swift` (registered in `AppDelegate`) attaches a
`UIHingeInteraction` to the Flutter root view at launch (retrying while the
window appears), streams `{available, status, angle, sizeClass}` raw values,
and sends again when only the horizontal size class changes, or when a new
listener arrives. `#available(iOS 27.1, *)` keeps the 17.6
deployment target. Payload contract in the Swift file header.

## Rotation

`Info.plist` lists portrait only on iPhone, so no conventional phone can launch
sideways. The first known hinge status sets `HingeController.hasHinge`, which
makes `AppDelegate`'s `supportedInterfaceOrientationsFor` allow all but
upside down, and calls `hingeDetected` on `ays/foldable`, where
`unlockRotationWhenHingeFound` lifts Flutter's portrait lock. iPad keeps its own
list. So the interaction stays attached for the app's lifetime, and an event
channel listener only starts and stops receiving readings.

## Lifecycle and leaks

One controller per `GameScreen`; `dispose()` cancels the provider
subscription, closes both streams and disposes the provider. The screen
removes its `WidgetsBindingObserver`, engine listener and event subscription.
Tests assert no events arrive after dispose.

## Testing

`test/foldable/` — see [[Testing]] → Foldable.

Related: [[Foldable Hardware Capabilities]], [[Game Engine]].
