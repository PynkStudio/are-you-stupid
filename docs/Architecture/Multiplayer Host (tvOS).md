---
tags: [architecture, multiplayer, tvos, host]
updated: 2026-09-06
---

# Multiplayer Host (tvOS)

The Apple TV side of the party mode. A **separate, lightweight native tvOS
application** written in Swift + SwiftUI. It is the game master / display; it
owns every piece of authoritative state ([[Multiplayer Architecture]]).

## Why a separate native app, not Flutter-on-tvOS

The project's Flutter stack targets Android + iOS ([[Getting Started]]).
tvOS is a different SDK surface (no UIKit the Flutter embedder assumes, TV
remote focus model, `NWListener`/Bonjour as a first-class story). Embedding the
existing Flutter app into tvOS has **no clean, officially supported path** in
this codebase. A native host is the smallest, most reliable way to deliver
`NWListener` + Bonjour + `CoreImage` QR + SwiftUI, and it can be kept
vapor-light because all game rules live behind the protocol anyway.

The tvOS app does **not** share Flutter UI code — but it **must** implement the
exact wire contract in [[Multiplayer Protocol]] (a Swift model mirroring the
Dart one). That single contract is the only coupling between the two ends.

## Responsibilities

- Boot a room: generate a random room code, advertise
  `_ays-party._tcp` (Bonjour) with the room code as instance name, listen on a
  localhost-bound TCP socket.
- Render the lobby, the join QR (`areyoustupid://join?room=7F4K`), the player
  roster with ready states, and the START GAME gate (≥2 ready players).
- Own challenges: pick `challengeId` + `seed`, build the canonical challenge,
  broadcast `ROUND_START`, run the shared countdown.
- Validate every `PLAYER_ACTION`, award points/lives, detect duplicate/late/
  malformed input, broadcast `ROUND_RESULTS`, `PLAYER_ELIMINATED`,
  `PLAYER_SCORE`, and finally `GAME_END`.
- Present the game-show UI: GET READY/3-2-1-GO, in-round reveal, live
  scoreboard, elimination cards, winner animation, humor lines
  ([[Multiplayer Gameplay]]).

It deliberately does **not** do: ad serving, account/profile, any persistence
beyond trivial local settings/match stats ([[Multiplayer Product]]).

## Suggested structure (Swift)

```
AreYouStupidTV/
├── AreYouStupidTVApp.swift      app entry
├── Game/Host/
│   ├── RoomHost.swift           room lifecycle, ownership, gatekeeper
│   ├── ChallengeMaster.swift    seed generation + canonical challenge state
│   ├── RoundOrchestrator.swift  countdown, timing, judging, result assembly
│   └── ScoreKeeper.swift        mode scoring (lives vs points), standing
├── Net/
│   ├── NWListenerServer.swift   TCP accept + per-connection read/write
│   ├── BonjourAdvertiser.swift  _ays-party._tcp advertising
│   └── ProtocolModel.swift      mirrors [[Multiplayer Protocol]] models
├── QR/
│   └── QRGenerator.swift        CoreImage CIQRCodeGenerator (zero assets)
└── UI/                          SwiftUI screens per [[Multiplayer Gameplay]]
    ├── LobbyView, JoinQRView, RosterView
    ├── RoundView, ResultView, ScoreboardView
    ├── EliminationCard, WinnerView, ShareCardView
    └── Theme.swift              mirrors the Flutter palette ([[Rendering Pipeline]])
```

## Timing precision on TV

Both the countdown and the round clock are driven by the host's **monotonic
clock** (`clock_gettime_nsec_np(CLOCK_UPTIME_RAW)` / `ContinuousClock`) and
published in `ROUND_START.startAt` + `durationMs` ([[Multiplayer Protocol]]).
The UI schedule is strict: draw the countdown numbers against the deadline, not
against per-frame drift, so every player's phone and the TV land on GO
together ([[Multiplayer Gameplay]]).

## QR generation (no assets)

The QR is generated at runtime via `CIQRCodeGenerator` from the deep link
string, rendered into a SwiftUI image. This satisfies the zero-external-assets
pillar ([[Game Design Pillars]]) — no bundled QR asset, and the code stays
human-readable under the QR as a fallback.

## Local persistence

Only `UserDefaults`-backed settings relevant to hosting: last-used host name,
optionally per-room match history. No cloud, no account ([[Multiplayer
Product]]).

## Testability story

The pure `Host/` graph (`RoomHost`, `ChallengeMaster`, `RoundOrchestrator`,
`ScoreKeeper` + `ProtocolModel`) is unit-testable in Swift without a UI or a
real network (inject an `NWListenerServer`-interface abstraction). The
authoritative host rules are also cross-checked by the Flutter-side simulation
harness that speaks the same protocol ([[Multiplayer Development]]).

## Related

- [[Multiplayer Protocol]] — the shared contract this implements
- [[Multiplayer Architecture]] — the topology and host authority rule
- [[Multiplayer Client (Mobile)]] — the Flutter controller that connects
- [[Multiplayer Gameplay]] — modes, rounds, scoring, TV presentation
- [[Multiplayer Challenges]] — how the host seeds a canonical challenge