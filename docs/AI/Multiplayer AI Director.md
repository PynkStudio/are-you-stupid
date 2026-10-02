---
tags: [ai, multiplayer, architecture]
updated: 2026-09-11
---

# Multiplayer AI Director

Party mode, directed. Extends the v1 multiplayer architecture
([[Multiplayer Architecture]], [[Multiplayer Protocol]], [[Multiplayer Gameplay]]) with one new role: an on-device **AI Director Host**.

**Implementation status:** real end-to-end as of Phase 8 — election
(`RoomHost.electDirector`), the single-slot relay
(`startNextRound`/`startAiRound`), failover, and the Dart-side
`PartyAiDirector` runtime that generates and sends rounds/commentary all
exist and are tested. See "What travels over the wire" below for two
corrections against the original sketch (real names, six kinds not four).
Not built: commentary display in the UI (captured, not shown anywhere —
same deferral as single-player's own Phase 5), and the finer
battery/SoC-based Director tie-break this doc originally described (v1
uses a single compute-rank tier instead — see [[Decision Log]]).

## The rule that shapes everything

> **The Apple TV never runs the model.** `FoundationModels` is unavailable on
> tvOS ([[Foundation Models Integration]]). The match host (Apple TV) keeps
> *all* authority it has today — room, seed, rounds, validation, scores,
> elimination, winner — it just gains a new optional source of rounds.

So in a match:

```
Apple TV (match host, sole authority, no model)
   │  negotiates capabilities, announces assignments          ┌──────────────┐
   │  relays AI-generated rounds + commentary (validated) ───►│ AI Director  │
   │  relays players' results                          ◄───────│ Host: one    │
   └───────────────────────────────────────────────────────────│ capable      │
         all other phones (controllers, no model needed)       │ iPhone/iPad  │
                                                               └──────────────┘
```

## AI Director Host election

At match start (and whenever the role is empty), the match host runs an
**election over the connected clients' capabilities**:

1. Each client announces `AI_CAPABILITIES = { aiAvailable, computeRank,
   batteryPercent }` once, right after connecting.
2. Only clients with `aiAvailable == true` are candidates.
3. Priority: highest `computeRank` wins; tie-break by the lexicographically
   smaller `playerId` (stable, arbitrary, deterministic). **v1 keeps
   `computeRank` a single tier** (`aiAvailable ? 1 : 0`) rather than the
   finer SoC/battery-based rank this section originally described — a real
   per-device rank would need a new battery/device-info dependency for a
   tie-break that can't be verified without real hardware anyway (see
   [[Decision Log]]). **The host announces the winner via an
   `AI_DIRECTOR_ASSIGNMENT` message.** No device ever self-appoints.
4. If no capable phone joined, the match plays 100 % scripted
   ([[AI Challenge Generation]]) — identical to how a non-AI match already
   works. AI is additive, not required.

**Failover.** No separate heartbeat exists — re-election piggybacks on the
same disconnect/reconnect-grace-window machinery every seat already has.
The match host re-elects once the Director's seat is actually *removed*
(`RoomHost.removeSeat`, only after the grace window expires without a
reconnect — a Director that reconnects in time keeps its assignment
instead of losing and immediately regaining it), and until the new
assignment lands, serves **scripted** rounds from the existing seeded path
— rounds never wait on AI
([[Pre-generation Cache]]). A dead Director Host is a non-event for the match,
never a pause.

## What travels over the wire (never the model)

Only compact, structured results from the Director Host → match host → everyone.
**Six wire kinds, not four** — "the Director produces X" and "the host
relays X" are necessarily distinct messages in this protocol's model
(client→host vs. host→all), and the real names follow this protocol's own
flat Upper-`SNAKE_CASE` convention, not this doc's original
`client/aiCapabilities`-style sketch (corrected after Phase 7 implemented
it — see [[Decision Log]]):

