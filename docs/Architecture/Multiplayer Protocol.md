---
tags: [architecture, multiplayer, protocol, contract]
updated: 2026-09-11
---

# Multiplayer Protocol

The **single source of truth** for how the tvOS host and the Flutter mobile
controllers talk. Both ends implement this exact contract; the tvOS app does
**not** share Flutter UI code but **must** share this protocol (see
[[Multiplayer Host (tvOS)]] and [[Multiplayer Client (Mobile)]]).

> Rule: a protocol change without updating this note is an incomplete change
> ([[Documentation Rules]]). The versioned `protocolVersion` field lets old
> apps keep talking when this contract evolves.

## Guiding principles

1. **The host is authoritative.** It owns room, players, challenges, timing,
   validation, scores, eliminations, winner. Clients never award themselves
   points and never decide state ([[Multiplayer Architecture]]).
2. **Small JSON over a local TCP socket.** Every message is one JSON object,
   UTF-8, one per line (JSONL) so each side can read a frame with a single
   line parse. No message framing beyond the newline. Keeps both a Dart client
   and a Swift host trivial to implement and debug.
3. **Versioned and forward-tolerant.** `protocolVersion` is carried on every
   connect; a mismatched version gets a clean `REJECTED` instead of a crash.
   Unknown fields are ignored; unknown `type` values are ignored (or answered
   with the relevant `ERROR`). This is what makes raising the player cap at 8
   later ([[Multiplayer Product]]) easy.
4. **No wall-clock only.** Rounds carry an authoritative `startAt` epoch plus a
   `durationMs`; the host also stamps a monotonic `sentMs`. Clients derive
   "now" from these, not from their own clock, to tolerate latency.

## Transport & discovery

- **Transport:** plain TCP listened on by the host. `Network.framework`
   (`NWListener`/`NWConnection`) on tvOS and Swift. On Flutter a raw
   `dart:io` `Socket` client is preferred over a WebSocket package because the
   host is a plain TCP server — no new dependency ([[Getting Started]]).
- **Discovery:** host advertises Bonjour service `_ays-party._tcp` on the
   local network, with an `instance name` of the room code (e.g.
   `7F4K._ays-party._tcp`). Mobile can either scan for it or, more reliably on
   the QR path, resolve the host from the deep link (below).
- **Security on LAN:** the broadcast is plaintext. Room codes are short and the
   service is gone the moment the tvOS app quits ([[Multiplayer Product]]).
   No secrets travel; nothing is sensitive. This is acceptable for a local
   party game — see [[Decision Log]].

## Rooms and deep links

- **Room code:** short, human-typed-as-fallback, e.g. `7F4K`. Generated
   randomly at host boot; sufficiently random to avoid accidental collisions
   ([[Multiplayer Product]]).
- **QR deep link (universal scheme):** `areyoustupid://join?room=7F4K`.
   The QR encodes this URL. Scanning opens the Flutter app into the join flow.
- **Resolving the host from the code:** a room code alone does not carry the
   host's IP. Flow is: scan → app opens → app asks the Bonjour resolver for a
   service whose instance name equals the room code, then connects to that
   host. When Bonjour resolution is slow or unavailable the lobby also offers
   manual `ENTER ROOM CODE`, and the host always shows the raw code under the
   QR as a fallback ([[Multiplayer Product]]).

## Version

`protocolVersion: 1` on every connection handshake (`HELLO`).

## Message vocabulary

`type` is a simple Upper-`SNAKE_CASE` string. Target(s) beside the core one may
be absent. `ts` = local monotonic ms where the message was sent.

```
Message := { "protocolVersion": int,
             "type":             string,
             "ts":               int,
             ... per-type fields }
```

### Lifecycle

