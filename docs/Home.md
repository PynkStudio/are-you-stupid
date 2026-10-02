---
tags: [moc, index]
updated: 2026-09-15
---

# ARE YOU STUPID? — Documentation Home

> One job. Don't fuck it up.

A one-handed, offline, hyper-casual mobile game built with Flutter (Android + iOS).
The player gets a stupidly simple instruction and fails on something stupid.

**This vault is the source of truth for the project. Any AI agent working on this
repository MUST read [[Documentation Rules]] before touching code.**

## Start here

- [[Game Design Pillars]] — what the game is and why it works
- [[Architecture Overview]] — how the code is organised
- [[Adding a Challenge]] — the most common task in this repo
- [[Getting Started]] — run, test, build

## Map of content

### Gameplay
- [[Game Design Pillars]]
- [[Challenge Catalog]] — all 39 challenge templates
- [[Difficulty Curve]]
- [[Humor and Roasts]]

### Architecture
- [[Architecture Overview]]
- [[Game Engine]]
- [[Challenge System]]
- [[Rendering Pipeline]]
- [[Services]]
- [[State and Persistence]]
- [[Localization]]

### Product
- [[Monetization and Ads]]
- [[Virality and Sharing]]
- [[Roadmap]]

### Development
- [[Getting Started]]
- [[Adding a Challenge]]
- [[Testing]]
- [[Release Checklist]]

### Multiplayer — Apple TV party mode
A 2–8 player party mode: tvOS host (or a macOS **board-only** host with AirPlay
mirroring) + phones as controllers over the local network. **Phases 1–3
landed (Dart determinism, protocol + host reference, Flutter join/lobby/game
screens); Phase 4's Swift host (`RoomHost`, `Net/`, `QR/`, and now a real
`AYSHost.xcodeproj` App/UI shell) also landed and runs live on both macOS
and the tvOS simulator** — only real challenge judging, a second connected
client, and the game-show visual polish (scoreboard, eliminations, winner
animation, humor) remain. See [[Multiplayer Development]] for the
phase-by-phase detail.

- [[Multiplayer Product]] — concept, QR joining, ads, sharing, scope
- [[Multiplayer Gameplay]] — Last Stupid Standing + Stupid Battle, rounds,
  TV presentation, humor
- [[Multiplayer Challenges]] — synchronized seeded challenges + the four
  new families
- [[Multiplayer Architecture]] — topology and host authority
- [[Multiplayer Protocol]] — the versioned wire contract (v1)
- [[Multiplayer Host (tvOS)]] — the native SwiftUI host/display app
- [[Multiplayer Client (Mobile)]] — the Flutter controller app
- [[Multiplayer Development]] — phases, tests, simulation harness

### AI — dynamic game director
Apple Intelligence (Foundation Models) on-device director: AI challenge
generation, commentary, adaptive territory and a multiplayer AI host — all
behind a **validated, scripted-fallback-first** pipeline. Phases 1–2, A, B,
4–9 landed — single-player and multiplayer are both real end-to-end, with
a real Settings UI on top: the `ChallengeProvider` seam, the proposal
vocabulary + validator + on-device bridge ([[Foundation Models
Integration]]), the generic runtime that turns a validated proposal into a
real playable challenge (`lib/ai/generated_challenge_runtime.dart`),
`AiFeatureFlags` + its Settings Ai section (mode picker + availability
copy, translated into all six locales), real on-device commentary +
challenge generation (`@Guide`-constrained schema, snapshot-backed tools),
the pre-generation cache wired into `game_screen.dart`, and the full
multiplayer AI Director: election, a single-slot proposal relay, failover
(`RoomHost.swift`), and `lib/multiplayer/ai/party_ai_director.dart`, the
elected phone's own generation loop, wired into production
`mp_join_screen.dart`. Commentary display in the UI is the one deliberate
gap left in both single- and multiplayer (captured, not shown). **All ten
planned phases have landed**, including Phase 10's full-run integration
test (`test/ai/full_run_with_mock_bridge_test.dart`) exercising the real
production provider composition end to end. Real generation is unverified
on actual hardware (none available here) — the blind-playtest and
real-device evaluation gates ([[Testing and Evaluation]]) stay open until
that's possible — but the whole pipeline compiles, is wired end-to-end,
and is covered by unit/integration tests on both language sides.
Implementation phases are tracked in [[Development Plan]].

