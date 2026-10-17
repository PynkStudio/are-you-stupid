---
tags: [gameplay, multiplayer, modes, design]
updated: 2026-10-17
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

- The game show starts in the **lobby**, not at the first round. A generated
  purple stage drifts behind a plain brand masthead; the join QR is presented as a
  bright ticket, the empty roster has a bouncing dance-floor invitation, and
  joined players appear as numbered two-column cast cards. The copy reacts to
  0, 1, or 2+ players and the two-segment party meter makes the start gate
  legible from across the room.
- Motion is ambient and low-frequency so the QR stays easy to scan. The same
  lobby respects Reduce Motion by freezing its generated stage and emoji loop.

Every in-game board shares one broadcast chrome: a `ROUND 7  OF 20 · STUPID
BATTLE` (or `FINAL`) header with the brand on the right and a hairline below.
No capsule badges ("pills") anywhere on the board — hierarchy comes from type
size and colour, not from chips. Layouts are composed on a 1280×720 canvas and
scaled, so the Apple TV and a small Mac window show the same hierarchy.

During play, the spectacle moves to the **edges**. The active-round board keeps
one oversized status in an otherwise quiet center; a compact top-5 standings
board sits in the lower corner, while slow generated light pools stay
peripheral. Short, irreverent lines (`THE TV IS JUDGING YOU`, `EVERYONE CAN SEE
YOU THINKING`) supply character without competing with the actual challenge on
the phones.

Results are the comedy beat and hold for only 2.5 s, so their hierarchy is
strict, in this order:

1. **Verdict** from real facts — an elimination outranks everything
   (`GIULIA IS OUT.`), then a single failure is named (`CHIARA HAD ONE JOB.`),
   then the tally (`SUSPICIOUSLY COMPETENT`, `NOBODY READ THE INSTRUCTION`,
   `ONE BRAINCELL SURVIVED`, `MOSTLY STUPID`, `MIXED LEVELS OF
   EMBARRASSMENT`), with `2 OF 7 FAILED` as its kicker.
2. **The fail wall**: one large card per wrong player with the real one-line
   failure reason at sofa-readable size; in Last Stupid Standing the heart lost
   this round flashes, and a last life lost gets an `ELIMINATED` stamp. The wall
   steps from 1 to 2 to 3 columns as it fills instead of scrolling.
3. **Survivors** in one quiet strip ordered by speed; only the fastest thumb is
   highlighted. A clean round has no fail wall, so the fastest thumb becomes
   the hero instead.
4. **Standings** on the side with rank movement since the round opened (▲/▼);
   eliminated players sink, fade and are struck through.
5. The presenter's spoken line as a broadcast subtitle, and a hairline that
   fills while the board waits for the next round.

The final board has one hero: the winner's emoji and name at full scale with
their real stat line (points, right answers, average reaction). When Last
Stupid Standing ends with the last survivors losing their final life together,
there is no winner and the board says so (`NOBODY SURVIVED / EVERYONE IS
STUPID.`) instead of crowning a non-winner. Below the hero, up to three awards
backed by match stats: `FASTEST THUMB` (best single reaction),
`PROFESSIONALLY STUPID` (most fails) and `ON A ROLL` (longest streak, given to
someone without an award yet). The ranking calls the clear last place
`OFFICIALLY THE MOST STUPID` (never on a tie). One short spring reveal, disabled
by Reduce Motion.

A future optional [[Multiplayer Presenter]] may voice these safe comedy beats,
use validated spoken names and build room-local titles/rivalries from real
match facts. It never speaks over active input and never delays the round.

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
graphic). A player requests **rematch** from their phone. The room either
returns immediately to the lobby (any room-wide no-ads entitlement) or waits
for the requesting phone's single interstitial while every other surface runs
the synchronized comedy beat. No-fill/offline is immediate; fast rematch
remains the hard goal ([[Multiplayer Product]]).

## Related

- [[Multiplayer Protocol]] — the messages that carry rounds/results
- [[Multiplayer Architecture]] — host authority + timing
- [[Multiplayer Challenges]] — the seeded, synchronized challenge set
- [[Multiplayer Product]] — scope, ads, sharing, disconnect handling
- [[Multiplayer Presenter]] — voice, identity and narrative continuity
- [[Challenge Catalog]] — the single-player templates this reuses
