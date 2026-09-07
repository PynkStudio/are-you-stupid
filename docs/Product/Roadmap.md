---
tags: [product, roadmap]
updated: 2026-09-07
---

# Roadmap

## Shipped (MVP)

- Main menu, 39 challenge templates, random selection, difficulty progression
- Score + best score + stats, Game Over, one-tap retry
- Mock rewarded + interstitial ads, share result
- Settings, system sounds, haptics, local persistence, fully offline

## Next, in rough order of value

1. **Apple TV party mode (multiplayer) — macOS board host included.** A 2–8
   player game hosted on tvOS **or a macOS board-only host (no direct play,
   AirPlay mirror button)** with iPhone/iPad controllers over the local
   network. Phase 2 (wire protocol + client core + in-process host reference)
   is **landed**; full spec in the [[Multiplayer Product]] /
   [[Multiplayer Architecture]] / [[Multiplayer Protocol]] notes; build order in
   [[Multiplayer Development]]. This supersedes the daily-challenge idea below
   as the biggest virality lever.
2. **Real ad SDK** behind the existing `AdProvider` ([[Monetization and Ads]]).
3. **Store polish** — app icon, launch screen, screenshots, store copy.
   The game generates its own visuals, but the store listing needs assets.
4. **More templates.** The cheapest way to add depth: see [[Adding a Challenge]].
5. **Daily challenge** — a seeded run everyone gets the same day. Pure virality,
   still offline (seed = date).
6. **Replay clip export** — record the last 10 s to camera roll. Highest-effort,
   highest-reward for TikTok.
7. **AI dynamic director (Apple Intelligence).** On-device, opt-out only,
   offline-first: generated challenges + commentary behind a validated,
   scripted-fallback pipeline, plus an optional AI host for the party mode.
   **Status: spec only** — the full design is in [[Dynamic AI Director]] and
   the rest of the `docs/AI/` set; there is *no* shipped code and nothing is
   on by default. It stays behind feature flags and the evaluation gates in
   [[Testing and Evaluation]] until it demonstrably only makes the game
   better ([[Quality Neutrality and Guardrails]]). Build order in
   [[Development Plan]]. Requires iOS 26 device-language support and adds no
   network, accounts or analytics.

## Deliberately out of scope

Login, backend, cloud save, online leaderboard, subscriptions, characters, 3D,
external art. See [[Game Design Pillars]] before proposing any of them.

Note: the **multiplayer** slice is also explicitly scoped to keep out online
matchmaking, accounts, cloud saves, global leaderboards, voice/video chat and
cosmetics — any of those is a separate conversation ([[Multiplayer Product]]).

Note: the **AI** slice follows the same discipline — on-device only, no
server, no player identity, no analytics, and the model is never the
authority (validator is). Violating any of that is out of scope
([[Privacy and Offline]]).
