---
tags: [gameplay, multiplayer, challenges, design]
updated: 2026-09-06
---

# Multiplayer Challenges

How challenge synchronization works in the party mode, and the four
multiplayer-specific challenge families. The existing 39 templates from the
[[Challenge Catalog]] are reused as-is — see [[Multiplayer Gameplay]] for the
round flow around them.

## Why deterministic seeding is non-negotiable

Every player must see the **exact same** challenge. If every client independently
randomizes, latency jitter means players face different puzzles — the whole
game breaks. The host generates one canonical challenge and pushes it via
`ROUND_START`; clients locally rebuild the same `ChallengeView` from the same
seed ([[Multiplayer Protocol]]).

## Phase 1 refactor: deterministic `challengeId` + `seed`

The existing `ChallengeGenerator` picks a random template weighted by level
and avoids back-to-back repeats ([[Challenge System]]). For multiplayer the
host needs to:

1. **Pick a template id** — using the same weight/level rules the client
   already knows, but seeded so the sequence is deterministic across both ends.
2. **Push the picked `challengeId` + `seed`** once via `ROUND_START`.
3. **Locally rebuild** the canonical challenge from that tuple — using the
   existing template registry (`lib/challenges/registry.dart`), the `ChallengeParams`
   constructor, and the host's own reference RNG seeded by `seed`.

Phase 1 is landed in Dart: `lib/challenges/registry.dart` exposes the two
pieces of that contract:

- `templateById(String id)` — resolves a `ChallengeTemplate` by its stable
  id, or `null` for an unknown id (a host must treat `null` as a bad round,
  not crash).
- `buildFromSeed({challengeId, seed, level, locale})` — builds the canonical
  `Challenge` from `{ challengeId, seed }`. It seeds a fresh `Random(seed)`
  per call and derives `speed` from `level` via `Difficulty.speedForLevel`,
  exactly like the solo path, so every end agrees on timings without the host
  sending an explicit speed.

```dart
buildFromSeed(challengeId: 'tap_actual_color', seed: 28374, level: 12);
```

Same tuple → same `Challenge` → same `ChallengeView` on the Dart side, every
time. `buildFromSeed` is **not** used by single-player: `ChallengeGenerator`
remains the only solo entry point, and its behaviour is unchanged.

The determinism guarantee is scoped to Dart runtimes today (every Flutter
phone and the in-process simulation harness). Mirroring the exact seeded
stream when the native tvOS host lands is an open decision — see the
[[Decision Log]] entry *"Multiplayer Phase 1 landed: `buildFromSeed` …"*.

## How challenges land on every phone

The host includes in `ROUND_START`:

```json
{
  "roundId": "r14",
  "challengeId": "tap_actual_color",
  "seed": 28374,
  "durationMs": 2400,
  "config": { "level": 12 }
}
```

The client's `party_engine.dart` builds the challenge from those fields and
renders it locally via the existing [[Rendering Pipeline]]. Same instruction,
same targets, same colors, same timer — identical to every other connected
player, and to what the host itself built.

## Reusing the existing 39 templates

Most rounds use a template straight from [[Challenge Catalog]]. The host picks
one via the seeded sequence; every Dart end (the Flutter phones and the
in-process simulation harness) calls `buildFromSeed(challengeId:, seed:,
level:)`, producing the same `ChallengeView`. No new challenge code is needed
— the host's `ROUND_START` is all that is required.

**Phase 4 open question:** the native tvOS host ([[Multiplayer Host (tvOS)]])
is a separate Swift process and — unlike the all-Dart ends — is **not**
guaranteed to reproduce the seeded stream yet (see the [[Decision Log]] entry
*"Multiplayer Phase 1 landed: `buildFromSeed` …"*). Two options, neither
chosen: replicate Dart's PRNG in Swift so the host can rebuild locally, or keep
the host from needing a local rebuild at all.

## Multiplayer-specific challenge families

