---
tags: [ai, validation, safety]
updated: 2026-10-02
---

# AI Challenge Validator

The **deterministic gate** between the model and the player. The
Foundation Models suggestion becomes a playable challenge **only** when this
function says "valid". It is pure Dart, lives in `lib/ai/`, has zero model
dependencies, and is exhaustively unit-tested headless ([[Testing and Evaluation]]).

> **The validator is the authority — not the model, not the bridge, not the
> cache.** A challenge that skipped validation is a bug. A challenge that
> failed validation is never served, ever. Both are tested properties.

## Interface

```dart
ChallengeVerdict validate(GeneratedChallenge proposal, ValidationContext ctx);

// Sealed verdict types (lib/ai/challenge_validator.dart):
sealed class ChallengeVerdict {}
class VerdictValid             extends ChallengeVerdict {}
class VerdictExitChallenge     extends ChallengeVerdict {}
class VerdictRetryableForcedExit extends ChallengeVerdict {}
class VerdictInvalid           extends ChallengeVerdict { final String context; }
class VerdictFailureExit       extends ChallengeVerdict {}
```

| Verdict | Meaning | Fallback effect |
|---|---|---|
| `valid` | playable, serve it | — |
| `exitChallenge` | **statically unplayable** — engine cannot render it | drop silently to scripted ([[Pre-generation Cache]]) |
| `retryableForcedExit` | one regeneration may fix it (e.g. instruction too long) | regenerate **once**, then scripted |
| `invalid` | contradicts the [[Game Design Pillars]]; must not be played | regenerate once if retryable, else scripted |
| `failureExit` | the model is producing garbage — stop asking this unit | mark unit failed, keep scripted |

Deterministic re-validation holds: same proposal + same context ⇒ same
verdict, every time. This is what lets the cache be trusted and lets the
multiplayer host/phones agree on a bad round ([[Multiplayer AI Director]]).

## The checks (in order)

### 1. Envelope

- Non-empty `id`, `instruction`, exactly one `correctAnswer`, `source` set.
- `id` matches `^ai\\.[a-z0-9]{5}$` (so scripted ids never collide).
- No control characters, no emoji, no non-latin punctuation. Ids and enum
  names accept ASCII letters, digits `` `',.!?-_` `` and spaces only, in
  every locale. Player-facing text (instruction, fail lines, labels) uses
  the same ASCII set in English and `kLatinAllowlist` (any Latin-script
  letter, `’`, `¡¿`) in the other locales (`textAllowlistFor`). (This is
  also the "no AI-ASCII embedding" guardrail — see [[Quality Neutrality and
  Guardrails]].)

### 2. Instruction rule

- Under **8 words** in English, **up to 10** in it/fr/es/pt/de
  (`instructionMaxWords`; tokenized on spaces), and **uppercase** on screen
  (Unicode-aware: `ù` fails like `u`) — the [[Game Design Pillars]] rule,
  with the wordier-language exception from [[Localization and Language]].
- Exactly one imperative *action* verb (the mechanic's `action`), in the
  player's language (`AiAction.imperativeVerbsFor`), not a paragraph of
  instructions.
- Tone checks tokenize Unicode words and include a few localized
  forbidden / meta-AI tokens (`modello`, `KI`, …).

### 3. Mechanic contract

- `mechanic.move` must be in the vocabulary **and** its judging contract must
  hold: the elements it needs exist, the `action` matches, the declared
  `sense_decoys` correspond to real differences in the elements' fields
  (label vs color vs size vs motion).
- If the mechanic's contract says "trick required", `trickType != none` and
  `ctx.allowTricks == true`; otherwise trick types beyond `none` ∖ `swap`
  are rejected when `allowTricks` is false (mirrors the scratch of the
  [[Difficulty Curve]] ladder).

### 4. Element bounds

For every element (validated independently of the model's claimed values):

- `scale` in **[0.45, 2.0]** (never a physically un-hittable button),
- `opacity` in **[0.35, 1.0]** (never a genuinely invisible target),
- **target count in [2, 6]** (grids 2×2…3×2) — enough decoys, never a
  white-noise wall,
- `rotation` magnitude ≤ 0.6 rad, `dx`/`dy` within ±0.6 of the grid cell,
- exactly **1 correct element** unless the mechanic's contract says otherwise.

### 5. Time floor

- `timeLimitMs` ≥ the mechanic/family floor from [[Difficulty Curve]]
  (the per-challenge `floorMs`), scaled by `Difficulty.speedForLevel(level)`
  exactly like scripted challenges. A challenge that would be physically
  impossible is `invalid`.
- `timeLimitMs` ≤ 8000 ms — a generated challenge longer than a scripted
  round is suspicious and capped by construction.

### 6. Decoy honesty

- Every decoy must be an **inverted/mirror** of the correct answer in at
  least one sensed dimension (wrong color, other shape, scaled differently,
  back-to-front word, ...) — never random noise. This is the
  [[Dynamic AI Director]] "wrong answers must be tempting" rule checked
  mechanically: each decoy differs from the correct element in *≥ 1* of
  {color, label, shape, scale, rotation, opacity, position}.

### 7. Freshness / uniqueness

- Not a semantic duplicate of the last 4 served challenges (same mechanic +
  same decoy signature). A near-duplicate is `invalid` (→ one regen, then
  scripted).

### 8. Solution resolvability

- `correctAnswer.elementId` resolves to an element; `startsCorrect` is
  consistent with the mechanic (e.g. for `swap` tricks the correct element
  must *start* correct and swap away — a constant lie is `invalid`).

### 9. Neutrality & tone

- No slurs, profanity beyond the game's own [[Humor and Roasts]] pools,
  gendered/racial/religious attack, encouragement of self-harm, or
  references to real people/brands. Same rule for fail lines and hooks.
- **No meta-instructions that reference the AI** ("the model made this",
  "Apple Intelligence says"). The game never explains itself as a model
  ([[Quality Neutrality and Guardrails]] → "no AI wallpaper" rule).

## Regeneration policy

Exactly **one regeneration attempt per prefetch unit**, and only on
`retryableForcedExit`/`invalid`-with-retryable-reason. After that the unit is
`failureExit` and the engine gets the scripted path. **Never regenerate in the
input path** — regeneration exists only inside the prefetch loop
([[Pre-generation Cache]]), so no round is ever delayed "while we ask the
model again".

## What the validator does *not* do

- It does not tune difficulty (that's [[Player Telemetry and Adaptive Difficulty]]).
- It does not render, localize, or translate.
- It does not judge fun. Nothing the model writes can make the game
  *un*playable; whether it's *better* than scripted is measured, not assumed
  ([[Testing and Evaluation]] → playtest metrics).

## Related

- [[AI Challenge Generation]] — the shape being validated
- [[Quality Neutrality and Guardrails]] — the tone policy this enforces
- [[Pre-generation Cache]] — where validation lives in the pipeline
- [[Testing and Evaluation]] — the validator test matrix