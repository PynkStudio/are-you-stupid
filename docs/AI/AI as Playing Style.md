---
tags: [ai, gameplay, humor, product]
updated: 2026-09-07
---

# AI as Playing Style

The AI's place in the *feel* of the game — and where it has none at all.

## AI in Scoring / Leveling — never

The engine's scoring, level progression, streaks, win/loss state, and the
fail/continue flow are **untouched, byte for byte, by AI**:

- AI may change *which validated challenge is served*; it may **not** change
  the score awarded for a correct answer, the level a round starts at, or
  whether a failure continues the run.
- There is **no such thing as the model "granting" or "denying"** a
  level-up/win — the pipeline can't express it (the Director only returns
  challenges; the engine owns outcomes — [[Dynamic AI Director]]).
- The final score a player sees is computed by the same `GameState` logic in
  every mode. The "AI quality" never leaks into what the score *means*.

## AI in Monetization — never

- No AI-generated content, spending nudges, or revenue-tuning prompts. Monetization stays the purely static, scripted feature it is today
  ([[Monetization and Ads]]).
- The Director has no tool, flag, or code path that could influence
  monetization; the feature flags exist for gameplay surfaces only
  ([[Feature Flags]]).

## AI as voice (the style)

Where AI *is* allowed to contribute is **voice** — one more voice in the
house style, bounded by [[Humor and Roasts]]:

- AI lines must match the game's established rhythm: **short, deadpan, a
  punchline that lands in a single breathe**, on the roast spectrum the game
  already owns ([[Humor and Roasts]] → tone table). An AI line is not "the
  AI talking"; it's the same game whispering a new one-liner.
- Commentary categories (`correct`/`wrong`/`streak`/`comeback`/
  `elimination`/`finalRound`/`winner`/`loser`/`closeMatch`/`instantFailure`)
  and their length contracts live in [[AI Commentary]].
- **The fallback voice is identical to today.** A player who never gets an AI
  line hears the exact bank-built experience. The style test in playtests is
  blind: players are asked whether a round "felt like the game", without the
  mode being disclosed ([[Testing and Evaluation]]).

## What this buys

Sticking to voice-only keeps every riskiest AI trait (long generation,
refusals, non-locale drift, hallucinated winners) out of the places it would
hurt the most: the score, the wallet, and the fail/retry loop.

## Related

- [[Humor and Roasts]] — the tone floors AI lines must pass
- [[AI Commentary]] — the categories and length caps
- [[Game Engine]] / [[Difficulty Curve]] — the untouched scoring/level rules
- [[Quality Neutrality and Guardrails]] — the same rules as contracts
- [[Player Telemetry and Adaptive Difficulty]] — adaptation must not touch levels