---
tags: [architecture, multiplayer, tvos, macos, host]
updated: 2026-10-02
---

# Multiplayer Host (tvOS)

The board side of the party mode. A **separate, lightweight native app written
in Swift + SwiftUI**. It is the game master / display; it owns every piece of
authoritative state ([[Multiplayer Architecture]]). The same host binary ships
for **tvOS and macOS** — on the Mac it runs **board-only** (host + display,
no direct play — see [[Multiplayer Product]] and below).

## macOS board host (no direct play) + AirPlay

The **same native host target also runs on macOS**, and that Mac build is the
user's "big-screen host" when they don't have an Apple TV:

- **Board-only by design**: the Mac hosts rooms, owns the rules, renders the
  lobby/roster/rounds/results exactly like the TV. The person running the Mac
  does **not** play on the Mac — they play on their phone like everyone else
  ([[Multiplayer Product]] → phone-first). This keeps Mac and TV feature-identical
  with one shared host core (`Host/` Graph — see structure below) instead of a
  half-baked local controller.
- **AirPlay button**: the macOS host shows a mirror button that projects the
  board (the same SwiftUI presentation the TV renders natively) to another
  screen via AirPlay, for groups gathered around a regular monitor or a big
  screen. On tvOS there is no mirror button — the board *is* the primary
  output.
- The protocol, authority rules, scoring and UI are shared unchanged between
  the two targets; [[Decision Log]] records the scope call.

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

## Structure (Swift)

Two Swift Package targets inside `tvos/` (`AYSProtocol`, `AYSHostCore`) plus,
now, an actual generated Xcode project (`AYSHost.xcodeproj`, via
`xcodegen generate` from `tvos/project.yml`) with two app targets —
`AYSHost-tvOS` and `AYSHost-macOS` — that both build the same `App/` + `UI/`
SwiftUI sources against the package as a local dependency. `project.yml` is
checked in; `AYSHost.xcodeproj` is generated output (regenerate with
`xcodegen generate` from `tvos/` after touching `project.yml`).

```
tvos/
├── Package.swift                  AYSProtocol + AYSHostCore targets, platforms: macOS 13 / iOS 16 / tvOS 16
│                                  (needed for `#isolation`/checked continuations — see [[Decision Log]])
├── project.yml                    xcodegen spec — two app targets, one local package dependency
├── TVResources/
│   └── Assets.xcassets            "App Icon & Top Shelf Image.brandassets" (App Icon small/large
│                                  layered imagestacks, Top Shelf Image + Wide); wired into
│                                  `AYSHost-tvOS` only via `ASSETCATALOG_COMPILER_APPICON_NAME` in
│                                  `project.yml` — see [[Decision Log]]
├── App/
│   └── AYSHostApp.swift           @main SwiftUI App/Scene, shared by both targets
├── UI/                            shared SwiftUI board UI (tvOS + macOS, `#if os()` only where they
│                                  genuinely differ — the AirPlay button, window sizing)
│   ├── HostViewModel.swift        wires RoomHost + NWListenerServer + QRGenerator to SwiftUI via
│                                  RoomHost.onBroadcast; owns the room code and BoardScreen state
│   ├── RootView.swift             LOBBY -> ROUND -> RESULTS -> GAME_END, off HostViewModel.screen
│   ├── LobbyView.swift            room code, join QR, roster, START GAME (>=2 ready)
│   ├── RoundView.swift            GET READY / GO countdown display (round auto-closes on deadline)
│   ├── ResultsView.swift          per-player ✓/✕ + score delta, NEXT ROUND
│   ├── GameEndView.swift          standings + winner + REMATCH (same room, per docs/Gameplay/
│                                  Multiplayer Gameplay.md "instant rematch back into the lobby")
│   ├── AirPlayButton.swift        macOS-only `AVRoutePickerView` wrapper (board-only Mac host)
│   ├── RoundDurationProvider.swift  the App target's `ChallengeJudge` — resolves a duration
│                                  only, now that content judging moved to the client entirely
│                                  (see "Challenge judging" below); looks up each template's real
│                                  `maxDurationMs` from `AYSChallengeCatalog` (see [[Decision Log]])
│   ├── RoomCode.swift             random 4-char room code, ambiguous characters excluded
│   └── Theme.swift                dark ground, bold uppercase type — no bundled assets
├── Sources/
│   ├── AYSProtocol/                mirrors [[Multiplayer Protocol]] models — landed (Phase 2)
│   └── AYSHostCore/                 room/round/scoring authority — landed (Phase 4, partial)
│       ├── HostClock.swift          monotonic ms seam (manual for tests, wall-clock for real use)
│       ├── HostTransport.swift      line-based duplex seam (in-memory for tests, NWConnection for real)
│       ├── NWConnectionTransport.swift  the real HostTransport — Network.framework, JSONL framing
│       ├── NWListenerServer.swift   TCP accept loop + Bonjour advertising (`Net/`, landed)
│       ├── QRGenerator.swift        CIQRCodeGenerator join-link QR, no assets (`QR/`, landed)
│       ├── ChallengeJudge.swift     duration-only now — see "Challenge judging" below
│       ├── ChallengeCatalog.swift   id/minLevel/weight/starter, mirrors [[Challenge Catalog]] (data only)
│       ├── ChallengePicker.swift    weighted picker on that data — doesn't need to match Dart's sequence
│       └── RoomHost.swift           room lifecycle, gatekeeper, rounds, scoring, elimination, GAME_END,
│                                    the AI Director election/relay/failover (`electDirector`,
│                                    `startNextRound`/`startAiRound`, `pendingAiProposal` — see
│                                    [[Multiplayer AI Director]] Phase 8) — a faithful port of
│                                    test/support/party_host_reference.dart plus the AI additions, plus
│                                    an `onBroadcast` hook so a local UI observes the same events a
│                                    connected phone gets, without a fake loopback client
└── Tests/
    ├── AYSProtocolTests/            golden-fixture cross-check against the Dart codec
    └── AYSHostCoreTests/            AIDirectorTests.swift (election, relay, failover — [[Decision
                                     Log]]) plus the pre-AI suites below and NetworkTests.swift
                                     (Bonjour naming unconditionally, real-socket cases opt-in only)
                                     and QRGeneratorTests.swift