Four new families that become fun *specifically* because everyone plays
simultaneously. They follow the same rules as the existing templates (own fail
line, judge on tap, under 8 words per instruction, see [[Game Design
Pillars]] and [[Challenge System]]).

---

### 1. SAME ANSWER (`same_answer`)

**Instruction:** `PICK A NUMBER 1–4` (under 8 words ✓)

**Phone:** four large number buttons, same challenge for all.

**After the round:** reveal what everyone picked:

```
MASSIMO  3
SAMI     3
LUCA     1
GIULIA   4
```

**TV:** the reveal itself is the joke — no score attached; used as a
non-scoring icebreaker round or a lives round where wrong = wrong consensus.

**Scoring:** optional — the host may award lives for matches against the
majority, or treat it purely as a reveal round (configurable via
`config.revealMode`).

---

### 2. FASTEST (`fastest`)

**Instruction:** `TAP AS SOON AS THE SCREEN TURNS GREEN`

**Phone:** blank screen → green → player taps. First correct tap wins.

**Timing:** both ends share `startAt` + `durationMs` from `ROUND_START`.
The host judges on `actionReceivedMs` relative to its own clock; cross-checks
the client's `clientTimestampMs` for abuse tolerance, but never trusts it as
authoritative ([[Multiplayer Protocol]]).

**TV:**
```
FASTEST
🥇 SAMI     187 ms
🥈 MASSIMO  194 ms
🥉 GIULIA   231 ms
   LUCA     301 ms
```

**Fail line:** those who tapped early get the existing reaction-roast
(`IMPATIENT.`, see [[Challenge Catalog]] `wait_for_green`); slowest may get a
custom `SLOW.`, but sparingly.

---

### 3. EXACTLY (`exactly_n`)

**Instruction:** `TAP EXACTLY 5 TIMES`

**Phone:** tap counter displayed live; tap settles 420 ms after the last tap
(reuse the `tap_twice` settle logic in [[Challenge Catalog]]).

**After the round:** reveal everyone's count:

```
MASSIMO  5 ✓
SAMI     5 ✓
LUCA     6 ✕
GIULIA   4 ✕
```

**Fail line:** `TOO MANY.` / `NOT ENOUGH.` (specific, matches the pattern in
[[Humor and Roasts]]); timeout gets the default late roast.

---

### 4. DON'T TAP (`dont_tap_global`)

**Instruction:** `DO NOT TAP ANYTHING`

**Phone:** a blank screen (or with a large `TAP ME` bait, identical to the
single-player `dont_tap` [[Challenge Catalog]]).

**After the round:** anyone who tapped is `💀`; non-tappers are `✓`.

```
MASSIMO  ✓
SAMI     ✓
LUCA     💀
GIULIA   ✓
```

**Lives/elimination:** taps immediately lose a life in elimination mode;
in battle mode they score zero for the round.

---

## Scoring across families

For **Stupid Battle** the host uses this baseline per correct answer:

- Correct: 100 points base.
- Fastest-family bonus: +50 / +25 / +10 for top-3 when the host configures
  `config.speedBonus: true`.
- Ties in `same_answer`: all matching the majority win.

For **Last Stupid Standing** scoring is binary — correct survives, incorrect
loses a life. Speed bonuses are **not** applied in elimination mode to keep
the pace tight and results readable at a glance.

## Cross-family consistent details

- Round instruction text is always **under 8 words**, uppercase, same
  structure in all six languages ([[Localization]]).
- Every family ships with a specific fail line; generic roasts are a last
  resort, never the first explanation ([[Humor and Roasts]]).
- Timeout always loses a life (elimination mode) or scores zero (battle mode),
  same as any wrong answer.

## Related

- [[Multiplayer Protocol]] — the message that carries `{challengeId, seed}`
- [[Multiplayer Gameplay]] — how these land in rounds, TV presentation, humor
- [[Multiplayer Architecture]] — host authority, determinism
- [[Challenge System]] — the base class contract, `ChallengeParams`, `.build()`
- [[Challenge Catalog]] — all 39 templates being reused