---
tags: [ai, gameplay, telemetry, difficulty]
updated: 2026-09-07
---

# Player Telemetry and Adaptive Difficulty

The Director's eyes and its adaptation muscle. Lives in `lib/ai/`; core stays
ignorant of it ([[Dynamic AI Director]]). **All telemetry is local, bounded,
and belongs to the player's device** — see [[Privacy and Offline]].

## What gets observed

Per round, the engine already emits exactly the events we need
(`GameEvent.levelStarted / correct / wrong / gameOver`, with `elapsed` —
[[Game Engine]]). The Director adds a thin listener and derives, for each
round:

| Signal | Source | Used for |
|---|---|---|
| `challengeId`, `mechanic`, `source`, `trickType` | challenge | territory/mechanics weighting |
| outcome (correct / wrong / timeout) | event | skill rate per mechanic |
| reaction time (ms) vs the round's `timeLimitMs` | `elapsed` | pacing, `fastStreak`-like feel |
| tap count + which decoys were tapped | `TapInfo`/`ChallengeView` | mistake classification |
| number of "almost" inputs before resolution | taps | overthinking / indecision |
| `level` at the time | context | progression context |

Nothing beyond what the engine already has in memory per-round is collected —
no location, no contact data, no other apps, no screen contents.

## Mistake categories

Each failure is classified into at most one category (a nearest-match against
the observable signal, not a model judgment):

| Category | Observable signature |
|---|---|
| `impulsiveTap` | single fast tap on a wrong answer, near `roundStart` |
| `textColorConfusion` | tapped a word whose *label* matched the instruction but whose color didn't |
| `memoryFailure` | memory mechanic (blackout), tapped before/after the reveal |
| `countingFailure` | counting mechanic, wrong cardinality |
| `timingFailure` | wrong wait/release timing on hold/timing mechanics |
| `instructionMisread` | tapped the "right" element for the *literal* wording (opposite mechanic) |
| `patternFailure` | inconsistent responses across identical repeated offers |
| `sequenceFailure` | broke a growing/locked sequence |
| `overthinking` | ≥ 2 taps then a wrong final answer on a patience/confidence mechanic |

Unknown/unclassifiable failures fall to `null` (no category) — they simply
don't feed the per-category weighting.

## The profile

A single rolling **`PlayerGameplayProfile`**, persisted locally under
**`ayu.profile`** (JSON, bounded to ~2 KB) and mirrored to the session's
`PlayerGameplayProfile` used by generation:

```jsonc
{
  "totalRoundsPlayed": 214,
  "fastestStreak": 12,
  "successRateByMechanic": { "tap_true_color": 0.71, "spam_until_stop": 0.33, ... },
  "mistakeRatesByCategory": { "textColorConfusion": 0.42, "impulsiveTap": 0.31, ... },
  "mostCommonMistakeCategory": "textColorConfusion",
  "averageReactionTimeMs": 690,
  "reactionTimeVarianceMs": 210,
  "winRateByDifficulty": { "1": 0.95, "5": 0.62, "12": 0.31 }
}
```

Rules:

- **Rolling window of the last 50 rounds** (`totalRoundsPlayed` is the all-time
  counter; the rates are windowed). Buys bounded storage *and* lets a player's
  improvement show up within a session or two.
- **Exponential moving average (α ≈ 0.15)** composites when the window
  underflows — adaptation never snaps.
- **Cold start = neutral.** With no profile, `AdaptiveChallengeProvider`
  behaves exactly like `ScriptedChallengeProvider`. The model sees a
  `profile: null` and generates a plain, high-validity challenge.
- **Cleared by Settings → RESET STATS** (same keys wiped as
  [[State and Persistence]]). Telemetry is gameplay data, not an analytics
  store; a reset must feel like a hard reset.
- No player identity, no names, no device identifiers in the profile.
  (`ProfileForPrompts` is a *truncation facade* — see [[Privacy and Offline]].)

## How adaptation works

Three knobs, from [[AI Challenge Generation]]:

1. **Level** — round number, unchanged gating. AI never changes what level
   means.
2. **Territory** — the player's own rate by mechanic re-weights the candidate
   pool: struggling at `tap_true_color`? more of the same falls in *as the
   model proposes it* — but the *variety guard* keeps ≤ 3 rounds with the same
   mechanic in any 8, so repetition never turns into a grind. Territory is a
   **preference, not a ceiling**: `minLevel > level` mechanics still never
   appear.
3. **Tension** — the read-outs the model fills (`timeLimitMs`, `scale`,
   decoys). Every proposed tension value is clamped by
   [[AI Challenge Validator]] bounds before play. `trickType` unlocks follow
   `Difficulty.allowsTricks` exactly.

**Adaptation never changes the rules.** Scoring, level progression, streak,
fail/continue, and the state machine are byte-identical whether the player is
running AI or scripted. The Director only changes *which validated challenge
is served*. See [[AI as Playing Style]] → "AI in Scoring / Leveling".

## Guard rails on the adaptation itself

- **No adapt-fast loops on loss streaks.** A single bad run (≤ 3 fails)
  can't drag territory/tension; the windowed rates use the rate *over 50
  rounds*, not the current run.
- **The model may narrow, the validator never widens.** Adaptation can only
  offer a *safer* candidate, never one the validator rejected.
- **Rollback is silent.** On any `failureExit`/flag flip, territory/tension
  snap back to the scripted default for the affected units
  ([[Feature Flags]], [[Quality Neutrality and Guardrails]] → Mitigation & rollback).

## Related

- [[AI Challenge Generation]] — how the profile feeds proposals
- [[AI Challenge Validator]] — the invariant the adaptation may not break
- [[Privacy and Offline]] — what may leave the device (nothing here)
- [[Difficulty Curve]] — the floors/ceilings every tension value obeys
- [[AI as Playing Style]] — what AI must never do to scoring/leveling