---
tags: [architecture, multiplayer, tvos, macos, host]
updated: 2026-10-18
---

# Multiplayer Host (tvOS)

The board side of the party mode. A **separate, lightweight native app written
in Swift + SwiftUI**. It is the game master / display; it owns every piece of
authoritative state ([[Multiplayer Architecture]]). The board UI is one
SwiftUI library (`AYSHostUI`) used by **two shells**: the native tvOS app
(`AYSHost-tvOS`) and, on the Mac, the **single Flutter macOS app**, which
opens the board in its own window when the player picks HOST ON THIS MAC
(see below).

## macOS: one app, two roles (2026-10-05)

There is **no separate Mac host app any more**. The Flutter macOS Runner
(`macos/`) is the only Mac product; it links the `AYSHostUI` package product
from `../tvos` as a local Swift package. Pressing MULTIPLAYER on macOS shows a
role chooser (`lib/ui/screens/multiplayer/mp_role_chooser.dart`):

- **PLAY ON THIS MAC** → the normal Flutter join flow, exactly as on a
  phone ([[Multiplayer Client (Mobile)]]).
- **HOST ON THIS MAC** → Dart calls `openHost` on the `ays/host_mode` method
  channel; `MainFlutterWindow.swift` opens (or re-focuses) a second
  `NSWindow` hosting `AYSHostBoardView()` — the very same SwiftUI board the
  Apple TV renders. Closing that window keeps the controller alive
  (`isReleasedWhenClosed = false`), so reopening returns to the same room.

On every other platform the chooser is skipped and MULTIPLAYER goes straight
to the join screen.

- **The board stays board-only**: the board window hosts rooms, owns the
  rules, renders the lobby/roster/rounds/results exactly like the TV; it is
  not itself a controller. Mac and TV remain feature-identical because they
  run one shared `AYSHostUI` + `AYSHostCore`.
- **AirPlay button**: the macOS host shows a mirror button that projects the
  board (the same SwiftUI presentation the TV renders natively) to another
  screen via AirPlay, for groups gathered around a regular monitor or a big
  screen. On tvOS there is no mirror button — the board *is* the primary
  output.
- **Whole controls are clickable on the Mac.** A macOS `.plain` button only
  hit-tests its label, so a background added outside the label left only the
  text clickable (2026-10-18 playtest: mode picker and START). Every lobby
  button keeps its padding/frame inside the label with a `contentShape`, so
  the full pill or card responds; tvOS keeps its `.card` focus style.
- The protocol, authority rules, scoring and UI are shared unchanged between
  the tvOS app and the Mac board window; [[Decision Log]] records both the
  original board-only call and the 2026-10-05 consolidation.

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
  `_ays-party._tcp` (Bonjour) with the room code as instance name plus a live
  TXT snapshot (device name, occupancy, capacity, state), listen on TCP.
- Render the lobby, the join QR (`https://pynkstudio.eu/ays/join?room=7F4K`), the player
  roster with ready states, and the START GAME gate (≥2 ready players).
- Own challenges: pick `challengeId` + `seed`, build the canonical challenge,
  broadcast `ROUND_START`, run the shared countdown.
- Validate every `PLAYER_ACTION`, award points/lives, detect duplicate/late/
  malformed input, broadcast `ROUND_RESULTS`, `PLAYER_ELIMINATED`,
  `PLAYER_SCORE`, and finally `GAME_END`.
- Present the game-show UI: GET READY/3-2-1-GO, in-round reveal, live
  scoreboard, elimination cards, winner animation, humor lines
  ([[Multiplayer Gameplay]]).

It deliberately does **not** do: ad serving, accounts, cloud profiles or
identity lookup. It only persists local settings/match stats and the bounded
anonymous presenter-career cache described below ([[Multiplayer Product]]).

## Structure (Swift)