```

**Verified live, this session:** `AYSHost-macOS` builds (`xcodebuild ...
-scheme AYSHost-macOS`) and runs — screenshotted with a real room code, a
real scannable QR, `NWListenerServer` actually bound and listening
("LISTENING ON PORT ...") and the AirPlay picker button, all with zero
manual intervention (no permission dialog blocked the local bind — unlike
the bare `swift test` CLI binary, a real signed `.app` with
`NSLocalNetworkUsageDescription` declared gets the normal one-time-if-ever
OS prompt instead of the synchronous XPC hang documented below and in
[[Decision Log]]). **Correction:** that first pass's "real Bonjour
advertising" claim was wrong — the port being open only proves the TCP
listener bound, not that anything was actually discoverable. A real-device
test (Mac host + iPhone/iPad client) right after confirmed the room never
showed up: `NSBonjourServices` had silently never made it into the built
Info.plist at all (an `INFOPLIST_KEY_*` scalar setting can't express the
array Bonjour needs — see [[Decision Log]] for the full bisect, including a
second xcodegen bug in the array-valued `info.properties` fix attempt).
Now fixed via a real static `tvos/App/Info.plist` (`INFOPLIST_FILE:
App/Info.plist`), confirmed with `PlistBuddy` that the built app carries
`NSBonjourServices` as a real array — but **actual cross-device discovery
still hasn't been re-verified against a real phone** as of this note; only
the Info.plist content is confirmed correct.

`AYSHost-tvOS` is the same sources compiled for tvOS — confirmed building
(`xcodebuild -destination 'generic/platform=tvOS Simulator'`) and running
live on a booted `Apple TV` simulator (`xcrun simctl install`/`launch`/`io
screenshot`), same room code + QR + listening-port pattern as macOS, after
downloading the tvOS platform (`xcodebuild -downloadPlatform tvOS`, done
with the user's explicit go-ahead — see [[Decision Log]]). This
confirmation predates the `NSBonjourServices` fix above, so it proves the
shared SwiftUI code and TCP bind work on tvOS too, not that tvOS discovery
specifically works — the same open item applies here.

**What the App/UI shell does not yet have:** EliminationCard, a real winner
animation beyond a name in text, a share card, and the humor lines
([[Multiplayer Gameplay]] "Humor lines", [[Multiplayer Development]] Phase
9) — the live standings overlay landed this session (`ScoreboardView.swift`,
fed by `PLAYER_SCORE` broadcasts via `HostViewModel.standings`). It also has
no XCTest target of its own — `RoomCode`/`RoundDurationProvider` are
exercised only by building successfully and the one live screenshot above,
not by an automated suite the way `AYSHostCoreTests` covers the package
(that package-level suite does now cover the `AYSChallengeCatalog` data
`RoundDurationProvider` looks up — `ChallengeCatalogTests.swift` — just
not the App-target lookup wrapper itself).

### Net/ and QR/: landed, but real-socket tests are opt-in only

`NWListenerServer` (accepts `NWConnection`s, optionally advertises
`_ays-party._tcp` via `NWListener.service`) and `NWConnectionTransport` (the
production `HostTransport`: JSONL framing over a real socket, mirroring
`lib/multiplayer/networking/session_socket.dart`'s `SocketPartyTransport`
exactly) are both written and build cleanly. `QRGenerator` renders the join
deep link (`areyoustupid://join?room=XXXX`, matching
`mp_home_screen.dart`'s `_deepLinkRoomCode` contract exactly) to a `CGImage`
via `CIQRCodeGenerator` — no SwiftUI/UIKit/AppKit dependency, so it's usable
from tvOS, iOS and macOS alike.

