---
tags: [architecture, multiplayer, client, flutter]
updated: 2026-09-07
---

# Multiplayer Client (Mobile)

The controller app: the **existing** Flutter application gains a multiplayer
entry point, join flow, and an in-game "controller" screen. It is deliberately
thin — a local renderer + input sender on top of the host's authority
([[Multiplayer Architecture]]). The single-player experience is untouched.

## What the client never does

It does **not** generate challenges, does **not** judge answers, does **not**
award itself points or lives, does **not** decide rounds or the winner.
Everything it renders is a mirror of host state arriving as
[[Multiplayer Protocol]] messages, or a deterministic local `ChallengeView`
built from the host's own `{ challengeId, seed }` (identical to what the host
built). It only:

- renders the current challenge + its local feedback/feedback flash;
- collects taps → sends `PLAYER_ACTION`;
- shows the join flow, lobby wait state, and result/share screens.

## Entry points

The home screen ([[Architecture Overview]]) gains a **MULTIPLAYER** tile. Two
ways in:

1. **Scan QR** — `areyoustupid://join?room=7F4K`. If the deep link opened the
   app directly, skip the scan screen and go straight to the join flow.
2. **ENTER ROOM CODE** — manual fallback, no camera needed
   ([[Multiplayer Product]]).

No account, no cloud, no network beyond the LAN ([[Game Design Pillars]]).

## Client structure (additive, pure-Dart core)

Phase 2 ships the headless core; the widget layer + transport come in Phase 3.

```
lib/multiplayer/                    NEW pure-Dart layer (no widgets) — landed (Phase 2)
├── protocol/protocol.dart          mirrors [[Multiplayer Protocol]] (Dart models + JSONL codec)
├── engine/party_session.dart       connection lifecycle + state machine
├── engine/party_state.dart         client mirror of host state for the UI
├── engine/party_controller.dart    tap → PLAYER_ACTION wiring
└── networking/party_transport.dart in-memory transport (headless tests; the
                                     real Bonjour + dart:io Socket arrive in Phase 3)

test/support/party_host_reference.dart  in-process host authority for the
                                    simulation harness (stands in for the Swift host)

lib/ui/screens/multiplayer/         NEW widget layer (controller UX) — Phase 3
├── mp_home_screen.dart             MULTIPLAYER tile landing / scan / enter code
├── mp_join_screen.dart             name + emoji + JOIN + waiting state
├── mp_lobby_screen.dart            "✓ JOINED … waiting for players" + roster
├── mp_game_screen.dart             controller ChallengeView + input
├── mp_result_screen.dart           personal result + share
└── mp_disconnect_view.dart         host-disconnected / network error states
```

The multiplayer widget layer reuses the existing [[Rendering Pipeline]]
(`ChallengeRenderer`, `TargetButton`, flash overlays) to draw the controller's
challenge — same visual language, no new rendering code.

## Profile / local persistence

On mobile, persist locally:

- **player name** (last used),
- **preferred emoji/avatar** (an optional emoji token displayed beside the
  name; auto-generated avatar if none — colored circle + initial, see
  [[Multiplayer Gameplay]]),
- **multiplayer statistics** (matches played, wins, best *least-stupid* finish),
- **settings** (reuse `SettingsManager` language/sound/haptics, [[Services]]).

All via `SharedPreferences` ([[State and Persistence]]) — no cloud.

## Join relaxation

To keep scanning snappy, the join flow restores a remembered profile when
present; the lobby auto-heals roster snapshots (`PLAYER_READY_ROSTER`) so the
player always sees current names/ready states. A player can back out to the
menu at any lobby state; leaving the room tells the host (`PLAYER_LEAVE`).

## Reconnect

On a temporary network drop the client holds the connection and, when back,
re-sends `HELLO` + the same player identity; the host restores the seat inside
the grace window (`PLAYER_RECONNECTED`, [[Multiplayer Architecture]]). If the
host quits, show `mp_disconnect_view` with an appropriate message — the match
is over, return to menu. Eliminated players stay connected to spectate; they
are never kicked.

## Ads policy

Client controllers show **no ads during any live multiplayer match**
([[Multiplayer Product]] and [[Monetization and Ads]]). Ads may only appear at
menu-return, before a new match, or after a match ends — and never inside a
round. The single-player `AdManager` policy is not disturbed.

## Testability

The pure-Dart engine/networking is headless-testable, and a **simulation
harness** runs many fake `PartySession`s against an in-process host reference
without physical devices ([[Multiplayer Development]]).

## Related

- [[Multiplayer Protocol]] — the shared contract the client speaks
- [[Multiplayer Architecture]] — topology + why clients are thin
- [[Multiplayer Host (tvOS)]] — the Swift controller counterpart
- [[Rendering Pipeline]] — the renderer the controller reuses
- [[Multiplayer Gameplay]] — what the controller shows during play
- [[Multiplayer Product]] — the player-facing flows and scope