| type | sender → | payload | notes |
|---|---|---|---|
| `HELLO` | client → host | `{ protocolVersion, appName, appVersion }` | first message after TCP connect |
| `HOST_HELLO` | host → client | `{ protocolVersion, hostName, roomCode, maxPlayers, protocolFeatures[] }` | host greets; on mismatch send `REJECTED` instead |
| `REJECTED` | either → | `{ reason, protocolVersion }` | version or policy mismatch; connection should close |
| `JOIN_ROOM` | client → host | `{ playerName, emoji }` | request to join; host replies `PLAYER_JOINED` or `ERROR` |
| `PLAYER_JOINED` | host → client | `{ selfClientId, roomId, players[] }` | full current player list snapshot, incl. self |
| `LEAVE_ROOM` | client → host | `{}` | explicit leave; host then broadcasts `PLAYER_LEAVE` |
| `PLAYER_LEAVE` | host → clients | `{ playerId, reason }` | `left` or `disconnected`; removes from lobby/roster |
| `PLAYER_READY` | client ↔ host | `{ playerId, ready }` | toggle ready state |
| `PLAYER_READY_ROSTER` | host → clients | `{ players[] }` | ready-state broadcast (lobby refresh) |
| `START_GAME` | host → clients | `{ mode, config }` | only sent when ≥2 ready |
| `PLAYER_DISCONNECTED` | host → clients | `{ playerId }` | in-match disconnect, grace window applies (below) |
| `PLAYER_RECONNECTED` | host → clients | `{ playerId }` | grace-window reconnect restored state |
| `GAME_END` | host → clients | `{ mode, results[], winnerId }` | final; clients render result + share |

### Rounds

| type | sender → | payload | notes |
|---|---|---|---|
| `ROUND_START` | host → clients | `{ roundId, challengeId, seed, startAt, durationMs, config }` | the **same** challenge for every player, from one seed; `config` carries e.g. `{ "level": N }` |
| `ROUND_COUNTDOWN` | host → clients | `{ roundId, atMs, state }` | `state`: `READY` / `GO`; `atMs` = host monotonic when it fires |
| `PLAYER_ACTION` | client → host | `{ playerId, roundId, action, correct, reason?, note?, clientTimestampMs }` | raw input **and** the client's own verdict — the host trusts `correct`/`reason`/`note` rather than re-judging (design change, see [[Decision Log]] and the note on `PlayerAction` in `lib/multiplayer/protocol/protocol.dart`). `action` is `{ kind: "tap", targetId?, index? }` (null `targetId` = background) or `{ kind: "count", count }` for counting families (see below) — informational on the wire now, not judged |
| `ROUND_RESULT` | host → each client | `{ roundId, correct, reason, scoreDelta, actionReceivedMs }` | per-player private result; also drives lives/elimination |
| `ROUND_RESULTS` | host → clients | `{ roundId, results[] }` | aggregated reveal for the TV + cross-phone standings |
| `ROUND_END` | host → clients | `{ roundId, ... }` | bookend; clients lock accuracy/points, TV shows NEXT ROUND |
| `PLAYER_ELIMINATED` | host → clients | `{ roundId, playerId, livesLeft }` | broadcast on reaching 0 lives |
| `PLAYER_SCORE` | host → clients | `{ playerId, mode, score, lives, standing }` | live scoreboard patch |

### Client / host errors

| type | sender → | payload |
|---|---|---|
| `ERROR` | either → | `{ code, detail }` (e.g. `ROOM_FULL`, `ROUND_CLOSED`, `DUPLICATE_ACTION`, `BAD_MESSAGE`) |

### AI Director (additive, [[Multiplayer AI Director]] — real end-to-end since Phase 8)

