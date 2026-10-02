---
tags: [architecture, multiplayer, client, flutter]
updated: 2026-09-11
---

# Multiplayer Client (Mobile)

The controller app: the **existing** Flutter application gains a multiplayer
entry point, join flow, and an in-game "controller" screen. It is deliberately
thin — a local renderer + input sender on top of the host's authority
([[Multiplayer Architecture]]). The single-player experience is untouched.

## What the client does and doesn't do

**Design change, see [[Decision Log]] and the note on `PlayerAction` in
[[Multiplayer Protocol]]:** the client *does* judge answers now — it used
not to. It does **not** generate challenges (the host still picks
`{ challengeId, seed, level }` and pushes it via `ROUND_START`), does **not**
award itself points or lives, and does **not** decide rounds or the winner —
those stay entirely host-authoritative. But content judging — "was this tap
correct" — moved here: `PartyChallengeRunner`
(`lib/multiplayer/engine/party_challenge_runner.dart`) drives the exact same
`Challenge` engine single-player uses (built from the host's
`{ challengeId, seed, level }` via `buildFromSeed`, identical to what the
host would have built if it still rebuilt anything) and reports the verdict
in the `PLAYER_ACTION` it sends. The host trusts that verdict rather than
re-deriving it — the deliberate trade-off is that a modified client could
self-report "always correct," accepted for a local, in-person party game
where porting 39 templates' judging logic (much of it genuinely
time-dependent — moving buttons, color shifts, memory recall) into a second
Swift implementation was the alternative. The client:

- renders the current challenge + its local feedback/feedback flash;
- **runs** the current challenge (`PartyChallengeRunner`, driven by a real
  `Ticker` in `mp_game_screen.dart` — the same pattern single-player's
  `game_screen.dart` uses for `GameEngine.tick`) and judges its own input;
- collects taps → forwards them into the runner, which sends the resulting
  `PLAYER_ACTION` (verdict included) once it settles;
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

Phase 2 shipped the headless core; Phase 3 added the widget layer + real
transport + discovery. See [[Multiplayer Development]] for exactly what's
verified vs. still unreachable without a real host (Phase 4).

```
lib/multiplayer/                    pure-Dart layer (no widgets) — landed (Phase 2)
├── protocol/protocol.dart          mirrors [[Multiplayer Protocol]] (Dart models + JSONL codec)
├── engine/party_session.dart       connection lifecycle + state machine; also owns the open
│                                  round's PartyChallengeRunner (starts it on GO, stops it on
│                                  ROUND_END) and exposes `tick(elapsed)` for the UI to drive
├── engine/party_challenge_runner.dart  drives one round's Challenge to a verdict — the
│                                  design-change piece, see above
├── engine/party_state.dart         client mirror of host state for the UI
├── engine/party_controller.dart    tap → PartySession.submitTap wiring (judging happens
│                                  inside the session's runner, not here)
├── networking/party_transport.dart in-memory transport (headless tests)
├── networking/session_socket.dart  real dart:io Socket PartyTransport — landed (Phase 3)
└── networking/lan_discovery.dart   Bonjour/NSD room-code resolution (package:nsd — native
                                   NsdManager/NSNetServiceBrowser, not a raw mDNS socket;
                                   see [[Decision Log]] for why it isn't multicast_dns anymore)
                                     — landed (Phase 3), nothing to discover until
                                     Phase 4's host advertises
└── ai/party_ai_director.dart       the elected phone's [[Multiplayer AI Director]] runtime
                                    (Phase 8) — inert on every other phone until named Director;
                                    reuses `lib/ai/`'s AppleAIService/ChallengeValidator/
                                    buildFromProposal pipeline, pushes results over the wire
                                    instead of into a local cache

test/support/party_host_reference.dart  in-process host authority for the
                                    simulation harness (stands in for the Swift host);
                                    also reused real-time by tool/dev_multiplayer_host.dart

lib/services/multiplayer_profile.dart  name/emoji/stats, SharedPreferences — landed (Phase 3)

lib/ui/screens/multiplayer/         widget layer (controller UX) — landed (Phase 3)
├── mp_common.dart                  MpBackground / MpAvatar / MpTextField / leaveAndExit
├── mp_home_screen.dart             MULTIPLAYER tile landing / in-app QR scan / enter code
├── mp_join_screen.dart             resolve room → connect → name + JOIN + waiting state
├── mp_lobby_screen.dart            "✓ JOINED … waiting for players" + roster + ready toggle
├── mp_game_screen.dart             controller ChallengeView + input (ChallengeRenderer reused);
│                                  owns the Ticker that drives PartySession.tick each frame
├── mp_result_screen.dart           standings + share
└── mp_disconnect_view.dart         host-disconnected / rejected overlay
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