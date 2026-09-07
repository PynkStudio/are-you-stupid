---
tags: [ai, multiplayer, architecture]
updated: 2026-09-07
---

# Multiplayer AI Director

Party mode, directed. Extends the v1 multiplayer architecture
([[Multiplayer Architecture]], [[Multiplayer Protocol]], [[Multiplayer Gameplay]]) with one new role: an on-device **AI Director Host**.

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

1. Each client announces `aiCapabilities = { aiAvailable: bool, computeRank,
   batteryPercent, locale }` (new additive message kind in the v1 protocol).
2. Only clients with `aiAvailable == true` are candidates.
3. Priority: highest `computeRank` (newer SoC / real Apple Intelligence
   device) wins; tie-break by lower battery drain risk (higher battery
   percent), then stable `peerId`. **The host announces the winner via an
   `aiDirectorAssignment` message.** No device ever self-appoints.
4. If no capable phone joined, the match plays 100 % scripted
   ([[AI Challenge Generation]]) — identical to how a non-AI match already
   works. AI is additive, not required.

**Failover.** The AI Director Host sends the same heartbeat the protocol
already requires. If the match host loses the heartbeat, it (re)elects over
the remaining candidates and, until the assignment lands, serves **scripted**
rounds from the existing seeded path — rounds never wait on AI
([[Pre-generation Cache]]). A dead Director Host is a non-event for the match,
never a pause.

## What travels over the wire (never the model)

Only compact, structured results from the Director Host → match host → everyone:

| Message (additive, v1) | Payload | Who broadcasts |
|---|---|---|
| `client/aiCapabilities` | `{ aiAvailable, computeRank, batteryPercent }` | each phone → match host |
| `host/aiDirectorAssignment` | `{ directorPeerId }` or `null` | match host → all |
| `host/aiChallengeRound` | a **validated** `GeneratedChallenge` payload (`source:"ai"`, `id`, elements, answer, floors, failLine) + `roundId` | match host relays the Director's proposal after validating it locally |
| `host/aiCommentary` | `{ kind, roundId, text }` | match host relays |

### Determinism without a shared model

- The **only** device that generates is the AI Director Host — so other phones
  never need the model for *generation*. They need the model for
  *nothing*, actually: receiving an AI round is pure Dart.
- Every receiver (Apple TV + phones) runs the **same
  [[AI Challenge Validator]]**; because validation is deterministic, either
  all ends agree it's playable or the match host declares the round bad
  (`roundError`) and falls back to a seeded scripted round. A "bad round" is a
  *round-level* decision (new round), never a crash and never a mid-round
  change.
- Scripted seeded rounds keep using today's `{ challengeId, seed }`
  `ROUND_START` tuple ([[Multiplayer Challenges]]) — no change there.
- `roundId` ties AI rounds and AI commentary together; commentary for a round
  is generated *by the same Director* (it owns the room's recent-lines dedupe
  — [[AI Commentary]]).

### Latency

The Director Host prefetches into its own cache ([[Pre-generation Cache]])
for the **next** round while the current one plays, so `host/aiChallengeRound`
is ready when the match arrives at the next beat. If the cache underflows, the
match host serves a seeded scripted round — the round *plays*, nobody waits.
The one generation-in-flight rule and the budget table
([[Performance and Resource Budgets]]) apply to the Director Host exactly as
to single-player.

## Scope cuts

- No cross-session AI memory; the Director Host's profile is its own player's
  ([[Player Telemetry and Adaptive Difficulty]]), and profiles are **never
  exchanged** between phones.
- The TV's on-screen text (roasts, scores) stays sourced from the *static*
  pools in v1 for the TV chrome; only round delivery + match commentary are
  AI-capable kinds ([[AI Commentary]] → kinds `elimination`, `finalRound`,
  `winner`, `loser`, `closeMatch`).
- If both a capable and an incapable phone are in a match, the incapable
  phones simply receive AI rounds like everyone else — capability is only
  needed to *be* the Director, never to *play*.

## Protocol impact

All four messages above are **additive** kinds in the versioned JSONL
contract. v1 peers ignore unknown message kinds by design
([[Multiplayer Protocol]]), so a match mixing a Director Host with an older
client keeps working scripted. The [[Multiplayer Development]] simulation
harness gets goldens for the AI message kinds ([[Testing and Evaluation]]).

## Related

- [[Dynamic AI Director]] / [[Pre-generation Cache]]
- [[Multiplayer Protocol]] / [[Multiplayer Architecture]] / [[Multiplayer Gameplay]]
- [[AI Commentary]] / [[AI Challenge Generation]] / [[AI Challenge Validator]]
- [[Feature Flags]] — `aiMultiplayerDirectorEnabled`