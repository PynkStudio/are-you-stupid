---
tags: [development, multiplayer, testing, roadmap]
updated: 2026-09-11
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
**Status: ✅ landed (client), ⚠️ unverified end-to-end.** `lib/ui/screens/multiplayer/`
ships all six screens (`mp_home_screen.dart` — landing + in-app QR scan
[`mobile_scanner`] + manual code entry; `mp_join_screen.dart` — discovery,
connect, name form; `mp_lobby_screen.dart` — roster + self ready toggle,
deliberately no START GAME button, that's TV-only; `mp_game_screen.dart` —
`ChallengeRenderer` + `PartyController` reused as-is; `mp_result_screen.dart`
— standings + share; `mp_disconnect_view.dart` — overlay for
`HOST_DISCONNECTED`/rejected). `lib/multiplayer/networking/` gained the real
production pieces Phase 2 stubbed out: `session_socket.dart`
(`SocketPartyTransport`, a `dart:io Socket` wrapped as `PartyTransport` —
symmetric, so it also works host-side) and `lan_discovery.dart`
(`LanPartyDiscovery`, browses `_ays-party._tcp` via `multicast_dns`).
`lib/services/multiplayer_profile.dart` persists name/emoji/stats
(`SharedPreferences`, mirrors `SettingsManager`'s shape).

**The "unverified" part:** `LanPartyDiscovery` is written and tested
(`matchesRoomCode` unit tests) against the documented Bonjour contract, but
there is still nothing on the LAN to discover — advertising is Phase 4's
job (the native tvOS/macOS host). So the real end-to-end path (scan → find
host → connect → play) cannot be exercised yet. To validate everything
*except* discovery this session, `mp_join_screen.dart` also has a
debug-only (`kDebugMode`) "DEV: HOST ADDRESS" manual `ip:port` entry, paired
with `tool/dev_multiplayer_host.dart` — see below and [[Decision Log]].
No OS-level deep link (scanning the room QR with the system camera and
having it open the app directly) yet either — that's Phase 8 ("QR joining +
polished lobby") by design; Phase 3's "scan" is the in-app camera scanner
only, which already covers the canonical `[ SCAN QR ]` entry point.

**Test suites landed** (`test/multiplayer/`): `session_socket_test.dart`
(real loopback TCP round-trip — the first suite to exercise a live socket
instead of `InMemoryPartyTransport`), `lan_discovery_test.dart`
(`matchesRoomCode` — the mDNS I/O itself isn't unit-testable, see above),
`mp_home_screen_test.dart` (`roomCodeFromScannedValue` QR-payload parsing),
`multiplayer_profile_test.dart`, and `socket_integration_test.dart` — two
real `SocketPartyTransport` clients against a real `PartyHostReference` over
an actual loopback socket, join → ready → same `ROUND_START` tuple →
`GAME_END`. That closes the "does the real socket wiring actually work"
gap; what's still missing is a widget-level flow test driving the six
screens themselves (`MobileScanner`/live sockets from inside `flutter test`
is real additional effort, not attempted this pass).

**`tool/dev_multiplayer_host.dart`** — a throwaway dev CLI, *not* Phase 4.
Reuses `test/support/party_host_reference.dart` (the same authority Phase 2's
suites already prove correct) real-time-driven via a `FakePartyClock`
advanced by a wall-clock `Timer.periodic` instead of test code stepping it.
Opens a plain `ServerSocket`, does **not** advertise over Bonjour (a correct
mDNS responder is real Phase 4 host work — see [[Decision Log]] for why this
wasn't hand-rolled here), and prints its LAN address for the app's dev
manual-connect field. Run with `dart run tool/dev_multiplayer_host.dart
[port]`, type `start` once ≥2 phones are readied up.

### Phase 4 — Native tvOS host/display app (+ macOS board host)
SwiftUI host implementing the protocol, QR generation, Bonjour advertising,
lobby + round + results UI ([[Multiplayer Host (tvOS)]]). The **same host
binary also ships as a macOS app**: on the Mac it is **board-only** (host +
display; no local controller, no direct play on the Mac itself — the person
running the Mac plays on their phone like everyone else), with an **AirPlay
button** to mirror the board to another screen. The tvOS and macOS hosts
share one host core; see [[Decision Log]].

**Status: ⚠️ partial, but every "Not started" item from the previous pass has
now landed at least once.** The authoritative `Host/` graph is landed and
tested: `tvos/Sources/AYSHostCore/RoomHost.swift` is a faithful port of
`test/support/party_host_reference.dart` — room lifecycle, gatekeeper,
round timing, action validation, both modes' scoring, elimination and
`GAME_END` — built against injectable `HostClock`/`HostTransport` seams so
it needs no UI or real network to test, plus an `onBroadcast` hook so a
local UI observes the same events a connected phone gets. `Net/`
(`NWListenerServer` + `NWConnectionTransport`, real TCP with JSONL framing
plus `_ays-party._tcp` Bonjour advertising via `NWListener.service`) and
`QR/` (`QRGenerator`, `CIQRCodeGenerator` over the join deep link, no
assets) are landed — see [[Multiplayer Host (tvOS)]] for why the
real-socket *tests* are opt-in (`AYS_RUN_NETWORK_TESTS=1`) rather than part
of the default run; the real `Net/`/`QR/` *code* itself is confirmed
working live (below). 32 `AYSHostCoreTests` cases mirror the Dart
room-lifecycle/round-sync/reconnect suites plus Bonjour naming and QR
generation; `swift test` from `tvos/` runs all 55 (23 protocol + 32 host
core, 4 of those skipped by default), all green.

**The App/UI shell is real, not aspirational, as of this session.**
`tvos/project.yml` (`xcodegen generate`) produces `AYSHost.xcodeproj` with
`AYSHost-tvOS` and `AYSHost-macOS` targets sharing one `App/` + `UI/`
SwiftUI source set (`HostViewModel`, `RootView`, `LobbyView`, `RoundView`,
`ResultsView`, `GameEndView`, `AirPlayButton`, `Theme`) against the package
as a local dependency. Both targets **build**; both were **run and
screenshotted live** this session — `AYSHost-macOS` launched as a real
`.app` (a room code, a real scannable join QR, `NWListenerServer` actually
bound and printing its port, the AirPlay picker button, zero manual
intervention needed) and `AYSHost-tvOS` on a booted Apple TV simulator
(same Lobby, same live room code + QR + listening port, confirming the
identical SwiftUI source really is platform-agnostic). Getting there also
required downloading the tvOS platform (`xcodebuild -downloadPlatform
tvOS`, done with the user's explicit go-ahead — multi-GB, not something to
do unprompted) since Xcode 26 doesn't ship it by default. See [[Decision
Log]] for the xcodegen YAML quirk that blocked the first attempt and full
detail on what "landed" means here versus real coverage.

**Update: challenge judging resolved, not by porting to Swift.** The
`ChallengeJudge`/PRNG question above is answered: the host never judges
content at all now, in either language. The *client* judges its own input
(`PartyChallengeRunner`, driving the real `Challenge` single-player uses)
and reports the verdict in every `PLAYER_ACTION`; both hosts
(`RoomHost.swift`, `test/support/party_host_reference.dart`) simply trust
it. `ChallengeJudge` shrank to one method (`spec`, duration + unknown-id
only); the App/UI shell's coin-flip placeholder (`DemoChallengeJudge`) is
gone, replaced by `RoundDurationProvider` — genuine small production
behavior now, not a demo stand-in. See the design-change note on
`PlayerAction` in [[Multiplayer Protocol]] and [[Decision Log]].

**Still genuinely not done:** the App/UI shell has no EliminationCard, real
winner animation, share card or humor lines (Phase 9 below — the live
ScoreboardView landed this session), no XCTest target of its own (it's
verified by building + the one live screenshot per platform, not an
automated suite), and per-template round durations (one fixed 6000ms for
every challenge today, on the Swift side). No second, real *client* was
connected to either running Swift host directly from this note's original
pass — see the real-device follow-up below, which closed that gap.

**Update, real-device follow-up:** the user did exactly that test (Mac
host + a real iPhone and iPad) right after this pass, and rooms weren't
discoverable at all. Three separate real bugs turned up, not just an
unexercised path: `NSBonjourServices` had silently never made it into the
built host Info.plist (the listening port shown in the screenshots above
only proves the TCP bind, not that Bonjour was actually advertising); a
client-side `SocketException` during mDNS lookup crashed the join flow
instead of falling back gracefully; and, after confirming Local Network
permission *was* granted, a third crash — `OSError: Address already in
use` binding mDNS port 5353, a sibling exception type the first fix's
catch clause didn't cover. All three now fail gracefully rather than
crash — see [[Decision Log]] for the full diagnosis of each.

**Confirmed working, real two-device test (bypassing discovery via the DEV
field):** a real iPhone and iPad both connected to `AYSHost-macOS`, joined,
readied up, and landed on the identical rendered challenge at the same
time — `NWConnectionTransport`, `RoomHost`'s room/round lifecycle, and the
client's existing deterministic `{challengeId, seed, level}` →
`ChallengeView` build (Phase 1) all confirmed correct end to end with real
hardware, first time, no test doubles either side. This isolates the
remaining bug precisely to Bonjour/mDNS discovery — not the protocol, not
the host, not challenge rendering. Judging was still fake at the time of
this test (`DemoChallengeJudge`, a coin flip with no idea what either phone
actually answered), so it didn't exercise scoring, elimination, or the
results/winner UI, only sync + join + render — **now resolved, see the
"challenge judging resolved" note above and [[Decision Log]]; a fresh
two-real-device pass exercising the new client-judged flow is still
outstanding.**

**Update: `lan_discovery.dart` rewritten on `package:nsd` instead of
`package:multicast_dns`.** Real users can't rely on the `kDebugMode`
DEV-address field, so discovery has to actually work, not just fail
gracefully — retrying a raw-socket bind was never going to fully fix a
port-5353 contention with iOS's own `mDNSResponder`. `nsd` wraps the
platform's own service-discovery APIs (`NsdManager` on Android,
`NSNetServiceBrowser` on iOS/macOS) instead of binding a second, competing
socket, which removes the two real-device failure modes above by
construction rather than papering over them. `matchesRoomCode` simplified
accordingly (plain instance-name string match, no PTR-domain parsing);
Android gained the `INTERNET` permission `nsd` requires
(`CHANGE_WIFI_MULTICAST_STATE` was already there). `flutter build ios
--simulator --no-codesign` and `flutter build apk --debug` both confirmed
building with the new plugin linked in — see [[Decision Log]] for the full
migration notes, including an unrelated pre-existing Gradle 9 build break
found and fixed along the way. **Not yet confirmed:** whether this actually
fixes discovery against the user's real iPhone/iPad — a real-device retest
is the next step, not this rewrite itself.

