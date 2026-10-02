---
tags: [development, testing]
updated: 2026-09-15
---

# Testing

```bash
flutter test          # everything
flutter analyze       # must be clean, zero issues
dart run tool/gen_protocol_fixtures.dart   # regenerate Swift golden fixtures (protocol change only)
swift test             # from tvos/ — AYSProtocol (29) + AYSHostCore (54) = 83 cases, 4 skipped by
                        # default (real-socket tests — see AYS_RUN_NETWORK_TESTS below)
```

## Fixed: intermittent overflow in `app_flow_test.dart`

Several tests that reach Game Over used to fail intermittently (roughly 1 in
5–8 runs, "same test data every time") with:

```
A RenderFlex overflowed by 24 pixels on the bottom.
```

Root cause: [`GameOverView`](../../lib/ui/screens/game_over_view.dart)'s
outer `Column` is deliberately non-scrolling, and two of its lines —
the roast and the viral prompt — are picked at random from pools of very
different lengths (`roast.spicy.10` is 8 words; most neutral lines are one).
An unlucky long pick wrapped to a second line at 40px, and the layout had no
slack left for it. "Same test data" was true (`bestLevel: 1`) but the
random roast/viral text wasn't — that's what actually varied between runs.
**Fix:** wrapped both in `FittedBox(fit: BoxFit.scaleDown)`, the same idiom
already used for the level number two lines below (see [[Rendering
Pipeline]]'s "Labels use `FittedBox`" rule) — a long line shrinks to fit
instead of wrapping and blowing the column. See [[Decision Log]].

## The suites

### `test/multiplayer/` — the party-mode protocol + host rules (Phase 2)
Headless, no widgets. Five suites driven by the `PartyHarness`/`SimClient`
test double (`test/multiplayer/support/sim.dart`) sitting on top of the
in-process **host reference** (`test/support/party_host_reference.dart`),
which speaks the same [[Multiplayer Protocol]] the future Swift host will:

- `protocol_codec_test.dart` — every message (de)serializes losslessly,
  including `PartyAction` `tap` (target + index) and `count`, and the six
  [[Multiplayer AI Director]] kinds; unknown `type`/fields ignored
  (forward-tolerant); malformed/empty lines → `DECODED_MALFORMED`.
- `party_session_ai_test.dart` — the client-side dispatch for the three
  host→all AI kinds: `AI_DIRECTOR_ASSIGNMENT`/`AI_COMMENTARY` update
  `PartyState` and emit an event; a valid `AI_CHALLENGE_ROUND` opens a
  real, playable round via `buildPartyChallengeFromAiRound`, a malformed
  one surfaces `PartyError(code: 'BAD_AI_PROPOSAL')` instead of crashing;
  the three outbound `sendAiX` methods actually reach the wire.
- `party_ai_director_test.dart` — `PartyAiDirector`'s sending side: capability
  announcement once on join (and forced `aiAvailable: false` when
  `aiMultiplayerDirectorEnabled` is off); round generation only once
  elected Director, gated by flags/availability/validation; commentary on
  `PLAYER_ELIMINATED` and `GAME_END` (`winner`/`loser` by whether this
  phone's own `selfClientId` matches `winnerId`), including a regression
  case for a real bug caught here — an early draft let *every* phone try
  to send commentary on the same event, not just the elected Director.
- `room_lifecycle_test.dart` — version mismatch → `REJECTED`, gatekeeper
  malformed-input/unknown-type tolerance, join → `PLAYER_JOINED` + self-id +
  roster, `ROOM_FULL` at capacity, leave, ready propagation, `START_GAME`
  guard (<2 ready → error, host clock held still).
- `round_sync_test.dart` — two clients fed the same `ROUND_START` render the
  identical `ChallengeView` (same seed); countdown READY/GO; count action
  carries the client-reported verdict correct/wrong (the host trusts it,
  doesn't rejudge — see the design-change note on `PlayerAction` in
  [[Multiplayer Protocol]]); LSS lives + elimination at 0 + sole-survivor
  `GAME_END`; Battle base scoring + the exact speed-bonus split (fastest
  150, slower 125 from +50/+25); a "round auto-closes once every alive seat
  has answered" group (no downtime — closes early without `completeRound()`,
  ignores an eliminated seat's silence). `SimClient.letRoundTimeOut()`
  simulates a well-behaved client whose own runner reaches timeout locally
  and self-reports, as opposed to a truly silent/disconnected one (the
  host's own timeout fallback is a fixed "wrong," exercised separately).
- `reconnect_test.dart` — in-game drop holds the seat, matching reconnect
  restores self-id + roster (`PLAYER_RECONNECTED`), grace-window expiry
  prunes, outside-window reconnect rejected; duplicate/stale/closed-round
  `PLAYER_ACTION` → `DUPLICATE_ACTION` / `ROUND_CLOSED`.
- `simulation_test.dart` — full 8-player roster and a complete 4-player LSS
  game run to a sole survivor, all in one test process.

### `test/multiplayer/` — the mobile client's own suites (Phase 3)
The four new pieces this phase added — the client screens themselves have
no widget-level test yet, see [[Multiplayer Development]] for that gap:

- `session_socket_test.dart` — real loopback TCP: `SocketPartyTransport`
  delivers lines both directions, `inbound` completes when the peer closes,
  `send()` after `close()` is a safe no-op, `connect()` throws
  `SocketException` against a dead port. The first suite exercising an
  actual socket instead of `InMemoryPartyTransport`.
- `lan_discovery_test.dart` — `matchesRoomCode`'s matching rule: a plain
  case-insensitive/trimmed instance-name match against `package:nsd`'s
  `Service.name` (rewritten from a PTR-domain regex when the package
  switched from `multicast_dns` to `nsd` — see [[Decision Log]]). The
  discovery I/O itself isn't unit-testable without a live network, a real
  advertiser (the tvOS/macOS host) and the native `NsdManager`/
  `NSNetServiceBrowser` plumbing `nsd` wraps.
- `mp_home_screen_test.dart` — `roomCodeFromScannedValue` parses the
  `areyoustupid://join?room=XXXX` QR payload, rejects anything else.
- `multiplayer_profile_test.dart` — `MultiplayerProfileManager` persistence
  (name/emoji trimmed, `bestStanding` only ever improves, listeners notified).
- `socket_integration_test.dart` — the closest thing to an end-to-end proof
  without a widget test: two real `SocketPartyTransport` clients connect to
  a `PartyHostReference` over an actual loopback socket, join, ready up,
  get the same `ROUND_START` tuple, and reach `GAME_END` together. Closes
  the gap between "the protocol is correct" (Phase 2, in-memory transport)
  and "the real socket wiring is correct" (nothing exercised that before).

### `tvos/Tests/AYSHostCoreTests/` — the Swift host authority (Phase 4, partial)
42 XCTest cases against `RoomHost`, `AYSChallengeCatalog` and the `Net/`/`QR/`
layers, mirroring the Dart suites above but on the Swift port
([[Multiplayer Host (tvOS)]]) — `InMemoryHostTransport` + `ManualHostClock`
play the same headless-double role `InMemoryPartyTransport` +
`FakePartyClock` play on the Dart side. Content judging moved to the
client entirely (the design-change note on `PlayerAction`, [[Decision
Log]]), so the real `ChallengeJudge` (`RoundDurationProvider`) only
resolves a round's duration now — `FakeChallengeJudge` here stands in for
that lookup, not for judging:

- `RoomLifecycleTests.swift` — HOST_HELLO, protocolVersion mismatch →
  REJECTED, malformed/unknown-type tolerance, join → roster, `ROOM_FULL`,
  leave, ready broadcast, `startGame` throwing under 2 ready.
- `RoundSyncTests.swift` — identical `ROUND_START` tuple to every client,
  READY/GO countdown, a count action carrying the client-reported verdict
  straight through, timeout judged incorrect, a round auto-closing once
  every alive seat has answered, Battle base score + the exact 150/125
  speed-bonus split, LSS lives/elimination/sole-survivor `GAME_END`.
- `ReconnectTests.swift` — grace-window hold + restore (`PLAYER_RECONNECTED`
  with the same `selfClientId`), expiry prune, outside-window reject,
  duplicate/stale/pre-round `PLAYER_ACTION` → the matching error code.
- `QRGeneratorTests.swift` — join deep-link string matches
  `mp_home_screen.dart`'s `_deepLinkRoomCode` regex exactly, deterministic
  output, different room codes → different pixels, scaling.
- `ChallengeCatalogTests.swift` — `AYSChallengeCatalog.all` still has all 39
  templates, unique ids, and no zero/negative `maxDurationMs`/weight/minLevel
  ([[Decision Log]] on how each `maxDurationMs` was derived).
- `AIDirectorTests.swift` — [[Multiplayer AI Director]]: `AI_CAPABILITIES`
  remembered per seat; the election (highest `computeRank`, tie-break on
  `playerId`, no capable seat ⇒ no Director); `startNextRound` consuming
  a pending Director proposal exactly once and falling back to scripted
  otherwise; an impersonated round/commentary proposal from a
  non-Director ignored; the Director's own commentary relayed to
  everyone; failover once the Director's seat is actually removed (both
  with and without another candidate), and a pre-game leave excluding
  that seat from the election.
- `NetworkTests.swift` — `BonjourServiceTests` (instance-name/service-type
  rule) always runs; `NWConnectionTransportTests` (real loopback TCP: line
  delivery, multi-line buffering, `onDone` on peer close, and a full
  `RoomHost` round to `GAME_END` over real sockets — the Swift mirror of
  `socket_integration_test.dart`) is gated behind the
  `AYS_RUN_NETWORK_TESTS=1` environment variable and **skips by default**.
  **Why:** a plain command-line binary asking `NWListener` to accept
  connections needs the one-time macOS "Local Network" permission prompt;
  answered by nobody in an unattended shell, the underlying XPC call blocks
  synchronously and can wedge Swift concurrency's whole cooperative thread
  pool — confirmed directly this session (`swift test` had to be
  `kill -9`'d; a `readyTimeout` on `NWListenerServer.start` did not save it,
  since the timeout task itself never got scheduled). Run
  `AYS_RUN_NETWORK_TESTS=1 swift test` from an interactive Terminal and
  click Allow once to actually exercise it — see [[Decision Log]] and
  [[Multiplayer Host (tvOS)]].

Building this surfaced a real bug worth knowing about if you touch
`RoomHost.attachClient`: see [[Decision Log]] on why the per-connection
closures weak-capture `self` but strongly capture the connection object,
not the other way around.

#### Protocol-echo: `tvos/` Swift mirror against Dart-emitted goldens
The Swift mirror (`swift test` from `tvos/`, 29 cases) decodes every line of
`tvos/Tests/AYSProtocolTests/Fixtures/messages.golden.jsonl` — bytes emitted by
the Dart codec, by design the same object the Swift host will receive on its
socket — asserts field values, and tests the same forward-tolerance rules
(unknown `type` → `.unknownType`, garbage → `.malformed`, unknown fields
ignored). Regenerate the fixture with `dart run
tool/gen_protocol_fixtures.dart` whenever the protocol changes; the count
assert (34 lines) forces a deliberate regeneration. Swift encode is semantic
(parse-then-emit), so both sides stay lossless without being byte-identical.

### `test/challenge_determinism_test.dart` — the multiplayer seed contract
For every registered template across 4 seeds × 3 level bands: same
`{ challengeId, seed, level }` → deep-identical `ChallengeView` (every
render-relevant field compared), stable duration/id, unknown ids resolve to
`null` from `templateById`, and unknown ids throw from `buildFromSeed`. This
is what guarantees host and every phone rebuild the same challenge from a
`ROUND_START` tuple — see [[Multiplayer Challenges]] and [[Decision Log]].

### `test/challenge_templates_test.dart` — the contract
Runs **every** registered template across 12 seeds × 3 level bands and asserts:

- registry has ≥ 30 templates with unique ids
- starters are available at levels 1–3
- round length between 0.6 s and 8 s
- instruction is **under 8 words** (the design rule, enforced)
- target ids unique, scale > 0, opacity in 0.2–1.0
- the round always resolves if the player does nothing

A new template is covered by this the moment it is registered.

### `test/challenge_behaviour_test.dart` — the rules
Per-challenge: the winning input, the losing input, the trap, the exact fail
line. Uses `FakeHost` + `advance()` from `test/support/fake_host.dart`, so no
widgets and no clock.

### `test/game_engine_test.dart` — the loop
Phases and timings, level progression, roasts, timeout, input ignored outside
`playing`, continue-once-per-run, event emission, and the generator rules
(starter gating, no back-to-back repeats, `minLevel` respected). The
`difficulty` group asserts the stepped speed table itself — the tutorial's
five gentle sub-steps through level 9, that every ten-level band from 10 on
is flat internally then jumps at the boundary, and that the pace-note
milestones fire at exactly level 6 and level 10 — see [[Difficulty Curve]].

### `test/timer_bar_test.dart` — the retry-remount lifecycle
Isolates one specific worry from a real-device report ("the timer bar shows
after a fresh build but not after Game Over → RETRY"): `GameScreen._buildBody`
tears the whole `Column` (timer bar included) out of the tree during
`GamePhase.intro` and mounts a fresh one for the next run's level 1. This
test hides a `TimerBar`, removes it from the tree entirely, then remounts a
visible one, and asserts it paints at full opacity immediately — no leftover
animation state from the disposed instance. Passes; the real-device report
itself is still open, see [[Decision Log]].

### `test/app_flow_test.dart` — the real widget tree
Menu → PLAY → LEVEL 1 → timeout → Game Over → TRY AGAIN, stats recording, and
the settings toggles. Note: `pumpAndSettle()` never settles on the game screen
(it animates every frame by design) — advance with fixed `pump(step)` loops.
See the overflow fix above.

Also asserts the `TimerBar` is actually visible at level 1 — including that
its colored fill renders at its real 8 px height, not the zero-height layout
bug fixed in [[Difficulty Curve]] — that it's *still* visible (same height
check) after a full Game Over → RETRY cycle, and that tapping the wrong
flash calls `GameEngine.skipWrongFlash()` and reaches Game Over well before
`wrongFlash` would have elapsed on its own.

Also covers the Settings screen's external links ("ABOUT THE GAME", "PRIVACY
POLICY", the "Made by PynkStudio" credit — see [[Services]]): a
`_FakeUrlLauncher` replaces `UrlLauncherPlatform.instance` for the test so
tapping the rows records the URL instead of opening a real browser. Two
variants cover the locale-dependent "about" link: English gets the `/en`
case-study page, Italian gets the Italian one.

Also covers the Settings screen's Ai section ([[Feature Flags]] Phase 9):
the mode picker defaults to Genius and the "not supported" copy shows with
no native bridge available. Needs an explicit mock handler on the
`ays/apple_intelligence` channel — a bare, unregistered `MethodChannel`
call never resolves in a `testWidgets` binding (unlike a bare `test()`,
where it rejects with `MissingPluginException` right away), a real gotcha
found and logged while writing this case (see [[Decision Log]]).

### `test/ad_manager_test.dart` — the ad policy
`AdManager` against a fake `AdProvider` that never has a fill: asserts the
rewarded-continue button is never offered when `isReady` is false, i.e. the
"no dead-end ad buttons" rule actually holds when offline. Also covers the
"remove ads" purchase: once `SettingsManager.noAdsPurchased` is set, the
rewarded continue is granted for free (offline included) and the interstitial
never fires, even with the fill/counter conditions that would otherwise show
one. See [[Monetization and Ads]].

### `test/localization_test.dart` — the six languages stay in sync
Asserts every locale in `lib/i18n/strings_*.dart` defines the exact same key
set as English (a stray/missing key otherwise fails silently into the English
fallback — see [[Localization]]), that no key is left empty, that
`spell_count`'s per-language letter/digit maps are complete, and that
`word.opposite.*` pairs are well-formed. Also re-runs the **under 8 words**
instruction rule across every template in every language (not just English —
this is what caught a French instruction going over the limit from padded
guillemets during the initial pass). Plus one widget test: booting with
`ays.locale = 'it'` renders the home screen in Italian.

### `test/ai/` — the dynamic-AI director suites ([[Development Plan]] Phases 2–10)
All against `MockAppleAIService` / a mocked `ays/apple_intelligence`
`MethodChannel` — no real model runs in this environment ([[Testing and
Evaluation]]). One file per layer:

- `challenge_validator_test.dart` — every [[AI Challenge Validator]] rule,
  both sides, plus determinism and the single-retry regeneration rule.
- `challenge_proposal_test.dart` — `ChallengeProposal` ↔ `GeneratedChallenge`
  envelope semantics.
- `apple_ai_service_test.dart` — the Dart side of the bridge contract:
  availability states, decode/`decodingFailure`, `ok:false` → fallback
  mapping, bare-boolean calls.
- `generated_challenge_runtime_test.dart` — one behavior group per
  `mechanic.action` for the proposal → playable `Challenge` runtime.
- `feature_flags_test.dart` — `AiFeatureFlags`' documented defaults,
  master-off short-circuit, persistence, the three modes' exact flag
  postures.
- `commentary_test.dart` — `isCommentaryLineValid` and
  `CommentaryProvider`'s static-bank-first ladder.
- `prefetch_loop_test.dart` — the generic `PrefetchLoop<T>` primitive: pop,
  single-in-flight, ring-full no-op, stale-fetch discard on `invalidate()`.
- `provider_test.dart` — `AIChallengeProvider`: cold start, flag/locale/
  availability gating (including the levels-1-3 starter-gate regression
  group added in Phase 10 — see [[Decision Log]]), cache-key invalidation,
  a validated proposal reaching the cache, an invalid one never reaching
  it, and the real `requestChallenge` payload shape.
- `profile_for_prompts_test.dart` — `profileForPrompts`'s cold-start
  defaults, rounding, and privacy-allowed-key allowlist.
- `telemetry_test.dart` — mistake classification, rolling-window math, EMA,
  reset-on-`RESET STATS`.
- `full_run_with_mock_bridge_test.dart` — Phase 10's one integration test:
  a full match through the exact production provider composition and a
  real `GameEngine`, covering AI-served/fallback/mode-switch/no-error-UI in
  one run (see [[Testing and Evaluation]]'s suite table for detail).

Plus the multiplayer AI wire suites under `test/multiplayer/`
(`party_session_ai_test.dart`, `party_ai_director_test.dart`) and their
Swift mirror (`tvos/Tests/AYSHostCoreTests/AIDirectorTests.swift`,
`ProtocolTests.swift`).

The one hard rule from the original spec still applies: Phase 1's
`ChallengeProvider` refactor kept every pre-existing suite in this file
green *unchanged*, and `flutter analyze` stays zero-issue at each phase.

## Writing tests for a new challenge

```dart
final c = buildMyChallenge(params(level: 10));
final host = FakeHost();
c.onStart(host);
advance(c, host, to: const Duration(milliseconds: 800)); // let the trap arm
c.onTap(tapOn('c2'), host);
expect(host.failed, isTrue);
expect(host.reason, 'THAT ONE WAS HONEST.');
```

## Manual pass before shipping

See [[Release Checklist]].
