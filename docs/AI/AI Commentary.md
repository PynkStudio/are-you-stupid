---
tags: [ai, gameplay, humor]
updated: 2026-09-07
---

# AI Commentary

The second model use-case: one-sentence reactions between rounds. **Static
first, AI on top** — a player on the scripted path hears the same
[[Humor and Roasts]] pools they hear today, verbatim.

## The ladder

| Source | When | Rules |
|---|---|---|
| Static bank (existing pools) | always available | unchanged pick logic (random, occasional strength, [[Difficulty Curve]] best-effort) |
| AI commentary | flag on **and** model available | generated per-`kind`, cached ([[Pre-generation Cache]]), validated for tone+length |
| Both | default | AI *preferred within* the same categories; if a unit fails, the static bank fills the slot. Never AI-only, never blanket AI |

There is **no "AI mode" that replaces the static voice** — the feature is
"more and fresher lines when the model is there", not a different game voice.

## Kinds (the closed vocabulary)

The model is asked to produce text **for exactly one kind**, so the tone and
anatomy per kind stay controlled (same pattern as mechanics — closed
categories, validated):

| kind | trigger | tone contract |
|---|---|---|
| `correct` | correct answer | short, dry praise — "NOT BAD. FOR YOU." |
| `wrong` | mistake | the roast — one sentence, ends the flash line slot |
| `streak` | fast-streak extension | escalate, never repeat a prior line |
| `comeback` | recovering from a fail streak | acknowledging the player read the joke |
| `elimination` | multiplayer player knocked out | roasting the *player*, never the device |
| `finalRound` | last-two in multiplayer | tension, not hostility |
| `winner` | match ends | one sentence, respects loser line too |
| `loser` | match ends | the loss line |
| `closeMatch` | final margin ≤ 1 | the "it was this close" line |
| `instantFailure` | scripted/trick instant fail | the trap's own one-liner |

Every kind has a **max length** (`≤ 6 words` for `correct`/`streak`;
`≤ 12 words` for roasted kinds), hard-validated. An AI line never quotes the
player, never references the model, never drifts off-topic
([[Quality Neutrality and Guardrails]]).

## Generation-time rules

- **Context the model gets** (per unit): the `kind`, the current run's stats
  (streak length, comeback-in-progress, win/loss margins in multiplayer), and
  *nothing else* — no names, no raw full transcript, no history dumps. It gets
  the compact `PlayerGameplayProfile` only via the tool, never the raw log
  ([[Dynamic Profiles and Tool Calling]]).
- **Temperature high** (≈ 0.9) for this unit; `maximumResponseTokens` capped.
- **Randomness + dedupe:** the Director keeps a short recent-lines set per
  session and requests "not this set" via prompt; the same line twice in a
  row is rejected and the previous line reused.
- **Always one sentence.** Periods are the only sentence terminator allowed in
  commentary output by the validator.

## Where the lines land

- `wrong` → the red-flash roast slot (`GameState.reason`), same slot as today;
  AI quality is why the 2.85 s flash with tap-to-skip exists
  ([[Decision Log]] → "Wrong flash is now 2.85s").
- `correct`/`streak` → the green flash line, only when the engine already
  shows one; never adds a new widget.
- Multiplayer kinds → handled by [[Multiplayer AI Director]]; ASCII-only so
  they survive the wire form without escaping surprises.
- **No commentary in the input path.** Every AI line is prefetched ahead of
  the moment it's needed ([[Pre-generation Cache]]); the fallback is the
  static bank, so a slow model simply means "the usual lines".

## Related

- [[Dynamic AI Director]] / [[Pre-generation Cache]]
- [[Humor and Roasts]] — the static floors and the tone this layer extends
- [[Quality Neutrality and Guardrails]] — tone/length validation
- [[Multiplayer AI Director]] — multiplayer kinds and the wire
- [[Localization and Language]] — v1 English-only model lines