Three Swift Package library targets inside `tvos/` (`AYSProtocol`,
`AYSHostCore`, and `AYSHostUI`, whose sources are the `UI/` folder) plus a
generated Xcode project (`AYSHost.xcodeproj`, via `xcodegen generate` from
`tvos/project.yml`) with **one** app target, `AYSHost-tvOS`, that is only the
`App/` entry point linking `AYSHostUI`. The Mac consumes the same
`AYSHostUI` product from `macos/Runner.xcodeproj` (local package reference
`../tvos`). `AYSHostBoardView` is the library's single public entry point.
`project.yml` is checked in; `AYSHost.xcodeproj` is generated output
(regenerate with `xcodegen generate` from `tvos/` after touching
`project.yml`).

```
tvos/
├── Package.swift                  AYSProtocol + AYSHostCore + AYSHostUI targets, platforms: macOS 13 / iOS 16 / tvOS 16
│                                  (needed for `#isolation`/checked continuations — see [[Decision Log]])
├── project.yml                    xcodegen spec — the tvOS app target, one local package dependency
├── TVResources/
│   └── Assets.xcassets            "App Icon & Top Shelf Image.brandassets" (App Icon small/large
│                                  layered imagestacks, Top Shelf Image + Wide); wired into
│                                  `AYSHost-tvOS` only via `ASSETCATALOG_COMPILER_APPICON_NAME` in
│                                  `project.yml` — see [[Decision Log]]
├── App/
│   └── AYSHostApp.swift           tvOS @main SwiftUI App/Scene showing AYSHostBoardView
├── UI/                            the AYSHostUI library: shared SwiftUI board (tvOS app + Mac board
│                                  window, `#if os()` only where they genuinely differ — the AirPlay button)
│   ├── HostViewModel.swift        wires RoomHost + NWListenerServer + QRGenerator to SwiftUI via
│                                  RoomHost.onBroadcast; owns the room code and BoardScreen state,
│                                  the round number, the standings snapshot taken when each round
│                                  opens (rank movement, heart lost this round) and per-player
│                                  `PlayerMatchStats` (display-only, feed the final awards)
│   ├── RootView.swift             public `AYSHostBoardView` (hosting) + internal `BoardScreens`
│                                  switch: LOBBY -> ROUND -> RESULTS -> GAME_END
│   ├── LobbyView.swift            animated game-show lobby: join ticket, plain brand masthead,
│                                  two-column player cards, mode picker and 2-ready party meter
│   ├── RoundView.swift            restrained live-show stage: ROUND n header, GET READY / GO +
│                                  compact top-5 standings
│   ├── ResultsView.swift          failure-first reveal: verdict, fail wall with real reasons,
│                                  eliminations, survivor strip with fastest thumb, standings ▲/▼
│   ├── GameEndView.swift          winner hero (or NOBODY SURVIVED, or IT'S A TIE for a Battle
│                                  draw with every leader highlighted), stat-backed awards, final
│                                  standings + REMATCH (same room, per docs/Gameplay/
│                                  Multiplayer Gameplay.md "instant rematch back into the lobby")
│   ├── ScoreboardView.swift       shared standings list: rank, emoji, movement, hearts/score
│   ├── AirPlayButton.swift        macOS-only `AVRoutePickerView` wrapper (Mac board window)
│   ├── RoundDurationProvider.swift  the App target's `ChallengeJudge` — resolves a duration
│                                  only, now that content judging moved to the client entirely
│                                  (see "Challenge judging" below); looks up each template's real
│                                  `maxDurationMs` from `AYSChallengeCatalog` (see [[Decision Log]])
│   ├── RoomCode.swift             random 4-char room code, ambiguous characters excluded
│   └── Theme.swift                purple stage palette, generated edge lights and broadcast chrome
│                                  — bold uppercase type, no bundled assets; `BoardCanvas` (1280×720
│                                  design canvas scaled by `unit`), `BoardHeader`, `PresenterCaption`,
│                                  `HeartsView`, `AdvanceBar`. No capsule badges ("pills")
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
    ├── AYSHostUITests/              BoardSnapshotTests.swift: renders every in-game board state
                                     from seeded fixtures (`HostViewModel.seedForSnapshot`, DEBUG
                                     only); writes PNGs when `AYS_BOARD_SNAPSHOT_DIR` is set
    └── AYSHostCoreTests/            AIDirectorTests.swift (election, relay, failover — [[Decision
                                     Log]]) plus the pre-AI suites below and NetworkTests.swift
                                     (Bonjour naming unconditionally, real-socket cases opt-in only)
                                     and QRGeneratorTests.swift
