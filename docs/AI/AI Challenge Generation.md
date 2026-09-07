---
tags: [ai, gameplay, challenges]
updated: 2026-09-07
---

# AI Challenge Generation

What the model is allowed to invent, and how it reaches the player. Read
[[AI Challenge Validator]] before this — generation rules exist to make
validation *succeed*, not as suggestions.

## ChallengeProvider = the seam

`lib/core/challenge_generator.dart` stops being the single source. Challenge
selection moves behind a **`ChallengeProvider`** interface. The engine only
knows "give me a challenge for this context". Providers decide how:

```dart
abstract class ChallengeProvider {
  // Engine face: synchronous on purpose — the game loop never awaits the
  // model. null = "nothing to offer right now"; the Fallback swallows
  // nulls and always lands on scripted ([[Pre-generation Cache]]).
  // The async prefetch/warm face lives on AppleAIService (Phase 2) and the
  // Director loop (Phase 5), composed BEHIND this interface, so _startLevel
  // is never async. See the Phase 1 [[Decision Log]] entry.
  GeneratedChallenge? next(ChallengeContext context);
  void reset();                       // forget recent-memory at start of a run
}

class ChallengeContext {
  final int level;            // current round
  final AppLocale locale;     // player language; flows in per-call
  final bool allowTricks;     // level-based, mirrors Difficulty.allowsTricks
  final int seed;             // multiplayer only; solo uses the engine's own rng
  // — joined by later phases, after the engine needs them —
  // final PlayerGameplayProfile? profile;  // Phase 3 telemetry ([[Player Telemetry and Adaptive Difficulty]])
  // final Duration timeLimitSla;           // Phase 5 prefetch budget ([[Pre-generation Cache]])
}
```

Concrete providers, always composed front→back by the Director
([[Dynamic AI Director]] → "The challenge pipeline"):

| Provider | Job |
|---|---|
| `ScriptedChallengeProvider` | The existing weighted `ChallengeGenerator` logic, unchanged. Always present. The floor. |
| `AIChallengeProvider` | Prefetches model proposals, validates, enqueues; returns `null` (never an error). |
| `FallbackChallengeProvider` | Wraps both: tries AI-cache, falls back to scripted. **Never blocks** ([[Pre-generation Cache]]). |

An `AdaptiveChallengeProvider` wraps `FallbackChallengeProvider` and biases
selections from the [[Player Telemetry and Adaptive Difficulty]] profile.
Adaptation adjusts *which* validated candidates are picked, **never** raw
numbers the validator already gated.

## `GeneratedChallenge` — the portable model

A **validated** challenge travels as plain data (Dart `GeneratedChallenge`),
mirrored by the Swift `@Generable` `ChallengeProposal` (the pre-validation
wire form). Same field contract:

```jsonc
{
  "id": "ai.za7q2",                      // "ai." + 5-char base36; unique per prefetch
  "mechanic": {                           // the controlled vocabulary, below
    "move": "tap_true_color",
    "action": "tap",                      // tap | tap_many | hold | donot_tap |
                                          // tap_sequence | tap_until_stop | color_pick
    "kind": "mixed",                      // see mechanic matrix
    "sense_decoys": ["color", "size"]
  },
  "instruction": "TAP THE ONLY BLUE",     // < 8 words, uppercase, language = locale
  "elements": [                           // rendered by the existing engine layouts
    {"id": "e1", "label": "BLUE",  "color": "blue",  "shape": "squircle",
     "scale": 1.0, "rotation": 0, "dx": 0, "dy": 0, "opacity": 1.0, "hidden": false},
    {"id": "e2", "label": "RED",   "color": "red",   "shape": "squircle",
     "scale": 0.8, "rotation": 0.3, "dx": 0.4, "dy": 0, "opacity": 1.0, "hidden": false}
  ],
  "correctAnswer": {"elementId": "e1", "startsCorrect": false},
  "difficulty": {"level": 7, "timeLimitMs": 2200, "trickType": "swap"},
  "failLine": { "en": "THE ONLY BLUE WAS THE FIRST." } ,   // one line, per-locale
  "seed": 1337,                           // drives the rng-backed layout for determinism ([[Multiplayer AI Director]])
  "source": "ai"
}
```

Rules that hold regardless of the mechanic:

- **The model proposes mechanics, layout, instruction and decoys. It never
  paints pixels.** All rendering goes through the existing
  `ChallengeView`/`TargetSpec` language ([[Challenge System]]); `elements`
  map 1:1 to `TargetSpec`s. No new renderer is shipped for AI content — an
  unplayable mechanic is one the vocabulary doesn't contain.