**What's actually verified headless:** `BonjourServiceTests` (the instance
name / service type rule) and all of `QRGeneratorTests` (deep-link string,
deterministic output, different input → different pixels, scaling) run
every time, no network involved.

**What isn't:** the four cases in `NWConnectionTransportTests` that open a
real `NWListener`/`NWConnection` over loopback. On macOS, a plain
(unsigned/ad-hoc) command-line binary asking to *accept* inbound
connections needs the user to grant the one-time "Local Network" TCC
permission — inside an unattended shell with nobody to click Allow, the
underlying XPC call blocks *synchronously* and can wedge Swift
concurrency's entire cooperative thread pool, including unrelated
`Task.sleep` timeouts in sibling tasks. Confirmed directly this session:
`swift test` hung indefinitely (had to `kill -9` the process) the moment it
reached that code, with or without a `readyTimeout` guard on
`NWListenerServer.start` — the timeout task itself never got to run. So
these four tests check `ProcessInfo.processInfo.environment` for
`AYS_RUN_NETWORK_TESTS=1` *before* touching `Network.framework` at all, and
skip otherwise — `swift test` stays fast and green by default. Run
`AYS_RUN_NETWORK_TESTS=1 swift test` from an interactive Terminal, click
Allow on the prompt the first time, to actually exercise the real `Net/`
layer end-to-end (two `SimClient`s over real sockets through a real
`RoomHost`, to `GAME_END` — the Swift mirror of
`socket_integration_test.dart`). See [[Decision Log]] for the full story;
this is the same category of gap [[Multiplayer Development]] already flags
for `LanPartyDiscovery` and Phase 10's real-device pass — a real, properly
signed app only ever sees that dialog once.

### Challenge judging: resolved — the host never rebuilds content at all

`RoomHost` never touches challenge content directly, and now never needs
to: [[Multiplayer Challenges]]'s "Phase 4 open question" (reimplement Dart's
seeded PRNG *and* all 39 templates' judging logic in Swift, or decide the
host doesn't need to) is answered in favor of the second option. The
*client* judges its own input — `PartyChallengeRunner`
(`lib/multiplayer/engine/party_challenge_runner.dart`, Dart) drives the same
`Challenge` engine single-player uses and reports the verdict in every
`PLAYER_ACTION`. `RoomHost.onAction` builds its `JudgeVerdict` straight from
that trusted `correct`/`reason`/`note` instead of calling into a judge at
all — `ChallengeJudge` now only has one method, `spec(...)`, used to resolve
a round's *duration* (and reject an unknown `challengeId`). See the
design-change note on `PlayerAction` in [[Multiplayer Protocol]] and
[[Decision Log]] for the full reasoning and the accepted trade-off (a
modified client could self-report "always correct" — out of scope to defend
against for a local, in-person party game).

`AYSHostCoreTests` still injects `FakeChallengeJudge` for `spec(...)` (fixed
duration, optionally an unknown-id set) — real test doubles like
`SimClient.tap`/`commitCount` now take an explicit `correct:` parameter
directly, mirroring how a real phone's `PartyChallengeRunner` would have
computed it, rather than deriving it through a judge.