| Message (additive, v1) | Payload | Direction |
|---|---|---|
| `AI_CAPABILITIES` | `{ aiAvailable, computeRank, batteryPercent }` | each phone → match host |
| `AI_DIRECTOR_ASSIGNMENT` | `{ directorPeerId }` or `null` | match host → all |
| `AI_ROUND_PROPOSAL` | `{ roundId, proposal }` — the Director's own validated `ChallengeProposal` wire JSON | the Director phone → match host |
| `AI_CHALLENGE_ROUND` | `{ roundId, proposal, startAt, durationMs }` | match host → all, relayed **as-is** |
| `AI_COMMENTARY_PROPOSAL` | `{ kind, roundId, text }` | the Director phone → match host |
| `AI_COMMENTARY` | `{ kind, roundId, text }` | match host → all, relayed as-is |

The match host does **not** re-validate `AI_ROUND_PROPOSAL` before
relaying it — it has no `ChallengeValidator` (that's ~400 lines of pure
Dart) and no challenge-rendering registry, and porting either to Swift
would repeat the exact duplication already rejected for judging (see
[[Decision Log]]). It trusts the Director phone the same way it already
trusts every player's self-reported `PlayerAction.correct` — a light
structural sanity check, not re-validation.

### Determinism without a shared model

- The **only** device that generates is the AI Director Host — so other phones
  never need the model for *generation*. They need the model for
  *nothing*, actually: receiving an AI round is pure Dart.
- Only the Director phone runs [[AI Challenge Validator]] — the Apple TV
  match host trusts its verdict rather than re-running it (see the
  "What travels over the wire" note above). Each phone still builds its own
  playable `Challenge` from the relayed `AI_CHALLENGE_ROUND` proposal via
  `generated_challenge_runtime.dart`'s `buildFromProposal` — deterministic
  because the full proposal travels on the wire, not just a seed to replay.
- Scripted seeded rounds keep using today's `{ challengeId, seed }`
  `ROUND_START` tuple ([[Multiplayer Challenges]]) — no change there.
- `roundId` ties AI rounds and AI commentary together; commentary for a round
  is generated *by the same Director* (it owns the room's recent-lines dedupe
  — [[AI Commentary]]).

### Latency

`PartyAiDirector` generates one round ahead of need — triggered every time a
round opens (scripted or AI), so there's a full round's worth of time for
generation to land before the *next* one starts — and sends it the moment
it validates. The match host's own `pendingAiProposal` is a single slot,
not a ring: if nothing has arrived by the time the next round needs to
start, `startNextRound` serves a seeded scripted round instead — the round
*plays*, nobody waits, the same underflow contract as single-player's
[[Pre-generation Cache]], just without that note's SLA timers or
`cancelUnit` plumbing (there's nothing to cancel — one device generating
for the whole room only ever has the one in-flight request `PartyAiDirector`
itself already serializes).

## Scope cuts

- No cross-session AI memory; the Director Host's profile is its own player's
  ([[Player Telemetry and Adaptive Difficulty]]), and profiles are **never
  exchanged** between phones.
- The TV's on-screen text (roasts, scores) stays sourced from the *static*
  pools in v1 for the TV chrome; only round delivery + match commentary are
  AI-capable kinds. `PartyAiDirector` sends three of [[AI Commentary]]'s
  five multiplayer kinds today — `elimination` (on `PLAYER_ELIMINATED`) and
  `winner`/`loser` (on `GAME_END`, by whether this phone's own
  `selfClientId` matches `winnerId`); `finalRound` and `closeMatch` aren't
  wired to a trigger yet, and none of the three are shown anywhere in the
  UI yet either (captured in `HostViewModel.lastAiCommentary`, not
  displayed — see [[Decision Log]]).
- If both a capable and an incapable phone are in a match, the incapable
  phones simply receive AI rounds like everyone else — capability is only
  needed to *be* the Director, never to *play*.

## Protocol impact

All six messages above are **additive** kinds in the versioned JSONL
contract. v1 peers ignore unknown message kinds by design
([[Multiplayer Protocol]]), so a match mixing a Director Host with an older
client keeps working scripted. Golden fixtures cover all six on both
`protocol.dart` and `ProtocolModel.swift` ([[Testing and Evaluation]]).

## Related

- [[Dynamic AI Director]] / [[Pre-generation Cache]]
- [[Multiplayer Protocol]] / [[Multiplayer Architecture]] / [[Multiplayer Gameplay]]
- [[AI Commentary]] / [[AI Challenge Generation]] / [[AI Challenge Validator]]
- [[Feature Flags]] — `aiMultiplayerDirectorEnabled`