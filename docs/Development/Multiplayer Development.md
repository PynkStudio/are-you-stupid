---
tags: [development, multiplayer, testing, roadmap]
updated: 2026-09-07
---

# Multiplayer Development

How the party mode gets built and tested. Existing single-player flow,
services and rendering are **not** rewritten ([[Architecture Overview]]); the
multiplayer slice is additive ([[Multiplayer Architecture]]). Built in the
[[Getting Started]] environment plus a new `tvos/` Swift target.

## Development order (do not skip ahead)

### Phase 1 — Deterministic challenge generation (foundation)
Refactor the challenge path so a template can be built from
`{ challengeId, seed }` deterministically, without changing single-player
behaviour ([[Multiplayer Challenges]]).
**Status: ✅ landed** (Dart). `lib/challenges/registry.dart` ships
`templateById(id)` and the canonical `buildFromSeed({challengeId, seed,
level, locale})`; `test/challenge_determinism_test.dart` proves the same
tuple → identical `ChallengeView` across every template. Cross-language
determinism (the Swift host in Phase 4) stays an open decision — [[Decision
Log]].

### Phase 2 — Protocol + local host/client networking abstraction
Port [[Multiplayer Protocol]] to a pure-Dart layer (`lib/multiplayer/`) and a
Swift mirror. Host + client engines speak the same contract headless.
**Status: ✅ landed (Dart).** `lib/multiplayer/` ships the codec + every wire
message (`protocol/protocol.dart`), the in-memory transport
(`networking/party_transport.dart`), the client session/state/controller
(`engine/party_session.dart`, `engine/party_state.dart`,
`engine/party_controller.dart`) and the authoritative **host reference**
(`test/support/party_host_reference.dart` — the in-process stand-in for the
future Swift host, so the rules are provable before real sockets exist). The
Swift protocol mirror (`tvos/`) is a carve-out of this phase — see below.

**Test suites landed** (`test/multiplayer/`, headless, no widgets):
`protocol_codec_test.dart` (lossless round-trip incl. `PartyAction` tap/count,
unknown `type`/fields tolerated, malformed → `DECODED_MALFORMED`),
`room_lifecycle_test.dart` (version `REJECTED`, gatekeeper malformed/unknown-type tolerance, join/roster/self-id, `ROOM_FULL` at capacity, leave, ready propagation, <2-ready start guard), `round_sync_test.dart` (same seed → same `ChallengeView` across
clients, countdown READY/GO, count-action judging, LSS lives/elimination/
sole-survivor `GAME_END`, Battle base score + exact speed-bonus split
150/125), `reconnect_test.dart` (grace-window hold + state restore, expiry
prune, outside-window reject, stale/duplicate/closed-round action
validation) and `simulation_test.dart` (full roster + a 4-player LSS game
run to a sole survivor in one process). All driven by the `PartyHarness` /
`SimClient` test double in `test/multiplayer/support/sim.dart`.

The `tvos/` Swift mirror (a `swift package` — module `AYSProtocol`,
`Sources/AYSProtocol/ProtocolModel.swift`) mirrors the Dart model + JSONL
codec 1:1 and is cross-checked by **23 `swift test` cases** against golden
fixtures emitted from the Dart codec
(`tool/gen_protocol_fixtures.dart` → `tvos/Tests/AYSProtocolTests/Fixtures/
messages.golden.jsonl`). Regenerate fixtures with
`dart run tool/gen_protocol_fixtures.dart`, then `swift test` from `tvos/`
(see "Protocol-echo" under tests below).

### Phase 3 — Multiplayer joining in the Flutter app
MULTIPLAYER entry point, scan/join/roster screens ([[Multiplayer Product]]
copy), host discovery.

### Phase 4 — Native tvOS host/display app (+ macOS board host)
SwiftUI host implementing the protocol, QR generation, Bonjour advertising,
lobby + round + results UI ([[Multiplayer Host (tvOS)]]). The **same host
binary also ships as a macOS app**: on the Mac it is **board-only** (host +
display; no local controller, no direct play on the Mac itself — the person
running the Mac plays on their phone like everyone else), with an **AirPlay
button** to mirror the board to another screen. The tvOS and macOS hosts
share one host core; see [[Decision Log]].