Picking which `challengeId` to play next is a *different*, already-settled
question: since only the host picks (clients just render whatever
`ROUND_START` says), `ChallengePicker` doesn't need to match Dart's sequence
at all — ordinary Swift randomness over the ported catalog metadata is
enough.

### Where the app shell itself stands

**Landed.** `tvos/project.yml` (`xcodegen`) generates `AYSHost.xcodeproj`
with `AYSHost-tvOS` and `AYSHost-macOS` app targets, both building the
shared `App/` + `UI/` SwiftUI sources against the `AYSProtocol`/`AYSHostCore`
package as a local dependency — `RoomHost` and the rest of the package no
longer need to stay Xcode-project-free to be buildable, and the app shell
is real, not aspirational. `AYSHost-macOS` is confirmed building and
running (see the "Structure (Swift)" section above for the live-verified
details); `AYSHost-tvOS` compiles the identical sources for tvOS and is
blocked only on whether this machine has the tvOS platform installed, not
on any missing capability — see [[Decision Log]] for what changed (this
session found `xcodegen`/`tuist` already installed alongside Xcode 26,
which is what made this possible; a prior pass had incorrectly concluded
no Xcode project could be produced at all).

### App Store distribution (2026-10-02)

Both host targets ship **inside the phone app's App Store record** —
universal purchase, one product page for iPhone + Apple TV + Mac — so
`project.yml` sets `PRODUCT_BUNDLE_IDENTIFIER = com.ays.areYouStupid` (the
iOS Runner's id) for both, `PRODUCT_NAME = "Are You Stupid"`,
`DEVELOPMENT_TEAM = G48384PHQK`, automatic signing, `MARKETING_VERSION
1.0.0`. A player who owns the game on iPhone sees it offered on their
Apple TV without searching. See [[Decision Log]].

- **tvOS icon** — `TVResources/Assets.xcassets` ("App Icon & Top Shelf
  Image" brand assets) is compiled into `AYSHost-tvOS`.
- **macOS icon** — `MacResources/Assets.xcassets/AppIcon.appiconset`,
  generated from the repo-root `icon.png` on Apple's Mac grid (824 pt
  rounded rect + shadow on a 1024 canvas, 16–1024 px).
- **macOS App Sandbox** (required by the Mac App Store) —
  `App/AYSHost-macOS.entitlements`, generated by xcodegen:
  `app-sandbox`, `network.server` (the phones connect to the host's
  listener), `network.client`.
- `App/Info.plist` adds `CFBundleDisplayName`,
  `LSApplicationCategoryType = public.app-category.casual-games` (there is no "party-games" UTI — the Mac App Store rejected it, error 90249) and
  `ITSAppUsesNonExemptEncryption = false`.

Still ahead: the tvOS remote-focus pass and Phase 10's real-device pass.

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

**Landed.** `RoomHost` is unit-tested in Swift without a UI or a real network
— `HostTransport`/`HostClock` are injectable seams (`InMemoryHostTransport`,
`ManualHostClock`), exactly the abstraction this note used to describe as a
plan. 42 `AYSHostCoreTests` cases cover the room lifecycle, round sync,
scoring (both modes, exact speed-bonus split), elimination/sole-survivor,
reconnect grace window, and the AI Director election/relay/failover
([[Multiplayer AI Director]] Phase 8), plus (unconditionally) Bonjour
instance-name rules and QR generation — see [[Testing]] for the
real-socket cases' opt-in gate.
The authoritative host rules are also cross-checked by the Flutter-side
simulation harness that speaks the same protocol ([[Multiplayer
Development]]).

A real bug turned up building this: `RoomHost.attachClient`'s connection
closures must weak-capture `self` (so a connection can never keep the whole
host alive) but strongly capture the per-connection `Connection` object
(so one connection's lifetime doesn't depend on bookkeeping elsewhere) —
getting this backwards made messages silently vanish with no error the
moment nothing else happened to hold the host. See [[Decision Log]].

## Related

- [[Multiplayer Protocol]] — the shared contract this implements
- [[Multiplayer Architecture]] — the topology and host authority rule
- [[Multiplayer Client (Mobile)]] — the Flutter controller that connects
- [[Multiplayer Gameplay]] — modes, rounds, scoring, TV presentation
- [[Multiplayer Challenges]] — how the host seeds a canonical challenge