| type | sender → | payload | notes |
|---|---|---|---|
| `AI_CAPABILITIES` | client → host | `{ aiAvailable, computeRank, batteryPercent }` | once, after connecting; host remembers it per seat |
| `AI_DIRECTOR_ASSIGNMENT` | host → clients | `{ directorPeerId }` or omitted (`null`) | the Director election result |
| `AI_ROUND_PROPOSAL` | client → host | `{ roundId, proposal }` | Director only; `proposal` is the Director's own validated `ChallengeProposal` wire JSON, opaque to the protocol layer |
| `AI_CHALLENGE_ROUND` | host → clients | `{ roundId, proposal, startAt, durationMs }` | relayed as-is, trusted the same way `PLAYER_ACTION.correct` is — opens an AI-authored round instead of `ROUND_START`'s `{challengeId, seed}` pick, since there's no shared generator to replay from a seed |
| `AI_COMMENTARY_PROPOSAL` | client → host | `{ kind, roundId, text }` | Director only |
| `AI_COMMENTARY` | host → clients | `{ kind, roundId, text }` | relayed as-is |

## Round synchronization contract

- Host builds **one** challenge from `{ challengeId, seed }`, deterministically,
   and sends `ROUND_START` to every client ([[Multiplayer Challenges]]).
- `startAt` is a shared epoch chosen by the host. Clients begin the countdown
   at `max(0, startAt − now)` using `ROUND_COUNTDOWN`, then render the
   instruction at `startAt`.
- A `PLAYER_ACTION` that arrives after the host's own timeout for that round is
   ignored with `ROUND_CLOSED`; a missing `roundId` or a duplicate action for
   the same `roundId`+`playerId` is answered `DUPLICATE_ACTION` / `BAD_MESSAGE`.
- The host never trusts the client's `clientTimestampMs` for correctness — it
   is used only for the reaction-time tie-break / bonus, cross-checked against
   the host's `actionReceivedMs`.
- **The client judges, the host trusts it.** `PartyChallengeRunner`
   (`lib/multiplayer/engine/party_challenge_runner.dart`) drives the real
   `Challenge` for the round — the same engine single-player uses — through
   individual taps exactly like the on-screen renderer shows them (counting
   families like `tap_twice` / `tap_exactly_n` are driven tap-by-tap too, not
   pre-committed as a final count; the `Challenge` itself tracks the running
   total and its own settle grace window). Whatever it decides (`pass`/`fail`)
   becomes the `PLAYER_ACTION`'s `correct`/`reason`/`note` — one message per
   player per round still holds (a duplicate is answered `DUPLICATE_ACTION`),
   it just now carries a verdict instead of raw input the host re-derives.
   A round also closes the moment every alive seat has answered, without
   waiting out the full timer ("no downtime," [[Game Design Pillars]]).
- Clients keep rendering the same `ChallengeView` as the host's canonical
   view for the round id; they do not regenerate it ([[Multiplayer
   Challenges]]).
- On a grace-window reconnect the host re-sends `PLAYER_JOINED` (full roster,
   `selfClientId` = the restored seat) to the reconnecting client **and** then
   broadcasts `PLAYER_RECONNECTED` to the room — the reconnected phone learns
   who it is again before gameplay continues.

## Message-size budget

Keep messages under ~256 bytes in the happy path. `ROUND_START` includes the
challenge `config`, which is the only larger message and is still under
a few hundred bytes for a 4-button grid. `players[]` arrays scale with room
size — capped at 8, so never big. If a message is big, compress later, not now
([[Decision Log]]).

## Compatibility notes

- A client that doesn't understand a `type` ignores it and waits — new host
   features degrade gracefully on old clients.
- The host gatekeeper is the only authority on version. When `protocolVersion`
   differs, it sends `REJECTED` and closes; it does **not** try to guess a
   common subset for v1 (that's a future concern once >1 version exists).
- Everything here is loose-coupled to UI on purpose: [[Multiplayer
   Architecture]] routes messages to the engine, and any view reads engine
   state. This is what lets the Flutter app and the Swift host both speak it
   without sharing code.

## Related

- [[Multiplayer Architecture]] — why the host is authoritative, the topology
- [[Multiplayer Host (tvOS)]] — the Swift/NWListener implementation
- [[Multiplayer Client (Mobile)]] — the Flutter controller implementation
- [[Multiplayer Challenges]] — the seeded challenge contract
- [[Multiplayer Gameplay]] — modes, rounds, scoring on top of this wire