- [[Dynamic AI Director]] — the overview and pipeline
- [[Foundation Models Integration]] — the Swift/Dart bridge contract
- [[AI Challenge Generation]] / [[AI Challenge Validator]]
- [[Player Telemetry and Adaptive Difficulty]]
- [[AI Commentary]] / [[Pre-generation Cache]]
- [[Dynamic Profiles and Tool Calling]]
- [[Multiplayer AI Director]]
- [[Feature Flags]] / [[Quality Neutrality and Guardrails]]
- [[Privacy and Offline]] / [[Performance and Resource Budgets]]
- [[Localization and Language]] / [[Error States and Failure Communication]]
- [[AI as Playing Style]] / [[Testing and Evaluation]] / [[Development Plan]]

### Meta
- [[Documentation Rules]] — **mandatory for AI agents**
- [[Decision Log]]

## Status

| Area | State |
|---|---|
| MVP gameplay loop | Done |
| Challenge templates | 39 shipped |
| Persistence (best score, stats, settings) | Done |
| Ads | Real, via AdMob (`AdMobAdProvider`); `MockAdProvider` stays default for tests/local dev |
| Sound / haptics | System sounds + platform haptics |
| Sharing | OS share sheet via `share_plus` |
| Backend | None. On purpose. |
| Multiplayer party mode (Apple TV + macOS board host) | Phases 1–4 landed (Dart + Swift host, `Net/`, `QR/`, App/UI Xcode shell), Phases 5–7's rules landed. **Real challenge judging landed:** the "Phase 4 open question" (can Swift judge a Dart-generated challenge) is resolved by moving judging to the client entirely — `PartyChallengeRunner` drives the real single-player `Challenge` engine and reports the verdict, both hosts trust it (see [[Decision Log]]). Discovery switched to `package:nsd` (native platform APIs) after two real-device bugs. Live standings board, mode picker, and no-downtime round auto-close/advance also landed. Still open: game-show polish (elimination card, winner animation, share card, humor lines — Phase 9) and a fresh real-device pass on the new judging flow. See [[Multiplayer Development]] |
| AI dynamic director (Apple Intelligence) | All ten planned phases landed: `ChallengeProvider` providers in `lib/ai/` incl. a real `AIChallengeProvider`/`PrefetchLoop` wired into `game_screen.dart` (with a starter-level exclusion — see [[Decision Log]]), proposal vocabulary + `ChallengeValidator` + `ays/apple_intelligence` bridge (`available`/`requestCommentary`/`requestChallenge` all real; only `requestFinalRound`/`requestMultiplayerHost` still stubbed, no caller yet), `generated_challenge_runtime.dart`, `AiFeatureFlags` + its Settings Ai section, `lib/ai/commentary.dart`, `lib/ai/profile_for_prompts.dart`, the full multiplayer AI Director (election/relay/failover in `RoomHost.swift`, `lib/multiplayer/ai/party_ai_director.dart` wired into `mp_join_screen.dart`), and a Phase 10 full-run integration test driving the real production composition through a full `GameEngine` match. Real generation unverified on actual hardware (none available here) but the full pipeline compiles and is wired end-to-end. See [[Dynamic AI Director]] / [[Development Plan]] |
| Version control | Git, public on GitHub: `PynkStudio/are-you-stupid` |
| Languages | English, Italian, French, Spanish, Portuguese, German — see [[Localization]] |

## Build status (2026-09-15)

| Target | State |
|---|---|
| `flutter analyze` | clean |
| `flutter test` | 303/303 passing — see [[Testing]] |
| `swift test` (from `tvos/`) | 83 cases (29 protocol + 54 host core), all green; 4 real-socket cases skip by default (`AYS_RUN_NETWORK_TESTS=1` to run for real) — see [[Testing]] |
| Android debug APK | builds |
| Android release APK | builds, signed with a real upload key (not debug) — see [[Release Checklist]] |
| iOS simulator | builds and runs via `flutter run`, hot reload included |

Still open before store submission: app icon, launch screen, entering the
privacy policy URL into App Store Connect / Play Console — see [[Release
Checklist]].
