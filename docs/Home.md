---
tags: [moc, index]
updated: 2026-09-06
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

### Product
- [[Monetization and Ads]]
- [[Virality and Sharing]]
- [[Roadmap]]

### Development
- [[Getting Started]]
- [[Adding a Challenge]]
- [[Testing]]
- [[Release Checklist]]

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
| Version control | Git, public on GitHub: `PynkStudio/are-you-stupid` |

## Build status (2026-09-06)

| Target | State |
|---|---|
| `flutter analyze` | clean |
| `flutter test` | 38 tests, one intermittently flaky — see [[Testing]] |
| Android debug APK | builds |
| Android release APK | builds, signed with a real upload key (not debug) — see [[Release Checklist]] |
| iOS simulator | builds and runs via `flutter run`, hot reload included |

Still open before store submission: app icon, launch screen, privacy policy —
see [[Release Checklist]].
