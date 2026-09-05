---
tags: [architecture, challenges]
updated: 2026-09-05
---

# Challenge System

`lib/core/challenge.dart` + `lib/challenges/`

## The contract

```dart
abstract class Challenge {
  String get id;                  // template id, used for stats and dedupe
  ChallengeTag get tag;           // color, word, patience, counting, memory,
                                  // reaction, perception, trick
  Duration get duration;          // round length
  ChallengeView get view;         // current frame, pure data

  void onStart(ChallengeHost host) {}
  void onTick(Duration elapsed, ChallengeHost host) {}
  void onTap(TapInfo tap, ChallengeHost host);
  void onTimeout(ChallengeHost host) => host.fail(reason: 'TOO SLOW.');
}
```

A `Challenge` instance lives for exactly one round. It is built by a
`ChallengeTemplate` from `ChallengeParams { level, rng, speed }`.

## ChallengeView

Pure data, no widgets:

- `instruction` — under 8 words, uppercase on screen
- `layout` — `grid2x2 | grid3 | row | single | none | free`
- `targets` — `TargetSpec(id, label, color, shape, scale, rotation, dx, dy,
  opacity, hidden)`
- `hint`, `bigCenterText`, `tapCounter`
- `blackout` — hides the play area (memory challenges)
- `showTimer`, `pressure` (0..1 visual stress)

## Input model

Everything is judged on **pointer down** (`TapKind.down`). The game must feel
instant; waiting for the release adds perceptible lag. `TapKind.up` exists only
for hold-style challenges.

`TapInfo` carries `targetId` (null = background), `index` (visual position, used
by "TAP LEFT" after the buttons swap) and `elapsed`.

## Base classes

`lib/challenges/base.dart`:

- `BaseChallenge` — mutable fields + `view` assembly + `mutateTarget()`
- `TapTargetChallenge` — "tap the right one", with `correctIds`
- `PatienceChallenge` — passes on timeout, fails on any touch

Plus helpers: `honestColorTargets`, `mixedColorTargets`, `numberTargets`,
`wordTargets`.

## Registry

`lib/challenges/registry.dart` holds `kChallengeTemplates`:

```dart
ChallengeTemplate(
  id: 'tap_color',
  tag: ChallengeTag.color,
  build: buildTapColor,
  minLevel: 1,     // never appears earlier
  weight: 1.4,     // relative pick probability
  starter: true,   // usable in levels 1-3
)
```

See [[Adding a Challenge]] and the full list in [[Challenge Catalog]].

## Selection

`ChallengeGenerator`:
1. filters by `minLevel` (and `starter` for levels 1–3),
2. drops the last 4 played ids so nothing repeats back to back,
3. picks by `weight`.

Rules covered by tests in [[Testing]].