### Phase 5 — Synchronized gameplay
`ROUND_START` broadcast, countdown sync, input collection, host judging,
`ROUND_RESULTS`, lives/elimination groundwork.

### Phase 6 — Last Stupid Standing
3 lives, eliminations, winner animation, spectate mode.

### Phase 7 — Stupid Battle
Points, per-round standings board, final results + winner, score sharing.

### Phase 8 — QR joining + polished lobby
QR deep-link → join ([[Multiplayer Product]]); roster editing, player count,
grace-period reconnects.

### Phase 9 — TV animations, humor, result screens
Humour lines ([[Multiplayer Gameplay]]), winner card, share card, rematch.

### Phase 10 — Real-device validation
2, 4 and 8 physical devices on the same Wi-Fi. Verify: QR scan latency,
discovery reliability, round-lock synchronization across phones, TV
presentation readability, disconnect/rejoin, rematch speed.

## Test strategy

Same culture as [[Testing]]: core logic headless, then the simulation harness,
then the live-debug passes.

### Unit / contract suites (Flutter, pure Dart)

- **Protocol round-trip** — every message (de)serializes losslessly; unknown
  `type` ignored; `protocolVersion` mismatch → `REJECTED`.
- **Room lifecycle** — create room, join, leave (via `PLAYER_LEAVE` and via
  timeout), grace-window reconnect restores state, max player count enforced
  (2..8), a 2nd-join to a full room → `ROOM_FULL`.
- **Synchronization** — two clients fed the same `ROUND_START` render the
  identical `ChallengeView` (same `challengeId`, seed, level, duration).
- **Scoring / lives / elimination / winner** — per-mode rules from
  [[Multiplayer Gameplay]]: point correctness, lives decrement, elimination at
  0 lives, sole-survivor determination, `GAME_END` standings order.
- **Action validation** — duplicate `PLAYER_ACTION` → `DUPLICATE_ACTION` and no
  score; invalid/malformed message → `BAD_MESSAGE`; action after round
  timeout → `ROUND_CLOSED`.
- **Reconnect** — state preserved across a grace-window reconnect; seats
  dropped only after the window.
- **Malformed network messages** — garbage bytes, oversized frames, truncated
  JSONL: host stays up and answers `ERROR`.

### Simulation harness (host reference)

A single in-process host reference exposes the same protocol messages the
Swift host will. Tests instantiate **2–8 fake `PartySession` clients** that:

- join with a name/emoji, set READY;
- receive `ROUND_START` and either answer correctly, incorrectly, or
  **not at all** (timeout — the important elimination/zero-score case);
- send duplicate/late/garbage actions to confirm the host's rejection.

The harness proves the protocol and host rules before any real sockets or the
Swift app exist, and is the reference the `tvos/` host must pass against.

### tvOS (Swift) tests

- `RoomHost`/`RoundOrchestrator`/`ScoreKeeper` unit-tested without a network
  or UI (inject a listener abstraction).
- A protocol-echo test asserts the Swift `ProtocolModel` passes the
  harness round-trip fixtures (shared golden JSON emitted from the Flutter
  side).

### Live runs

Per-Phase manual pass on 2/4/8 real devices; plus the [[Release Checklist]]
gate (`flutter analyze` clean, `flutter test` green, docs current).

## Acceptance

Per [[Multiplayer Product]] success criteria; the simulator makes the rules
provably correct early, and only the real-LAN pass (Phase 10) validates the
wire/QR/Bonjour physics.

## Related

- [[Getting Started]] — base toolchain (Flutter 3.47+, Xcode 26+) + `tvos/`
- [[Testing]] — the single-player suites this extends
- [[Multiplayer Protocol]] — fixture source of truth for both test sides
- [[Multiplayer Challenges]] — the deterministic-build contract Phase 1 lands
- [[Multiplayer Host (tvOS)]] / [[Multiplayer Client (Mobile)]] — the two ends