### Phase 5 — Synchronized gameplay
`ROUND_START` broadcast, countdown sync, input collection, host judging,
`ROUND_RESULTS`, lives/elimination groundwork.

**Status: ✅ landed, real judging included.** `ROUND_START` broadcast,
countdown, and input collection are proven live end-to-end (see Phase 4's
real two-device test above) as well as headless
(`AYSHostCoreTests`/`test/multiplayer/`). Judging is no longer host-side at
all: the client's `PartyChallengeRunner` drives the real `Challenge` and
reports a real verdict, which `RoomHost`/`PartyHostReference` trust
directly — see the "challenge judging resolved" note above and the
design-change note on `PlayerAction` in [[Multiplayer Protocol]].
`RoundDurationProvider` resolves each round's host-side timeout deadline
from real per-template durations (`AYSChallengeCatalog`'s `maxDurationMs`,
one per template — see [[Decision Log]]) rather than one flat number for
every challenge; the board itself still never renders the challenge
content — only the phones do — so this is purely about how long the host
waits for a seat that never answers at all before force-closing the round.

### Phase 6 — Last Stupid Standing
3 lives, eliminations, winner animation, spectate mode.

**Status: ⚠️ rules landed, presentation partial.** Lives/eliminations/
sole-survivor `GAME_END` are real and tested on both hosts
(`RoomHost`/`PartyHostReference`), now driven by genuine client-reported
verdicts. Spectate mode works (an eliminated seat stays connected,
`mp_game_screen.dart` shows an `ELIMINATED` badge, the client's phase moves
to `playing` so it stops expecting rounds). Missing: a dedicated
elimination-moment card (currently just the persistent badge) and a real
winner animation (`GameEndView` shows the name in plain text) — Phase 9.

### Phase 7 — Stupid Battle
Points, per-round standings board, final results + winner, score sharing.

**Status: ⚠️ scoring landed, standings board landed, sharing not started.**
`PLAYER_SCORE` broadcasts (base 100 + optional top-3 speed bonus) are real
and tested. The live standings board landed this session
(`ScoreboardView.swift`, shown during rounds and results on the board) and
`GameEndView` shows final standings + winner. Score sharing (a shareable
result card/text, matching the single-player share flow) hasn't been
started — Phase 9.

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