- **`instruction` is under 8 words and in the player's locale.** Hard rule,
  validated ([[AI Challenge Validator]].  V1 ships English-only model output;
  everything else falls back ([[Localization and Language]]).
- **`correctAnswer` is exact.** A generated challenge that cannot name *the*
  winning input is rejected outright.
- **`failLine` is per-locale, one sentence, and always present.** The
  challenge's own fail line is what [[Game Design Pillars]] demands every
  failure be explainable with.
- **`timeLimitMs` respects the difficulty floors** — a flow / continuity
  check, never a suggestion.
- **`trickType`** is a closed enum (`none | swap | fake_button | sequence |
  rule_flip | color_shifts | requires_anomaly`) that mirrors the existing
  "tricks unlock" ladder ([[Difficulty Curve]]): `allowTricks` is required for
  any mechanic that sets a non-`none` trick.
- **`source`** is always `"ai"` for generated challenges; the engine never
  distinguishes origin at runtime except in debug captures/telemetry
  ([[Privacy and Offline]]).

## `ChallengeMechanic` — the controlled vocabulary

Generation is *closed-vocabulary by construction*: the model picks a mechanic
from an enum the engine knows how to render and judge. New mechanics are added
code-first (mirroring [[Adding a Challenge]]), then the vocabulary is extended
in both schema and registry. V1 ships a starter set:

| mechanic | engine family | example generated play |
|---|---|---|
| `tap_true_color` | color/word conflict | "TAP THE WORD'S COLOR" with word=BLUE painted GREEN — classic |
| `tap_missing_color` | perception | instruction names a hue absent from the grid — the *lack* is the answer |
| `tap_second_order` | sequence | "TAP LEFT EACH ROUND" but the grid is a *different* arrangement each time |
| `dont_tap_odd` | trick/pairing | odd item shuffled mid-round after a slow first look |
| `tap_every_but` | counting/patience | "TAP ALL BUT THE RED" with zero reds in the grid (tempting paranoia) |
| `obey_once_then_flip` | rule change | first tap locks the rule; the second tap starts obeying the *opposite* |
| `sequence_grow_remember` | memory | a short sequence that grows with each correct answer |
| `hold_true_color` | hold/timing | hold blue for the full window — release early and it was the *other* color |
| `spam_until_stop` | timing | tap until the instruction changes ("STOP" baked into the round) |

Each mechanic declares the **judging contract**: which `element`s must exist,
what `correctAnswer` means, and which `tricky` variants it composes with. The
validator enforces the contract ([[AI Challenge Validator]] →
"Mechanic contract check").

## The `source` ancestry and dedupe

`ScriptedChallengeProvider` returns `source: "scripted"`. The Director dedupes
against the **recent played set** exactly like `ChallengeGenerator` already
does (last 4 ids, [[Challenge System]] → "Selection"); generated ids that are
near-duplicates of a just-played scripted challenge (same mechanic + same
decoys) are rejected by the validator's "freshness" check.

## Adaptation and the three knobs

`AdaptiveChallengeProvider` expresses difficulty through **three independent
knobs**, matching what the Difficulty Curve already encodes
([[Difficulty Curve]]):

1. **Level** — the round number; gating (which mechanics are allowed) follows
   `minLevel`/`allowTricks` exactly like the scripted registry.
2. **Territory** — the *pool* of mechanics to draw from. The profile's
   [[Player Telemetry and Adaptive Difficulty]] weighting biases territory
   (struggling with color conflicts → more `tap_true_color`, fewer fresh
   mechanics), still gated by `allowTricks`.
3. **Tension** — the scripted difficulty read-outs the model fills:
   `timeLimitMs`, `scale`, `decoys` per element, `rotation`, `opacity`.
   Every tension field the model sets is **clamped to the same bounds the
   validator already enforces**; the model may not propose floors.

Conceptually the model proposes; the validator disposes; the fallback
provides.

## Commentary hooks (the model littering the run)

Challenges may also **carry a `hook`** — a short, single-sentence trap tease
the model generates ("THE FIRST WAS THE ONLY BLUE.") displayed in the round's
intro beat. It must be *true*, generated from the same `correctAnswer`, and
fed through the same 8-word validator rule. Hook generation is optional and
flag-gated like commentary ([[Feature Flags]]).

## Related

- [[AI Challenge Validator]]
- [[Dynamic AI Director]] / [[Pre-generation Cache]]
- [[Player Telemetry and Adaptive Difficulty]]
- [[Multiplayer AI Director]] — deterministic rounds from `{secretSeed,
  challengeId}` on the wire
- [[Challenge System]] / [[Difficulty Curve]] — the vocabulary it builds on
- [[Localization and Language]]