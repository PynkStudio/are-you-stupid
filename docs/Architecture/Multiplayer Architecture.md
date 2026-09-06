---
tags: [architecture, multiplayer, overview]
updated: 2026-09-06
---

# Multiplayer Architecture

The party mode that turns the iPhone/iPad Flutter game into a 2–8 player,
controller-led, TV-hosted party game. This is a **new vertical slice** over the
existing single-player app — the single-player experience is untouched.

```
                 APPLE TV
              Native SwiftUI
                   │
             Game Host (authoritative)
                   │
        Local Network / LAN  (TCP + Bonjour)
                   │
       ┌───────────┼───────────┐
       │           │           │
     iPhone      iPhone      iPad
     Flutter     Flutter     Flutter
       │           │           │
    Player 1    Player 2    Player 3
```

## The one rule this time

**The Apple TV host is the authority. Clients are dumb terminals for input and
display.** The host owns room state, the player list, the challenge sequence,
the random seed, the current round, the countdown, validation, scores,
eliminations and the winner. Mobile clients render the current challenge,
collect taps, send `PLAYER_ACTION`s, and show local feedback — nothing else.
They never independently decide game state and never award themselves points.

This mirrors the single-player rule (`core/`/`challenges/` don't import
widgets, the renderer can't judge — see [[Architecture Overview]]) and is what
makes the wire contract the only thing both ends share.

## Where it lives

```
lib/multiplayer/            NEW pure-Dart layer, no widgets, headless-testable
├── protocol/               shared message model + (de)serialization
│   └── protocol.dart       (kept in lockstep with the Swift host)
├── engine/
│   ├── party_session.dart  client-side session: connection, state machines
│   ├── party_state.dart    client mirror of host state the UI renders
│   └── party_controller.dart  input → PLAYER_ACTION, outbound
├── networking/             transport only
│   ├── host_locator.dart   Bonjour resolution from a room code
│   ├── session_socket.dart dart:io Socket client, JSONL framing
└── …                       (all pure Dart so it's testable without widgets)
```

The tvOS counterpart is a separate, lightweight Swift target ([[Multiplayer
Host (tvOS)]]). It shares **only** the protocol contract, not Flutter code.

## Host authority and timing

- The host generates **one** challenge per round from `{ challengeId, seed }`
  and broadcasts `ROUND_START` — all clients render the same challenge
  ([[Multiplayer Challenges]]). Never does each client roll its own.
- Timing is the host's monotonic clock published in `ROUND_START.startAt` +
  `durationMs`; clients drive a countdown off it and tolerate small network
  latency rather than trusting wall-clock ([[Multiplayer Protocol]]).
- Validation happens only on the host. Duplicate/late/malformed actions are
  answered with the relevant `ERROR` and score nothing.

## Reconnect / grace window

A disconnecting player is **not** dropped from the room. The host holds the
seat for a short grace period (e.g. 15 s). If the same player identity
reconnects (same name+client id key) inside the window, their lives, score and
standing are restored (`PLAYER_RECONNECTED`). Players who left during a round
are marked eliminated/removed from that round's result but keep the TV seat.
Eliminated players stay connected to spectate — they are never kicked.

If the host quits, the match ends; the mobile app shows an appropriate
`HOST_DISCONNECTED` state. No host migration for the MVP ([[Multiplayer
Product]] and [[Decision Log]]).

## Discovery + QR joining

Two complementary paths, both offline/LAN-only:

- **Bonjour discovery:** host advertises `_ays-party._tcp` with the room code
  as its instance name. The app's lobby can auto-list live rooms.
- **Deep-link QR:** the TV shows `areyoustupid://join?room=7F4K` as a QR
  (image generated on-device — zero external assets, [[Game Design Pillars]]).
  Scanning opens the Flutter app straight into the join flow; the app resolves
  the host from the room code via Bonjour. If a saved player profile exists
  ([[Multiplayer Client (Mobile)]]), join is one tap.

Full join UX in [[Multiplayer Product]].

## State flow

Host state (parity with [[Multiplayer Protocol]] message sequence):

```
idle → lobby (players join, READY)
    → countdown (3-2-1-GO, optional shared)
    → round (ROUND_START → collect PLAYER_ACTION → judge on host)
        └─ per mode: score/lives patch; elimination broadcast on 0 lives
    → ROUND_RESULTS reveal → NEXT ROUND / final
    → GAME_END → results + winner → back to lobby for instant rematch
```

Client state mirrors this but is *driven by host messages*; the client engine
never steps its own game clock except to count down to `startAt` and render
its local `ChallengeView`.

## Testability

This layer is pure Dart by the same rule as `core/`, so every host + client
rule can be exercised headless — including a **simulation harness** that runs
many fake clients against one host in a single test process
([[Multiplayer Development]]).

## Related

- [[Architecture Overview]] — the single-player root this extends
- [[Multiplayer Protocol]] — the wire contract (the shared language)
- [[Multiplayer Host (tvOS)]] / [[Multiplayer Client (Mobile)]] — the two ends
- [[Multiplayer Gameplay]] — modes, rounds, scoring, TV presentation
- [[Multiplayer Challenges]] — deterministic, synchronized challenge seeding
- [[Multiplayer Product]] — the player-facing concept and scope
- [[Multiplayer Development]] — phases, testing, simulation harness