```

**Historical (pre-2026-10-05, when a separate `AYSHost-macOS` target
existed):** `AYSHost-macOS` builds (`xcodebuild ...
-scheme AYSHost-macOS`) and runs — screenshotted with a real room code, a
real scannable QR, `NWListenerServer` actually bound and listening
(the UI now says `READY TO PARTY`; the numeric port stays internal) and the
AirPlay picker button, all with zero
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
screenshot`), same room code + QR + ready-state pattern as macOS, after
downloading the tvOS platform (`xcodebuild -downloadPlatform tvOS`, done
with the user's explicit go-ahead — see [[Decision Log]]). This
confirmation predates the `NSBonjourServices` fix above, so it proves the
shared SwiftUI code and TCP bind work on tvOS too, not that tvOS discovery
specifically works — the same open item applies here.

**What the App/UI shell does not yet have:** a dedicated EliminationCard or a
share card ([[Multiplayer Development]] Phase 9). Winner reveal, result
verdicts, restrained humor and the live standings overlay have landed
(`ScoreboardView.swift`, fed by `PLAYER_SCORE` broadcasts via
`HostViewModel.standings`; see [[Multiplayer Gameplay]]). Its board screens
are covered by `AYSHostUITests` (render snapshots of every in-game state), but
`RoomCode`/`RoundDurationProvider` are
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
universal link (`https://pynkstudio.eu/ays/join?room=XXXX`, matching
`mp_home_screen.dart`'s `_deepLinkRoomCode` contract exactly) to a `CGImage`
via `CIQRCodeGenerator` — no SwiftUI/UIKit/AppKit dependency, so it's usable
from tvOS, iOS and macOS alike.

**Direct-connect hint (2026-10-14).** Once the listener is ready,
`HostViewModel.startHosting()` stores `directHostHint` — the board's LAN IPv4
(`LocalAddress.primaryIPv4()`: private-range, `en*` interfaces first, never
loopback or link-local) plus the bound port — and the QR becomes
`…/ays/join?room=XXXX&h=ip:port`. Phones use it only when Bonjour can't find
the room ([[Multiplayer Protocol]]).

**Threading (2026-10-12).** `RoomHost` is single-threaded. The board creates
`NWListenerServer(connectionQueue: .main)`: every accepted connection is
created, attached and served on the main queue — the same place the
`@MainActor` `HostViewModel` drives start/next/complete round. Before this,
each connection got its own queue, and several phones joining together raced
on the seat dictionary and crashed the board (`EXC_BAD_ACCESS` in
`RoomHost.rosterSnapshot`, reproduced on the Apple TV simulator with four
`tool/dev_bot_players.dart` bots). Tests that build a server without a queue
keep the old per-connection queues; `testSharedConnectionQueueSerializesSimultaneousJoins`
(opt-in, like the other socket tests) covers the shared queue. See
[[Decision Log]].

**What's actually verified headless:** `BonjourServiceTests` (instance name,
service type and the exact TXT room-card fields) and all of `QRGeneratorTests` (deep-link string,
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

**Landed.** `tvos/project.yml` (`xcodegen`) generates `AYSHost.xcodeproj`.
Since 2026-10-05 it has only the `AYSHost-tvOS` app target (the Mac board
lives in the Flutter macOS app — see "macOS: one app, two roles"); the
paragraph below is the history of the original two-target shell, which built
the shared `App/` + `UI/` SwiftUI sources against the `AYSProtocol`/`AYSHostCore`
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

The tvOS host and the Flutter macOS app ship **inside the phone app's App
Store record** — universal purchase, one product page for iPhone + Apple TV +
Mac — so `project.yml` sets `PRODUCT_BUNDLE_IDENTIFIER = com.ays.areYouStupid`
(the iOS Runner's id, also the macOS Runner's), `PRODUCT_NAME = "Are You Stupid"`,
`DEVELOPMENT_TEAM = G48384PHQK`, automatic signing, `MARKETING_VERSION
1.0.0`. A player who owns the game on iPhone sees it offered on their
Apple TV without searching. See [[Decision Log]].

- **tvOS icon** — `TVResources/Assets.xcassets` ("App Icon & Top Shelf
  Image" brand assets), generated by `tool/make_tv_icons.py` from
  `icon.png`: a full-bleed dark backdrop layer with a soft glow, an empty
  middle layer, and a front layer with the brain + title cut out of the
  iOS icon (so the parallax has depth and no square-in-a-rectangle
  framing). The script also renders both Top Shelf images (art + "THE
  PARTY GAME FOR YOUR TV"). Re-run it whenever `icon.png` changes.
- **macOS icon** — the Flutter Runner's
  `macos/Runner/Assets.xcassets/AppIcon.appiconset`, generated by
  `tool/make_apple_icons.py` from the repo-root `icon.png` on Apple's Mac
  grid (824 pt rounded rect + dark shadow on a transparent 1024 canvas,
  16–1024 px). It deliberately has no light outline. macOS 26+ instead
  reads the Icon Composer icon `macos/Runner/AppIcon.icon` (same name, so
  `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` picks it): one full-bleed
  1024 px layer from `icon.png`, near-black fill, no translucency or
  specular, masked by the system. Without it macOS 26+ frames the legacy
  tile in a pale plate. The same script refreshes that layer.
- **macOS App Sandbox** (required by the Mac App Store) —
  `macos/Runner/{DebugProfile,Release}.entitlements`: `app-sandbox`,
  `network.server` (phones connect to the board window's listener; Debug
  also needs it for the Flutter VM service), `network.client` (joining a
  room as a player). `macos/Runner/Info.plist` declares
  `NSLocalNetworkUsageDescription` and `NSBonjourServices = [_ays-party._tcp]`
  for both roles, plus the games category and the encryption flag below.
  The presenter backend keys (`AYSPresenterBackendURL`/`AYSPresenterAPIToken`)
  are in both Info.plists, fed by `tvos/Config/Presenter.xcconfig` (the
  Runner's Debug/Release xcconfigs include it). Without the untracked
  secrets file, the board uses the offline/system-voice presenter path.
- `App/Info.plist` (tvOS) adds `CFBundleDisplayName`,
  `LSApplicationCategoryType = public.app-category.games` (the Mac App Store rejected both `party-games` and `casual-games` with error 90249 — use the plain Games UTI) and
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

## Room perks and commercial break

`RoomHost` begins at 8 seats. A joined phone's store-confirmed Party Pack
claim raises `maxPlayers` to 16 but does not change ads. Remove Ads only sets
the room-wide ad flag; Party Bundle arrives as both claims and activates both.
Benefits remain until the host room
closes. A ninth free join emits `PARTY_PACK_NUDGE` before returning
`ROOM_FULL_UPGRADABLE`.

After `GAME_END`, the first `REMATCH_REQUEST` either broadcasts
`REMATCH_READY` immediately or starts a single-client `AD_BREAK_STARTED` /
`AD_BREAK_FINISHED` handshake. Apple TV and Mac never load an ad. Their game
end view shows troll sponsor copy during the break; Party Pack activation adds
a generated high-energy lobby banner. Dedicated activation audio is a future
sound now uses the same generated show palette as the round-start,
elimination and winner stingers.

`HostSoundEffects` loads those four MP3s from the `AYSHostUI` Swift-package
resource bundle, allowing both Apple TV and the embedded Mac board to use the
same files. Multiple short effects may overlap, but every player has a fixed
`0.32` gain so the full-scale masters never play directly into headphones or
TV speakers. Effects are independent from presenter speech and its mode.

## Presenter runtime

`PresenterEngine` is pure Swift and turns verified round/game facts into
cues, picking copy from a `PresenterLineBook` (most specific key first).
`HostViewModel` also retains each `ROUND_START.challengeId` until its matching
`ROUND_RESULTS`; the engine maps all 39 ids into nine stable editorial
mechanics. Savage selection can therefore target the sole wrong player,
someone still at zero after three rounds, a first point arriving on round four
or later, and a three-error streak. Named mechanic templates are allowlisted;
an unknown remote key is discarded and can never invent a match fact.
`PresenterPackStore` (UI) syncs the published book and its hash-verified
clips into Caches, and keeps whichever of the synced and bundled books has
the higher revision. `PresenterAudioController` resolves pack clip → disk
cache → shared backend → subtitle only (system speech in DEBUG builds only),
waits on the backend while the cue stays relevant rather than on a fixed
timeout, and checks semantic expiry until playback begins. At each
`ROUND_START`, `HostViewModel` prefetches the engine's `likelyNamedLines`
into the disk cache (8 per round, Voice mode only). A line still loading at the next round is discarded; audio
already playing finishes naturally. Results expire with their round; final
verdicts remain eligible while Game End is visible. The engine emits at most
one cue per result and uses combined result/title templates when both facts
land together. Every cue passes the repetition guard (`PresenterLineHistory`:
6-beat cooldown by normalized text and punchline, named jokes once per match,
`result.player.again` escalation); a beat with nothing fresh emits no cue, so
`gameEnd`, `lobbyEmpty` and `returningCue` return optionals
([[Multiplayer Presenter]] → "Repetition guard").
The store starts from the board device locale (`en`, `it`, `fr`, `es`, `pt`,
`de`, otherwise English) and isolates manifest, ETag and audio caches by
locale. The same locale drives the board's own screen text:
`HostViewModel.strings` builds a `BoardStrings` (`AYSHostCore`) from the
presenter locale, and every fixed lobby/round/results/final/options string
goes through it, so voice, captions and UI never disagree. Mode names and the
brand stay English, as on the phones; the host's English fallback reason
`too slow` is localized at display (`BoardStrings.failReason`), while a
phone's own fail reason is shown as sent. Presenter controls stay behind the
lobby's secondary `OPTIONS` button: room-language override (`LANGUAGE`), persistent output (`OFF`, `MUTE`, `VOICE`)
and an independent roast level (`NEUTRAL`, `SAVAGE`) disabled only while
output is Off. Off suppresses playback and the matching caption; Mute renders
the caption immediately without touching any audio path.

`PresenterCareerStore` records at most 64 earned careers by opaque `personaId`
in board `UserDefaults`. A known persona gets one return cue per lobby. Winner
careers become `IL KING INDISCUSSO`; other earned titles can also carry over.
Careers store `PresenterLineBook.Title` keys and `returningCue` words them
with the current line book, so the welcome never mixes languages.
Positive titles expire after 90 days and negative performance jokes after 7.

The shared backend route lives in the PynkStudio Menuary repository at
`src/app/api/ays/presenter/` (live speech, `pack`, `pack/clips/[sha256]`),
served at `https://pynkstudio.eu`; ElevenLabs by default, OpenAI as the
fallback. Revision 1 of all six locale packs is live and bundled with the host
(66 verified MP3 clips total); the host checks for a newer revision at first
hosting launch without making connectivity a gameplay dependency. System TTS
is only the development fallback.
See [[Multiplayer Presenter]].

For ambiguous join names, `RoomHost` selects the joined AI-capable seat with
highest `computeRank` (join order breaks ties), forwards the request privately
and accepts the matching response only from that seat. It does not persist or
broadcast the requested display name.

## Local persistence

Only `UserDefaults`-backed settings relevant to hosting: last-used host name,
optional match history and the bounded presenter-career cache. No cloud, no
account ([[Multiplayer Product]]).

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
