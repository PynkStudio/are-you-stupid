---
tags: [moc, index]
updated: 2026-09-07
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
mirroring) + phones as controllers over the local network. **Phase 2 (protocol
+ client core + in-process host reference, 32 headless tests) landed;** the
rest below is specification. As it ships, per-phase changes update these notes
(see [[Multiplayer Development]]).

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
behind a **validated, scripted-fallback-first** pipeline. The branch
`ai/dynamic-director` carries the full spec below, plus the **Phase 1
`ChallengeProvider` seam** (scripted floor shipped, no AI behavior on yet);
implementation phases are tracked in [[Development Plan]].

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
| Multiplayer party mode (Apple TV + macOS board host) | Phase 2 landed: wire protocol, client core + in-process host reference, 32 headless tests. Phase 3+ spec'd. See [[Multiplayer Development]] |
| AI dynamic director (Apple Intelligence) | Phase 1 seam landed: `ChallengeProvider` providers in `lib/ai/`; engine consumes the seam, still 100% scripted. No AI behavior yet. See [[Dynamic AI Director]] / [[Development Plan]] |
| Version control | Git, public on GitHub: `PynkStudio/are-you-stupid` |
| Languages | English, Italian, French, Spanish, Portuguese, German — see [[Localization]] |

## Build status (2026-09-07)

| Target | State |
|---|---|
| `flutter analyze` | clean |
| `flutter test` | 95 tests across 12 suites (32 are the multiplayer Phase 2 headless suites), one intermittently flaky — see [[Testing]] |
| Android debug APK | builds |
| Android release APK | builds, signed with a real upload key (not debug) — see [[Release Checklist]] |
| iOS simulator | builds and runs via `flutter run`, hot reload included |

Still open before store submission: app icon, launch screen, entering the
privacy policy URL into App Store Connect / Play Console — see [[Release
Checklist]].
