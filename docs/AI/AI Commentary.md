---
tags: [ai, gameplay, humor]
updated: 2026-10-02
---

# AI Commentary

The second model use-case: one-sentence reactions between rounds. **Static
first, AI on top** — a player on the scripted path hears the same
[[Humor and Roasts]] pools they hear today, verbatim.

**Implementation status:** `lib/ai/commentary.dart` + the real Swift
`AYSCommentaryService` landed ([[Development Plan]] Phase 4), and
**single-player now shows it** (`lib/ai/solo_commentary.dart`, wired in
`game_screen.dart`): a prefetched aside on the wrong flash and the Game Over
verdict — see "Where the lines land". Lines are written **in the player's
language** (all six locales, see [[Localization and Language]]). Five
multiplayer kinds (`elimination`/`finalRound`/`winner`/`loser`/`closeMatch`)
fall back onto the tonally-closest existing pool rather than dedicated copy,
since they have no `roast.*`-style pool of their own yet — see the
2026-09-11 [[Decision Log]] entry. `CommentaryProvider.aiLine` is the AI
rung alone (returns `null` instead of a static line) for call sites that
show nothing extra when the model has nothing.

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
| `gameOver` | single-player run ends | the verdict on the run, written from its facts (level, best, new best, streak, the instruction that ended it); static fallback = the Game Over roast pool |

Every kind has a **max length** (`≤ 6 words` for `correct`/`streak`;
`≤ 12 words` for roasted kinds), hard-validated. An AI line never quotes the
player, never references the model, never drifts off-topic
([[Quality Neutrality and Guardrails]]). Charset: strict ASCII for English
(multiplayer always asks in English, keeping the wire ASCII); Latin script
(accents, `ß`, `¡¿`, `’`) for the other locales. Quotes the model wraps a
line in are stripped before validation (`normalizeCommentaryLine`). The
forbidden-token and meta-AI lists carry a few localized entries
(`modello`, `KI`, …) — deliberately short and unambiguous.

## Generation-time rules

- **Context the model gets** (per unit): the `kind`, the moment's facts
  (`wrong`: the level; `gameOver`: `RunSummary` — level reached, personal
  best, new best yes/no, best fast streak, the failed instruction and its
  fail line), the spicy-roasts setting (off → "keep it gentle"), the recent
  lines to avoid, and *nothing else* — no names, no raw transcript, no
  history dumps. Everything in the context is game text the player already
  saw ([[Privacy and Offline]]).
- **Temperature high** (≈ 0.9) for this unit; `maximumResponseTokens` capped.
- **Randomness + dedupe:** the Director keeps a short recent-lines set per
  session and requests "not this set" via prompt; the same line twice in a
  row is rejected and the previous line reused.
- **Always one sentence.** Periods are the only sentence terminator allowed in
  commentary output by the validator.

## Where the lines land

- `wrong` (single-player) → an **aside under** the red flash's headline
  (`FlashOverlay.aside`), never in place of it: the headline stays the
  challenge's own fail line ([[Game Design Pillars]] → every failure
  explainable in one line). Prefetched by `SoloCommentator`'s size-1 ring
  from every `levelStarted`; an empty ring means no aside and the flash
  looks exactly like the scripted game. Locale / spicy-setting changes drop
  the cached line.
- `gameOver` (single-player) → the Game Over card's headline. Requested at
  the moment of the fail with the run's facts; the 2.85 s wrong flash is its
  latency budget. If it isn't there when the card appears it may still swap
  in during the card's 600 ms input lock, never after; otherwise the static
  roast stays. Nothing on the card says the line is AI.
- `correct`/`streak` → not shown in single-player yet.
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
- [[Localization and Language]] — commentary in all six locales