---
tags: [gameplay, multiplayer, modes, design]
updated: 2026-09-06
---

# Multiplayer Gameplay

The party mode's play rules on top of [[Multiplayer Protocol]] and
[[Multiplayer Architecture]]. This describes **existing/intended behaviour** —
when the mode ships, the notes get bumped to match exactly what runs.

## Modes

### MODE 1 — LAST STUPID STANDING (elimination)

- Every player starts with **3 lives** (`❤️ ❤️ ❤️`).
- Each incorrect answer (or timeout) removes one life.
- At 0 lives the player is `ELIMINATED` — `PLAYER_ELIMINATED` is broadcast. The
  eliminated player keeps watching (never kicked, [[Multiplayer Architecture]])
  but stops participating in this match's rounds: they receive no further
  `ROUND_START` challenges for scoring.
- Play continues until **one player remains**, or everyone is eliminated
  (host picks the least-stupid survivor/winner deterministically).
- Winner revealed as **THE LEAST STUPID** / **NOT STUPID AFTER ALL**, with a
  host winner animation.

### MODE 2 — STUPID BATTLE (points)

- All players stay active for a **fixed number of rounds** (default 20).
- Each correct answer earns points; a faster correct answer may earn a small
  **bonus** when the challenge is a reaction/`FASTEST`-style round (judged by
  the host's `actionReceivedMs`, cross-checked against `clientTimestampMs`
  — [[Multiplayer Protocol]]; the client never self-awards).
- Incorrect answers score zero.
- After each round the TV shows a standings board (medals + scores), and at the
  end shows `FINAL RESULTS` + `WINNER`.
- Lives are not used; elimination never happens. Losing is just a low score.

## Shared round flow (both modes)

1. `ROUND_START { challengeId, seed, roundId, startAt, durationMs, config }`
   delivered to every client ([[Multiplayer Challenges]]).
2. Shared countdown `3-2-1-GO` (authoritative `startAt`).
3. Players answer independently on their phones; each `PLAYER_ACTION` is
   validated by the host only (duplicate/late/malformed → `ERROR`, no score).
4. Reveal `ROUND_RESULTS` on the TV with a synchronized result for each
   player (correct/wrong, who lost a life, who's fastest).
5. `ROUND_END` bookend → `NEXT ROUND` (or `GAME_END`).
6. Deferred to keep rounds bite-sized: transitions are short, never long
   animations that interrupt the loop.

## Synchronization (non-negotiable)

The host builds the canonical challenge **once** per round and pushes it.
Clients never independently randomize — every phone must show the exact same
challenge ([[Multiplayer Challenges]]). Timing uses `startAt`/`durationMs`
host-published, not client wall-clock ([[Multiplayer Protocol]]).

## TV presentation (game-show, not a mirrored phone)

Large typography, dramatic but **short** transitions:

- `ROUND 14` → `GET READY…` → `3 2 1 GO` (countdown driven by the host's
  deadline).
- In-round: live player states `✓ / ✕ / 💀`, correctness against the reveal.
- After all answered: `RESULTS` board, then `NEXT ROUND`.
- **Live scoreboard** during appropriate moments:

```
STUPID BATTLE
SAMI     820
MASSIMO  760
LUCA     610
GIULIA   490
```

## Humor lines (playful, never every round)

The TV occasionally reacts to mistakes, drawn from a small pool — never shown
after every round, never hostile to the person ([[Humor and Roasts]] tone):

- `LUCA. REALLY?` · `YOU HAD ONE JOB.` · `MASSIMO IS COOKING.`
- `NOBODY READS INSTRUCTIONS.` · `THAT WAS EMBARRASSING.` · `BRO.`
- `HOW DID YOU EVEN DO THAT?` · `ONLY THREE BRAINCELLS REMAIN.`
- `WE HAVE LOST LUCA.` · `SAMI IS SUSPICIOUSLY SMART.` · `THIS IS GETTING PERSONAL.`

Rare on purpose. The MVP keeps it English-first; per-language transcretion is a
future pass ([[Localization]]-style, [[Decision Log]]).

## Elimination screen

- **TV:** `💀 LUCA — YOU ARE ELIMINATED. YOU HAD ONE JOB.`
- **Mobile:** `YOU'RE OUT 💀 — Watch the others make stupid mistakes.`
- The eliminated player stays in the room and watches; they are not kicked.

## Winner + rematch

`GAME_END` → winner animation + shareable result card (text + screenshot-style
graphic), then instant **rematch** back into the lobby
([[Multiplayer Product]]). Fast rematch is a hard goal.

## Related

- [[Multiplayer Protocol]] — the messages that carry rounds/results
- [[Multiplayer Architecture]] — host authority + timing
- [[Multiplayer Challenges]] — the seeded, synchronized challenge set
- [[Multiplayer Product]] — scope, ads, sharing, disconnect handling
- [[Challenge Catalog]] — the single-player templates this reuses